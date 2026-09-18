interface Env {
  DEEPSEEK_API_KEY?: string;
  ALLOWED_ORIGINS?: string;
  MAX_DAILY_REQUESTS?: string;
  COACH_COORDINATOR: DurableObjectNamespace;
}
