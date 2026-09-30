# Arquitectura propuesta: Google Places API (New) como complemento de catálogo

Fecha: 2026-09-20  
Estado: diseño únicamente. No se creó API key, no se ejecutó SQL y no se modificó `App.js` ni Supabase.

## Decisión de arquitectura

Google Places API (New) debe ser una **fuente complementaria de descubrimiento, identidad y fotografía dinámica**, nunca la fuente de verdad operacional de Maleku Go.

| Dato | Fuente de verdad |
|---|---|
| Nombre curado, categoría, estado, planificación, duración, reserva | Maleku Go / proveedor en Supabase |
| Tarifas, impuestos, unidades, costo y presupuesto | Maleku Go / proveedor en Supabase |
| Horarios operativos que afectan el planificador | Maleku Go / proveedor validado en Supabase |
| Transporte, rutas y costos de movilidad | Maleku Go / proveedor en Supabase |
| Identidad externa de un lugar | `google_place_id`, opcional |
| Foto externa de respaldo | Google Places, obtenida dinámicamente |
| Foto propia o enviada por negocio | Supabase Storage y `businesses.image_url` |

La app no descargará, copiará ni subirá fotografías de Google Places a Supabase Storage. Tampoco persistirá URLs Google, binarios, `photos[].name`, attributions o reseñas de Google.

## Arquitectura propuesta

```text
React Native / Expo
  │
  ├─ image_url propia válida ────────────────► Supabase Storage / URL propia
  │
  └─ sin imagen propia + google_place_id
       │
       ▼
Supabase Edge Function: google-place-photo
  │  1. valida el business_id solicitado
  │  2. obtiene google_place_id e image_source desde Supabase
  │  3. llama Place Details (New), con field mask mínimo: photos, googleMapsUri
  │  4. llama Place Photos (New) solo para la foto visible
  │  5. devuelve metadatos efímeros: photoUri + attributions + googleMapsUri
  ▼
Google Places API (New)
```

La Edge Function es el punto correcto para la integración porque la clave de servidor no llega al bundle Expo ni a `App.js`. Expo consume la función por `fetch`, por lo que no requiere instalar dependencias nuevas.

## Regla de presentación de imagen

La regla debe ser única y no debe afectar Smart Schedule:

1. Si `business.image_url` es un string no vacío y representa una imagen propia publicada, renderizarla.
2. Si no hay imagen propia y existe `business.google_place_id`, solicitar una imagen dinámica al proxy.
3. Si la función falla, el lugar no tiene fotos o no existe `google_place_id`, renderizar el placeholder actual.

`image_source` guía la procedencia, pero no invalida la prioridad: durante una migración, un `image_url` propio no vacío debe ganar incluso si `image_source` es `NULL` por compatibilidad.

| `image_url` | `google_place_id` | resultado |
|---|---|---|
| propia válida | cualquiera | imagen propia |
| NULL/vacía | presente | Google Places dinámico |
| NULL/vacía | ausente | placeholder |

## Cambios mínimos propuestos en Supabase

Agregar únicamente campos opcionales a `public.businesses`:

- `google_place_id text NULL`: identificador durable de Places; es el único dato Places que se propone guardar de forma permanente.
- `image_source text NULL`: `own`, `business` o `google_places`.
- `external_source text NULL`: opcional; valor esperado inicial `google_places` cuando el lugar fue reconciliado manualmente con Google.
- `external_updated_at timestamptz NULL`: opcional; instante interno en que Maleku Go validó el vínculo externo, no una afirmación de actualización de Google.

No se agregan tablas de fotos Google, ni se reemplaza `image_url`. No se almacena `photos[].name`, ya que Google indica que ese identificador no puede almacenarse/cachéarse. [Place Photos (New)](https://developers.google.com/maps/documentation/places/web-service/place-photos)

### SQL propuesto — NO EJECUTADO

```sql
-- NO EJECUTAR SIN REVISION
-- FASE 1 — Metadatos opcionales de Google Places.
-- No modifica image_url ni migra datos existentes.

begin;

alter table public.businesses
  add column if not exists google_place_id text,
  add column if not exists image_source text,
  add column if not exists external_source text,
  add column if not exists external_updated_at timestamptz;

alter table public.businesses
  drop constraint if exists businesses_image_source_check;

alter table public.businesses
  add constraint businesses_image_source_check
  check (
    image_source is null
    or image_source in ('own', 'business', 'google_places')
  );

create index if not exists businesses_google_place_id_idx
  on public.businesses (google_place_id)
  where google_place_id is not null;

commit;
```

No se recomienda un índice `UNIQUE` inicialmente: dos registros internos podrían referirse temporalmente al mismo complejo/proveedor durante una reconciliación de catálogo. La deduplicación debe revisarse en administración, no fallar de modo inesperado en producción.

## Edge Functions futuras

### 1. `google-place-photo`

Entrada mínima:

```json
{ "businessId": "uuid", "maxWidthPx": 640 }
```

Responsabilidades:

1. Validar request, limitar ancho (por ejemplo 240/640/1200), aplicar rate limit por usuario/IP y no aceptar `photoName` del cliente.
2. Leer solamente `id`, `is_active`, `is_verified`, `image_url`, `image_source`, `google_place_id` desde `businesses`.
3. Rechazar si el negocio no es público, tiene una foto propia prioritaria o no tiene `google_place_id`.
4. Pedir Place Details (New) con un field mask mínimo para `photos` y `googleMapsUri`.
5. Elegir una foto de la respuesta actual y solicitar Place Photos (New) con `skipHttpRedirect=true`.
6. Devolver al cliente una respuesta efímera con `photoUri`, `authorAttributions`, `googleMapsUri`, `flagContentUri` si está disponible, y un indicador `source: 'google_places'`.
7. No escribir esa respuesta en Supabase, Storage, AsyncStorage ni tablas de logs de contenido.

### 2. `google-places-search` — solo para administración de catálogo

Entrada: consulta textual y sesgo geográfico opcional.  
Salida: candidatos de revisión manual con `id`, nombre visible, dirección, ubicación y enlace Maps cuando esté permitido.

La función debe usar Text Search (New) con una máscara mínima, por ejemplo `places.id,places.displayName,places.formattedAddress,places.location,places.googleMapsUri`. Text Search exige `textQuery` y una field mask; pedir campos extra aumenta la respuesta y puede cambiar el SKU/costo. [Text Search (New)](https://developers.google.com/maps/documentation/places/web-service/text-search)

No debe actualizar automáticamente `businesses`. Un administrador compara proveedor, dirección y coordenadas; solo después aprueba manualmente la asociación `google_place_id`.

## Seguridad de API key

1. Guardar la clave de Google únicamente como secreto de Supabase Edge Functions, por ejemplo `GOOGLE_PLACES_API_KEY`.
2. Nunca incluirla en `EXPO_PUBLIC_*`, `app.json`, `App.js`, AsyncStorage, logs o respuestas de la función.
3. Restringir la clave en Google Cloud a Places API (New) y a la identidad/egreso de servidor que corresponda; configurar cuotas y alertas de facturación.
4. La función acepta `businessId`, no URLs, `placeId` arbitrarios ni nombres de recursos de foto. Así evita convertirse en un proxy genérico de Google.
5. Requerir una sesión si el contenido se ofrece en un panel administrativo; para fotos públicas, permitir solo negocios activos/verificados y aplicar cuota/rate limiting.

## Atribución y cumplimiento

Google exige respetar las atribuciones y políticas de Places API. Si una foto incluye `authorAttributions`, deben mostrarse junto a ella; además el usuario debe poder acceder al contenido fuente en Google Maps mediante `googleMapsUri`. [Policies and attributions](https://developers.google.com/maps/documentation/places/web-service/policies?authuser=804924846)

Aplicación práctica propuesta:

- En tarjeta pequeña: se puede omitir la atribución del autor solo si tocar la imagen abre un detalle que sí expone la atribución completa, conforme a las reglas de fotos de Google.
- En detalle o galería: mostrar autor, enlace si existe y acción “Ver en Google Maps”.
- Si se muestran datos Places fuera de un mapa de Google, incluir la atribución/logotipo Google Maps que corresponda a la política vigente.
- Añadir enlaces a términos y política de privacidad de Maleku Go que incorporen los requisitos de Google.

La política vigente prohíbe prefetched/cached content de Places salvo excepciones; `place_id` es una excepción explícita. [Policies and attributions](https://developers.google.com/maps/documentation/places/web-service/policies?authuser=804924846)

## Estrategia de minimización de costos

1. No consultar Google para negocios que ya tengan `image_url` propia válida.
2. No precargar fotos de todas las tarjetas ni ejecutar búsquedas al abrir Home.
3. Solicitar una foto únicamente cuando una tarjeta Google visible necesite renderizar imagen; deduplicar solicitudes concurrentes solo durante el ciclo de render en memoria, sin persistir contenido Places.
4. Solicitar un único tamaño por contexto (por ejemplo, 240 para miniaturas y 640 para detalle); las solicitudes de fotos requieren `maxWidthPx` o `maxHeightPx`. [Place Photos (New)](https://developers.google.com/maps/documentation/places/web-service/place-photos)
5. Usar masks mínimas: no wildcard (`*`), reseñas, ratings, horarios, teléfonos ni datos que Maleku Go no vaya a mostrar en esa petición. Las masks son obligatorias y también controlan costo. [Choose fields to return](https://developers.google.com/maps/documentation/places/web-service/choose-fields)
6. Limitar `google-places-search` a administración y a acción explícita “Buscar coincidencia”; guardar solo el `place_id` aprobado.
7. Configurar presupuestos, cuotas, alertas y observabilidad por endpoint en Google Cloud y Edge Functions.

## Estrategia de fallback y errores

| Situación | Resultado visible | Acción técnica |
|---|---|---|
| `image_url` propia válida | Imagen propia | No llamar Google. |
| Sin propia + `google_place_id` + foto disponible | Foto dinámica Google con atribución | Respuesta efímera de Edge Function. |
| Place sin fotos | Placeholder | Guardar nada; no reintentar en bucle. |
| 404/expiración de foto | Placeholder | En siguiente vista pedir Details de nuevo; nunca reutilizar `photo.name` almacenado. |
| 429/cuota o fallo Google | Placeholder silencioso para usuario; telemetría técnica agregada | Backoff limitado y no bloquear Home/itinerario. |
| Error Edge Function/red | Placeholder | Smart Schedule y presupuesto siguen intactos. |
| Coincidencia ambigua Text Search | No asociar automáticamente | Revisión humana. |

## Cambios futuros acotados en `App.js`

No son parte de esta fase. Cuando se implemente:

1. Centralizar la decisión visual en un helper de presentación, por ejemplo `resolveBusinessImageSource(business)`; no mezclarla con tarifas, actividad ni Smart Schedule.
2. Extender únicamente el `select` de `businesses` para incluir `google_place_id` e `image_source` donde ya se consulta `image_url`.
3. Crear un componente de imagen externa que gestione carga/error/atribución y muestre placeholder.
4. Mantener todos los cálculos de itinerario usando `businesses.latitude`, `longitude`, tarifas y horarios controlados por Maleku Go; una foto Google no modifica esos campos.
5. Integrar una acción administrativa separada para buscar y aprobar coincidencias; no insertar ni actualizar automáticamente durante el flujo del turista.

## Fases de implementación

1. **Esquema:** aprobar y aplicar los cuatro campos opcionales; no poblar masivamente todavía.
2. **Administración:** Edge Function de Text Search, UI privada de coincidencias y aprobación humana de `google_place_id`.
3. **Fotos dinámicas:** Edge Function de foto, componente React Native y atribución en tarjetas/detalle.
4. **Observabilidad:** cuotas, rate limit, errores y medición de fallback.
5. **Validación legal/UX:** revisar términos, privacidad, atribución y experiencia offline.

## Riesgos y controles

| Riesgo | Control |
|---|---|
| Exposición de API key | Edge Function + secreto de servidor + restricciones Cloud. |
| Costos por render masivo | Carga bajo demanda, masks mínimas, límites y cuotas. |
| Violación de política de caché | Guardar solo `google_place_id`; no persistir fotos, URLs, photo names ni detalles Places. |
| Asociación de negocio errónea | Text Search solo asistido; aprobación humana por dirección/coordenadas/proveedor. |
| Atribución ausente | Metadatos efímeros obligatorios y UI de detalle con enlace Google Maps. |
| Fallo externo afecta viaje | Placeholder; ninguna rama de Places se conecta a Smart Schedule, presupuesto, impuestos o traslados. |
| Datos comerciales divergentes | Prohibir que Google alimente precios, duración, impuestos, reservas, tarifas o transporte. |

## Qué no almacenar

- Fotografías descargadas de Google en Supabase Storage.
- Bytes, base64 o thumbnails de fotos Google.
- `photos[].name` / resource name / photo reference.
- URLs `photoUri` o URLs de redirección de foto como `businesses.image_url`.
- Reseñas, ratings, precios Google, horarios Google o datos comerciales como sustituto de proveedor.
- Una API key en el cliente.
- Respuestas completas de Place Details/Text Search en tablas de producción.

## Compatibilidad con el planificador actual

La integración propuesta es puramente de enriquecimiento visual e identidad externa. No cambia `businesses.id`, tarifas, experiencias, horarios, coordenadas curadas, disponibilidad, categorías operativas ni los objetos que consume Smart Schedule. Si Places no responde, el comportamiento del planificador es el mismo: el negocio conserva su placeholder actual.

