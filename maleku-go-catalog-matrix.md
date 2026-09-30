# Matriz de preparación de catálogo — Maleku Go

Fecha: 2026-09-20  
Estado: preparación local; no se ejecutó SQL ni se cambió Supabase.

## Leyenda de evidencia

- **A — confirmado:** existe en `public.businesses` según la auditoría previa, o está explícitamente proporcionado como dato actual.
- **B — recuperado de seed histórico/código:** nombre, categoría solicitada o duración inferida desde una heurística existente de `App.js`; no equivale a datos comerciales verificados.
- **C — faltante:** el proyecto no contiene un valor demostrable; no se debe sembrar como dato de producción.
- **D — no duplicar:** el negocio ya existe en Supabase y debe resolverse por nombre normalizado para conservar su UUID real.

## Matriz de entidades objetivo

| name | categoría | estado | budget_level | precio min/max/unidad/moneda | duration_minutes | reserva | lat/lon | image_url / archivo esperado | horario | departures | fuente local | campos faltantes |
|---|---|---|---|---|---:|---|---|---|---|---|---|---|
| Nayara Gardens | Hospedaje | A, D | premium (A) | C | — | C | C | URL actual `seed/nayara-gardens.jpg` (A) | C | C | Auditoría de `businesses`; assets locales | tarifas, ubicación, horario, reserva, salidas |
| Volcano Lodge Hotel & Thermal Experience | Hospedaje | A, D | medio (A) | C | — | C | C | URL actual `seed/volcano-lodge.jpg` (A) | C | C | Auditoría de `businesses`; assets locales | tarifas, ubicación, horario, reserva, salidas |
| Los Lagos | Hospedaje | B | C | C | — | C | C | `seed/los-lagos.jpg` | C | C | Nombre/categoría solicitados; sin seed SQL | todos salvo nombre/categoría |
| Arenal Springs | Hospedaje | B | C | C | — | C | C | `seed/arenal-springs.jpg` | C | C | Nombre/categoría solicitados; sin seed SQL | todos salvo nombre/categoría |
| Royal Corin | Hospedaje | B | C | C | — | C | C | `seed/royal-corin.jpg` | C | C | Nombre/categoría solicitados; sin seed SQL | todos salvo nombre/categoría |
| Arenal Kioro | Hospedaje | B | C | C | — | C | C | `seed/arenal-kioro.jpg` | C | C | Nombre/categoría solicitados; sin seed SQL | todos salvo nombre/categoría |
| Lomas del Volcán | Hospedaje | B | C | C | — | C | C | `seed/lomas-del-volcan.jpg` | C | C | Nombre/categoría solicitados; sin seed SQL | todos salvo nombre/categoría |
| Arenal Observatory | Hospedaje | B | C | C | — | C | C | `seed/arenal-observatory.jpg` | C | C | Nombre/categoría solicitados; sin seed SQL | todos salvo nombre/categoría |
| Tabacón | Hospedaje | B | C | C | — | C | C | `seed/tabacon.jpg` | C | C | Nombre/categoría solicitados; sin seed SQL | todos salvo nombre/categoría |
| Asha Hostel | Hospedaje | B | C | C | — | C | C | `seed/asha-hostel.jpg` | C | C | Nombre/categoría solicitados; sin seed SQL | todos salvo nombre/categoría |
| Volcán Arenal | Naturaleza / actividad | B | C | C | 180 (B) | C | C | `seed/volcan-arenal.jpg` | C | C | Heurística `name.includes('volcan arenal')`, `App.js:8043–8044`, `9248–9249` | proveedor, tarifa, ubicación, agenda, reserva |
| Río Celeste | Naturaleza / actividad | B | C | C | 480 (B) | C | C | `seed/rio-celeste.jpg` | C | C | Heurística de 8 h, `App.js:8029–8031`, `9234–9236` | proveedor, tarifa, ubicación, agenda, reserva |
| Catarata La Fortuna | Naturaleza / actividad | B | C | C | 180 (B) | C | C | `seed/catarata-la-fortuna.jpg` | C | C | Heurística de 3 h, `App.js:8050`, `9255` | proveedor, tarifa, ubicación, agenda, reserva |
| Mistico Arenal Hanging Bridges Park | Naturaleza | A, D | medio (A) | C | 240 (B) | C | C | sin URL; esperado `seed/mistico-arenal-hanging-bridges-park.jpg` | C | C | Auditoría de `businesses`; heurística Místico/Puentes 4 h | precio, ubicación, horario, reserva, imagen |
| ATV | Aventura / actividad | B | C | C | 240 (B) | C | C | `seed/atv.jpg` | C | C | Heurística de 4 h, `App.js:8062`, `9267` | nombre comercial/proveedor, tarifa, ubicación, agenda, reserva |
| Rafting Balsa | Aventura / actividad | B | C | C | 330 (B) | C | C | `seed/rafting-balsa.jpg` | C | C | Heurística genérica rafting 5.5 h, `App.js:8056–8060`, `9261–9265` | proveedor, tarifa, ubicación, agenda, reserva |
| Cavernas de Venado | Aventura / actividad | B | C | C | 300 (B) | C | C | `seed/cavernas-de-venado.jpg` | C | C | Heurística de 5 h, `App.js:8068`, `9273` | proveedor, tarifa, ubicación, agenda, reserva |
| Observación de Aves | Vida silvestre / actividad | B | C | C | 240 (B) | C | C | `seed/observacion-de-aves.jpg` | C | C | Heurística de 4 h, `App.js:8080–8081`, `9285–9286` | nombre comercial/proveedor, tarifa, ubicación, agenda, reserva |
| Safari Float | Vida silvestre / actividad | B | C | C | 180 (B) | C | C | `seed/safari-float.jpg` | C | C | Heurística de 3 h, `App.js:8074`, `9279` | proveedor, tarifa, ubicación, agenda, reserva |
| Tour de Café y Chocolate | Cultura / actividad | B | C | C | 180 (B) | C | C | `seed/tour-de-cafe-y-chocolate.jpg` | C | C | Coincidencia `cafe y chocolate` = 3 h, `App.js:8099–8102`, `9304–9307` | proveedor, tarifa, ubicación, agenda, reserva |
| Tour de Chocolate | Cultura / actividad | B | C | C | 150 (B) | C | C | `seed/tour-de-chocolate.jpg` | C | C | Heurística de 2.5 h, `App.js:8094`, `9299` | proveedor, tarifa, ubicación, agenda, reserva |
| Don Juan | Cultura / actividad | B | C | C | C | C | C | `seed/don-juan.jpg` | C | C | Nombre/categoría solicitados; no hay regla específica ni seed local | todos salvo nombre/categoría |
| Restaurantes/comidas reales | Restaurante / Café | C | C | C | C | C | C | por negocio, `seed/<slug>.jpg` | C | C | Código filtra categorías, pero no contiene nombres concretos: `App.js:15560–15620`, `16664–16730` | lista de establecimientos y todos los datos comerciales |

## Datos recuperados versus faltantes

### Confirmados y no duplicables

1. Nayara Gardens — UUID actual: `caacd26b-92e0-4638-acea-074bc77f25c9`.
2. Volcano Lodge Hotel & Thermal Experience — UUID actual: `c92de92e-25cd-4f02-b74f-b70f86f0e010`.
3. Mistico Arenal Hanging Bridges Park — UUID actual: `0ee01a84-aa18-4aec-9673-ab24f9b847cd`.

Los tres deben resolverse en el SQL por `lower(trim(name))`; nunca se deben recrear con UUIDs fijos.

### Valores históricos recuperables del código

Las duraciones señaladas como B son fallback de Smart Schedule, no hechos comerciales. Sirven para completar una ficha de revisión, pero se deben validar con el proveedor antes de insertarlas en `business_experiences.duration_minutes`.

### Ausencias verificadas

No se encontraron en el proyecto:

- `INSERT` históricos para el catálogo solicitado.
- coordenadas verificables para las entidades objetivo.
- precios, monedas o unidades comerciales verificables para las entidades objetivo.
- horarios/departures verificables para el catálogo histórico.
- nombres de restaurantes reales.
- imágenes para las entidades distintas de Nayara y Volcano Lodge.

## Estructura de destino requerida por el planificador

| Tabla | Uso de catálogo recomendado | Campos mínimos que deben estar validados antes de publicar |
|---|---|---|
| `public.businesses` | Proveedor/lugar/hospedaje/restaurante | `name`, `category`, `is_active`, `is_verified`, coordenadas si interviene en traslado; `image_url` solo cuando ya exista el objeto Storage. |
| `public.business_experiences` | Cada tour/actividad planificable | `business_id`, `name`, `experience_type`, `schedule_type`, `duration_minutes`, `is_active`, `is_bookable`, reserva, horarios/ubicación cuando aplique. |
| `public.business_rates` | Hospedaje, negocios legacy y servicios generales | `business_id`, `rate_name`, `price`, `currency`, `price_unit`, `active`, fiscalidad. |
| `public.experience_rates` | Tarifas de tours/experiencias | `experience_id`, `price`, `currency`, `price_unit`, `active`, fiscalidad, restricciones de viajeros si aplica. |
| `public.business_hours` | Horario de negocio/restaurante legacy | `business_id`, `day_of_week`, apertura, cierre, `is_closed`, último ingreso si existe. |
| `public.experience_schedules` | Sesiones FIXED | `experience_id`, día, inicio, fin, `is_active`. |
| `public.business_departures` | Salidas estructuradas futuras | Solo cuando haya datos reales; no es consultada directamente por el planificador actual. |
| `public.business_meal_services` | Comidas incluidas o con costo | Datos reales del servicio, precio/unidad/fiscalidad y asociación correcta. |
| `public.business_transport_routes` | Transporte de hospedaje | Ruta dirigida, precio/unidad, capacidad y fiscalidad; no insertar con datos supuestos. |

## Resultado de preparación

- Entidades objetivo identificadas: **22** más una categoría abierta de restaurantes.
- Existentes/no duplicables: **3**.
- Con duración recuperable solo como heurística: **11** (incluye Místico; no es tarifa ni dato validado).
- Listas para insertar sin completar datos comerciales: **0**.
- Entidades parcialmente descritas (nombre/categoría y, en algunos casos, duración heurística): **19**.
- Entidades completamente faltantes para producción: **19**; restaurantes además requieren un inventario nominal.
