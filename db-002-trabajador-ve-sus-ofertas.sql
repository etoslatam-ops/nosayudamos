-- El trabajador puede seguir viendo las ofertas a las que se postuló aunque ya no estén activas
create or replace function public.me_postule_a(p_oferta uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.postulaciones where oferta_id = p_oferta and trabajador_id = auth.uid())
$$;

create policy "trabajador ve ofertas a las que se postulo" on public.ofertas for select
  using (public.me_postule_a(id));
