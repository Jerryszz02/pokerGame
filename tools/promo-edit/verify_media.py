#!/usr/bin/env python3
"""Measure exported videos without modifying them or judging editorial quality.

Example (use the bundled Python runtime for Pillow contact sheets)::

    python3 verify_media.py trailer.mp4 shorts.mp4 --output-dir out/verification \
        --cut 4 --cut 8 --cut 14

All timestamps are seconds from the start of the file. Additional cuts apply to
each input; out-of-range cuts are ignored. Each cut samples one frame before,
at, and after the cut. Black/silent intervals are observations, not failures.
Exit 1 means a measurement failed, a video stream is missing, or decode errors
were found. Exit 0 is not an editorial approval or a loudness compliance claim.
"""

import argparse
from datetime import datetime, timezone
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys

SHOTCUT = Path('/Applications/Shotcut.app/Contents/MacOS')
NUMBER = r'[-+\d.eE]+'


def run(command, timeout):
    try:
        result = subprocess.run([str(item) for item in command], capture_output=True,
                                text=True, encoding='utf-8', errors='replace',
                                timeout=timeout)
        return {'returncode': result.returncode, 'stdout': result.stdout,
                'stderr': result.stderr, 'timed_out': False}
    except subprocess.TimeoutExpired as error:
        def as_text(value):
            return value.decode('utf-8', errors='replace') if isinstance(value, bytes) else value or ''
        return {'returncode': None, 'stdout': as_text(error.stdout),
                'stderr': as_text(error.stderr), 'timed_out': True}
    except OSError as error:
        return {'returncode': None, 'stdout': '', 'stderr': str(error), 'timed_out': False}


def number(value):
    try:
        parsed = float(value)
        return parsed if math.isfinite(parsed) else None
    except (ValueError, TypeError):
        return None


def rate(value):
    try:
        return float(Fraction(value))
    except (ValueError, ZeroDivisionError, TypeError):
        return None


def log_result(directory, name, result):
    path = directory / (name + '.log')
    path.write_text(result['stdout'] + '\n' + result['stderr'], encoding='utf-8')
    return {'status': 'ok' if result['returncode'] == 0 else 'error',
            'returncode': result['returncode'], 'timed_out': result['timed_out'],
            'log': str(path)}


def parse_loudness(text):
    for block in reversed(re.findall(r'\{[^{}]*\}', text)):
        try:
            value = json.loads(block)
        except json.JSONDecodeError:
            continue
        if 'input_i' in value:
            # Keep the original strings: FFmpeg reports silence as "-inf".
            return value
    return None


def parse_silence(text, duration):
    intervals = []
    start = None
    events = re.finditer(r'silence_(start|end):\s*(' + NUMBER + ')', text)
    for event in events:
        value = float(event.group(2))
        if event.group(1) == 'start':
            start = value
        elif start is not None:
            intervals.append({'start': start, 'end': value, 'duration': value - start})
            start = None
    if start is not None:
        intervals.append({'start': start, 'end': duration,
                          'duration': max(0, duration - start) if duration is not None else None,
                          'end_inferred_from_stream_duration': True})
    return intervals


def parse_black(text):
    pattern = (r'black_start:(' + NUMBER + r')\s+black_end:(' + NUMBER
               + r')\s+black_duration:(' + NUMBER + ')')
    return [dict(zip(('start', 'end', 'duration'), map(float, match)))
            for match in re.findall(pattern, text)]


def sample_times(duration, fps, interval, cuts):
    times = {}
    def add(value, reason):
        if 0 <= value < duration:
            key = round(value, 6)
            times.setdefault(key, set()).add(reason)
    for index in range(math.ceil(duration / interval)):
        add(index * interval, 'interval')
    frame = 1 / fps if fps else 1 / 30
    add(max(0, duration - frame), 'last_frame')
    for cut in cuts:
        if 0 <= cut < duration:
            add(cut - frame, 'before_cut')
            add(cut, 'cut')
            add(cut + frame, 'after_cut')
    return [(value, sorted(reasons)) for value, reasons in sorted(times.items())]


def contact_sheets(frames, directory):
    from PIL import Image, ImageDraw, ImageFont
    outputs = []
    width, height, label_height = 320, 200, 36
    columns, rows = 4, 5
    font = ImageFont.load_default(size=14)
    for offset in range(0, len(frames), columns * rows):
        page = frames[offset:offset + columns * rows]
        used_rows = math.ceil(len(page) / columns)
        sheet = Image.new('RGB', (columns * width, used_rows * (height + label_height)), '#171a1c')
        draw = ImageDraw.Draw(sheet)
        for index, frame in enumerate(page):
            x, y = (index % columns) * width, (index // columns) * (height + label_height)
            with Image.open(frame['path']) as picture:
                picture.thumbnail((width, height))
                sheet.paste(picture, (x + (width - picture.width) // 2,
                                     y + (height - picture.height) // 2))
            label = f"{frame['time']:.3f}s | {','.join(frame['reasons'])}"
            draw.text((x + 5, y + height + 4), label, fill='white', font=font)
        path = directory / f'contact-{len(outputs) + 1:02d}.jpg'
        sheet.save(path, quality=92)
        outputs.append(str(path))
    return outputs


def inspect_video(source, directory, args):
    directory.mkdir(parents=True, exist_ok=True)
    report = {'input': str(source), 'output_directory': str(directory), 'errors': []}
    probe = run([args.ffprobe, '-v', 'error', '-show_format', '-show_streams',
                 '-of', 'json', source], args.timeout)
    report['probe'] = log_result(directory, 'ffprobe', probe)
    if probe['returncode'] != 0:
        report['errors'].append('ffprobe failed; see ffprobe.log')
        return report
    try:
        metadata = json.loads(probe['stdout'])
    except json.JSONDecodeError:
        report['errors'].append('ffprobe did not return valid JSON')
        return report
    (directory / 'ffprobe.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    videos = [stream for stream in metadata.get('streams', [])
              if stream.get('codec_type') == 'video' and not stream.get('disposition', {}).get('attached_pic')]
    audios = [stream for stream in metadata.get('streams', []) if stream.get('codec_type') == 'audio']
    report['metadata'] = metadata
    report['video_streams'] = [{key: stream.get(key) for key in (
        'index', 'codec_name', 'profile', 'width', 'height', 'pix_fmt', 'r_frame_rate',
        'avg_frame_rate', 'duration', 'nb_frames', 'color_space', 'color_transfer', 'color_primaries')}
        | {'fps': rate(stream.get('avg_frame_rate'))} for stream in videos]
    report['audio_streams'] = [{key: stream.get(key) for key in (
        'index', 'codec_name', 'sample_rate', 'channels', 'channel_layout', 'duration')}
        for stream in audios]
    duration = number(metadata.get('format', {}).get('duration'))
    report['duration'] = duration
    if not videos:
        report['errors'].append('No playable video stream')
        return report
    video = videos[0]
    video_duration = number(video.get('duration')) or duration
    fps = rate(video.get('avg_frame_rate')) or rate(video.get('r_frame_rate'))

    base = [args.ffmpeg, '-nostdin', '-hide_banner', '-nostats']
    decoded = run(base + ['-v', 'error', '-err_detect', 'explode', '-i', source,
                         '-map', '0:v?', '-map', '0:a?', '-progress', 'pipe:1',
                         '-f', 'null', '-'], args.timeout)
    report['decode'] = log_result(directory, 'decode', decoded)
    report['decode']['error_lines'] = [line for line in decoded['stderr'].splitlines() if line.strip()]
    report['decode']['progress_complete'] = 'progress=end' in decoded['stdout']
    progress = dict(line.split('=', 1) for line in decoded['stdout'].splitlines() if '=' in line)
    report['decode']['last_progress'] = progress
    if decoded['returncode'] != 0 or decoded['stderr'].strip() or not report['decode']['progress_complete']:
        report['decode']['status'] = 'error'
        report['errors'].append('Full decode reported an error or did not finish; see decode.log')

    black_filter = f'blackdetect=d={args.black_duration}:pix_th={args.black_pixel_threshold}:pic_th={args.black_picture_threshold}'
    black = run(base + ['-v', 'info', '-i', source, '-map', f"0:{video['index']}",
                        '-an', '-vf', black_filter, '-f', 'null', '-'], args.timeout)
    report['blackdetect'] = log_result(directory, 'blackdetect', black)
    report['blackdetect'].update({'stream_index': video['index'], 'filter': black_filter,
                                 'intervals': parse_black(black['stderr'])})
    if black['returncode'] != 0:
        report['errors'].append('Black detection failed; see blackdetect.log')

    report['audio_measurements'] = []
    for stream in audios:
        index = stream['index']
        audio_filter = (f'silencedetect=noise={args.silence_db}dB:d={args.silence_duration},'
                        'loudnorm=I=-16:TP=-1:LRA=11:print_format=json')
        result = run(base + ['-v', 'info', '-i', source, '-map', f'0:{index}', '-vn',
                            '-af', audio_filter, '-f', 'null', '-'], args.timeout)
        entry = log_result(directory, f'audio-{index}', result)
        entry.update({'stream_index': index, 'filter': audio_filter,
                      'loudnorm_target': {'integrated_lufs': -16, 'true_peak_dbtp': -1, 'lra_lu': 11},
                      'loudnorm': parse_loudness(result['stderr']),
                      'silence_intervals': parse_silence(result['stderr'], number(stream.get('duration')) or duration)})
        report['audio_measurements'].append(entry)
        if result['returncode'] != 0 or entry['loudnorm'] is None:
            entry['status'] = 'error'
            report['errors'].append(f'Audio stream {index} measurement failed; see audio-{index}.log')
    if not audios:
        report['audio_note'] = 'No audio stream; loudness and silence measurements are not applicable.'

    report['frames'] = []
    report['contact_sheets'] = []
    if not args.no_frames:
        if not video_duration or video_duration <= 0:
            report['errors'].append('Unknown video duration; frame sampling skipped')
        else:
            frame_directory = directory / 'frames'
            frame_directory.mkdir(exist_ok=True)
            for index, (time, reasons) in enumerate(sample_times(video_duration, fps, args.interval, args.cut)):
                path = frame_directory / f'{index:04d}-{time:010.3f}s.jpg'
                result = run(base + ['-v', 'error', '-ss', f'{time:.6f}', '-i', source,
                                     '-map', f"0:{video['index']}", '-frames:v', '1', '-q:v', '2',
                                     '-update', '1', '-y', path], args.timeout)
                if result['returncode'] != 0 or not path.is_file() or path.stat().st_size == 0:
                    log_result(directory, f'frame-{index:04d}', result)
                    report['errors'].append(f'Frame extraction failed at {time:.6f}s')
                else:
                    report['frames'].append({'time': time, 'reasons': reasons, 'path': str(path)})
            if not args.no_contact_sheet and report['frames']:
                try:
                    report['contact_sheets'] = contact_sheets(report['frames'], directory)
                except (ImportError, OSError) as error:
                    report['errors'].append(f'Contact sheet failed: {error}; use the bundled Python with Pillow')
    return report


def summary(reports):
    lines = ['Media measurement summary', '',
             'Observations only: black/silent intervals and loudness values require review.',
             'The loudnorm target is a measurement reference; no source media was changed.', '']
    for report in reports:
        lines.append(f"File: {report['input']}")
        lines.append(f"Duration: {report.get('duration', 'unknown')} seconds")
        for video in report.get('video_streams', []):
            lines.append(f"Video {video['index']}: {video['width']}x{video['height']}, {video['fps']} fps, {video['codec_name']}, {video['pix_fmt']}")
        lines.append(f"Audio streams: {len(report.get('audio_streams', []))}")
        lines.append(f"Full decode: {report.get('decode', {}).get('status', 'not run')}")
        lines.append(f"Black intervals: {json.dumps(report.get('blackdetect', {}).get('intervals', []))}")
        for audio in report.get('audio_measurements', []):
            loudness = audio.get('loudnorm') or {}
            lines.append(f"Audio {audio['stream_index']}: integrated {loudness.get('input_i', 'unknown')} LUFS, true peak {loudness.get('input_tp', 'unknown')} dBTP, LRA {loudness.get('input_lra', 'unknown')} LU")
            lines.append(f"Silence intervals: {json.dumps(audio['silence_intervals'])}")
        lines.append(f"Frames: {len(report.get('frames', []))}; contact sheets: {len(report.get('contact_sheets', []))}")
        lines.extend('ERROR: ' + error for error in report['errors'])
        lines.extend([f"Evidence: {report['output_directory']}", ''])
    return '\n'.join(lines)


def positive(value):
    parsed = float(value)
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError('must be a positive finite number')
    return parsed


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('videos', type=Path, nargs='+')
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--ffmpeg', type=Path, default=SHOTCUT / 'ffmpeg')
    parser.add_argument('--ffprobe', type=Path, default=SHOTCUT / 'ffprobe')
    parser.add_argument('--timeout', type=positive, default=600, help='seconds per subprocess')
    parser.add_argument('--interval', type=positive, default=2, help='sample every N seconds (default: 2)')
    parser.add_argument('--cut', type=float, action='append', default=[], help='extra cut timestamp; repeatable')
    parser.add_argument('--no-frames', action='store_true', help='skip frames and contact sheets')
    parser.add_argument('--no-contact-sheet', action='store_true', help='extract frames only')
    parser.add_argument('--black-duration', type=positive, default=0.1)
    parser.add_argument('--black-pixel-threshold', type=float, default=0.10)
    parser.add_argument('--black-picture-threshold', type=float, default=0.98)
    parser.add_argument('--silence-db', type=float, default=-50)
    parser.add_argument('--silence-duration', type=positive, default=0.5)
    args = parser.parse_args()
    for value in (args.black_pixel_threshold, args.black_picture_threshold):
        if not 0 <= value <= 1:
            parser.error('black thresholds must be between 0 and 1')
    if any(not math.isfinite(value) or value < 0 for value in args.cut):
        parser.error('--cut must be finite and non-negative')
    if not math.isfinite(args.silence_db):
        parser.error('--silence-db must be finite')
    for path in args.videos:
        if not path.is_file():
            parser.error(f'input file does not exist: {path}')
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    reports = []
    for path in args.videos:
        source = path.resolve()
        slug = re.sub(r'[^a-zA-Z0-9_.-]+', '-', source.stem).strip('-') or 'video'
        identity = hashlib.sha256(str(source).encode()).hexdigest()[:8]
        print(f'Measuring {source.name}', flush=True)
        report = inspect_video(source, output / f'{slug}-{identity}', args)
        reports.append(report)
        (Path(report['output_directory']) / 'report.json').write_text(
            json.dumps(report, indent=2, ensure_ascii=False, allow_nan=False) + '\n', encoding='utf-8')
    payload = {'generated_at': datetime.now(timezone.utc).isoformat(), 'schema_version': 1,
               'scope': 'objective measurements, not editorial approval',
               'ffmpeg': str(args.ffmpeg), 'ffprobe': str(args.ffprobe), 'videos': reports}
    (output / 'report.json').write_text(json.dumps(payload, indent=2, ensure_ascii=False, allow_nan=False) + '\n', encoding='utf-8')
    text = summary(reports)
    (output / 'summary.txt').write_text(text, encoding='utf-8')
    print(text)
    return int(any(report['errors'] for report in reports))


if __name__ == '__main__':
    sys.exit(main())
