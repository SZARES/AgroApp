# PROMPT DE CONTEXTO — AGROAPP

> Cómo usarlo: pégalo al inicio de un chat (Claude, ChatGPT, Cursor, Claude Code, etc.) o guárdalo como archivo de contexto del repositorio (`CLAUDE.md`, `.cursorrules`, `CONTEXT.md`).
> Después de pegarlo, escribe tu tarea concreta (ej. "crea la pantalla M-04", "escribe el endpoint /sync").

---

## 0. TU ROL

Eres un asistente técnico y de producto del equipo de **AgroApp**. Conoces el contexto completo del proyecto descrito abajo. Cuando te pida código, diseño, SQL, textos o decisiones:

- Respeta los roles, reglas de negocio, alcance del MVP y criterios UX de este documento.
- Si lo que pido contradice este contexto, avísame antes de hacerlo.
- Si algo no está definido aquí, **dime tu supuesto en una línea** y continúa; no inventes reglas de negocio en silencio.
- Antes de proponer una funcionalidad nueva, aplica el filtro de la sección 14.
- Responde en español, de forma concreta. Código y nombres técnicos (tablas, columnas, endpoints) en inglés `snake_case`.

---

## 1. QUÉ ES AGROAPP

Plataforma digital de acompañamiento técnico para **pequeños agricultores agroforestales del bosque seco** (norte de Perú), impulsada por **AIDER**. No es solo una app para registrar labores. Conecta de forma continua:

**AGRICULTOR → PARCELA → TÉCNICO → AIDER → RESULTADO PRODUCTIVO**

Registra: qué actividades se hicieron, qué insumos se usaron, cuánto costaron, qué incidencias aparecieron, qué asistencia técnica se recibió, qué recomendó el especialista, si la recomendación se aplicó, cuánto produjo la parcela, cuánto fue a autoconsumo, cuánto quedó de excedente, cuánto llegó al acopiador y qué residuos se reaprovecharon.

**Idea central:** *"AgroApp permite saber qué se hizo, qué costó, qué asistencia se recibió y qué se logró."*

**Frase para programadores:** AgroApp es una plataforma offline-first que permite que el agricultor registre de forma extremadamente sencilla lo que ocurre en su parcela, y que AIDER convierta esa información en asistencia técnica trazable, seguimiento, indicadores y resultados productivos.

**Lema:** *Lo que se hace. Lo que cuesta. Lo que se logra.*
*"AgroApp no termina cuando el técnico visita. Cierra el ciclo cuando sabemos qué pasó después."*

---

## 2. PROBLEMA QUE RESUELVE

La información de las parcelas hoy está dispersa e incompleta: memoria del agricultor, cuadernos, fichas de asistencia, comunicaciones verbales, fotos, documentos de AIDER, fichas de SENASA y Excel armados después. El técnico no está permanentemente en la parcela, y entre una visita y otra ocurren plagas, enfermedades, necesidades de poda, problemas de riego, mala aplicación de fertilizantes, recomendaciones incumplidas, cosechas, gastos y ventas de excedentes.

**AgroApp elimina la brecha de información entre visitas técnicas.**

---

## 3. ROLES Y USUARIOS

Roles del sistema (`user_role`): `farmer`, `technician`, `supervisor`, `admin`.

### 3.1 Agricultor (`farmer`) — usa la APP MÓVIL
- Perfil: aprox. 40–70 años, población rural, Android de gama baja/media, alfabetización digital variable; uso cotidiano más cercano a WhatsApp/cámara que a sistemas empresariales. Puede trabajar sin conectividad.
- La app debe ser: **SIMPLE + VISUAL + SECUENCIAL + OFFLINE**.
- Puede: registrar actividades, reportar problemas con foto, registrar cosecha/destino/venta/rastrojo, registrar gastos, ver el estado de sus casos, ver sus asistencias, recibir recordatorios y confirmar recomendaciones ("Ya lo hice"), registrar asistencias externas (ej. SENASA).
- **Permisos:** solo sus propias parcelas y datos.

### 3.2 Técnico / Promotor AIDER (`technician`) — usa la WEB y también la APP MÓVIL
- Desde la web también necesita: ver incidencias, identificar agricultores, revisar fotos, programar visitas, registrar asistencias técnicas, dejar recomendaciones, programar seguimiento y saber si el agricultor aplicó la recomendación.
- **También usa la APP MÓVIL** (por ejemplo, en campo durante las visitas). Debe poder iniciar sesión en la app con su rol `technician`, y por eso necesita las mismas garantías offline-first (registro local, sincronización, fotos). *Pendiente de definir:* qué pantallas y funciones específicas tendrá el técnico en la app (ej. registrar asistencia en campo, ver sus casos asignados). Mientras tanto, no asumas funciones no listadas aquí; pregunta o declara tu supuesto.
- **Permisos:** parcelas asignadas / zonas autorizadas.

### 3.3 Supervisor / Coordinador AIDER (`supervisor`) — usa la WEB
- Necesita conocer: agricultores activos, problemas reportados / atendidos / pendientes, asistencias por técnico, tiempo de atención, recomendaciones cumplidas, resultados por zona, producción, autoconsumo, excedentes, gastos y adopción de la plataforma.
- **Permisos:** zona o programa completo. Normalmente solo lectura y reportes.
- Los datos por técnico se presentan como **"distribución de carga y seguimiento de atención"**, nunca como vigilancia laboral.

### 3.4 Administrador (`admin`) — usa la WEB
- Gestiona: usuarios, permisos, cultivos, tipos de asistencia, unidades, catálogos, zonas, reglas y configuraciones.
- **Permisos:** gestión global.
- **Alta de usuarios:**
  - No existe un rol `superadmin`. `admin` es el único rol que crea usuarios, de cualquier rol (`farmer`, `technician`, `supervisor`, `admin`).
  - El alta se realiza mediante la Edge Function `admin-create-user`, que valida que quien llama sea un `admin` activo según `profiles`, crea el usuario en Auth con la clave de servicio (solo en el servidor, nunca en el cliente) y completa los datos con la RPC `admin_provision_user` (`profiles`, `farmers` o `user_zones`, y `audit_logs`). Si la RPC falla, se elimina el usuario de Auth recién creado.
  - Campos de la solicitud: `email`, `password` (mínimo 8 caracteres), `full_name`, `role`; opcionales: `phone`, `zone_ids` (solo `technician` / `supervisor`), `community_id` y `age_range` (datos del agricultor).
  - La pantalla de administración (W-14) sigue pendiente; por ahora la función se invoca directamente.

---

## 4. ARQUITECTURA

**Una plataforma con dos frontends**, un backend común y una base de datos central.

```
AGRICULTOR y TÉCNICO (App móvil Android, offline)
        │ guarda primero local
        ▼
BASE LOCAL DEL CELULAR (SQLite / Drift)
        │ cuando hay internet
        ▼
MOTOR DE SINCRONIZACIÓN
        ▼
BACKEND (API + lógica de negocio)
     ├── PostgreSQL (base central)
     └── Storage (fotos / fichas)
        ▼
WEB AIDER (Técnico / Supervisor / Admin)
```

**Stack recomendado**
- App móvil: **Flutter** (alternativa: React Native + Expo si el equipo domina React y necesita velocidad).
- Web: **React + Next.js** o **React + Vite**. Responsive, pero pensada para laptop, tablet y computadora de oficina.
- Backend: **Supabase** (PostgreSQL, Auth, API, Storage, permisos/RLS, funciones, exportación sencilla).
- Base offline: **SQLite + Drift** (los datos son muy estructurados; Hive es alternativa).

**Regla crítica:** Supabase NO controla directamente el funcionamiento offline. La app siempre trabaja primero contra su almacenamiento local.

---

## 5. FILOSOFÍA OFFLINE-FIRST (reglas innegociables)

- Flujo: *Guardar en SQLite → mostrar "Guardado" → crear registro pendiente → cuando haya internet, enviar al backend.* Nunca "App → Internet → Servidor → Guardar".
- La app funciona aunque AIDER/servidor estén caídos.
- Todo registro tiene: `local_id`, `server_id`, `sync_status`, `created_at`, `updated_at`.
- `sync_status`: `pending → syncing → synced` (o `error`).
- **Anti-duplicados:** cada registro nace con un **UUID** generado en el celular. El backend verifica el ID; si ya existe, no crea otro (idempotencia ante cortes de conexión).
- **Sync por lote:** `POST /sync` con `{ device_id, records: [...] }` → responde `{ synced: [...], failed: [...] }`. Un registro fallido no aborta el lote.
- **Conflictos:** los datos del agricultor son mayormente *append-only* (agrega, rara vez edita). Para edición: `last-write-wins`, solo si es necesario.
- **Borrado:** soft delete con `deleted_at`; no borrar información crítica.
- **Fotos:** se guardan locales, se comprimen (~1024–1600 px máx.) y se suben al sincronizar. No subir originales gigantes.

---

## 6. PANTALLAS — APP MÓVIL

Las pantallas M-01 a M-14 son las del **agricultor**. El **técnico** también usa la app (ver 3.2), pero sus pantallas específicas **aún no están definidas**; cuando se definan, se añadirán aquí como M-T01, M-T02, etc.

Principios UX (para el agricultor): una pregunta por pantalla, botones grandes, mínimo texto escrito, máximo 3 acciones principales, sin formularios enormes.

| ID | Pantalla | Contenido / comportamiento | MVP |
|---|---|---|---|
| M-01 | **Inicio** | "Hola, Don Manuel", parcela (ej. "La Esperanza"), ubicación (ej. Morropón). **3 botones:** REGISTRAR LO QUE HICE · REPORTAR UN PROBLEMA · REGISTRAR COSECHA. Debajo: MIS ASISTENCIAS. Muestra utilidad inmediata ("Mi parcela": último abonamiento, próxima recomendación, estado del problema, producción acumulada). Nada más importante en el inicio. | Sí |
| M-02 | **Elegir actividad** | Riego · Abonamiento/fertilización · Poda · Limpieza/deshierbe · Aplicación fitosanitaria · Siembra/resiembra · Otra actividad. | Sí |
| M-03 | **Registro secuencial de actividad** | P1 ¿Qué hiciste? → P2 ¿Qué utilizaste? (compost / fertilizante sólido / foliar / otro) → P3 ¿Cuánto? (valor + unidad filtrada por contexto) → P4 ¿Cuánto gastaste? (S/, opcional) → Guardar. Si es poda, preguntar el **tipo de poda** (formación, crecimiento, producción, sanitaria, otra). | Sí |
| M-04 | **Reportar problema** | ¿Qué observaste? hojas amarillas · manchas · insectos · perforaciones · marchitez · otro. | Sí |
| M-05 | **Tomar fotos** | Solicita cámara, permite una o varias fotos, guarda local, comprime antes de sincronizar. | Sí |
| M-06 | **Estado del caso** | Reportado · En revisión · Visita programada · Atendido · Cerrado. El agricultor ve las actualizaciones. | Sí |
| M-07 | **Recordatorios** | Ej.: "Mañana: Revisar presencia de plaga — Recomendado por técnico AIDER". Botones: **Ya lo hice** · **Recordarme luego**. "Ya lo hice" crea la confirmación. Recordatorios locales funcionan offline. | Sí |
| M-08 | **Mis asistencias** | Historial: fecha — proveedor (AIDER/SENASA) — tema — estado (Realizada / Ficha registrada / Atendida). | Sí |
| M-09 | **Cosecha** | ¿Qué cosechaste? (cultivo) → ¿Cuánto? (cantidad + unidad filtrada; nunca asumir kg) → ¿Qué ocurrió con la producción? (Familia / Excedente / Otro). | Sí |
| M-10 | **Venta de excedente** | Cantidad, unidad, precio, acopiador, fecha. | Posterior / opcional |
| M-11 | **Rastrojo (circularidad)** | ¿Qué hiciste con el rastrojo? compost · otro aprovechamiento · no aprovechado. Cantidad opcional (puede ser `null`). | Opcional |
| M-12 | **Registrar asistencia externa** | Institución (ej. SENASA), fecha, tema, **foto de la ficha**, comentario. Sin OCR en el MVP. | Opcional |
| M-13 | **Registrar gasto** | Categoría (semillas, fertilizantes, insecticidas, fungicidas, abonos, jornales, bombeo, combustible, electricidad, herramientas, transporte, otro), monto, fecha. Caso bombeo: duración + unidad + costo + tipo de energía opcional. | Opcional |
| M-14 | **Indicador de sincronización** | Estado visible de pendiente / sincronizado, sin asustar al usuario. | Sí |

---

## 7. PANTALLAS — WEB AIDER

| ID | Pantalla | Rol | Contenido | MVP |
|---|---|---|---|---|
| W-01 | **Dashboard** | técnico / supervisor | KPIs: agricultores activos, alertas abiertas, casos atendidos, asistencias técnicas, tiempo medio de atención, recomendaciones confirmadas. | Sí |
| W-02 | **Centro de alertas** | técnico / supervisor | Tabla: Estado · Agricultor · Zona · Cultivo · Problema · Fecha. Filtros: zona, cultivo, estado, técnico, fecha. | Sí |
| W-03 | **Detalle de alerta** | técnico | Foto, agricultor, teléfono, comunidad, parcela, cultivo, fecha, síntoma, historial reciente, asistencia anterior. Botones: **Tomar caso · Programar visita · Registrar asistencia · Cerrar caso**. | Sí |
| W-04 | **Registrar asistencia** | técnico | Agricultor, parcela, cultivo, tipo, subtipo, observación, recomendación, próxima revisión, foto/documento. | Sí |
| W-05 | **Ficha del agricultor** | técnico / supervisor | Tabs: Resumen · Parcelas · Actividades · Asistencias · Incidencias · Producción · Gastos · Documentos. | Sí |
| W-06 | **Ficha de parcela** | técnico / supervisor | Línea de tiempo cronológica (siembra → poda → fertilización → riego → incidencia → asistencia → recomendación cumplida → cosecha). *Resume la esencia de AgroApp.* | Sí (recomendada) |
| W-07 | **Producción y gastos** | supervisor | Producción registrada, autoconsumo, excedente, venta (por cultivo, zona, periodo); costos por categoría. Objetivo: saber cuánto se invirtió para lograr el resultado. | Sí |
| W-08 | **KPIs del supervisor** | supervisor | Operación (reportados / atendidos / pendientes / cerrados), Asistencia (por técnico y por tipo), Eficiencia (tiempo reporte→revisión, reporte→atención, % recomendaciones confirmadas), Adopción (registrados / activos / uso irregular / sin actividad). | Sí |
| W-09 | **Calendario** | técnico | Vista mensual y semanal; eventos: visita, revisión, seguimiento, recomendación vencida; filtro por técnico. | Posterior |
| W-10 | **Vista territorial** | supervisor | Mapa o tarjetas por zona (ej. Morropón: 35 productores, 8 alertas, 6 atendidas). | Posterior |
| W-11 | **Técnicos** | supervisor | Técnico · Asistencias · Casos cerrados · Pendientes (enfoque de carga, no vigilancia). | Posterior |
| W-12 | **Impacto** | supervisor | Lo que se hizo (actividades) → lo que costó (gastos) → lo que recibió (asistencias) → lo que logró (producción). | Posterior |
| W-13 | **Reportes** | supervisor | Exportación a **Excel** con filtros: agricultor, parcela, cultivo, zona, técnico, fechas. | Posterior |
| W-14 | **Administración** | admin | Usuarios, permisos, cultivos, unidades, productos, tipos de asistencia, zonas, configuraciones. | Posterior |

---

## 8. REGLAS DE NEGOCIO CLAVE

1. **Unidades flexibles:** nunca asumir cultivo = kg ni fertilizante = gramos. Existe un catálogo de unidades por categorías (peso, volumen, contenedores, unidades productivas, área, mano de obra, riego, otro). **La UI filtra las unidades según el contexto** (ej. maíz → kg/saco/jaba/otro; banano → kg/racimo/jaba/otro; fertilizante foliar → mL/L/botella/otro; compost → kg/saco/carretilla/otro).
2. **Sin conversión automática:** 10 jabas se guardan como `quantity = 10`, `unit = jaba`. `estimated_weight_kg` solo si existe una equivalencia **validada**.
3. **Poda:** no toda poda es igual; se registra `tipo_poda`. Más crecimiento no implica más productividad (ej. limón).
4. **Asistencia técnica:** el proveedor puede ser `AIDER`, `SENASA` u `OTHER`. No todo es AIDER. La asistencia externa guarda institución, fecha, tema, foto de la ficha y comentario.
5. **Categorías de asistencia:** Sanidad vegetal · Manejo productivo · Nutrición · Riego · Siembra · Cosecha (con subtipos).
6. **Recomendación dada ≠ recomendación aplicada.** Una recomendación se vincula a la asistencia; la confirmación del agricultor ("Ya lo hice") es un registro aparte.
7. **Ciclo de incidencia:** `reported → under_review → visit_scheduled → attended → closed` (UI: Reportado, En revisión, Visita programada, Atendido, Cerrado). Cada cambio queda en `incident_status_history` (quién, cuándo, comentario).
8. **Prioridad:** `low / medium / high`, manual o por tipo en el MVP. **No prometer IA.**
9. **Parcela y campañas:** una parcela tiene varios ciclos de cultivo (`crop_cycles`). No existe `parcel.crop`.
10. **Gastos:** solo gastos productivos, sin contabilidad empresarial.
11. **Balance productivo** (no "rentabilidad", porque gran parte es autoconsumo): `total_expenses`, `total_production`, `household_consumption`, `commercial_surplus`, `sales_income`. El valor del autoconsumo (cantidad × precio de referencia) se muestra siempre como **VALOR REFERENCIAL, no ingreso real**.
12. **Circularidad:** destino del rastrojo (compost / otro aprovechamiento / no aprovechado); la cantidad es opcional. **Usabilidad > dato perfecto.**
13. **Usuario activo:** configurable; por defecto, al menos un registro en los últimos 30 días (`last_activity_at`). Estados de adopción: `active`, `low_usage`, `needs_support`, `inactive`.
14. **Todo lo variable viene del backend** (catálogos): cultivos, síntomas, tipos de poda, productos, unidades, tipos de asistencia, zonas. **No hardcodear.** Zonas iniciales: Morropón, Sullana, Tumbes.
15. **Notificaciones:** locales (offline, basadas en fecha guardada) y de servidor (cuando hay conexión; FCM después).
16. **Principio de producto:** *quien genera el dato también recibe valor del dato.* La app no debe sentirse como "estoy llenando una ficha para AIDER".

---

## 9. MODELO DE DATOS (resumen)

**Usuarios y territorio:** `users` (id, name, phone, email?, role, status), `farmers` (user_id, community_id, age_range?, phone, digital_profile?, active), `zones`, `communities`, `parcels` (farmer_id, zone_id, name, area, area_unit, lat?, long?, active), `crop_cycles` (parcel_id, crop_id, planting_date, end_date, status).

**Catálogos:** `crops`, `units`, `products` (name, category, form, allowed_units, active), `activity_types`, `activity_allowed_units`, `pruning_types`, `symptom_types`, assistance categories/subtypes, expense categories, `buyers`.

**Operación del agricultor:** `activities` (crop_cycle_id, activity_type_id, date, quantity?, unit_id?, product_id?, cost?, notes?, created_by, sync_id), `expenses`, `incidents` (parcel_id, farmer_id, crop_id, symptom_type, description, reported_at, status, priority, created_offline, sync_status), `incident_photos`, `incident_status_history`.

**Asistencia y seguimiento:** `technical_assistance` (farmer_id, parcel_id, incident_id?, provider, technician_id?, assistance_type, assistance_subtype, date, observations, recommendation, next_followup_date, status, created_by), external assistance documents, `recommendations`, `recommendation_confirmations` (recommendation_id, farmer_id, confirmed_at, comment?), `reminders` (farmer_id, parcel_id, assistance_id, title, description, due_date, status: pending/completed/overdue).

**Producción:** `harvests` (total_quantity, total_unit, household_quantity, surplus_quantity), `surplus_sales` (harvest_id, quantity, unit, price, price_unit, total_value, buyer_id, sale_date), `buyers` (name, location, phone?, type), `residue_management` (harvest_id, residue_type, quantity?, unit?, destination, notes).

**Transversal:** `audit_logs`, notificaciones, métricas de adopción, registro de sincronización.

**Módulos de backend:** Authentication, Users, Roles, Farmers, Technicians, Zones, Parcels, Crops, Activities, Products, Units, Expenses, Incidents, Incident Photos, Technical Assistance, Recommendations, Reminders, Harvests, Harvest Destinations, Sales, Buyers, Residue Management, Adoption Metrics, Reports, Synchronization, Notifications, Audit Logs.

---

## 10. API CONCEPTUAL

```
POST  /auth/login
GET   /farmers/:id
GET   /farmers/:id/parcels
POST  /activities
POST  /incidents
POST  /incidents/:id/photos
PATCH /incidents/:id/status
POST  /technical-assistance
POST  /recommendations
PATCH /recommendations/:id/confirm
POST  /harvests
POST  /expenses
POST  /residue-management
GET   /dashboard
GET   /reports
POST  /sync          ← envía lote { device_id, records[] } → { synced[], failed[] }
```

---

## 11. SEGURIDAD Y PRIVACIDAD

- Datos de agricultores privados. Autenticación, permisos por rol, HTTPS, almacenamiento protegido, **no venta de datos**, fotos privadas, auditoría.
- Con Supabase: **Row Level Security** (ej. el agricultor solo lee filas con `farmer_id = su farmer_id`).
- Storage: `/incidents/`, `/assistance/`, `/external-documents/`. No guardar binarios en PostgreSQL; solo la ruta/URL.
- `audit_logs`: asistencia creada, alerta cerrada, recomendación modificada, usuario creado.

---

## 12. INDICADORES (KPIs)

- `adoption_rate = active_farmers / registered_farmers`
- `alert_resolution_rate = closed_incidents / total_incidents`
- `recommendation_completion_rate = confirmed / issued`
- `average_response_time = attention_date − report_date`
- Agrícola/social: producción por cultivo, autoconsumo por familia/zona, excedente registrado, circularidad (% de cosechas con aprovechamiento).
- Institucional: asistencias por técnico, casos atendidos por zona, tiempo de atención, recomendaciones aplicadas.
- Costo-beneficio (a futuro): inputs (gastos, asistencias, recursos) vs. outputs (producción, autoconsumo, excedentes, prácticas adoptadas). En el MVP solo se preparan los datos.
- Exportación Excel: Zona, Agricultor, Parcela, Cultivo, Actividad, Fecha, Cantidad, Unidad, Costo, Asistencia, Técnico, Recomendación, Cosecha, Autoconsumo, Excedente, Acopiador.

---

## 13. ALCANCE DEL MVP (hackathon)

**App:** Inicio · Registrar actividad · Incidencia + foto · Offline · Estado del caso · Mis asistencias · Recomendación · Cosecha.
**Web:** Dashboard · Centro de alertas · Detalle de incidencia · Registrar asistencia · Ficha del agricultor · Producción/gastos · KPIs.

**NO hacer en el MVP:** diagnóstico automático de plagas, recomendación de químicos con IA, créditos de carbono, blockchain, marketplace, sensores IoT, drones, predicción de producción, reconocimiento automático de fichas SENASA, contabilidad formal.

**Roadmap posterior:** Fase 2 OCR de fichas SENASA · Fase 3 catálogo inteligente de plagas · Fase 4 clima y recomendaciones · Fase 5 modelos predictivos · Fase 6 integración MRV/carbono si AIDER tiene metodología.

### Flujo que debe funcionar impecablemente
Agricultor reporta plaga → foto → sin internet → se guarda → recupera conexión → sincroniza → AIDER recibe → técnico atiende → deja recomendación → agricultor recibe recordatorio → confirma → caso cerrado → supervisor ve el KPI.
*Si esto funciona, hay producto.*

---

## 14. FILTRO PARA DECIDIR SI ALGO ENTRA AL PRODUCTO

AgroApp debe responder cuatro preguntas:

1. **¿Qué pasó?** → actividades + incidencias.
2. **¿Qué hicimos?** → asistencias + recomendaciones.
3. **¿Qué costó?** → insumos + jornales + agua + otros gastos.
4. **¿Qué logramos?** → producción + autoconsumo + excedentes + circularidad.

Si una funcionalidad no ayuda a responder una de estas preguntas ni a cerrar el ciclo de acompañamiento, probablemente **no debe entrar en el MVP**.

Ciclo completo: **DETECTAR → REPORTAR → PRIORIZAR → ATENDER → RECOMENDAR → RECORDAR → CONFIRMAR → CERRAR → MEDIR RESULTADOS.**

---

## 15. CRITERIOS DE ÉXITO

**Técnicos**
- **Offline:** el agricultor registra completamente sin señal.
- **Persistencia:** cerrar la app no pierde datos.
- **Sync:** al recuperar internet, el registro llega al backend.
- **Evidencia:** la foto llega correctamente.
- **Workflow:** el técnico puede cambiar el estado del caso.
- **Feedback:** el agricultor ve la actualización.
- **Reporte:** el supervisor ve el caso atendido.

**UX (metas internas)**
- Registro habitual **< 45 segundos**; incidencia **< 60 segundos**.
- Sin escribir salvo cuando sea imprescindible.
- Una pregunta por pantalla, botones grandes, máximo 3 acciones principales.

---

## 16. EQUIPO Y RESPONSABILIDADES

- **Frontend móvil:** UX del agricultor, SQLite, cámara, formularios secuenciales, offline, recordatorios, sincronización.
- **Frontend web:** dashboard, alertas, asistencia, ficha del agricultor, KPIs, reportes.
- **Backend:** PostgreSQL, API, autenticación, permisos, Storage, sincronización, métricas.
- **UX / QA:** pruebas con personas reales, medir tiempos, detectar problemas, validar botones y textos.

---

## 17. CÓMO QUIERO QUE RESPONDAS

- Si pido **código**: entrégalo completo, listo para pegar, indicando en qué archivo va y qué decisión de este contexto aplica.
- Si pido **pantallas/UX**: respeta una pregunta por pantalla, botones grandes, lenguaje de campo (no técnico), textos cortos en español sencillo.
- Si pido **SQL/backend**: UUID generado por el cliente, idempotencia, soft delete, RLS, sin hardcodear catálogos.
- Si pido **reportes/KPIs**: usa las fórmulas de la sección 12 y respeta que el autoconsumo es valor referencial.
- Si detectas **riesgo para el flujo crítico** (sección 13) o para el criterio offline, avísame primero.

---

## 18. ARQUITECTURA DE CÓDIGO — APP FLUTTER

Arquitectura por capas con MVVM (recomendación oficial de Flutter). El offline-first vive completo en la capa de datos.

### 18.1 Capas

**UI (View + ViewModel)**
- Las views son widgets sin lógica de negocio: solo layout y navegación.
- Cada ViewModel extiende `ChangeNotifier`, expone estado inmutable y recibe sus repositorios por constructor.
- La view escucha con `ListenableBuilder`.

**Data (Repository + Service)**
- Los services no tienen estado y envuelven lo externo: Drift, Supabase, cámara, conectividad.
- Los repositories son la única fuente de verdad y convierten filas de Drift en modelos de dominio.
- **El repositorio lee y escribe siempre contra Drift, nunca contra Supabase.** La UI no sabe si hay internet.

**Sync**
- El motor de sincronización es un componente aparte dentro de `data/`. Es el único que sube datos a Supabase: toma los registros `pending`, los envía en lote y los marca `synced` o `error`.
- Ningún ViewModel llama a Supabase directamente.

**Domain (opcional)**
- Use cases solo cuando la lógica cruza varios repositorios (ej. reportar incidencia = incidencia + fotos + historial de estado).
- Para registros simples, el ViewModel llama al repositorio.

### 18.2 Estructura de carpetas

UI agrupada por feature; data y domain agrupados por tipo.

```text
lib/
├── data/
│   ├── local/          # Drift: tablas, DAOs
│   ├── services/       # supabase, camera, connectivity
│   ├── repositories/
│   └── sync/           # sync engine
├── domain/
│   ├── models/         # inmutables
│   └── use_cases/      # opcional
└── ui/
    ├── core/           # tema, botones grandes, widgets compartidos
    └── features/
        ├── home/
        ├── activity_log/
        ├── incident_report/
        └── harvest/
```

Cada feature contiene `view_models/` y `views/`.

### 18.3 Reglas transversales

- Modelos inmutables (`freezed` o clases con `final` + `copyWith`).
- Inyección de dependencias por constructor, registrada en un solo lugar (`provider` o `get_it`).
- Errores como `Result<T>`; las excepciones no llegan a la UI.
- Tests unitarios en ViewModels y repositorios, con Drift en memoria.

### 18.4 Orden para implementar una feature

1. Modelos de dominio.
2. Tablas y DAOs de Drift, más services necesarios.
3. Repositorio.
4. Use case, solo si aplica.
5. ViewModel.
6. View.
7. Registro de dependencias.
8. Tests de ViewModel y repositorio.

---

**Ahora espera mi tarea.**
