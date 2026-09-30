-- Catalog-only structural baseline generated from production on 2026-09-07.
-- Source project: pura-ruta-guide (production). No data rows are included.
-- Excluded historical backups: businesses_backup_20260824, businesses_backup_20260830_cleanup, businesses_location_backup_20260901.
-- Apply only to a fresh Supabase TEST project after review.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

                                                  CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

                                                  CREATE OR REPLACE FUNCTION public.generar_itinerario(p_total_budget numeric, p_days integer, p_adults integer DEFAULT 1, p_children integer DEFAULT 0, p_seniors integer DEFAULT 0, p_pets integer DEFAULT 0, p_preferences text[] DEFAULT NULL::text[])
 RETURNS json
 LANGUAGE plpgsql
AS $function$
declare
  v_persons int;
  v_per_person numeric;
  v_tier record;
  v_hospedaje_budget numeric;
  v_alimentacion_budget numeric;
  v_transporte_budget numeric;
  v_tours_budget numeric;
  v_night_budget numeric;
  v_hotel record;
  v_meal_budget numeric;
  v_restaurante record;
  v_rentacar record;
  v_tour_budget_per_day numeric;
  v_tours json[] := '{}';
  v_day int;
  v_pref text;
  v_tour record;
  v_total_estimated numeric := 0;
begin
  v_persons := greatest(p_adults + p_children + p_seniors, 1);
  v_per_person := p_total_budget / v_persons;

  -- 1) Determinar el nivel de presupuesto (budget_tiers es editable sin tocar código)
  select * into v_tier
  from budget_tiers
  where v_per_person >= min_total_per_person
    and (max_total_per_person is null or v_per_person <= max_total_per_person)
  limit 1;

  if v_tier.tier is null then
    select * into v_tier from budget_tiers order by min_total_per_person desc limit 1;
  end if;

  v_hospedaje_budget := p_total_budget * v_tier.pct_hospedaje / 100;
  v_alimentacion_budget := p_total_budget * v_tier.pct_alimentacion / 100;
  v_transporte_budget := p_total_budget * v_tier.pct_transporte / 100;
  v_tours_budget := p_total_budget * v_tier.pct_tours / 100;

  -- 2) Hospedaje: elegir el mejor hotel que quepa en el presupuesto por noche
  --    (usa el PRECIO REAL, no la etiqueta bajo/medio/premium)
  v_night_budget := v_hospedaje_budget / greatest(p_days, 1);

  select b.id, b.name, bp.price_min, bp.price_max
  into v_hotel
  from businesses b
  join business_prices bp on bp.business_id = b.id and bp.price_type = 'per_night' and bp.active
  where b.category = 'Hospedaje' and b.is_active
    and bp.price_min <= v_night_budget
  order by bp.price_max desc
  limit 1;

  if v_hotel.id is null then
    -- Si nada entra en el presupuesto, ofrecer la opción más barata disponible
    select b.id, b.name, bp.price_min, bp.price_max
    into v_hotel
    from businesses b
    join business_prices bp on bp.business_id = b.id and bp.price_type = 'per_night' and bp.active
    where b.category = 'Hospedaje' and b.is_active
    order by bp.price_min asc
    limit 1;
  end if;

  -- 3) Alimentación: presupuesto por comida (2 comidas/día por persona)
  v_meal_budget := v_alimentacion_budget / greatest(p_days * 2 * v_persons, 1);

  select b.id, b.name, bp.price_min, bp.price_max
  into v_restaurante
  from businesses b
  join business_prices bp on bp.business_id = b.id and bp.price_type = 'per_person_meal' and bp.active
  where b.category = 'Restaurante' and b.is_active
    and bp.price_min <= v_meal_budget
  order by bp.price_max desc
  limit 1;

  if v_restaurante.id is null then
    select b.id, b.name, bp.price_min, bp.price_max
    into v_restaurante
    from businesses b
    join business_prices bp on bp.business_id = b.id and bp.price_type = 'per_person_meal' and bp.active
    where b.category = 'Restaurante' and b.is_active
    order by bp.price_min asc
    limit 1;
  end if;

  -- 4) Rent a car (todo el viaje, si el presupuesto de transporte alcanza)
  select b.id, b.name, bp.price_min, bp.price_max
  into v_rentacar
  from businesses b
  join business_prices bp on bp.business_id = b.id and bp.price_type = 'per_day_rental' and bp.active
  where b.category = 'Renta' and b.is_active
    and bp.price_min * p_days <= v_transporte_budget
  order by bp.price_max desc
  limit 1;

  -- 5) Tours: uno por día, rotando entre las categorías de interés del turista
  --    (usa las categorías REALES: Naturaleza, Aventura, Vida Silvestre, Cultura, Tours)
  v_tour_budget_per_day := v_tours_budget / greatest(p_days, 1) / v_persons;

  if p_preferences is null or array_length(p_preferences, 1) is null then
    p_preferences := array['Naturaleza','Aventura','Vida Silvestre','Cultura','Tours'];
  end if;

  for v_day in 1..p_days loop
    v_pref := p_preferences[1 + mod(v_day - 1, array_length(p_preferences, 1))];

    select b.id, b.name, b.category, bp.price_min, bp.price_max
    into v_tour
    from businesses b
    join business_prices bp on bp.business_id = b.id and bp.price_type = 'per_person_tour' and bp.active
    where b.category = v_pref and b.is_active
      and bp.price_min <= v_tour_budget_per_day
    order by bp.price_max desc
    limit 1;

    if v_tour.id is null then
      select b.id, b.name, b.category, bp.price_min, bp.price_max
      into v_tour
      from businesses b
      join business_prices bp on bp.business_id = b.id and bp.price_type = 'per_person_tour' and bp.active
      where b.category = v_pref and b.is_active
      order by bp.price_min asc
      limit 1;
    end if;

    if v_tour.id is not null then
      v_tours := v_tours || json_build_object(
        'dia', v_day,
        'tour', v_tour.name,
        'categoria', v_tour.category,
        'precio_por_persona', v_tour.price_min
      );
    end if;
  end loop;

  -- 6) Costo total estimado real (para comparar contra el presupuesto ingresado)
  select coalesce(sum((t->>'precio_por_persona')::numeric), 0) * v_persons
  into v_total_estimated
  from unnest(v_tours) t;

  v_total_estimated := v_total_estimated
    + coalesce(v_hotel.price_min * p_days, 0)
    + coalesce(v_restaurante.price_min * 2 * p_days * v_persons, 0)
    + coalesce(v_rentacar.price_min * p_days, 0);

  return json_build_object(
    'nivel_presupuesto', v_tier.tier,
    'presupuesto_total', p_total_budget,
    'personas', v_persons,
    'dias', p_days,
    'desglose_asignado', json_build_object(
      'hospedaje', round(v_hospedaje_budget, 2),
      'alimentacion', round(v_alimentacion_budget, 2),
      'transporte', round(v_transporte_budget, 2),
      'tours', round(v_tours_budget, 2)
    ),
    'hospedaje_recomendado', case when v_hotel.id is not null then
      json_build_object('nombre', v_hotel.name, 'precio_por_noche', v_hotel.price_min)
      else null end,
    'restaurante_recomendado', case when v_restaurante.id is not null then
      json_build_object('nombre', v_restaurante.name, 'precio_por_persona', v_restaurante.price_min)
      else null end,
    'rentacar_recomendado', case when v_rentacar.id is not null then
      json_build_object('nombre', v_rentacar.name, 'precio_por_dia', v_rentacar.price_min)
      else null end,
    'itinerario_tours', to_json(v_tours),
    'costo_total_estimado', round(v_total_estimated, 2),
    'alcanza_el_presupuesto', v_total_estimated <= p_total_budget
  );
end;
$function$
;

                                                  CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin

    insert into public.profiles (
        id,
        full_name,
        avatar_url
    )
    values (
        new.id,
        new.raw_user_meta_data ->> 'full_name',
        new.raw_user_meta_data ->> 'avatar_url'
    );

    return new;

end;
$function$
;

                                                  CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

                                                  CREATE OR REPLACE FUNCTION public.set_experience_record_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

                                                  CREATE OR REPLACE FUNCTION public.update_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
    new.updated_at = now();
    return new;
end;
$function$
;

                                                  CREATE TABLE IF NOT EXISTS public.budget_tiers (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          tier text NOT NULL,
                          min_total_per_person numeric(10,2) NOT NULL,
                          max_total_per_person numeric(10,2),
                          pct_hospedaje numeric(4,1) NOT NULL,
                          pct_alimentacion numeric(4,1) NOT NULL,
                          pct_transporte numeric(4,1) NOT NULL,
                          pct_tours numeric(4,1) NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.business_categories (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          business_id uuid NOT NULL,
                          category text NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.business_departures (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          business_id uuid NOT NULL,
                          day_of_week integer NOT NULL,
                          departure_time time without time zone NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.business_experiences (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          business_id uuid NOT NULL,
                          name text NOT NULL,
                          description text,
                          category text,
                          duration_minutes integer NOT NULL,
                          is_active boolean DEFAULT true NOT NULL,
                          is_bookable boolean DEFAULT false NOT NULL,
                          requires_reservation boolean DEFAULT false NOT NULL,
                          booking_url text,
                          whatsapp text,
                          latitude double precision,
                          longitude double precision,
                          operating_days smallint[] DEFAULT ARRAY[(0)::smallint, (1)::smallint, (2)::smallint, (3)::smallint, (4)::smallint, (5)::smallint, (6)::smallint] NOT NULL,
                          opening_time time without time zone,
                          closing_time time without time zone,
                          schedule_notes text,
                          schedule_source text,
                          schedule_verified_at date,
                          schedule_status text,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL,
                          experience_type text,
                          meal_type text,
                          schedule_type text,
                          minimum_participant_age integer,
                          maximum_participant_age integer,
                          minimum_group_size integer,
                          maximum_group_size integer);

                                                  CREATE TABLE IF NOT EXISTS public.business_hours (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          business_id uuid NOT NULL,
                          day_of_week integer NOT NULL,
                          opening_time time without time zone NOT NULL,
                          closing_time time without time zone NOT NULL,
                          is_closed boolean DEFAULT false NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL,
                          last_entry_time time without time zone);

                                                  CREATE TABLE IF NOT EXISTS public.business_prices (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          business_id uuid NOT NULL,
                          price_type text NOT NULL,
                          price_min numeric(10,2) NOT NULL,
                          price_max numeric(10,2) NOT NULL,
                          currency text DEFAULT 'USD'::text NOT NULL,
                          season text DEFAULT 'todo_el_ano'::text,
                          active boolean DEFAULT true NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.business_rates (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          business_id uuid NOT NULL,
                          rate_name text NOT NULL,
                          traveler_type text DEFAULT 'general'::text NOT NULL,
                          price numeric(10,2) NOT NULL,
                          currency text DEFAULT 'USD'::text NOT NULL,
                          price_unit text DEFAULT 'persona'::text NOT NULL,
                          valid_from date,
                          valid_until date,
                          season_type text DEFAULT 'regular'::text NOT NULL,
                          is_holiday_rate boolean DEFAULT false NOT NULL,
                          is_promotion boolean DEFAULT false NOT NULL,
                          description text,
                          active boolean DEFAULT true NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL,
                          source_url text,
                          verified_at date,
                          tax_included boolean,
                          min_age integer,
                          max_age integer,
                          nationality_type text,
                          rate_category text,
                          min_people integer,
                          max_people integer,
                          notes text,
                          source_type text DEFAULT 'business_owner'::text NOT NULL,
                          last_checked_at timestamp with time zone,
                          source_name text);

                                                  CREATE TABLE IF NOT EXISTS public.business_verifications (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          business_id uuid NOT NULL,
                          requested_by uuid NOT NULL,
                          status text DEFAULT 'pending'::text NOT NULL,
                          document_url text,
                          notes text,
                          verified_by uuid,
                          verified_at timestamp with time zone,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.businesses (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          owner_id uuid,
                          name text NOT NULL,
                          description text,
                          category text NOT NULL,
                          phone text,
                          email text,
                          website text,
                          address text,
                          province text,
                          canton text,
                          district text,
                          latitude double precision,
                          longitude double precision,
                          image_url text,
                          is_active boolean DEFAULT true NOT NULL,
                          is_verified boolean DEFAULT false NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL,
                          budget_level text,
                          price_min numeric(10,2),
                          price_max numeric(10,2),
                          price_unit text,
                          price_currency text DEFAULT 'USD'::text,
                          duration_minutes integer,
                          requires_reservation boolean DEFAULT false NOT NULL,
                          schedule_source text,
                          schedule_verified_at date,
                          schedule_notes text,
                          schedule_status text DEFAULT 'unknown'::text);

                                                  CREATE TABLE IF NOT EXISTS public.currency_rates (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          currency_code text NOT NULL,
                          currency_name text,
                          buy_rate numeric(12,4),
                          sell_rate numeric(12,4),
                          source text DEFAULT 'BCCR'::text NOT NULL,
                          rate_date date NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.experience_rates (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          experience_id uuid NOT NULL,
                          rate_name text,
                          traveler_type text DEFAULT 'general'::text NOT NULL,
                          price numeric NOT NULL,
                          currency text DEFAULT 'USD'::text NOT NULL,
                          price_unit text DEFAULT 'persona'::text NOT NULL,
                          valid_from date,
                          valid_until date,
                          season_type text,
                          is_holiday_rate boolean DEFAULT false NOT NULL,
                          is_promotion boolean DEFAULT false NOT NULL,
                          tax_included boolean DEFAULT true NOT NULL,
                          active boolean DEFAULT true NOT NULL,
                          description text,
                          min_age integer,
                          max_age integer,
                          nationality_type text,
                          rate_category text,
                          min_people integer,
                          max_people integer,
                          notes text,
                          source_url text,
                          source_type text,
                          source_name text,
                          verified_at date,
                          last_checked_at timestamp with time zone,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.experience_schedules (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          experience_id uuid NOT NULL,
                          weekday smallint NOT NULL,
                          start_time time without time zone NOT NULL,
                          end_time time without time zone,
                          is_active boolean DEFAULT true NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.favorites (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          user_id uuid NOT NULL,
                          business_id uuid NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.profiles (  id uuid NOT NULL,
                          full_name text,
                          avatar_url text,
                          role text DEFAULT 'user'::text NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.reviews (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          user_id uuid NOT NULL,
                          business_id uuid NOT NULL,
                          rating integer NOT NULL,
                          comment text,
                          created_at timestamp with time zone DEFAULT now() NOT NULL,
                          updated_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  CREATE TABLE IF NOT EXISTS public.trip_stops (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          trip_id uuid NOT NULL,
                          day_number integer NOT NULL,
                          order_index integer NOT NULL,
                          business_id uuid NOT NULL,
                          estimated_cost numeric(10,2),
                          time_slot text);

                                                  CREATE TABLE IF NOT EXISTS public.trips (  id uuid DEFAULT gen_random_uuid() NOT NULL,
                          user_id uuid NOT NULL,
                          adults integer DEFAULT 1 NOT NULL,
                          children integer DEFAULT 0 NOT NULL,
                          seniors integer DEFAULT 0 NOT NULL,
                          pets integer DEFAULT 0 NOT NULL,
                          days integer NOT NULL,
                          budget_tier text NOT NULL,
                          total_budget numeric(10,2) NOT NULL,
                          preferences text[] DEFAULT '{}'::text[] NOT NULL,
                          created_at timestamp with time zone DEFAULT now() NOT NULL);

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'budget_tiers_pkey' AND conrelid = 'public.budget_tiers'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.budget_tiers ADD CONSTRAINT budget_tiers_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'budget_tiers_tier_check' AND conrelid = 'public.budget_tiers'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.budget_tiers ADD CONSTRAINT budget_tiers_tier_check CHECK (tier = ANY (ARRAY['bajo'::text, 'medio'::text, 'premium'::text]));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'budget_tiers_tier_key' AND conrelid = 'public.budget_tiers'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.budget_tiers ADD CONSTRAINT budget_tiers_tier_key UNIQUE (tier);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_categories_pkey' AND conrelid = 'public.business_categories'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_categories ADD CONSTRAINT business_categories_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_categories_unique' AND conrelid = 'public.business_categories'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_categories ADD CONSTRAINT business_categories_unique UNIQUE (business_id, category);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_departures_day_of_week_check' AND conrelid = 'public.business_departures'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_departures ADD CONSTRAINT business_departures_day_of_week_check CHECK (day_of_week >= 0 AND day_of_week <= 6);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_departures_pkey' AND conrelid = 'public.business_departures'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_departures ADD CONSTRAINT business_departures_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_departures_unique' AND conrelid = 'public.business_departures'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_departures ADD CONSTRAINT business_departures_unique UNIQUE (business_id, day_of_week, departure_time);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_duration_minutes_check' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_duration_minutes_check CHECK (duration_minutes > 0 AND duration_minutes <= 1440);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_duration_positive' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_duration_positive CHECK (duration_minutes IS NULL OR duration_minutes > 0);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_group_size_valid' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_group_size_valid CHECK ((minimum_group_size IS NULL OR minimum_group_size >= 1) AND (maximum_group_size IS NULL OR maximum_group_size >= 1) AND (minimum_group_size IS NULL OR maximum_group_size IS NULL OR minimum_group_size <= maximum_group_size));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_latitude_check' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_latitude_check CHECK (latitude IS NULL OR latitude >= '-90'::integer::double precision AND latitude <= 90::double precision);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_longitude_check' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_longitude_check CHECK (longitude IS NULL OR longitude >= '-180'::integer::double precision AND longitude <= 180::double precision);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_meal_type_valid' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_meal_type_valid CHECK (meal_type IS NULL OR (meal_type = ANY (ARRAY['breakfast'::text, 'lunch'::text, 'dinner'::text])));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_operating_days_check' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_operating_days_check CHECK (operating_days <@ ARRAY[0::smallint, 1::smallint, 2::smallint, 3::smallint, 4::smallint, 5::smallint, 6::smallint]);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_participant_age_valid' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_participant_age_valid CHECK ((minimum_participant_age IS NULL OR minimum_participant_age >= 0) AND (maximum_participant_age IS NULL OR maximum_participant_age >= 0) AND (minimum_participant_age IS NULL OR maximum_participant_age IS NULL OR minimum_participant_age <= maximum_participant_age));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_pkey' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_schedule_type_valid' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_schedule_type_valid CHECK (schedule_type IS NULL OR (schedule_type = ANY (ARRAY['open_hours'::text, 'sessions'::text, 'on_request'::text])));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_time_check' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_time_check CHECK (opening_time IS NULL OR closing_time IS NULL OR opening_time <> closing_time);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_type_valid' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_type_valid CHECK (experience_type IS NULL OR (experience_type = ANY (ARRAY['adventure'::text, 'nature'::text, 'culture'::text, 'wildlife'::text, 'thermal'::text, 'wellness'::text, 'gastronomic'::text, 'tour'::text, 'attraction'::text, 'other'::text])));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_hours_day_of_week_check' AND conrelid = 'public.business_hours'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_hours ADD CONSTRAINT business_hours_day_of_week_check CHECK (day_of_week >= 0 AND day_of_week <= 6);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_hours_pkey' AND conrelid = 'public.business_hours'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_hours ADD CONSTRAINT business_hours_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_hours_unique_block' AND conrelid = 'public.business_hours'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_hours ADD CONSTRAINT business_hours_unique_block UNIQUE (business_id, day_of_week, opening_time, closing_time);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_hours_valid_time' AND conrelid = 'public.business_hours'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_hours ADD CONSTRAINT business_hours_valid_time CHECK (closing_time > opening_time);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_prices_pkey' AND conrelid = 'public.business_prices'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_prices ADD CONSTRAINT business_prices_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_prices_price_type_check' AND conrelid = 'public.business_prices'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_prices ADD CONSTRAINT business_prices_price_type_check CHECK (price_type = ANY (ARRAY['per_night'::text, 'per_person_meal'::text, 'per_person_tour'::text, 'per_day_rental'::text]));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_prices_season_check' AND conrelid = 'public.business_prices'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_prices ADD CONSTRAINT business_prices_season_check CHECK (season = ANY (ARRAY['alta'::text, 'baja'::text, 'todo_el_ano'::text]));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_rates_pkey' AND conrelid = 'public.business_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_rates ADD CONSTRAINT business_rates_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_rates_price_check' AND conrelid = 'public.business_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_rates ADD CONSTRAINT business_rates_price_check CHECK (price >= 0::numeric);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_rates_source_type_check' AND conrelid = 'public.business_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_rates ADD CONSTRAINT business_rates_source_type_check CHECK (source_type = ANY (ARRAY['business_owner'::text, 'official_website'::text, 'official_api'::text, 'maleku_admin'::text, 'partner_feed'::text]));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_verifications_pkey' AND conrelid = 'public.business_verifications'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_verifications ADD CONSTRAINT business_verifications_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_verifications_status_check' AND conrelid = 'public.business_verifications'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_verifications ADD CONSTRAINT business_verifications_status_check CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'businesses_budget_level_check' AND conrelid = 'public.businesses'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.businesses ADD CONSTRAINT businesses_budget_level_check CHECK (budget_level IS NULL OR (budget_level = ANY (ARRAY['premium'::text, 'medio'::text, 'bajo'::text])));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'businesses_duration_positive' AND conrelid = 'public.businesses'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.businesses ADD CONSTRAINT businesses_duration_positive CHECK (duration_minutes IS NULL OR duration_minutes > 0);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'businesses_pkey' AND conrelid = 'public.businesses'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.businesses ADD CONSTRAINT businesses_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'businesses_schedule_status_check' AND conrelid = 'public.businesses'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.businesses ADD CONSTRAINT businesses_schedule_status_check CHECK (schedule_status = ANY (ARRAY['verified'::text, 'partial'::text, 'unknown'::text]));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'currency_rates_currency_code_rate_date_key' AND conrelid = 'public.currency_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.currency_rates ADD CONSTRAINT currency_rates_currency_code_rate_date_key UNIQUE (currency_code, rate_date);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'currency_rates_pkey' AND conrelid = 'public.currency_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.currency_rates ADD CONSTRAINT currency_rates_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_age_range_check' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_age_range_check CHECK (min_age IS NULL OR max_age IS NULL OR min_age <= max_age);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_max_age_check' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_max_age_check CHECK (max_age IS NULL OR max_age >= 0);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_max_people_check' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_max_people_check CHECK (max_people IS NULL OR max_people > 0);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_min_age_check' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_min_age_check CHECK (min_age IS NULL OR min_age >= 0);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_min_people_check' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_min_people_check CHECK (min_people IS NULL OR min_people > 0);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_people_range_check' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_people_range_check CHECK (min_people IS NULL OR max_people IS NULL OR min_people <= max_people);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_pkey' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_price_check' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_price_check CHECK (price >= 0::numeric);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_validity_check' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_validity_check CHECK (valid_from IS NULL OR valid_until IS NULL OR valid_from <= valid_until);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_schedules_check' AND conrelid = 'public.experience_schedules'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_schedules ADD CONSTRAINT experience_schedules_check CHECK (end_time IS NULL OR end_time > start_time);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_schedules_pkey' AND conrelid = 'public.experience_schedules'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_schedules ADD CONSTRAINT experience_schedules_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_schedules_weekday_check' AND conrelid = 'public.experience_schedules'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_schedules ADD CONSTRAINT experience_schedules_weekday_check CHECK (weekday >= 1 AND weekday <= 7);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'favorites_pkey' AND conrelid = 'public.favorites'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.favorites ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'favorites_user_id_business_id_key' AND conrelid = 'public.favorites'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.favorites ADD CONSTRAINT favorites_user_id_business_id_key UNIQUE (user_id, business_id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_pkey' AND conrelid = 'public.profiles'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_role_check' AND conrelid = 'public.profiles'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_role_check CHECK (role = ANY (ARRAY['user'::text, 'business_owner'::text, 'admin'::text]));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'reviews_pkey' AND conrelid = 'public.reviews'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.reviews ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'reviews_rating_check' AND conrelid = 'public.reviews'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.reviews ADD CONSTRAINT reviews_rating_check CHECK (rating >= 1 AND rating <= 5);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'reviews_user_id_business_id_key' AND conrelid = 'public.reviews'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.reviews ADD CONSTRAINT reviews_user_id_business_id_key UNIQUE (user_id, business_id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trip_stops_pkey' AND conrelid = 'public.trip_stops'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.trip_stops ADD CONSTRAINT trip_stops_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_pkey' AND conrelid = 'public.trips'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.trips ADD CONSTRAINT trips_pkey PRIMARY KEY (id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_categories_business_id_fkey' AND conrelid = 'public.business_categories'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_categories ADD CONSTRAINT business_categories_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_departures_business_id_fkey' AND conrelid = 'public.business_departures'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_departures ADD CONSTRAINT business_departures_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_experiences_business_id_fkey' AND conrelid = 'public.business_experiences'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_experiences ADD CONSTRAINT business_experiences_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_hours_business_id_fkey' AND conrelid = 'public.business_hours'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_hours ADD CONSTRAINT business_hours_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_prices_business_id_fkey' AND conrelid = 'public.business_prices'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_prices ADD CONSTRAINT business_prices_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_rates_business_id_fkey' AND conrelid = 'public.business_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_rates ADD CONSTRAINT business_rates_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_verifications_business_id_fkey' AND conrelid = 'public.business_verifications'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_verifications ADD CONSTRAINT business_verifications_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_verifications_requested_by_fkey' AND conrelid = 'public.business_verifications'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_verifications ADD CONSTRAINT business_verifications_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES profiles(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'business_verifications_verified_by_fkey' AND conrelid = 'public.business_verifications'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.business_verifications ADD CONSTRAINT business_verifications_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES profiles(id) ON DELETE SET NULL;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'businesses_owner_id_fkey' AND conrelid = 'public.businesses'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.businesses ADD CONSTRAINT businesses_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id) ON DELETE SET NULL;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_rates_experience_id_fkey' AND conrelid = 'public.experience_rates'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_rates ADD CONSTRAINT experience_rates_experience_id_fkey FOREIGN KEY (experience_id) REFERENCES business_experiences(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'experience_schedules_experience_id_fkey' AND conrelid = 'public.experience_schedules'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.experience_schedules ADD CONSTRAINT experience_schedules_experience_id_fkey FOREIGN KEY (experience_id) REFERENCES business_experiences(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'favorites_business_id_fkey' AND conrelid = 'public.favorites'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.favorites ADD CONSTRAINT favorites_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'favorites_user_id_fkey' AND conrelid = 'public.favorites'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.favorites ADD CONSTRAINT favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_id_fkey' AND conrelid = 'public.profiles'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'reviews_business_id_fkey' AND conrelid = 'public.reviews'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.reviews ADD CONSTRAINT reviews_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'reviews_user_id_fkey' AND conrelid = 'public.reviews'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.reviews ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trip_stops_business_id_fkey' AND conrelid = 'public.trip_stops'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.trip_stops ADD CONSTRAINT trip_stops_business_id_fkey FOREIGN KEY (business_id) REFERENCES businesses(id);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trip_stops_trip_id_fkey' AND conrelid = 'public.trip_stops'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.trip_stops ADD CONSTRAINT trip_stops_trip_id_fkey FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_budget_tier_fkey' AND conrelid = 'public.trips'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.trips ADD CONSTRAINT trips_budget_tier_fkey FOREIGN KEY (budget_tier) REFERENCES budget_tiers(tier);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'trips_user_id_fkey' AND conrelid = 'public.trips'::regclass) THEN
    EXECUTE $ddl$
ALTER TABLE ONLY public.trips ADD CONSTRAINT trips_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
$ddl$;
  END IF;
END
$baseline$;

                                                  CREATE INDEX IF NOT EXISTS business_experiences_active_business_idx ON public.business_experiences USING btree (business_id, is_active) WHERE (is_active = true);

                                                  CREATE INDEX IF NOT EXISTS business_experiences_active_schedule_idx ON public.business_experiences USING btree (schedule_type) WHERE (is_active = true);

                                                  CREATE INDEX IF NOT EXISTS business_experiences_bookable_idx ON public.business_experiences USING btree (business_id, is_bookable) WHERE ((is_active = true) AND (is_bookable = true));

                                                  CREATE INDEX IF NOT EXISTS business_experiences_business_id_idx ON public.business_experiences USING btree (business_id);

                                                  CREATE INDEX IF NOT EXISTS business_experiences_category_idx ON public.business_experiences USING btree (category) WHERE (is_active = true);

                                                  CREATE INDEX IF NOT EXISTS business_rates_active_dates_idx ON public.business_rates USING btree (business_id, active, valid_from, valid_until);

                                                  CREATE INDEX IF NOT EXISTS business_rates_business_id_idx ON public.business_rates USING btree (business_id);

                                                  CREATE INDEX IF NOT EXISTS experience_rates_active_experience_idx ON public.experience_rates USING btree (experience_id, active) WHERE (active = true);

                                                  CREATE INDEX IF NOT EXISTS experience_rates_active_lookup_idx ON public.experience_rates USING btree (experience_id) WHERE (active = true);

                                                  CREATE INDEX IF NOT EXISTS experience_rates_experience_id_idx ON public.experience_rates USING btree (experience_id);

                                                  CREATE INDEX IF NOT EXISTS experience_rates_validity_idx ON public.experience_rates USING btree (valid_from, valid_until) WHERE (active = true);

                                                  CREATE INDEX IF NOT EXISTS experience_schedules_lookup_idx ON public.experience_schedules USING btree (experience_id, weekday, start_time) WHERE (is_active = true);

                                                  CREATE UNIQUE INDEX IF NOT EXISTS experience_schedules_unique_active_start_idx ON public.experience_schedules USING btree (experience_id, weekday, start_time) WHERE (is_active = true);

                                                  CREATE INDEX IF NOT EXISTS idx_business_departures_business_day ON public.business_departures USING btree (business_id, day_of_week);

                                                  CREATE INDEX IF NOT EXISTS idx_business_departures_business_id ON public.business_departures USING btree (business_id);

                                                  CREATE INDEX IF NOT EXISTS idx_business_hours_business_day ON public.business_hours USING btree (business_id, day_of_week);

                                                  CREATE INDEX IF NOT EXISTS idx_business_hours_business_id ON public.business_hours USING btree (business_id);

                                                  CREATE INDEX IF NOT EXISTS idx_business_prices_business_id ON public.business_prices USING btree (business_id);

                                                  CREATE INDEX IF NOT EXISTS idx_business_prices_type ON public.business_prices USING btree (price_type);

                                                  CREATE INDEX IF NOT EXISTS idx_businesses_active ON public.businesses USING btree (is_active);

                                                  CREATE INDEX IF NOT EXISTS idx_businesses_category ON public.businesses USING btree (category);

                                                  CREATE INDEX IF NOT EXISTS idx_businesses_location ON public.businesses USING btree (latitude, longitude);

                                                  CREATE INDEX IF NOT EXISTS idx_businesses_owner ON public.businesses USING btree (owner_id);

                                                  CREATE INDEX IF NOT EXISTS idx_businesses_verified ON public.businesses USING btree (is_verified);

                                                  CREATE INDEX IF NOT EXISTS idx_favorites_business ON public.favorites USING btree (business_id);

                                                  CREATE INDEX IF NOT EXISTS idx_favorites_user ON public.favorites USING btree (user_id);

                                                  CREATE INDEX IF NOT EXISTS idx_reviews_business ON public.reviews USING btree (business_id);

                                                  CREATE INDEX IF NOT EXISTS idx_reviews_user ON public.reviews USING btree (user_id);

                                                  CREATE INDEX IF NOT EXISTS idx_verifications_business ON public.business_verifications USING btree (business_id);

                                                  CREATE INDEX IF NOT EXISTS idx_verifications_status ON public.business_verifications USING btree (status);

                                                  ALTER TABLE ONLY public.budget_tiers ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.business_categories ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.business_departures ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.business_experiences ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.business_hours ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.business_prices ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.business_rates ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.business_verifications ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.businesses ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.currency_rates ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.experience_rates ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.experience_schedules ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.favorites ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.profiles ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.reviews ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.trip_stops ENABLE ROW LEVEL SECURITY;

                                                  ALTER TABLE ONLY public.trips ENABLE ROW LEVEL SECURITY;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_rates' AND policyname = 'Anyone can view active business rates') THEN
    EXECUTE $ddl$
CREATE POLICY "Anyone can view active business rates" ON public.business_rates AS PERMISSIVE FOR SELECT TO public USING ((active = true));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'businesses' AND policyname = 'Anyone can view active businesses') THEN
    EXECUTE $ddl$
CREATE POLICY "Anyone can view active businesses" ON public.businesses AS PERMISSIVE FOR SELECT TO anon, authenticated USING ((is_active = true));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_categories' AND policyname = 'Anyone can view business categories') THEN
    EXECUTE $ddl$
CREATE POLICY "Anyone can view business categories" ON public.business_categories AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reviews' AND policyname = 'Anyone can view reviews') THEN
    EXECUTE $ddl$
CREATE POLICY "Anyone can view reviews" ON public.reviews AS PERMISSIVE FOR SELECT TO anon, authenticated USING (true);
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'trip_stops' AND policyname = 'Cada usuario ve y edita solo las paradas de sus viajes') THEN
    EXECUTE $ddl$
CREATE POLICY "Cada usuario ve y edita solo las paradas de sus viajes" ON public.trip_stops AS PERMISSIVE FOR ALL TO public USING ((trip_id IN ( SELECT trips.id
   FROM trips
  WHERE (trips.user_id = auth.uid()))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'trips' AND policyname = 'Cada usuario ve y edita solo sus viajes') THEN
    EXECUTE $ddl$
CREATE POLICY "Cada usuario ve y edita solo sus viajes" ON public.trips AS PERMISSIVE FOR ALL TO public USING ((user_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_experiences' AND policyname = 'Experiencias visibles de negocios activos') THEN
    EXECUTE $ddl$
CREATE POLICY "Experiencias visibles de negocios activos" ON public.business_experiences AS PERMISSIVE FOR SELECT TO anon, authenticated USING ((((is_active = true) AND (EXISTS ( SELECT 1
   FROM businesses b
  WHERE ((b.id = business_experiences.business_id) AND (b.is_active = true))))) OR (EXISTS ( SELECT 1
   FROM businesses b
  WHERE ((b.id = business_experiences.business_id) AND (b.owner_id = auth.uid()))))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'businesses' AND policyname = 'Owners can delete businesses') THEN
    EXECUTE $ddl$
CREATE POLICY "Owners can delete businesses" ON public.businesses AS PERMISSIVE FOR DELETE TO authenticated USING ((owner_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_rates' AND policyname = 'Owners can delete rates for own businesses') THEN
    EXECUTE $ddl$
CREATE POLICY "Owners can delete rates for own businesses" ON public.business_rates AS PERMISSIVE FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM businesses b
  WHERE ((b.id = business_rates.business_id) AND (b.owner_id = auth.uid())))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_rates' AND policyname = 'Owners can insert rates for own businesses') THEN
    EXECUTE $ddl$
CREATE POLICY "Owners can insert rates for own businesses" ON public.business_rates AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM businesses b
  WHERE ((b.id = business_rates.business_id) AND (b.owner_id = auth.uid())))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'businesses' AND policyname = 'Owners can update businesses') THEN
    EXECUTE $ddl$
CREATE POLICY "Owners can update businesses" ON public.businesses AS PERMISSIVE FOR UPDATE TO authenticated USING ((owner_id = auth.uid())) WITH CHECK ((owner_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_rates' AND policyname = 'Owners can update rates for own businesses') THEN
    EXECUTE $ddl$
CREATE POLICY "Owners can update rates for own businesses" ON public.business_rates AS PERMISSIVE FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM businesses b
  WHERE ((b.id = business_rates.business_id) AND (b.owner_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM businesses b
  WHERE ((b.id = business_rates.business_id) AND (b.owner_id = auth.uid())))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_prices' AND policyname = 'Precios visibles para todos') THEN
    EXECUTE $ddl$
CREATE POLICY "Precios visibles para todos" ON public.business_prices AS PERMISSIVE FOR SELECT TO public USING ((active = true));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_experiences' AND policyname = 'Propietario administra experiencias propias') THEN
    EXECUTE $ddl$
CREATE POLICY "Propietario administra experiencias propias" ON public.business_experiences AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM businesses b
  WHERE ((b.id = business_experiences.business_id) AND (b.owner_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM businesses b
  WHERE ((b.id = business_experiences.business_id) AND (b.owner_id = auth.uid())))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'experience_rates' AND policyname = 'Propietario administra tarifas de experiencias propias') THEN
    EXECUTE $ddl$
CREATE POLICY "Propietario administra tarifas de experiencias propias" ON public.experience_rates AS PERMISSIVE FOR ALL TO authenticated USING ((EXISTS ( SELECT 1
   FROM (business_experiences e
     JOIN businesses b ON ((b.id = e.business_id)))
  WHERE ((e.id = experience_rates.experience_id) AND (b.owner_id = auth.uid()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (business_experiences e
     JOIN businesses b ON ((b.id = e.business_id)))
  WHERE ((e.id = experience_rates.experience_id) AND (b.owner_id = auth.uid())))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_prices' AND policyname = 'Solo el dueño del negocio edita sus precios') THEN
    EXECUTE $ddl$
CREATE POLICY "Solo el dueño del negocio edita sus precios" ON public.business_prices AS PERMISSIVE FOR ALL TO public USING ((business_id IN ( SELECT businesses.id
   FROM businesses
  WHERE (businesses.owner_id = auth.uid()))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'experience_rates' AND policyname = 'Tarifas visibles de experiencias activas') THEN
    EXECUTE $ddl$
CREATE POLICY "Tarifas visibles de experiencias activas" ON public.experience_rates AS PERMISSIVE FOR SELECT TO anon, authenticated USING ((((active = true) AND (EXISTS ( SELECT 1
   FROM (business_experiences e
     JOIN businesses b ON ((b.id = e.business_id)))
  WHERE ((e.id = experience_rates.experience_id) AND (e.is_active = true) AND (b.is_active = true))))) OR (EXISTS ( SELECT 1
   FROM (business_experiences e
     JOIN businesses b ON ((b.id = e.business_id)))
  WHERE ((e.id = experience_rates.experience_id) AND (b.owner_id = auth.uid()))))));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'favorites' AND policyname = 'Users can add favorites') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can add favorites" ON public.favorites AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'businesses' AND policyname = 'Users can create businesses') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can create businesses" ON public.businesses AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((owner_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reviews' AND policyname = 'Users can create reviews') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can create reviews" ON public.reviews AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'favorites' AND policyname = 'Users can delete own favorites') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can delete own favorites" ON public.favorites AS PERMISSIVE FOR DELETE TO authenticated USING ((user_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reviews' AND policyname = 'Users can delete own reviews') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can delete own reviews" ON public.reviews AS PERMISSIVE FOR DELETE TO authenticated USING ((user_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_verifications' AND policyname = 'Users can request verification') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can request verification" ON public.business_verifications AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((requested_by = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'reviews' AND policyname = 'Users can update own reviews') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can update own reviews" ON public.reviews AS PERMISSIVE FOR UPDATE TO authenticated USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'Users can update their own profile') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can update their own profile" ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated USING ((id = auth.uid())) WITH CHECK ((id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'favorites' AND policyname = 'Users can view own favorites') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can view own favorites" ON public.favorites AS PERMISSIVE FOR SELECT TO authenticated USING ((user_id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'business_verifications' AND policyname = 'Users can view own verification requests') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can view own verification requests" ON public.business_verifications AS PERMISSIVE FOR SELECT TO authenticated USING ((requested_by = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'Users can view their own profile') THEN
    EXECUTE $ddl$
CREATE POLICY "Users can view their own profile" ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING ((id = auth.uid()));
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'business_experiences_updated_at_trigger' AND tgrelid = 'public.business_experiences'::regclass AND NOT tgisinternal) THEN
    EXECUTE $ddl$
CREATE TRIGGER business_experiences_updated_at_trigger BEFORE UPDATE ON public.business_experiences FOR EACH ROW EXECUTE FUNCTION public.set_experience_record_updated_at();
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'experience_rates_updated_at_trigger' AND tgrelid = 'public.experience_rates'::regclass AND NOT tgisinternal) THEN
    EXECUTE $ddl$
CREATE TRIGGER experience_rates_updated_at_trigger BEFORE UPDATE ON public.experience_rates FOR EACH ROW EXECUTE FUNCTION public.set_experience_record_updated_at();
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_businesses_updated_at' AND tgrelid = 'public.businesses'::regclass AND NOT tgisinternal) THEN
    EXECUTE $ddl$
CREATE TRIGGER update_businesses_updated_at BEFORE UPDATE ON public.businesses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_profiles_updated_at' AND tgrelid = 'public.profiles'::regclass AND NOT tgisinternal) THEN
    EXECUTE $ddl$
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_reviews_updated_at' AND tgrelid = 'public.reviews'::regclass AND NOT tgisinternal) THEN
    EXECUTE $ddl$
CREATE TRIGGER update_reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
$ddl$;
  END IF;
END
$baseline$;

                                                  DO $baseline$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_verifications_updated_at' AND tgrelid = 'public.business_verifications'::regclass AND NOT tgisinternal) THEN
    EXECUTE $ddl$
CREATE TRIGGER update_verifications_updated_at BEFORE UPDATE ON public.business_verifications FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
$ddl$;
  END IF;
END
$baseline$;
