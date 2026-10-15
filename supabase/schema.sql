-- ODYSSAI Proposals & CRM — esquema de Supabase
-- Pegar completo en Supabase → SQL Editor → Run. Se puede correr más de una vez.

-- Leads del CRM (las 3 marcas comparten tabla)
create table if not exists public.leads (
  id          text primary key,
  brand       text not null check (brand in ('aipilot', 'capta', 'odyssai')),
  name        text not null,
  company     text not null default '',
  email       text not null default '',
  phone       text not null default '',
  amount      numeric not null default 0,
  source      text not null default '',
  stage       text not null default 'Nuevo Lead'
              check (stage in ('Nuevo Lead', 'Diagnóstico', 'Propuesta', 'Negociación', 'Cerrado', 'Perdido')),
  closer      text not null default '',
  notes       jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid()
);

create index if not exists leads_brand_idx on public.leads (brand);

-- Configuración compartida del equipo: 'webhook' (texto) y 'closers' (lista)
create table if not exists public.settings (
  key         text primary key,
  value       jsonb,
  updated_at  timestamptz not null default now()
);

-- Quién y cuándo modificó cada lead
create or replace function public.leads_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

drop trigger if exists leads_touch on public.leads;
create trigger leads_touch before update on public.leads
  for each row execute function public.leads_touch();

-- Seguridad: solo usuarios con sesión (los closers que invites) leen y escriben.
-- Visitantes anónimos con el link de la app no ven nada.
alter table public.leads enable row level security;
alter table public.settings enable row level security;

drop policy if exists "equipo lee leads" on public.leads;
drop policy if exists "equipo crea leads" on public.leads;
drop policy if exists "equipo edita leads" on public.leads;
drop policy if exists "equipo borra leads" on public.leads;
create policy "equipo lee leads"   on public.leads for select to authenticated using (true);
create policy "equipo crea leads"  on public.leads for insert to authenticated with check (true);
create policy "equipo edita leads" on public.leads for update to authenticated using (true) with check (true);
create policy "equipo borra leads" on public.leads for delete to authenticated using (true);

drop policy if exists "equipo lee settings" on public.settings;
drop policy if exists "equipo escribe settings" on public.settings;
create policy "equipo lee settings"     on public.settings for select to authenticated using (true);
create policy "equipo escribe settings" on public.settings for all    to authenticated using (true) with check (true);

-- Tiempo real: cada closer ve los cambios de los demás sin recargar
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'leads') then
    alter publication supabase_realtime add table public.leads;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'settings') then
    alter publication supabase_realtime add table public.settings;
  end if;
end $$;

-- Valores iniciales
insert into public.settings (key, value) values
  ('closers', '["Marco Escamilla", "Ernesto Ercole"]'::jsonb),
  ('webhook', '""'::jsonb)
on conflict (key) do nothing;
