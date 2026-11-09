-- Cada oferta indica en qué lugar es el trabajo, y cada persona o negocio puede indicar su zona
alter table public.ofertas add column if not exists lugar text;
alter table public.perfiles alter column zona drop default;
create index if not exists ofertas_lugar_idx on public.ofertas(lugar);
