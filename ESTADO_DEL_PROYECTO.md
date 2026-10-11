# AgroApp — Estado del proyecto

Rama: `feat/full-supabase-app`. Stack: Flutter (Android + web) + Supabase, offline-first con Drift.

> **Importante.** Todo lo de este documento se verificó leyendo el código y con `flutter analyze`.
> **Nada se probó en un dispositivo ni contra Supabase real de punta a punta.** Los tests
> los corre el equipo; algunos tests viejos pueden estar desactualizados tras los cambios de T4–T7.

---

## 1. Lo que está hecho (conectado a backend real, 0% mock)

### Backend (Supabase)
- [x] Edge Function `admin-create-user` + RPC `admin_provision_user` (crea usuario de Auth + perfil; si falla, borra el Auth creado).
- [x] Edge Function `admin-manage-user` (reset de contraseña, cambio de estado).
- [x] Login de agricultor por DNI (`<dni>@agricultores.agroapp`), personal por correo (migración 12).
- [x] `parcels.geometry` (migración 13).
- [x] Migración 14: `visit_attendance_confirmations` (llegó / no llegó) y `recommendation_followups` (marca del técnico "siguió / no siguió"); `sync_batch` ampliado.
- [x] Políticas de Storage para fotos (`incidents`, `external-documents`), RLS y endurecimiento de EXECUTE.
- [x] Script `create-admin` para crear el primer admin.

### Núcleo offline / sync
- [x] Réplica local genérica en Drift + cola de salida (outbox) con UUID de cliente.
- [x] Motor de sync: sube y baja cada 5 s, cursores por tabla, fallo por registro sin abortar el lote.
- [x] Subida de fotos a Storage antes de enviar la fila (bucket según la tabla).
- [x] Indicador de sync visible (pendiente / sincronizando / sincronizado).

### Autenticación y roles
- [x] DNI + contraseña (agricultor) y correo (resto), sesión persistente, ruteo por rol.
- [x] Arranque offline con sesión en caché, aviso si el servidor cierra la sesión.
- [x] Layout móvil (agricultor) y consola web de 3 paneles (técnico, supervisor, admin).

### Agricultor (app móvil)
- [x] **Inicio:** saludo, parcela, 3 botones principales, "Mis asistencias", resumen (último abono, próxima recomendación, incidencia activa, producción).
- [x] **Mi parcela:** lista, polígono/marcador en mapa, "Agregar terreno" con GPS real, guardado offline.
- [x] **Reportar problema:** parcela → síntomas (catálogo) → descripción → 0–3 fotos (cámara/galería, comprimidas) → guardado offline.
- [x] **Estado del caso + "Mis reportes":** estado, historial (quién/cuándo/comentario), fotos.
- [x] **Recomendaciones:** "Ya lo hice" (`recommendation_confirmations`).
- [x] **Llegada del técnico:** "El técnico llegó / No llegó".
- [x] **Registrar actividad:** flujo secuencial con unidades por contexto y gasto opcional en S/; lista y detalle reales.
- [x] **Registrar cosecha:** cantidad+unidad, destino, venta a acopiador, rastrojo; lista real.
- [x] **Mis asistencias:** lista y detalle reales (AIDER/SENASA/otra) + "Registrar visita externa" con fotos de la ficha, sin OCR.

### Técnico (app + web)
- [x] Bandeja de alertas (móvil: pestañas Casos/Mapa; web: lista + área principal), ordenada por prioridad y fecha.
- [x] Mapa con pines de incidencias sobre parcelas; tocar un pin abre el caso.
- [x] Detalle del caso: agricultor, parcela, cultivo, síntomas, fotos, visita, recomendaciones, historial.
- [x] Acciones guardadas offline: tomar caso, programar visita, registrar asistencia, dejar recomendación, marcar atendido, cerrar.
- [x] Ve la confirmación de llegada del agricultor y marca "siguió / no siguió" cada recomendación.

### Admin (web)
- [x] Usuarios, catálogos, configuración y auditoría (ver sección 3).

### Supervisor (web)
- [x] **Dashboard (T11):** adopción, % alertas resueltas, % recomendaciones confirmadas, tiempo medio de atención, producción/autoconsumo/excedente por unidad, gastos y carga por técnico, con filtro por zona. Lee las vistas KPI de Supabase (sin cambios de base). **Caveat (Opción B):** la carga por técnico muestra conteos con id enmascarado, sin nombres, porque el RLS de `profiles` oculta los técnicos al supervisor; los nombres requieren una función `security definer` (Opción A). Pendiente verificar contra Supabase real.

---

## 2. Lo que falta

### Alta prioridad (para la demo)
- [ ] **Prueba real de punta a punta** (teléfono + Supabase): login, reporte con fotos sin internet → sync → alerta del técnico → visita → llegada → recomendación → "Ya lo hice" → cierre. Es el mayor riesgo del proyecto.
- [ ] **Dashboard del supervisor (T11):** implementado en la web (ver "Supervisor (web)"). Falta verificarlo contra Supabase real y, si se quieren nombres de técnicos, aplicar la Opción A (función `security definer`).
- [ ] **Módulos web vacíos:** Parcelas, Calendario, Territorio, Equipo, Reportes muestran un marcador de posición (`ModulePlaceholder`).
- [ ] **Exportación a Excel** filtrable por zona/agricultor/parcela/cultivo/fecha.

### Media prioridad
- [ ] **Calendario + consejos de Piura (T9):** actividades, incidencias, cosechas, asistencias, recordatorios.
- [ ] **"Recordarme luego"** como recordatorio real (hoy solo muestra un aviso; el agricultor no tiene permiso de escritura en `reminders`).
- [ ] **Comentario en el cambio de estado** del técnico: no llega al servidor (un trigger escribe el historial y el técnico no puede insertarlo). Solución: RPC que cambie el estado y reciba el comentario.
- [ ] **Notificaciones** locales offline y de servidor (FCM).
- [ ] **Pin manual en el mapa** al agregar terreno (el mapa actual no tiene coordenadas reales; haría falta `flutter_map` + tiles).
- [ ] **Permisos de ubicación en iOS** (solo se agregaron los de Android).

### Pulido (T12)
- [ ] Botón de atrás flotante en pantallas internas.
- [ ] Animaciones y transiciones con propósito.
- [ ] Componente web de 3 paneles reutilizado en todos los módulos.
- [ ] Revisión de accesibilidad y pruebas en Android gama baja/media.

### Deuda técnica / riesgos conocidos
- [ ] Tests desactualizados o sin escribir para T4–T7 y las pantallas nuevas (los corre el equipo).
- [ ] Dos técnicos que marquen la misma recomendación a la vez pueden chocar (`recommendation_id` único).
- [ ] Un incidente y su foto en el mismo milisegundo: la foto puede fallar una vez por clave foránea y se reintenta en el siguiente ciclo.
- [ ] Compilar el APK en Windows requiere activar el **Modo desarrollador** (symlinks).
- [ ] Protección contra contraseñas filtradas: es un ajuste del panel de Supabase, no de la API.
- [ ] La revisión de seguridad de Gentle AI quedó sin hacer en varios cambios (autenticación, riesgo alto).
- [ ] **Cuentas demo** en `auth.users` sin `auth.identities` (su login puede fallar). Hay que borrarlas desde el panel de Supabase (Authentication → Users); no se borraron desde el código.

---

## 3. Preguntas frecuentes

### ¿El admin puede gestionar usuarios de todos los roles?
**Parcialmente.**

| Capacidad | Estado |
|---|---|
| Crear usuarios de los 4 roles (agricultor, técnico, supervisor, admin) | Sí, vía `admin-create-user` |
| Asignar zonas, comunidad, teléfono y rango de edad al crear | Sí |
| Resetear contraseña | Sí, vía `admin-manage-user` |
| Activar / desactivar / suspender (bloquea el acceso) | Sí, vía `admin-manage-user` |
| Editar asignaciones de zonas | Sí (pantalla de asignaciones del usuario) |
| **Eliminar un usuario definitivamente** | **No.** Está pensado así: se desactiva en vez de borrar para conservar el historial |
| Cambiar el rol de un usuario ya creado | No verificado; probablemente hay que crear otro usuario |

El borrado definitivo se haría a mano desde el panel de Supabase, y solo si el usuario no tiene
historial asociado (parcelas, actividades, incidencias).

### ¿Dónde se gestionan los catálogos?
En la pestaña de Administración de la web: cultivos, tipos de actividad y sus unidades, unidades,
productos, síntomas, tipos de poda, zonas, comunidades, acopiadores, precios y equivalencias de
unidades, y configuración. Las pantallas móviles los leen del backend, sin valores fijos.

### ¿Qué ve cada rol?
- **Agricultor:** solo sus parcelas, en la app móvil.
- **Técnico:** sus zonas y parcelas asignadas, en la app móvil (offline) y en la web.
- **Supervisor:** web, solo lectura y reportes de su zona o programa (dashboard pendiente).
- **Admin:** web, gestión global.

---

## 4. Orden sugerido para lo que queda
1. Prueba real de punta a punta y corrección de lo que aparezca.
2. Dashboard del supervisor.
3. Calendario + consejos de Piura.
4. Módulos web restantes + Excel.
5. Pulido de UI.
