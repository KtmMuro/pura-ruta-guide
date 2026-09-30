-- Complement for the Supabase-managed auth schema.
-- Apply after production-schema-2026-09-06.sql, only to TEST.
-- Does not recreate auth.users.

DO $baseline$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'on_auth_user_created'
      AND tgrelid = 'auth.users'::regclass
      AND NOT tgisinternal
  ) THEN
    EXECUTE $trigger$
      CREATE TRIGGER on_auth_user_created
        AFTER INSERT ON auth.users
        FOR EACH ROW EXECUTE FUNCTION public.handle_new_user()
    $trigger$;
  END IF;
END
$baseline$;
