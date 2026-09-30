-- Maleku Go — esquema sincronizado y verificado manualmente
-- Fecha: 2026-09-15
--
-- Este archivo refleja el estado aplicado y verificado en Supabase el 15/09/2026.
-- No borra datos, no cambia App.js y no se ejecuta automáticamente.
-- También es defensivo para una instalación histórica o nueva.
--
-- La FK business_meal_services.experience_id ya fue revisada y validada en la
-- instancia de referencia. Si falta en otra instancia, este script valida las
-- referencias antes de crearla.

begin;

-- ============================================================================
-- 0. PREFLIGHT NO DESTRUCTIVO
-- ============================================================================

select
  'business_meal_services.experience_id sin experience válida' as check_name,
  count(*) as row_count
from public.business_meal_services ms
left join public.business_experiences e on e.id = ms.experience_id
where ms.experience_id is not null
  and e.id is null;

select
  ms.id,
  ms.business_id,
  ms.experience_id,
  ms.meal_type,
  ms.service_type,
  ms.is_active
from public.business_meal_services ms
where ms.experience_id is not null
order by ms.id;

-- Muestra políticas permisivas ya existentes. No se eliminan ni sustituyen
-- automáticamente porque podrían corresponder a una decisión de producto.
select
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'business_meal_services',
    'business_transport_routes',
    'business_hours',
    'business_departures',
    'businesses'
  )
order by tablename, policyname;

-- ============================================================================
-- 1. SINCRONIZACIÓN ESTRUCTURAL
-- ============================================================================

-- Campos que el select maestro de App.js usa para planificación y hospedaje.
alter table public.businesses
  add column if not exists planning_role text,
  add column if not exists check_in_time time without time zone,
  add column if not exists check_out_time time without time zone;

-- La ruta open_hours de las experiences lo solicita explícitamente.
alter table public.business_experiences
  add column if not exists last_entry_time time without time zone;

-- Fiscalidad: NULL conserva "impuesto pendiente/desconocido"; nunca significa 0.
alter table public.business_rates
  add column if not exists tax_rate numeric(7,6);

alter table public.experience_rates
  add column if not exists tax_rate numeric(7,6);

-- Contrato mínimo de servicios de comida. IF NOT EXISTS no altera una tabla real
-- ya existente; las columnas posteriores completan instalaciones históricas.
create table if not exists public.business_meal_services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  experience_id uuid,
  meal_type text not null,
  service_type text not null,
  start_time time without time zone,
  end_time time without time zone,
  price numeric(12,2),
  price_currency text,
  price_unit text,
  requires_reservation boolean not null default false,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.business_meal_services
  add column if not exists experience_id uuid,
  add column if not exists meal_type text,
  add column if not exists service_type text,
  add column if not exists start_time time without time zone,
  add column if not exists end_time time without time zone,
  add column if not exists price numeric(12,2),
  add column if not exists price_currency text,
  add column if not exists price_unit text,
  add column if not exists requires_reservation boolean not null default false,
  add column if not exists notes text,
  add column if not exists is_active boolean not null default true;

-- Contrato mínimo para el embed PostgREST usado por App.js.
create table if not exists public.business_transport_routes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null,
  route_name text,
  origin_type text,
  origin_business_id uuid,
  origin_name text,
  origin_latitude double precision,
  origin_longitude double precision,
  destination_type text,
  destination_business_id uuid,
  destination_name text,
  destination_latitude double precision,
  destination_longitude double precision,
  price numeric(12,2),
  currency text,
  price_unit text,
  tax_included boolean,
  tax_rate numeric(7,6),
  is_round_trip boolean not null default false,
  is_included boolean not null default false,
  requires_reservation boolean not null default false,
  min_people integer,
  max_people integer,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.business_transport_routes
  add column if not exists tax_included boolean,
  add column if not exists tax_rate numeric(7,6);

-- ============================================================================
-- 2. FK, ÍNDICES Y VERIFICACIONES DE INTEGRIDAD
-- ============================================================================

do $sync$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'business_meal_services_business_id_fkey'
      and conrelid = 'public.business_meal_services'::regclass
  ) then
    alter table public.business_meal_services
      add constraint business_meal_services_business_id_fkey
      foreign key (business_id) references public.businesses(id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'business_transport_routes_business_id_fkey'
      and conrelid = 'public.business_transport_routes'::regclass
  ) then
    alter table public.business_transport_routes
      add constraint business_transport_routes_business_id_fkey
      foreign key (business_id) references public.businesses(id)
      on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'business_transport_routes_origin_business_id_fkey'
      and conrelid = 'public.business_transport_routes'::regclass
  ) then
    alter table public.business_transport_routes
      add constraint business_transport_routes_origin_business_id_fkey
      foreign key (origin_business_id) references public.businesses(id)
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'business_transport_routes_destination_business_id_fkey'
      and conrelid = 'public.business_transport_routes'::regclass
  ) then
    alter table public.business_transport_routes
      add constraint business_transport_routes_destination_business_id_fkey
      foreign key (destination_business_id) references public.businesses(id)
      on delete set null;
  end if;

  if exists (
    select 1
    from public.business_meal_services ms
    left join public.business_experiences e on e.id = ms.experience_id
    where ms.experience_id is not null and e.id is null
  ) then
    raise exception 'No se puede crear business_meal_services_experience_id_fkey: existen experience_id huérfanos.';
  elsif not exists (
    select 1 from pg_constraint
    where conname = 'business_meal_services_experience_id_fkey'
      and conrelid = 'public.business_meal_services'::regclass
  ) then
    alter table public.business_meal_services
      add constraint business_meal_services_experience_id_fkey
      foreign key (experience_id) references public.business_experiences(id)
      on delete cascade;
  elsif exists (
    select 1 from pg_constraint
    where conname = 'business_meal_services_experience_id_fkey'
      and conrelid = 'public.business_meal_services'::regclass
      and not convalidated
  ) then
    alter table public.business_meal_services
      validate constraint business_meal_services_experience_id_fkey;
  end if;
end
$sync$;

create index if not exists idx_business_meal_services_business_active
  on public.business_meal_services (business_id, is_active);
create index if not exists idx_business_meal_services_experience_active
  on public.business_meal_services (experience_id, is_active)
  where experience_id is not null;
create index if not exists idx_business_transport_routes_business_active
  on public.business_transport_routes (business_id, active);
create index if not exists idx_business_transport_routes_origin_business
  on public.business_transport_routes (origin_business_id)
  where origin_business_id is not null;
create index if not exists idx_business_transport_routes_destination_business
  on public.business_transport_routes (destination_business_id)
  where destination_business_id is not null;

-- ============================================================================
-- 3. RLS Y POLÍTICAS VERIFICADAS
-- ============================================================================

alter table public.business_meal_services enable row level security;
alter table public.business_transport_routes enable row level security;
alter table public.business_hours enable row level security;
alter table public.business_departures enable row level security;

-- Solo se eliminan los nombres alternativos que introducía la versión previa de
-- este mismo archivo. No se toca ninguna otra política existente.
drop policy if exists "Maleku tourist reads active meal services" on public.business_meal_services;
drop policy if exists "Maleku owners manage meal services" on public.business_meal_services;
drop policy if exists "Maleku tourist reads active transport routes" on public.business_transport_routes;
drop policy if exists "Maleku owners manage transport routes" on public.business_transport_routes;
drop policy if exists "Maleku tourist reads active business hours" on public.business_hours;
drop policy if exists "Maleku owners manage business hours" on public.business_hours;
drop policy if exists "Maleku tourist reads active business departures" on public.business_departures;
drop policy if exists "Maleku owners manage business departures" on public.business_departures;

-- Se recrean solo las ocho políticas de este contrato para que una instancia
-- histórica no conserve una definición anterior con el mismo nombre.
drop policy if exists "Horarios visibles de negocios activos" on public.business_hours;
create policy "Horarios visibles de negocios activos"
  on public.business_hours for select to anon, authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_hours.business_id
        and (b.is_active = true or b.owner_id = auth.uid())
    )
  );

drop policy if exists "Propietario administra horarios propios" on public.business_hours;
create policy "Propietario administra horarios propios"
  on public.business_hours for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_hours.business_id
        and b.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_hours.business_id
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Salidas visibles de negocios activos" on public.business_departures;
create policy "Salidas visibles de negocios activos"
  on public.business_departures for select to anon, authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_departures.business_id
        and (b.is_active = true or b.owner_id = auth.uid())
    )
  );

drop policy if exists "Propietario administra salidas propias" on public.business_departures;
create policy "Propietario administra salidas propias"
  on public.business_departures for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_departures.business_id
        and b.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_departures.business_id
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Comidas visibles de negocios activos" on public.business_meal_services;
create policy "Comidas visibles de negocios activos"
  on public.business_meal_services for select to anon, authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_meal_services.business_id
        and (
          (b.is_active = true and business_meal_services.is_active = true)
          or b.owner_id = auth.uid()
        )
    )
  );

drop policy if exists "Propietario administra comidas propias" on public.business_meal_services;
create policy "Propietario administra comidas propias"
  on public.business_meal_services for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_meal_services.business_id
        and b.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_meal_services.business_id
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Rutas visibles de negocios activos" on public.business_transport_routes;
create policy "Rutas visibles de negocios activos"
  on public.business_transport_routes for select to anon, authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_transport_routes.business_id
        and (
          (b.is_active = true and business_transport_routes.active = true)
          or b.owner_id = auth.uid()
        )
    )
  );

drop policy if exists "Propietario administra rutas propias" on public.business_transport_routes;
create policy "Propietario administra rutas propias"
  on public.business_transport_routes for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_transport_routes.business_id
        and b.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_transport_routes.business_id
        and b.owner_id = auth.uid()
    )
  );

-- ============================================================================
-- 4. GRANT / REVOKE
-- ============================================================================
-- Se revoca también de PUBLIC porque anon/authenticated pueden heredarlo.
revoke all privileges on table
  public.business_meal_services,
  public.business_transport_routes,
  public.business_hours,
  public.business_departures
from public, anon, authenticated;

grant select on table
  public.business_meal_services,
  public.business_transport_routes,
  public.business_hours,
  public.business_departures
to anon, authenticated;

grant insert, update, delete on table
  public.business_meal_services,
  public.business_transport_routes,
  public.business_hours,
  public.business_departures
to authenticated;

-- ============================================================================
-- 5. VERIFICACIONES FINALES (LECTURA SOLAMENTE)
-- ============================================================================

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'business_meal_services',
    'business_transport_routes',
    'business_hours',
    'business_departures'
  )
order by c.relname;

select
  conrelid::regclass::text as table_name,
  conname as constraint_name,
  convalidated,
  pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid in (
  'public.business_meal_services'::regclass,
  'public.business_transport_routes'::regclass
)
  and contype = 'f'
order by table_name, constraint_name;

select
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'business_meal_services',
    'business_transport_routes',
    'business_hours',
    'business_departures'
  )
order by tablename, policyname;

select
  table_name,
  grantee,
  privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in (
    'business_meal_services',
    'business_transport_routes',
    'business_hours',
    'business_departures'
  )
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;

commit;
