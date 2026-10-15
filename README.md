# ODYSSAI — Proposals & CRM

App interna de ODYSSAI (un solo `index.html`, sin build) para generar propuestas comerciales
(AIPilot, Capta, ODYSSAI) y dar seguimiento a leads en un CRM tipo kanban.
Se publica en Netlify (sitio `odyssaicloserscrm`).

- **Propuestas:** servicios seleccionables, vista previa, copiar texto, PDF y envío a GoHighLevel.
- **CRM:** pipeline por marca, arrastrar entre etapas, edición, notas con historial, closers, CSV.
- **Modo nube (opcional):** Supabase con login por link al correo y cambios en vivo entre closers.

Puesta en marcha paso a paso: **[SETUP.md](SETUP.md)**

| Archivo | Qué es |
|---|---|
| `index.html` | La app completa |
| `supabase/schema.sql` | Tablas y reglas de seguridad para Supabase |
| `n8n/odyssai-ghl-workflow.json` | Flujo de n8n que crea contactos y oportunidades en GHL |
| `netlify.toml` | Publica la raíz del repo en Netlify |
