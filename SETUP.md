# Puesta en marcha — ODYSSAI Proposals & CRM

La app funciona en dos modos:

| Modo | Cuándo | Dónde viven los datos |
|---|---|---|
| **💾 Local** | `SUPABASE_URL` y `SUPABASE_ANON_KEY` vacíos en `index.html` | Solo en el navegador de cada persona |
| **☁ Nube** | Ambos valores llenos | Supabase, compartido por todo el equipo, con login y cambios en vivo |

El indicador junto a **⚙ Configuración** (arriba a la derecha) dice en qué modo estás.

---

## 1. Publicación en Netlify (una sola vez)

Sitio: **odyssaicloserscrm** → https://odyssaicloserscrm.netlify.app

Para que cada cambio aprobado en GitHub se publique solo:

1. Netlify → sitio **odyssaicloserscrm** → menú izquierdo **Deploys**.
2. Botón **Link repository** / **Connect to Git** → **GitHub** → repo **Odyssaiapp**.
3. Branch: `main` · Build command: *(vacío)* · Publish directory: `.`
4. **Deploy**.

Alternativa manual: descarga `index.html` de GitHub y arrástralo al cuadro *"Already built it? Drop a folder…"* del Project overview.

---

## 2. Base de datos compartida (Supabase) — ~10 min

### 2.1 Crear el proyecto
1. Entra a https://supabase.com → **New project**.
2. Nombre: `odyssai-crm` · Región: la más cercana (p. ej. *East US*) · Guarda la contraseña de la base de datos en un lugar seguro.

### 2.2 Crear las tablas
1. Menú izquierdo **SQL Editor** → **New query**.
2. Copia y pega **todo** el contenido de [`supabase/schema.sql`](supabase/schema.sql) → **Run**.
3. Debe decir *Success*. Se puede volver a correr sin problema.

Esto crea las tablas `leads` y `settings`, con seguridad: **solo usuarios con sesión pueden ver o modificar datos**. Un visitante con el link de la app no ve nada.

### 2.3 Configurar el acceso (login por link al correo)
1. **Authentication → Sign In / Providers**: deja **Email** activado y **desactiva "Allow new users to sign up"**. Así solo entran las personas que invites.
2. **Authentication → URL Configuration**:
   - **Site URL:** `https://odyssaicloserscrm.netlify.app`
   - **Redirect URLs:** agrega `https://odyssaicloserscrm.netlify.app/**`
3. **Authentication → Users → Invite user**: invita a cada closer con su correo (tú, Ernesto, etc.).

### 2.4 Conectar la app
1. **Project Settings → API** (o **Data API**). Copia:
   - **Project URL** (ej. `https://abcd1234.supabase.co`)
   - **anon / public key** (empieza con `eyJ…`). Esta llave es pública por diseño; la protección real son las reglas del paso 2.2.
2. En `index.html`, al inicio del `<script>`, llena:
   ```js
   const SUPABASE_URL = 'https://abcd1234.supabase.co';
   const SUPABASE_ANON_KEY = 'eyJ...';
   ```
   (O pásale ambos valores a Claude y él hace el cambio y el PR.)
3. Publica (merge a `main` si Netlify está conectado a GitHub).

### 2.5 Primer uso
- Al abrir la app aparece **"Acceso para el equipo de closers"**: escribe tu correo → te llega un link → ábrelo **en el mismo navegador**.
- Si ese navegador tenía leads del modo local, aparece el aviso **"Hay N leads guardados solo en este navegador" → Subir a la nube**.
- En **⚙ Configuración** captura el webhook de n8n y la lista de closers; se comparten con todo el equipo.

---

## 3. Integración con GoHighLevel vía n8n — ~15 min

### 3.1 Datos de GHL
1. **Token:** GHL (subcuenta) → **Settings → Private Integrations → Create new integration**. Permisos mínimos:
   `contacts.write`, `contacts.readonly`, `opportunities.write`, `opportunities.readonly`. Copia el token.
2. **Location ID:** **Settings → Business Profile** (o en la URL de la subcuenta: `/location/XXXX/`).
3. **Pipelines:** en **Opportunities → Pipelines** crea un pipeline por marca, con estos nombres (o ajústalos en la configuración del flujo):
   - Pipelines: `AIPilot`, `Capta`, `ODYSSAI`
   - Etapas: `Nuevo Lead`, `Diagnóstico`, `Propuesta`, `Negociación`, `Cerrado`, `Perdido`

   El flujo busca pipeline y etapa **por nombre** (sin importar acentos ni mayúsculas), así que no necesitas IDs.

### 3.2 Importar el flujo
1. n8n → **Workflows → Import from File** → [`n8n/odyssai-ghl-workflow.json`](n8n/odyssai-ghl-workflow.json).
2. **Token como credencial** (ya no va en texto plano dentro del flujo): n8n → **Credentials → Add credential → Header Auth**.
   - Nombre de la credencial: `GHL Private Integration`
   - Name: `Authorization`
   - Value: `Bearer ` seguido del token (con el espacio). Ej.: `Bearer pit-xxxx…`
   - **Save**. Luego abre los tres nodos **GHL: …** y en *Credential for Header Auth* elige `GHL Private Integration`.
3. Abre el nodo **Preparar datos** y edita solo el bloque `CONFIG`:
   ```js
   locationId: 'tu location id',
   pipelines: { aipilot: 'AIPilot', capta: 'Capta', odyssai: 'ODYSSAI' },
   ```
4. **Save** → interruptor **Active** (arriba a la derecha).
5. Abre el nodo **Webhook ODYSSAI** → pestaña **Production URL** → copia la URL (termina en `/webhook/odyssai`).
   El webhook solo acepta llamadas desde `https://odyssaicloserscrm.netlify.app` (opción *Allowed Origins*). Si cambias el dominio de la app, cámbialo ahí también.

> **Si ya tenías importada la versión anterior del flujo:** bórrala o desactívala e importa esta. La anterior tenía el token en texto plano: después de importar la nueva, **regenera el token** en GHL (Private Integrations → Rotate) y pon el nuevo solo en la credencial.

### 3.3 Conectar la app
En la app → **⚙ Configuración** → pega la Production URL → **Guardar**. El punto verde indica que está configurado.

### 3.4 Qué hace el flujo
```
App ──POST──▶ Webhook ─▶ Preparar datos ─▶ GHL contacto (crea o actualiza por email/teléfono)
                                         ─▶ Leer pipelines ─▶ Ubicar pipeline y etapa
                                         ─▶ GHL oportunidad (crea o actualiza, con monto y estado)
                                         ─▶ Responder a la app ({ ok, error, aviso })
```
- **🚀 Crear en GHL** (Propuestas): contacto + oportunidad en la etapa *Propuesta*, con etiqueta de la marca y `propuesta-enviada`.
- **Guardar + GHL** y **🚀 Sync GHL** (CRM): contacto + oportunidad en la etapa actual del lead. *Cerrado* → `won`, *Perdido* → `lost`.
- El teléfono se normaliza (10 dígitos → `+52…`).
- Si algo falla, la app muestra la causa en español, por ejemplo *GHL rechazó el token…*, *Falta el Location ID…* o *No existe un pipeline llamado "AIPilot"…* (en ese caso sí se crea el contacto). El detalle completo queda en n8n → **Executions**.

### 3.5 Probar
1. En la app, Propuestas → llena un prospecto de prueba → **🚀 Crear en GHL**.
2. Debe salir **✓ Enviado a GHL** y en GHL aparecer el contacto y la oportunidad.
3. Si sale *"No se pudo conectar (revisa URL o CORS en n8n)"*: confirma que el flujo está **Active**, que usaste la **Production URL** (no la de prueba) y que abriste la app desde `https://odyssaicloserscrm.netlify.app`.
4. Para crear el contacto en GHL el prospecto necesita **email o WhatsApp**.

---

## 4. Uso diario (resumen para el equipo)

- **Propuestas:** elige marca → datos del prospecto → marca o desmarca servicios → **📋 Copiar texto** (WhatsApp/correo), **📄 PDF** (en el diálogo de impresión elige *Guardar como PDF*) o **🚀 Crear en GHL** → **+ Añadir al CRM**.
- **CRM:** arrastra tarjetas entre columnas, clic en una tarjeta para notas, closer, etapa, **✏ Editar**, **🚀 Sync GHL** o **🗑 Eliminar**. El correo y el WhatsApp del lead son clicables.
- **⬇ CSV** descarga los leads de la marca activa (se abre en Excel).
- Cada cambio de etapa queda registrado en el historial de notas, con fecha y autor.
