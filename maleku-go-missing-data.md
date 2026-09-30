# Datos faltantes para el seed productivo — Maleku Go

Fecha: 2026-09-20  
Este documento no contiene datos inventados ni cambios en Supabase.

## Bloqueadores de catálogo

No existe un seed histórico versionado que aporte tarifas, ubicaciones, horarios o proveedores para Los Lagos, Arenal Springs, Royal Corin, Arenal Kioro, Lomas del Volcán, Arenal Observatory, Tabacón, Asha Hostel, Río Celeste, Catarata La Fortuna, ATV, Rafting Balsa, Cavernas de Venado, Observación de Aves, Safari Float, los tours de café/chocolate, Don Juan o restaurantes concretos.

Las reglas de `App.js` que reconocen algunos nombres solo proporcionan duración de fallback. No son evidencia suficiente para activar o verificar un negocio, cobrarlo, mostrar una imagen o programarlo en producción.

## Información necesaria por tipo

### Negocios/hospedajes

Para cada hospedaje faltante se requiere:

1. Nombre comercial legal y URL/fuente de verificación.
2. Categoría y nivel de presupuesto validado.
3. Dirección y coordenadas reales.
4. Check-in/check-out y horario operativo.
5. Al menos una tarifa activa en `business_rates`: importe, moneda, unidad, vigencia, impuesto incluido/tasa y fuente.
6. Reserva requerida, contacto y URL de reserva si aplica.
7. Imagen con derechos ya subida a Storage; solo entonces `image_url`.

### Actividades/tours

Para cada actividad se requiere:

1. Proveedor real que exista en `public.businesses`.
2. Una fila `business_experiences` con duración validada, tipo de experiencia, tipo de agenda y reserva.
3. Coordenadas propias o proveedor con coordenadas válidas.
4. Horario de apertura o sesiones en `experience_schedules`.
5. Una o más tarifas activas en `experience_rates`, con unidad, moneda, impuesto y restricciones de edad/grupo si corresponde.
6. Imagen confirmada y fuente/autoría.

### Restaurantes/comidas

No hay nombres de restaurantes respaldados por el proyecto. Antes de cargar alguno se necesita:

1. Nombre comercial, categoría y proveedor.
2. Ubicación y horarios en `business_hours`.
3. Precio estructurado verificable, o estado explícito de precio pendiente.
4. Servicios de comida asociados solo cuando sean reales (`business_meal_services`).

## Datos específicos recuperables del código — requieren validación

| Entidad | Duración heurística actual | No debe tratarse aún como |
|---|---:|---|
| Volcán Arenal | 180 min | horario, tarifa ni duración comercial confirmada |
| Río Celeste | 480 min | producto/proveedor confirmado |
| Catarata La Fortuna | 180 min | horario, tarifa ni reserva |
| Místico/Puentes Colgantes | 240 min | tarifa o horario actual |
| ATV | 240 min | nombre comercial/proveedor/tarifa |
| Rafting | 330 min | ruta Balsa concreta ni precio |
| Cavernas de Venado | 300 min | reserva/tarifa/horario |
| Safari Float | 180 min | proveedor/tarifa/horario |
| Observación de Aves | 240 min | producto comercial definido |
| Tour de Café y Chocolate | 180 min | proveedor/tarifa/horario |
| Tour de Chocolate | 150 min | proveedor/tarifa/horario |

## Imágenes faltantes esperadas

Los siguientes paths son solo nombres esperados; no son URLs ni implican que el objeto ya exista:

- `seed/los-lagos.jpg`
- `seed/arenal-springs.jpg`
- `seed/royal-corin.jpg`
- `seed/arenal-kioro.jpg`
- `seed/lomas-del-volcan.jpg`
- `seed/arenal-observatory.jpg`
- `seed/tabacon.jpg`
- `seed/asha-hostel.jpg`
- `seed/volcan-arenal.jpg`
- `seed/rio-celeste.jpg`
- `seed/catarata-la-fortuna.jpg`
- `seed/mistico-arenal-hanging-bridges-park.jpg`
- `seed/atv.jpg`
- `seed/rafting-balsa.jpg`
- `seed/cavernas-de-venado.jpg`
- `seed/observacion-de-aves.jpg`
- `seed/safari-float.jpg`
- `seed/tour-de-cafe-y-chocolate.jpg`
- `seed/tour-de-chocolate.jpg`
- `seed/don-juan.jpg`

Nayara Gardens y Volcano Lodge ya tienen URL asociada según la auditoría de imágenes. No deben duplicarse ni reemplazarse durante el seed de catálogo.

## Orden seguro antes de una ejecución productiva

1. Reunir fuente comercial y consentimiento/fuente de imagen para cada entidad.
2. Completar una hoja de aprobación con todos los campos obligatorios.
3. Resolver duplicados por nombre normalizado y revisar manualmente homónimos.
4. Insertar negocios verificados inicialmente como datos coherentes.
5. Insertar experiencias vinculadas con los IDs resueltos de esos negocios.
6. Insertar horarios/sesiones y tarifas verificadas.
7. Subir imágenes y verificar `storage.objects` antes de escribir `image_url`.
8. Ejecutar pruebas del planificador y de presupuesto con datos de staging.

## Riesgos antes de ejecutar un seed

- Crear negocios no verificados como activos los haría visibles y planificables prematuramente.
- Cargar tarifas o impuestos aproximados comprometería el motor de presupuesto.
- Asociar una experiencia a un proveedor incorrecto rompe traslados, comidas y reservas.
- Coordenadas estimadas alteran el Smart Schedule y el combustible.
- Reutilizar URLs sin confirmar Storage puede dejar tarjetas sin imagen.
- Comparar solo por nombre puede confundir homónimos; revisar manualmente coincidencias antes de insertar.

