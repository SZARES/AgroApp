# AgroApp — Estado actual de la implementación

Documento de traspaso para un asistente de IA que retoma el proyecto. Describe **qué está construido y cómo está hoy** (2026-10-10). El contexto de producto (roles, reglas de negocio, alcance del MVP, pantallas previstas) está en [CONTEXT.md](CONTEXT.md): léelo primero y trata este archivo como su complemento técnico.

Convención usada aquí: "verificado" significa que se comprobó ejecutándolo o consultándolo; lo demás sale de leer el código.

Este archivo no contiene contraseñas ni claves. Pídelas a la persona con la que trabajas.

---

## 1. Qué es, en una línea

App Flutter (móvil + web) offline-first para agricultores del bosque seco del norte de Perú y el equipo de AIDER (técnico, supervisor, admin), con backend Supabase.

## 2. Repositorio y entorno

| Dato | Valor |
|---|---|
| Ruta local | `C:\Users\JASM\Documents\Projects\hackathon\AgroApp` (Windows 11, PowerShell) |
| Remoto | `github.com:SZARES/AgroApp.git` |
| Rama de trabajo | `mockup` (último commit: `52f0466`, merge de `feat/full-supabase-app`) |
| Otras ramas | `master` (inicial), `feat/full-supabase-app` (trabajo de otro miembro del equipo, se fusiona en `mockup`) |
| Nombre del paquete Dart | `hackathon` (los imports son `package:hackathon/...`) |
| Application ID Android | `com.example.hackathon` |
| Flutter | 3.47.7 stable, Dart SDK `^3.10.7` |

Varias personas hacen push a las mismas ramas. Antes de editar, revisa `git status` y `git log`: los archivos cambian entre sesiones.

## 3. Backend Supabase

- **Proyecto:** ref `odttcsahrucsohtbqbro`.
- **Configuración del cliente:** URL y clave pública en [lib/config/supabase_config.dart](lib/config/supabase_config.dart). La clave de servicio nunca va en el cliente.
- **Acceso por MCP:** [.mcp.json](.mcp.json) define el servidor `supabase` apuntando a ese proyecto (requiere autorizarlo con OAuth). Los cambios por MCP van directo al proyecto remoto: no hay entorno local ni de staging.

### 3.1 Migraciones (`supabase/migrations/`)

`01_enums` → `02_catalogs` → `03_core_tables` → `04_indexes` → `05_functions_triggers` → `06_rls` → `07_storage` → `08_views` → `09_sync_rpc` → `10_seed_demo` → `11_admin_provision_and_hardening` / `11_verification` → `12_admin_user_provisioning` / `12_farmer_dni_login` → `13_parcel_geometry` → `14_visit_attendance_and_recommendation_marks`.

Verificado: la 14 está aplicada en el remoto (existen `visit_attendance_confirmations` y `recommendation_followups`, y `sync_batch` acepta la primera).

### 3.2 Esquema `public`

43 tablas, todas con RLS activado.

- **Catálogos:** `zones`, `communities`, `crops`, `units`, `unit_equivalences`, `products`, `product_units`, `activity_types`, `activity_type_units`, `crop_harvest_units`, `pruning_types`, `symptom_types`, `assistance_categories`, `assistance_subtypes`, `expense_categories`, `buyers`, `reference_prices`, `app_settings`.
- **Personas y territorio:** `profiles` (rol y estado), `user_zones`, `farmers` (incluye `dni`), `parcels` (`latitude`, `longitude`, `geometry` GeoJSON), `technician_parcels`, `crop_cycles`.
- **Operación:** `activities`, `expenses`, `incidents`, `incident_photos`, `incident_status_history`, `technical_assistance`, `assistance_documents`, `recommendations`, `recommendation_confirmations`, `recommendation_followups`, `visit_attendance_confirmations`, `reminders`, `harvests`, `surplus_sales`, `residue_management`, `notifications`, `device_tokens`.
- **Sistema:** `audit_logs`, `sync_log`.

Roles (`user_role`): `farmer`, `technician`, `supervisor`, `admin`.

### 3.3 Funciones del servidor

- **RPC `sync_batch(p_device_id, p_records)`**: inserción por lote, idempotente (`on conflict (id) do nothing`), con lista blanca de tablas. Devuelve `{ synced, failed }` y escribe en `sync_log`.
- **RPC `admin_provision_user(...)`**: crea `profiles` y, según el rol, `farmers` o `user_zones`.
- **Edge Functions** (`supabase/functions/`): `admin-create-user` (solo un admin activo; exige contraseña de 8+ caracteres) y `admin-manage-user`.
- **Helpers de RLS:** `app_role()`, `current_farmer_id()`, `can_access_farmer()`, `can_access_assistance()`.

### 3.4 Inicio de sesión

- Personal (técnico, supervisor, admin): correo + contraseña.
- Agricultor: escribe su **DNI** (8 dígitos); la app lo convierte a `<dni>@agricultores.agroapp` para Supabase Auth ([login_identifier.dart](lib/domain/models/login_identifier.dart)).

### 3.5 Cuentas de prueba

| Rol | Cuenta | Estado |
|---|---|---|
| Agricultor | "Agricultor Demo" (DNI terminado en `8912`) | Funciona (login verificado). Sin parcela. Comunidad Demo. |
| Técnico | "Técnico Demo" (`tecnico2@…`) | Funciona (login verificado). Zona Morropón. |
| Admin | Cuenta real de un miembro del equipo | Funciona; es personal, no de demo. |
| Agricultor | "Don Manuel" (seed) | **Rota**: login devuelve HTTP 500. |
| Técnico | "Técnica Rosa" (seed) | **Rota** (500). |
| Supervisor | "Supervisor Luis" (seed) | **Rota** (500). |
| Admin | "Admin AgroApp" (seed) | **Rota** (500). |

Los usuarios exactos están en `public.profiles`; las contraseñas hay que pedirlas al equipo.

**Por qué fallan las cuatro del seed** (verificado): `10_seed_demo.sql` inserta directo en `auth.users` dejando `confirmation_token`, `recovery_token`, `email_change` y `email_change_token_new` en NULL, y sin fila en `auth.identities`. Auth responde `"Database error querying schema"`. Arreglo pendiente: poner cadena vacía en esos campos y crear la identidad `email`. No hay ninguna cuenta demo de supervisor ni de admin que funcione.

Las dos cuentas demo que funcionan se crearon por SQL con ese arreglo ya incluido (tokens en `''`, fila en `auth.identities`, luego `admin_provision_user`). Usa ese mismo patrón si creas más usuarios por SQL.

### 3.6 Datos existentes

Catálogos con semilla (3 zonas: Morropón, Sullana, Tumbes; 3 cultivos; 31 unidades; 7 tipos de actividad). Datos de operación casi vacíos: 1 parcela ("La Esperanza", de Don Manuel, **sin coordenadas**), 1 ciclo de cultivo, 1 incidencia de semilla. `sync_log` estaba vacío en la última revisión.

## 4. Arquitectura de la app

Capas (UI → lógica → datos), con `provider` para inyección de dependencias:

```
lib/
  main.dart                  Inicializa Supabase y monta los providers
  app.dart                   MaterialApp + AuthGate; arma el árbol por rol
  config/                    supabase_config, dependencies (providers), map_config
  domain/models/             Modelos inmutables (Parcel, GeoPoint, Incident, AppUser, ...)
  data/
    local/                   Base Drift: tablas outbox, local_records, app_settings
    services/                Acceso a plataforma/red (Supabase auth, sync, admin, fotos, conectividad)
    repositories/            Reglas de datos; la UI solo habla con estos
    sync/                    SyncEngine y registro de tablas replicadas
  ui/
    core/                    Tema y widgets compartidos (field_map, aider_shell, ...)
    features/<feature>/      views/ + view_models/ por funcionalidad
    mock/mock_data.dart      Datos ficticios que aún usan algunas pantallas
  utils/result.dart          Result<T> (Ok / Error)
```

Convenciones del código: comentarios y nombres en inglés, textos de interfaz en español; view models con `ChangeNotifier`; repositorios detrás de interfaces para poder falsearlos en tests; errores como `Result` y enums de fallo, no excepciones hacia la UI.

### 4.1 Offline-first

- La UI lee y escribe en la **réplica local** (Drift/SQLite) a través de `LocalStore`.
- Las escrituras se encolan en `outbox` y `SyncEngine` las sube con `sync_batch` cuando hay conexión; también descarga las tablas listadas en [sync_tables.dart](lib/data/sync/sync_tables.dart) de forma incremental por `updated_at`.
- Suben por lote: `activities`, `expenses`, `incidents`, `incident_photos`, `harvests`, `surplus_sales`, `residue_management`, `recommendation_confirmations`, `technical_assistance`, `assistance_documents`, `visit_attendance_confirmations`.
- No se replican: `audit_logs`, `sync_log`, `device_tokens`.
- **Web:** Drift necesita `web/drift_worker.js` y `web/sqlite3.wasm` (ya están en el repo, del release `drift-2.34.4`). Si se actualiza `drift`, hay que reemplazarlos por los del release correspondiente.

### 4.2 Navegación por rol ([auth_gate.dart](lib/ui/features/auth/views/auth_gate.dart))

- Sin sesión → bienvenida → login.
- `farmer` → inicio del agricultor, en columna centrada.
- `technician` → en teléfono, vista móvil del técnico; en web o ventana ancha (≥ 900 px), consola.
- `supervisor` / `admin` → consola; en teléfono se sugiere usar una computadora.

## 5. Estado por funcionalidad

| Funcionalidad | Estado | Notas |
|---|---|---|
| Bienvenida y login | Real | DNI o correo contra Supabase Auth; sesión restaurada al abrir. |
| Inicio del agricultor | Real | Resumen desde la réplica local. Sin parcela se ocultan "Registrar actividad", "Reportar problema" y "Registrar cosecha". |
| Mis parcelas / Agregar terreno | Real | Guarda local y sincroniza. Ubicación por GPS del dispositivo. |
| Mapa de parcelas | Real | `flutter_map` con imágenes satelitales de Esri; ver sección 6. |
| Reportar problema (incidencia + foto) | Real en código | Llegó en el último merge (`incident_repository`, `photo_service`). No verificado de punta a punta. |
| Estado de un caso / Mis reportes | Real en código | Mismo merge; no verificado. |
| Técnico: bandeja y detalle de casos | Real en código | `technician_repository`, `technician_workspace`. En la consola web cubre los módulos Inicio y Alertas. No verificado en pantalla. |
| Consola: Administración | Real | Usuarios, catálogos y auditoría contra Supabase. Solo rol admin. |
| Consola: Parcelas, Territorio, Equipo, Reportes, Calendario | Placeholder | Pantallas vacías a propósito. |
| Registrar actividad | **Mock** | Usa `mock_data.dart`; no guarda. |
| Registrar cosecha | **Mock** | Usa `mock_data.dart`; no guarda. |
| Mis asistencias | **Mock** | Usa `mock_data.dart`. |
| Gastos, venta de excedentes, rastrojo, recordatorios | No construido | Las tablas existen; no hay pantallas. |

El equipo pidió explícitamente **no dejar datos hardcodeados**: lo que queda en `mock_data.dart` es deuda a eliminar, no un patrón a seguir.

## 6. Mapa y ubicación

- **Widget:** [field_map.dart](lib/ui/core/widgets/field_map.dart). Recibe `MapFieldShape` (nombre, centro, contorno opcional) y `MapPin` (posición, `resolved`, `id` opcional) en coordenadas reales (`GeoPoint`). `onPinTap` devuelve el `id` del pin tocado.
- **Conversión desde parcelas:** `projectParcels` en [parcel_map_projection.dart](lib/ui/features/parcel/view_models/parcel_map_projection.dart). Con `caseByParcel` los pines salen de los casos del técnico.
- **Teselas:** URL y atribución en [map_config.dart](lib/config/map_config.dart) (Esri World Imagery, sin API key). Requieren internet; sin conexión se dibujan los terrenos sobre fondo liso. Revisar los términos de Esri antes de publicar. Se evaluó Google Maps y se descartó por ahora: exige API key con facturación activada.
- **Ubicación:** [location_repository.dart](lib/data/repositories/location_repository.dart) usa `geolocator`. Primero toma la última ubicación conocida si tiene menos de 2 minutos; si no, pide una nueva al GPS.
- El mapa solo aparece si alguna parcela tiene coordenadas.

## 7. Problemas conocidos

1. **Cuentas del seed rotas** (sección 3.5). Bloquea probar supervisor y admin con cuentas demo.
2. **Emulador inestable.** El AVD `Pixel_5` usa una imagen de Android 17 (API 37, páginas de 16 KB) cuyos servicios de sistema fallan en bucle. Al pedir la ubicación, la llamada `removeNmeaListener` de `geolocator` se queda colgada en el servicio de ubicación del sistema, la app se congela (ANR) y Android la cierra; el sistema del emulador llegó a reiniciarse. Verificado en el registro del emulador. Recomendación: probar en un AVD con API 35 o 36, o en un teléfono real.
3. **Ubicación del emulador.** Por defecto reporta Mountain View, California. Para probar en Piura: `adb emu geo fix -79.97 -5.18` (longitud, luego latitud).
4. **Cierre al tomar foto en "Reportar problema".** Reportado por el equipo; **sin diagnosticar**: no ocurrió en el emulador conectado y no hay registro del dispositivo donde pasó. Hipótesis no confirmada: Android mata la app mientras la cámara está abierta y el código no recupera la foto (`ImagePicker.retrieveLostData` no se usa).
5. **Permiso INTERNET.** Faltaba en el manifiesto principal de Android (solo estaba en debug/profile); ya se agregó. Sin él, una build release no tiene red.
6. **Peso de recursos.** `assets/images/welcome_background.png` pesa 2,4 MB y ya no lo usa la bienvenida actual (que usa `assets/bgImagenMobil.jpeg` y `assets/bgImagenWeb.jpeg`); se puede borrar.

## 8. Cómo trabajar en el proyecto

```powershell
flutter pub get
flutter analyze          # debe quedar en "No issues found"
flutter test             # 245 tests, todos pasan en el commit 52f0466
flutter run -d chrome    # web (consola de técnico/supervisor/admin)
flutter run -d <device>  # Android
```

- Tras cambiar tablas Drift: `dart run build_runner build --delete-conflicting-outputs` (regenera `app_database.g.dart`).
- Los tests usan fakes en `test/testing/` (`fakes.dart`, `home_fakes.dart`) y una base Drift en memoria; no tocan la red.
- Los widgets con mapa se prueban sin red: las teselas fallan en silencio y el resto se dibuja.
- `adb` no está en el PATH; está en `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.

## 9. Pendientes sugeridos, en orden

1. Arreglar las cuatro cuentas del seed y dejar el arreglo como migración nueva (no editar `10_seed_demo.sql`, ya está aplicada).
2. Probar de punta a punta: agricultor registra parcela con ubicación → reporta problema con foto → sincroniza → el técnico lo ve en su bandeja y en el mapa.
3. Diagnosticar el cierre al tomar foto con el registro del dispositivo real.
4. Conectar a datos reales "Registrar actividad", "Registrar cosecha" y "Mis asistencias", y eliminar `mock_data.dart`.
5. Construir los módulos de consola que hoy son placeholder.
