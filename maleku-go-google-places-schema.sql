-- NO EJECUTAR SIN REVISION
-- Maleku Go — piloto Google Places: preparación de esquema únicamente.
-- No actualiza filas, no modifica image_url y no asigna google_place_id.

begin;

-- FASE 1 — Campos opcionales y compatibles con negocios existentes.
alter table public.businesses
  add column if not exists google_place_id text,
  add column if not exists image_source text,
  add column if not exists external_source text,
  add column if not exists external_updated_at timestamptz;

-- FASE 2 — Valores permitidos para el origen visual de una imagen.
-- NOT VALID conserva compatibilidad con filas existentes; el CHECK se aplica
-- a nuevas escrituras o actualizaciones de image_source.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.businesses'::regclass
      and conname = 'businesses_image_source_check'
  ) then
    alter table public.businesses
      add constraint businesses_image_source_check
      check (
        image_source is null
        or image_source in ('own', 'business', 'google_places')
      ) not valid;
  end if;
end
$$;

commit;

-- FASE 3 — Verificación posterior al ALTER (solo lectura).
select
  column_name,
  data_type,
  is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name = 'businesses'
  and column_name in (
    'google_place_id',
    'image_source',
    'external_source',
    'external_updated_at'
  )
order by column_name;

select
  conname as constraint_name,
  pg_get_constraintdef(oid) as constraint_definition,
  convalidated as validated_for_existing_rows
from pg_constraint
where conrelid = 'public.businesses'::regclass
  and conname = 'businesses_image_source_check';
