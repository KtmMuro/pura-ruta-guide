-- NO EJECUTAR SIN REVISION
-- Maleku Go — preparación idempotente de catálogo productivo.
-- Este archivo no contiene valores comerciales inventados.
-- Estado actual: fases de lectura/validación y plantillas comentadas.
-- Puede ejecutarse sin mutar datos: el bloque activo solo informa resolución de duplicados.

begin;

-- FASE 0 — INVENTARIO DE NOMBRES Y RESOLUCIÓN DE DUPLICADOS
-- No usa UUIDs inventados. La identidad se resuelve por nombre normalizado.
with catalog_targets(name, category, source_status) as (
  values
    ('Nayara Gardens', 'Hospedaje', 'existing'),
    ('Volcano Lodge Hotel & Thermal Experience', 'Hospedaje', 'existing'),
    ('Mistico Arenal Hanging Bridges Park', 'Naturaleza', 'existing'),
    ('Los Lagos', 'Hospedaje', 'missing_data'),
    ('Arenal Springs', 'Hospedaje', 'missing_data'),
    ('Royal Corin', 'Hospedaje', 'missing_data'),
    ('Arenal Kioro', 'Hospedaje', 'missing_data'),
    ('Lomas del Volcán', 'Hospedaje', 'missing_data'),
    ('Arenal Observatory', 'Hospedaje', 'missing_data'),
    ('Tabacón', 'Hospedaje', 'missing_data'),
    ('Asha Hostel', 'Hospedaje', 'missing_data'),
    ('Volcán Arenal', 'Naturaleza', 'missing_data'),
    ('Río Celeste', 'Naturaleza', 'missing_data'),
    ('Catarata La Fortuna', 'Naturaleza', 'missing_data'),
    ('ATV', 'Aventura', 'missing_data'),
    ('Rafting Balsa', 'Aventura', 'missing_data'),
    ('Cavernas de Venado', 'Aventura', 'missing_data'),
    ('Observación de Aves', 'Vida silvestre', 'missing_data'),
    ('Safari Float', 'Vida silvestre', 'missing_data'),
    ('Tour de Café y Chocolate', 'Cultura', 'missing_data'),
    ('Tour de Chocolate', 'Cultura', 'missing_data'),
    ('Don Juan', 'Cultura', 'missing_data')
)
select
  target.name as catalog_name,
  target.category as requested_category,
  target.source_status,
  business.id as existing_business_id,
  business.is_active,
  business.is_verified
from catalog_targets as target
left join public.businesses as business
  on lower(trim(business.name)) = lower(trim(target.name))
order by target.name;

-- FASE 1 — NEGOCIOS
-- INTENCIONALMENTE SIN INSERT ACTIVO.
-- Los 19 nombres sin negocio existente carecen de al menos ubicación,
-- tarifa, horario o evidencia comercial. No se publican placeholders.
-- Una vez que cada fila esté verificada, usar el patrón idempotente siguiente:
/*
with approved_businesses (
  name, category, description, budget_level, latitude, longitude,
  image_url, is_active, is_verified
) as (
  values
    -- Agregar únicamente filas con evidencia aprobada. No usar URL ficticia.
    -- ('Nombre verificado', 'Categoría', null, null, 0, 0, null, true, true)
)
insert into public.businesses (
  name, category, description, budget_level, latitude, longitude,
  image_url, is_active, is_verified
)
select
  source.name, source.category, source.description, source.budget_level,
  source.latitude, source.longitude, source.image_url,
  source.is_active, source.is_verified
from approved_businesses as source
where not exists (
  select 1
  from public.businesses as target
  where lower(trim(target.name)) = lower(trim(source.name))
);
*/

-- FASE 2 — EXPERIENCIAS
-- No insertar experiencias hasta identificar el proveedor real con business_id.
-- Resolver relaciones por el negocio existente, nunca con UUIDs predefinidos.
/*
with approved_experiences (
  provider_name, name, category, experience_type, schedule_type,
  duration_minutes, is_active, is_bookable, requires_reservation
) as (
  values
    -- ('Proveedor verificado', 'Experiencia verificada', 'Categoría',
    --  'nature', 'open_hours', 180, true, true, true)
), business_map as (
  select source.*, business.id as business_id
  from approved_experiences as source
  join public.businesses as business
    on lower(trim(business.name)) = lower(trim(source.provider_name))
)
insert into public.business_experiences (
  business_id, name, category, experience_type, schedule_type,
  duration_minutes, is_active, is_bookable, requires_reservation
)
select
  source.business_id, source.name, source.category, source.experience_type,
  source.schedule_type, source.duration_minutes, source.is_active,
  source.is_bookable, source.requires_reservation
from business_map as source
where not exists (
  select 1
  from public.business_experiences as target
  where target.business_id = source.business_id
    and lower(trim(target.name)) = lower(trim(source.name))
);
*/

-- FASE 3 — TARIFAS
-- Sin precios, moneda, unidad, impuesto y fuente verificables no hay INSERT.
-- Usar business_rates para hospedaje/negocio y experience_rates para tours.
/*
-- Patrón: buscar business_id / experience_id por nombre normalizado,
-- insertar solamente si no existe una tarifa equivalente activa.
*/

-- FASE 4 — HORARIOS Y SALIDAS
-- No insertar business_hours, experience_schedules o business_departures
-- sin fuente operativa actualizada y día/hora verificables.

-- FASE 5 — IMÁGENES
-- No actualizar businesses.image_url hasta que el objeto exista en
-- storage.objects dentro de pura-ruta-imagenes y haya sido revisado.

commit;

