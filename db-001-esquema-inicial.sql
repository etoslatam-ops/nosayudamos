-- NosAyudamos · Esquema inicial (versión 1, sin cobros)
-- Perfiles de trabajadores y empresas, ofertas y postulaciones.

-- ========== Catálogo de áreas de trabajo ==========
create table if not exists public.areas (
  id    text primary key,
  nombre text not null,
  orden int not null default 0
);

insert into public.areas (id, nombre, orden) values
  ('recepcion','Recepción',1),
  ('limpieza','Limpieza / Housekeeping',2),
  ('cocina','Cocina',3),
  ('salonero','Salonero / Mesero',4),
  ('bartender','Bartender',5),
  ('jardineria','Jardinería',6),
  ('mantenimiento','Mantenimiento',7),
  ('construccion','Construcción',8),
  ('guia','Guía turístico',9),
  ('chofer','Chofer / Transporte',10),
  ('ventas','Ventas / Tienda',11),
  ('cuido','Cuido de niños o adultos mayores',12),
  ('eventos','Eventos',13),
  ('otro','Otro',99)
on conflict (id) do nothing;

-- ========== Perfiles (uno por usuario) ==========
create table if not exists public.perfiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  tipo       text not null check (tipo in ('trabajador','empresa')),
  nombre     text not null,
  telefono   text,
  zona       text default 'La Fortuna',
  foto_url   text,
  creado_en  timestamptz not null default now()
);

create table if not exists public.trabajadores (
  perfil_id      uuid primary key references public.perfiles(id) on delete cascade,
  areas          text[] not null default '{}',
  descripcion    text,
  experiencia    text,
  disponibilidad text,           -- ej: "lunes y martes", "fines de semana"
  disponible     boolean not null default true
);

create table if not exists public.empresas (
  perfil_id      uuid primary key references public.perfiles(id) on delete cascade,
  nombre_negocio text not null,
  tipo_negocio   text,           -- hotel, restaurante, tour operador...
  direccion      text,
  descripcion    text
);

-- ========== Ofertas de trabajo ==========
create table if not exists public.ofertas (
  id           uuid primary key default gen_random_uuid(),
  empresa_id   uuid not null references public.perfiles(id) on delete cascade,
  titulo       text not null,
  area         text references public.areas(id),
  descripcion  text,
  fecha_inicio date not null,
  fecha_fin    date not null,
  horario      text,             -- ej: "7am a 3pm"
  pago         text,             -- ej: "₡15 000 por día"
  cupos        int not null default 1 check (cupos > 0),
  estado       text not null default 'activa'
               check (estado in ('activa','pausada','contratado','ya_no_se_necesita')),
  creado_en    timestamptz not null default now(),
  check (fecha_fin >= fecha_inicio),
  check (fecha_fin - fecha_inicio <= 14)   -- máximo 2 semanas
);
create index if not exists ofertas_estado_idx on public.ofertas(estado, fecha_inicio);
create index if not exists ofertas_empresa_idx on public.ofertas(empresa_id);

-- ========== Postulaciones ==========
create table if not exists public.postulaciones (
  id            uuid primary key default gen_random_uuid(),
  oferta_id     uuid not null references public.ofertas(id) on delete cascade,
  trabajador_id uuid not null references public.perfiles(id) on delete cascade,
  mensaje       text,
  estado        text not null default 'enviada'
                check (estado in ('enviada','vista','aceptada','rechazada','retirada')),
  creado_en     timestamptz not null default now(),
  unique (oferta_id, trabajador_id)
);
create index if not exists postulaciones_trabajador_idx on public.postulaciones(trabajador_id);

-- ========== Funciones de ayuda ==========
create or replace function public.mi_tipo() returns text
language sql stable security definer set search_path = public as $$
  select tipo from public.perfiles where id = auth.uid()
$$;

create or replace function public.es_duenio_oferta(p_oferta uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.ofertas where id = p_oferta and empresa_id = auth.uid())
$$;

create or replace function public.trabajador_postulo_a_mi_oferta(p_trabajador uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.postulaciones p
    join public.ofertas o on o.id = p.oferta_id
    where p.trabajador_id = p_trabajador and o.empresa_id = auth.uid()
  )
$$;

-- Crea el perfil automáticamente al registrarse (datos enviados en el registro)
create or replace function public.crear_perfil_nuevo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_tipo text := coalesce(new.raw_user_meta_data->>'tipo', 'trabajador');
  v_nombre text := coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email, '@', 1));
begin
  if v_tipo not in ('trabajador','empresa') then v_tipo := 'trabajador'; end if;
  insert into public.perfiles (id, tipo, nombre, telefono)
  values (new.id, v_tipo, v_nombre, new.raw_user_meta_data->>'telefono');
  if v_tipo = 'empresa' then
    insert into public.empresas (perfil_id, nombre_negocio)
    values (new.id, coalesce(new.raw_user_meta_data->>'nombre_negocio', v_nombre));
  else
    insert into public.trabajadores (perfil_id) values (new.id);
  end if;
  return new;
end $$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- ========== Seguridad (RLS) ==========
alter table public.areas         enable row level security;
alter table public.perfiles      enable row level security;
alter table public.trabajadores  enable row level security;
alter table public.empresas      enable row level security;
alter table public.ofertas       enable row level security;
alter table public.postulaciones enable row level security;

-- Áreas: lectura pública
create policy "areas lectura" on public.areas for select using (true);

-- Perfiles: cada quien ve el suyo; empresas ven trabajadores disponibles o que les postularon;
-- todos ven perfiles de empresas.
create policy "perfil propio" on public.perfiles for select using (id = auth.uid());
create policy "perfiles de empresas visibles" on public.perfiles for select using (tipo = 'empresa');
create policy "empresas ven trabajadores" on public.perfiles for select
  using (tipo = 'trabajador' and public.mi_tipo() = 'empresa');
create policy "editar perfil propio" on public.perfiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- Trabajadores
create policy "trabajador propio" on public.trabajadores for select using (perfil_id = auth.uid());
create policy "empresas ven trabajadores disponibles" on public.trabajadores for select
  using (public.mi_tipo() = 'empresa' and (disponible or public.trabajador_postulo_a_mi_oferta(perfil_id)));
create policy "editar trabajador propio" on public.trabajadores for update
  using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());

-- Empresas: lectura pública, edición propia
create policy "empresas lectura" on public.empresas for select using (true);
create policy "editar empresa propia" on public.empresas for update
  using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());

-- Ofertas: las activas son públicas; la empresa ve y maneja las suyas
create policy "ofertas activas publicas" on public.ofertas for select using (estado = 'activa');
create policy "empresa ve sus ofertas" on public.ofertas for select using (empresa_id = auth.uid());
create policy "empresa crea ofertas" on public.ofertas for insert
  with check (empresa_id = auth.uid() and public.mi_tipo() = 'empresa');
create policy "empresa edita sus ofertas" on public.ofertas for update
  using (empresa_id = auth.uid()) with check (empresa_id = auth.uid());
create policy "empresa borra sus ofertas" on public.ofertas for delete using (empresa_id = auth.uid());

-- Postulaciones
create policy "trabajador ve sus postulaciones" on public.postulaciones for select
  using (trabajador_id = auth.uid());
create policy "empresa ve postulaciones a sus ofertas" on public.postulaciones for select
  using (public.es_duenio_oferta(oferta_id));
create policy "trabajador se postula" on public.postulaciones for insert
  with check (
    trabajador_id = auth.uid()
    and public.mi_tipo() = 'trabajador'
    and exists (select 1 from public.ofertas o where o.id = oferta_id and o.estado = 'activa')
  );
create policy "trabajador retira postulacion" on public.postulaciones for update
  using (trabajador_id = auth.uid()) with check (trabajador_id = auth.uid() and estado = 'retirada');
create policy "empresa responde postulacion" on public.postulaciones for update
  using (public.es_duenio_oferta(oferta_id))
  with check (public.es_duenio_oferta(oferta_id) and estado in ('vista','aceptada','rechazada'));

-- La función del registro solo la usa el trigger
revoke execute on function public.crear_perfil_nuevo_usuario() from public, anon, authenticated;
