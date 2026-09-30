# Auditoría de imágenes de negocios — Maleku Go

Fecha de auditoría: 2026-09-20  
Modo: solo lectura. No se modificó Supabase ni `App.js`.

## Alcance y fuentes

- Fuente de datos: consulta de solo lectura a `public.businesses` mediante el cliente definido en `supabase.js` (`EXPO_PUBLIC_SUPABASE_URL` y `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`).
- Contrato visible de la app: `App.js` carga y renderiza `businesses.image_url` (por ejemplo, consultas alrededor de las líneas 2300, 2403, 2521 y renderizados alrededor de 1409, 2818 y 26706).
- Bucket objetivo: `pura-ruta-imagenes`.
- Se excluyeron los nombres que comienzan, sin distinguir mayúsculas/minúsculas, por `[TEST]`, `TEST` o `Prueba`.
- Se revisaron assets locales: existen `nayara-gardens.jpg` y `volcano lodge.jpg` en la raíz del proyecto; no existe una carpeta local `seed/` ni un archivo local de Místico con el nombre esperado.

### Limitación de Storage

La llamada de solo lectura `storage.list('seed')` devolvió una lista vacía con las credenciales públicas. Eso **no demuestra** que los objetos no existan: la enumeración puede estar restringida por las políticas de Storage aunque las URLs públicas conocidas sean accesibles desde la app. La verificación HTTP individual desde este entorno falló por TLS local, no por una respuesta 404/403 del bucket.

Por ello, el estado de los dos ejemplos suministrados se considera **referenciado y funcional según el contexto proporcionado**, pero la lista completa de objetos del bucket debe confirmarse con una cuenta que tenga permiso `SELECT` sobre `storage.objects`, o desde Supabase SQL Editor.

## Conexión Supabase localizada

`supabase.js` crea el cliente con las variables públicas de entorno. `App.js` consulta `businesses` e incluye el campo `image_url`; la aplicación no necesita un campo alternativo para mostrar la foto del negocio.

## Inventario de negocios reales

| id | name | category | is_active | is_verified | budget_level | image_url_actual | tiene_imagen | archivo_seed_sugerido |
|---|---|---|---:|---:|---|---|---:|---|
| `0ee01a84-aa18-4aec-9673-ab24f9b847cd` | Mistico Arenal Hanging Bridges Park | Naturaleza | true | true | medio | NULL | No | `seed/mistico-arenal-hanging-bridges-park.jpg` |
| `caacd26b-92e0-4638-acea-074bc77f25c9` | Nayara Gardens | Hospedaje | true | true | premium | `.../pura-ruta-imagenes/seed/nayara-gardens.jpg` | Sí | `seed/nayara-gardens.jpg` |
| `c92de92e-25cd-4f02-b74f-b70f86f0e010` | Volcano Lodge Hotel & Thermal Experience | Hospedaje | true | true | medio | `.../pura-ruta-imagenes/seed/volcano-lodge.jpg` | Sí | `seed/volcano-lodge.jpg` |

Nota de normalización: el nombre genérico de Volcano Lodge produciría `seed/volcano-lodge-hotel-thermal-experience.jpg`; se conserva `seed/volcano-lodge.jpg` como excepción canónica porque es el archivo ya utilizado por la aplicación y proporcionado como ejemplo.

## Clasificación de registros

### A. Con `image_url` válido/referenciado

- Nayara Gardens → `seed/nayara-gardens.jpg`
- Volcano Lodge Hotel & Thermal Experience → `seed/volcano-lodge.jpg`

### B. Con `image_url` NULL o vacío

- Mistico Arenal Hanging Bridges Park

### C. Con ruta posiblemente inexistente

- Ninguno entre los negocios reales: las dos rutas existentes siguen exactamente el patrón público del bucket y corresponden a los ejemplos funcionales suministrados.
- La existencia del objeto no pudo enumerarse desde el cliente anónimo; debe verificarse antes de una actualización masiva.

### D. No verificados

- Ninguno entre los negocios reales leídos.

### E. Inactivos

- Ninguno entre los negocios reales leídos.

## Registros excluidos por ser pruebas

| nombre | motivo |
|---|---|
| `[TEST] Actividad flexible — 180 min` | Prefijo `[TEST]` |
| `[TEST] Actividad flexible B — 120 min` | Prefijo `[TEST]` |
| `[TEST] Laboratorio Maleku Go — NO PRODUCCIÓN` | Prefijo `[TEST]` |
| `[TEST] Transporte Maleku Go — NO PRODUCCIÓN` | Prefijo `[TEST]` |
| `Prueba edición propietario Fotos v1` | Prefijo `Prueba` |
| `Prueba negocio1` | Prefijo `Prueba` |
| `Test foto registro v1` | Prefijo `TEST` sin distinguir mayúsculas/minúsculas |
| `Test2 negocio de prueba` | Prefijo `TEST` sin distinguir mayúsculas/minúsculas |

## Estado frente a Storage y acción recomendada

| business_name | business_id | archivo_seed_esperado | archivo_existe_en_storage | image_url_coincide | accion_recomendada |
|---|---|---|---|---|---|
| Mistico Arenal Hanging Bridges Park | `0ee01a84-aa18-4aec-9673-ab24f9b847cd` | `seed/mistico-arenal-hanging-bridges-park.jpg` | No verificable desde el cliente anónimo; no hay asset local correspondiente | No; `image_url` es NULL | Conseguir una imagen con derechos, subirla al path indicado y verificar el objeto antes de asociarla. |
| Nayara Gardens | `caacd26b-92e0-4638-acea-074bc77f25c9` | `seed/nayara-gardens.jpg` | Referenciado como ejemplo funcional; enumeración no verificable | Sí | No cambiar. Verificar una vez mediante SQL Editor/Storage Dashboard antes de automatizar. |
| Volcano Lodge Hotel & Thermal Experience | `c92de92e-25cd-4f02-b74f-b70f86f0e010` | `seed/volcano-lodge.jpg` | Referenciado como ejemplo funcional; enumeración no verificable | Sí | No cambiar. Verificar una vez mediante SQL Editor/Storage Dashboard antes de automatizar. |

## Resumen cuantitativo

| Métrica | Cantidad |
|---|---:|
| Negocios reales leídos | 3 |
| Con `image_url` no vacío | 2 |
| Sin imagen asociada | 1 |
| Activos y verificados | 3 |
| Inactivos reales | 0 |
| No verificados reales | 0 |
| Archivos de `seed/` confirmables mediante enumeración pública desde este entorno | No determinable |
| Asociaciones ya coherentes con los ejemplos funcionales | 2 |
| Asociaciones pendientes que puedan actualizarse inmediatamente sin subir/verificar un archivo | 0 |

### Imagen que todavía debe conseguirse/subirse

- `seed/mistico-arenal-hanging-bridges-park.jpg` — Mistico Arenal Hanging Bridges Park (`0ee01a84-aa18-4aec-9673-ab24f9b847cd`).

## SQL de verificación manual de Storage (solo lectura)

Ejecutar manualmente en Supabase SQL Editor con privilegios apropiados, antes de cualquier actualización:

```sql
select
  bucket_id,
  name,
  id,
  created_at,
  updated_at,
  metadata
from storage.objects
where bucket_id = 'pura-ruta-imagenes'
  and name in (
    'seed/nayara-gardens.jpg',
    'seed/volcano-lodge.jpg',
    'seed/mistico-arenal-hanging-bridges-park.jpg'
  )
order by name;
```

## SQL de actualización masiva preparado — NO EJECUTAR

Este script solo contempla asociaciones cuyo archivo haya sido confirmado previamente en `storage.objects`. Con el inventario actual no hay filas pendientes para actualizar: Nayara y Volcano ya coinciden; Místico requiere primero subir y verificar el objeto. Se deja el patrón seguro para una ejecución futura.

```sql
-- NO EJECUTAR SIN CONFIRMAR PRIMERO storage.objects.
begin;

with image_mapping (business_id, image_url) as (
  values
    (
      'caacd26b-92e0-4638-acea-074bc77f25c9'::uuid,
      'https://aqbaftianloblozeszhc.supabase.co/storage/v1/object/public/pura-ruta-imagenes/seed/nayara-gardens.jpg'
    ),
    (
      'c92de92e-25cd-4f02-b74f-b70f86f0e010'::uuid,
      'https://aqbaftianloblozeszhc.supabase.co/storage/v1/object/public/pura-ruta-imagenes/seed/volcano-lodge.jpg'
    )
)
update public.businesses as business
set image_url = image_mapping.image_url
from image_mapping
where business.id = image_mapping.business_id
  and business.image_url is distinct from image_mapping.image_url;

-- Verificar el número y las filas afectadas antes de confirmar.
rollback;
```

Para Místico, agregar una fila al mapeo solo después de que la consulta de `storage.objects` confirme `seed/mistico-arenal-hanging-bridges-park.jpg`; nunca usar una URL ficticia ni actualizar por nombre.

## Próximo paso seguro

1. Verificar los tres paths con la consulta de solo lectura anterior.
2. Obtener y subir exclusivamente la imagen licenciada de Místico al path sugerido.
3. Confirmar visualmente la URL pública.
4. Preparar una migración de asociación por `id`, con condición `IS DISTINCT FROM`, y revisar las filas antes de `COMMIT`.

