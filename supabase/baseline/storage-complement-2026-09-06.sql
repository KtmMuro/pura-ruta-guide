-- Complement for Supabase Storage. No production files are copied.
-- Apply after production-schema-2026-09-06.sql, only to TEST.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
SELECT
  'pura-ruta-imagenes',
  'pura-ruta-imagenes',
  true,
  52428800,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
WHERE NOT EXISTS (
  SELECT 1 FROM storage.buckets WHERE id = 'pura-ruta-imagenes'
);

DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Authenticated users can upload business images') THEN
    EXECUTE $policy$
      CREATE POLICY "Authenticated users can upload business images"
        ON storage.objects FOR INSERT TO authenticated
        WITH CHECK ((bucket_id = 'pura-ruta-imagenes'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text))
    $policy$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can delete their business images') THEN
    EXECUTE $policy$
      CREATE POLICY "Users can delete their business images"
        ON storage.objects FOR DELETE TO authenticated
        USING ((bucket_id = 'pura-ruta-imagenes'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text))
    $policy$;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Users can update their business images') THEN
    EXECUTE $policy$
      CREATE POLICY "Users can update their business images"
        ON storage.objects FOR UPDATE TO authenticated
        USING ((bucket_id = 'pura-ruta-imagenes'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text))
        WITH CHECK ((bucket_id = 'pura-ruta-imagenes'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text))
    $policy$;
  END IF;
END
$baseline$;
