# Auditoría de origen de negocios y actividades — Maleku Go

Fecha: 2026-09-20  
Modo: solo diagnóstico. No se modificó código, Supabase ni datos.

## Conclusión ejecutiva

El planificador actual **no contiene un catálogo hardcodeado** de Los Lagos, Arenal Springs, Royal Corin, Tabacón, Río Celeste, etc. Sus candidatos se originan en datos de Supabase, principalmente `public.businesses` y `public.business_experiences`.

Los nombres históricos que sobreviven dentro de `App.js` son, en su mayoría, **heurísticas por texto** para estimar duración o afinidad logística. Esas condiciones no crean actividades ni negocios: solo cambian una estimación si un registro que llegó desde Supabase tiene un nombre coincidente.

Con el estado confirmado de `public.businesses` —solo Nayara Gardens, Volcano Lodge Hotel & Thermal Experience y Mistico Arenal Hanging Bridges Park reales activos/verificados— el catálogo productivo disponible para el planificador no puede contener automáticamente los demás negocios históricos, salvo que alguno exista como experiencia de uno de esos tres proveedores en `business_experiences`.

## 1. Fuente de datos en tiempo de ejecución

| Uso | Fuente | Ubicación aproximada | Qué hace |
|---|---|---:|---|
| Explorar negocios | `public.businesses` | `App.js:2288–2360`, `loadPlaces()` | Carga lugares visibles, filtra por categoría/presupuesto y `is_active = true`. |
| Destacados Home | `public.businesses` | `App.js:2390–2445`, `loadFeaturedPlaces()` | Carga activos y verificados; además excluye nombres de prueba y exige `image_url`. |
| Planificador: base de negocios | `public.businesses` con relaciones anidadas | `App.js:5064–5158`, `generateTripItinerary()` | Carga negocio, atributos logísticos, `business_hours`, `business_rates` y rutas de transporte anidadas. |
| Experiencias/tours | `public.business_experiences` | `App.js:5215–5280` | Carga experiencias activas, proveedor anidado, `experience_schedules` y `experience_rates`. |
| Horarios de experiencias | Relación `experience_schedules` | `App.js:5232–5238`, consumida alrededor de `9580–10530` y `22900–23750` | Construye sesiones FIXED y disponibilidad por horario. |
| Tarifas de experiencias | Relación `experience_rates` | `App.js:5262–5278`, utilizada alrededor de `10189–10290` y `13836–13860` | Tarificación de EXPERIENCE, incluido ajuste por horario AM/PM. |
| Tarifas de negocio/hospedaje | Relación `business_rates` | `App.js:5096–5120`, `5433–6559`, `7325–7545`, `21286–21318` | Precio legacy/estructurado y selección de hospedaje. |
| Comidas asociadas | `public.business_meal_services` | `App.js:5175–5205`, consumida alrededor de `9580–9618`, `16212–16640` | Servicios incluidos o extra-cost de hospedajes/experiencias. |
| Comidas externas | `public.businesses` por categoría | `App.js:15560–15620`, `16664–16730` | Restaurantes/cafés legacy, únicamente si existen como negocios. |
| Rutas de hospedaje | relación `business_transport_routes` | `App.js:5124–5155`, `21424–22190` | Rutas y tarifas de transporte ofrecido por hospedaje. |

### Tablas referenciadas por el código, pero no usadas como catálogo directo del planificador

| Tabla | Uso en `App.js` | Observación |
|---|---|---|
| `business_categories` | `loadPlaces()` alrededor de 2318 | Amplía el filtro UI de Termales; no crea negocios. |
| `business_departures` | Sin consulta directa actual | No alimenta candidatos ni sesiones del planificador actual. |
| `business_prices` | Sin consulta directa actual | No alimenta el motor actual; prevalecen `business_rates` / `experience_rates`. |
| `favorites`, `profiles`, `business_verifications` | UI, autenticación y administración | No generan candidatos automáticos. |
| `fuel_prices`, `exchange_rates` | Vehículo propio | No son negocios, hospedajes ni actividades. |

## 2. Construcción efectiva de candidatos del planificador

1. `generateTripItinerary()` trae `data` desde `public.businesses` (`App.js:5066`).
2. Trae experiencias activas separadamente desde `public.business_experiences` (`App.js:5217`, `.eq('is_active', true)`).
3. Las experiencias `schedule_type = 'open_hours'` se transforman en `openHoursExperiencePlaces` (`App.js:6686–6743`), preservando `business_id`, coordenadas y tarifas de la experiencia.
4. Los negocios legacy planificables proceden de `data`, excluyendo `planning_role = provider`, categoría `transporte` y providers ya representados por una experiencia de horario abierto (`App.js:6749–6776`).
5. `planifiablePlaces` es la unión de ambos conjuntos; de ahí salen `scoredPlaces`, `activityPlaces`, alojamientos y candidatos flexibles (`App.js:6774–7188`).
6. Las experiencias con horarios/sesiones se incorporan como actividades FIXED desde `loadedActiveExperiences` y `experience_schedules` más adelante (`App.js:10538–10982`, `15335–15419`).

**Resultado:** el Smart Schedule no posee un catálogo propio. Agenda los objetos que llegaron por estas consultas y aplica reglas sobre sus campos.

## 3. Negocios reales confirmados actualmente

Fuente: consulta de solo lectura ya confirmada a `public.businesses`, excluyendo pruebas.

| Nombre | Tipo/categoría | Origen | ¿Participa actualmente? | Clasificación |
|---|---|---|---|---|
| Nayara Gardens | Hospedaje | `public.businesses` | Sí, candidato de hospedaje si pasa filtros/ranking | Dato real de Supabase |
| Volcano Lodge Hotel & Thermal Experience | Hospedaje | `public.businesses` | Sí, candidato de hospedaje y proveedor potencial de comidas/rutas | Dato real de Supabase |
| Mistico Arenal Hanging Bridges Park | Naturaleza | `public.businesses`; puede tener experiencias asociadas | Sí, candidato legacy o EXPERIENCE según sus relaciones | Dato real de Supabase |

No se encontraron otros negocios reales activos/verificados en la tabla `public.businesses` confirmada. La presencia de una experiencia real adicional depende de que exista una fila activa en `business_experiences` asociada a uno de esos negocios; el código no inventa esa fila si no llega de Supabase.

## 4. Nombres históricos: dónde aparecen realmente

| Nombre o familia | Origen exacto | Archivo/líneas | ¿Es negocio/actividad hardcodeado? | ¿Puede participar hoy? |
|---|---|---:|---|---|
| Los Lagos, Arenal Springs, Royal Corin, Arenal Kioro, Lomas del Volcán, Arenal Observatory, Tabacón, Asha Hostel | No hay coincidencia en `App.js` actual ni en SQL de datos versionado | — | No | Solo si se insertan como negocios/experiencias en Supabase. |
| Nayara | Registro real de `businesses`; también imagen local/documentación | Supabase en ejecución; referencias de imagen en `App.js` | No es hardcodeado como candidato | Sí, vía `public.businesses`. |
| Místico/Mistico | Registro real de `businesses`; heurística de duración por nombre | `App.js:8029–8095`, `9234–9300` | La heurística está hardcodeada; el negocio no | Sí, porque existe negocio real. |
| Volcán Arenal | Heurística `name.includes('volcan arenal')` | `App.js:8043–8044`, `9248–9249` | No | Solo si llega un registro Supabase con ese nombre. |
| Río Celeste | Heurística de duración estimada; comentario explicativo | `App.js:8029–8031`, `9216`, `9234–9236` | No | Solo si llega un registro Supabase coincidente. |
| Catarata La Fortuna | Heurística de duración; referencias puramente visuales en guía HTML | `App.js:8050`, `9255`; `maleku_go_style_guide.html` | No | Solo si llega un registro Supabase coincidente. |
| ATV | Keyword de preferencias y heurística de duración | `App.js:5512`, `8062`, `9267`, `22849`, `23863` | No | Solo si llega un registro Supabase coincidente. |
| Rafting Balsa | No existe el nombre exacto como dato; `rafting` es regla de duración | `App.js:8056–8060`, `9261–9265` | No | Solo si llega un registro Supabase coincidente. |
| Cavernas de Venado | Heurística de duración | `App.js:8068`, `9273` | No | Solo si llega un registro Supabase coincidente. |
| Observación de Aves | Heurística de duración | `App.js:8080–8081`, `9285–9286` | No | Solo si llega un registro Supabase coincidente. |
| Safari Float | Heurística de duración | `App.js:8074`, `9279` | No | Solo si llega un registro Supabase coincidente. |
| Tour de Café y Chocolate / Tour de Chocolate | Heurísticas de duración y preferencia gastronómica | `App.js:8087–8094`, `9292–9299` | No | Solo si llega un registro Supabase coincidente. |
| Restaurantes/comidas | Filtros por categoría (`restaurante`, `cafe`) y servicios de comida | `App.js:15560–15620`, `16664–16730`, `5175–5205` | No hay restaurante concreto hardcodeado | Solo si existen filas Supabase. |

### Hallazgo sobre material histórico

- No se encontraron `INSERT INTO businesses` ni `INSERT INTO business_experiences` con esos nombres en los SQL versionados revisados.
- Fuera de `App.js`, las únicas referencias encontradas fueron textos de la guía visual (`maleku_go_style_guide.html`) y archivos de respaldo/temporales de `App.js`; no son fuentes de datos del build activo.
- Los archivos `App.before-*`, `App_pan.js`, `App_1709.js` y el temporal `App.js.home-v2-2-prebackup-reconstruction.tmp` son copias históricas/no ejecutadas. Repiten la misma clase de heurística y no deben tomarse como catálogo de producción.

## 5. Heurísticas hardcodeadas que afectan datos dinámicos

`selectionEstimateHours()` y `estimateActivityHours()` contienen coincidencias de nombres para asignar duración cuando `duration_minutes` no es válido (`App.js:8006–8130` y `9194–9315`). Ejemplos:

- Río Celeste → 8 h.
- Místico/Puentes colgantes → 4 h.
- Volcán Arenal o Catarata La Fortuna → 3 h.
- Rafting → 5.5 h; ATV → 4 h; Cavernas de Venado → 5 h.
- Safari Float → 3 h; aves → 4 h; café/chocolate → 2.5–3 h.

Estas reglas son **fallbacks de planificación**, no registros. Son frágiles: un nuevo negocio cuyo nombre coincida recibe la duración implícita, y uno real con nombre distinto cae en el fallback de categoría. Antes de producción, la duración debe estar estructurada en `business_experiences.duration_minutes` o `businesses.duration_minutes` para evitar depender del texto.

## 6. Discrepancias entre código esperado y datos confirmados

| Severidad | Código espera | Estado confirmado | Impacto |
|---|---|---|---|
| Alta | Catálogo suficiente de negocios/tours/hospedajes desde `businesses` y experiencias asociadas | Solo 3 negocios reales en `businesses` | El planificador carece de diversidad y no puede reproducir los itinerarios históricos. |
| Alta | Comidas externas por negocios categoría restaurante/café | No hay restaurantes reales confirmados en `businesses` | No habrá candidatos externos; solo podría haber comidas de servicios asociados si existen. |
| Alta | Experiencias activas con horarios, tarifas y proveedores | No se confirmó un inventario actual de `business_experiences`/`experience_rates` | Los tours/sesiones históricos podrían haber desaparecido al sincronizar la base. |
| Media | Horarios reales mediante `business_hours` y `experience_schedules` | La aplicación los consulta; no hay datos confirmados para el nuevo catálogo salvo los existentes en Supabase | Sin horarios, el motor usa ramas/fallbacks o descarta candidatos según el tipo de actividad. |
| Media | Datos de comida y transporte en `business_meal_services` y `business_transport_routes` | Son dependencias directas del generador; su disponibilidad depende del esquema desplegado | Si una tabla o relación falta, la consulta anidada puede fallar o la función degradarse, según la ruta. |
| Media | Negocios activos en todos los candidatos del planificador | La consulta base del generador alrededor de 5066 no aplica explícitamente `.eq('is_active', true)` y `legacyPlanifiableBusinesses` tampoco vuelve a filtrarlo | Un registro inactivo legible podría entrar al conjunto legacy. Esto no explica el catálogo faltante, pero debe corregirse antes de producción. |

## 7. Fuente única de verdad recomendada antes de producción

La fuente única de verdad debe ser **Supabase**, con esta jerarquía:

1. `public.businesses`: entidad/proveedor/lugar, categoría, estado de publicación, ubicación, imagen, atributos básicos y, cuando aplique, alojamiento legacy.
2. `public.business_experiences`: cada actividad/tour vendible o planificable, vinculada por `business_id`, con duración, tipo de agenda, estado de reserva y coordenadas efectivas opcionales.
3. `public.experience_schedules`: sesiones/horarios de las experiencias.
4. `public.experience_rates` y `public.business_rates`: precios estructurados, monedas y fiscalidad.
5. `public.business_hours`: horarios de negocios legacy/restaurantes.
6. `public.business_meal_services`: comidas incluidas/extra-cost asociadas al negocio o experiencia.
7. `public.business_transport_routes`: rutas de hospedaje, únicamente cuando el hospedaje realmente las ofrece.

`App.js` debe consumir ese catálogo y no reconstruirlo desde arrays ni coincidencias por nombre. Las coincidencias históricas de duración pueden mantenerse temporalmente como compatibilidad, pero no como fuente de producto.

## 8. Datos que deben migrarse/cargarse a Supabase

Para recuperar el catálogo deseado, migrar por cada negocio real:

1. Una fila `businesses` con `is_active`, `is_verified`, categoría, `planning_role`, coordenadas, `image_url`, contacto y nivel de presupuesto.
2. Para tours/actividades: una fila `business_experiences` con `duration_minutes`, `schedule_type`, `is_active`, `is_bookable`, reserva y `business_id` válido.
3. Para tours por hora/sesión: filas en `experience_schedules`.
4. Para todo costo vendible: tarifas activas en `experience_rates` o `business_rates`, con unidad, moneda e impuestos.
5. Para restaurantes: negocio activo con categoría normalizada y al menos horario en `business_hours` y precio estructurado/legacy cuando se conozca.
6. Para hospedajes: tarifa por noche, check-in/check-out y, si se ofrece, comida/ruta en las tablas asociadas.

Prioridad de carga: hospedajes → actividades principales → horarios/sesiones → tarifas → restaurantes/comidas → imágenes → rutas de transporte.

## 9. Próximas verificaciones de solo lectura

Antes de cargar datos, ejecutar en Supabase SQL Editor:

```sql
select b.id, b.name, b.category, b.is_active, b.is_verified,
       e.id as experience_id, e.name as experience_name,
       e.schedule_type, e.duration_minutes, e.is_active as experience_active
from public.businesses b
left join public.business_experiences e on e.business_id = b.id
order by b.name, e.name;

select e.name as experience_name, r.rate_name, r.price, r.currency,
       r.price_unit, r.active
from public.business_experiences e
left join public.experience_rates r on r.experience_id = e.id
order by e.name, r.rate_name;
```

Estas consultas no cambian datos y permiten comprobar si algún tour histórico subsiste como experiencia de Nayara, Volcano Lodge o Místico.

## Dictamen

Los negocios y actividades históricos no proceden hoy de un mock/seed activo en el código. Proceden —o procedían— de la base Supabase. El catálogo productivo debe reconstruirse y versionarse como datos de Supabase antes de considerar el planificador listo para producción.

