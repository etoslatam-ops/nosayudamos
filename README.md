# NosAyudamos

Sitio para conectar personas que quieren trabajar por día u hora con negocios de La Fortuna que necesitan personal por unos días (de 1 día a 2 semanas).

## Páginas
- `index.html` — página informativa
- `ofertas.html` — ofertas activas (públicas)
- `cuenta.html` — entrar, crear cuenta y recuperar contraseña
- `panel.html` — panel del trabajador (perfil y postulaciones) y del negocio (ofertas, postulantes, buscar personal)

## Base de datos
Supabase, proyecto `nosayudamos` (organización etoslatam-ops). Los archivos `db-*.sql` tienen el esquema, en orden.
La conexión está en `config.js` (clave pública; la seguridad la dan las reglas RLS de la base de datos).

NosAyudamos es solo un intermediario de información: la contratación es responsabilidad del negocio que contrata.
