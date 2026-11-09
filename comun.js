// Funciones compartidas por todas las páginas de NosAyudamos
const sb = supabase.createClient(NA_CONFIG.url, NA_CONFIG.key);

const NA = {
  areas: [],

  esc(t) {
    return String(t ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  },

  fecha(f) {
    if (!f) return "";
    const [a, m, d] = f.split("-").map(Number);
    return new Date(a, m - 1, d).toLocaleDateString("es-CR", { weekday: "short", day: "numeric", month: "short" });
  },

  rangoFechas(i, f) {
    return i === f ? NA.fecha(i) : `${NA.fecha(i)} → ${NA.fecha(f)}`;
  },

  hoy() {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  },

  async cargarAreas() {
    if (NA.areas.length) return NA.areas;
    const { data } = await sb.from("areas").select("*").order("orden");
    NA.areas = data || [];
    return NA.areas;
  },

  nombreArea(id) {
    return (NA.areas.find(a => a.id === id) || {}).nombre || id || "";
  },

  // Enlace de WhatsApp a partir de un teléfono de Costa Rica
  whatsapp(tel, texto = "") {
    let n = String(tel || "").replace(/\D/g, "");
    if (!n) return null;
    if (n.length === 8) n = "506" + n;
    return `https://wa.me/${n}${texto ? "?text=" + encodeURIComponent(texto) : ""}`;
  },

  mensaje(el, texto, tipo = "info") {
    if (typeof el === "string") el = document.getElementById(el);
    if (!el) return;
    el.className = `mensaje visible ${tipo}`;
    el.textContent = texto;
    if (tipo === "ok") setTimeout(() => el.classList.remove("visible"), 4000);
  },

  async sesion() {
    const { data } = await sb.auth.getSession();
    return data.session;
  },

  async miPerfil() {
    const s = await NA.sesion();
    if (!s) return null;
    const { data } = await sb.from("perfiles").select("*").eq("id", s.user.id).maybeSingle();
    return data;
  },

  // Ajusta la barra superior según haya sesión o no
  async barra() {
    const nav = document.getElementById("nav-cuenta");
    if (!nav) return;
    const s = await NA.sesion();
    if (s) {
      nav.innerHTML = `<a class="btn btn-selva btn-chico" href="panel.html">Mi panel</a>`;
    } else {
      nav.innerHTML = `<a class="enlace" href="cuenta.html">Entrar</a>
        <a class="btn btn-lava btn-chico" href="cuenta.html?modo=registro">Registrarme</a>`;
    }
  },

  // Traducciones de los errores más comunes
  error(e) {
    const m = (e && e.message) || String(e);
    if (/Invalid login credentials/i.test(m)) return "Correo o contraseña incorrectos.";
    if (/Email not confirmed/i.test(m)) return "Todavía no confirmaste tu correo. Revisá tu bandeja de entrada.";
    if (/already registered|already been registered/i.test(m)) return "Ese correo ya tiene una cuenta. Probá entrar.";
    if (/Password should be at least/i.test(m)) return "La contraseña debe tener al menos 6 caracteres.";
    if (/duplicate key.*postulaciones/i.test(m)) return "Ya te postulaste a esta oferta.";
    if (/rate limit/i.test(m)) return "Demasiados intentos. Esperá unos minutos y probá de nuevo.";
    if (/ofertas_check1|fecha_fin - fecha_inicio/i.test(m)) return "Una oferta puede durar máximo 2 semanas.";
    if (/ofertas_check/i.test(m)) return "La fecha final no puede ser antes de la fecha de inicio.";
    return "Algo salió mal: " + m;
  },

  // Dibuja una tarjeta de oferta
  tarjetaOferta(o, empresa, extra = "") {
    const cupos = o.cupos > 1 ? `<span class="pastilla gris">${o.cupos} personas</span>` : "";
    return `<article class="tarjeta">
      <div class="meta"><span class="pastilla lava">${NA.esc(NA.nombreArea(o.area))}</span>${cupos}</div>
      <h3>${NA.esc(o.titulo)}</h3>
      <div class="negocio">${NA.esc(empresa?.nombre_negocio || "Negocio")}${empresa?.tipo_negocio ? " · " + NA.esc(empresa.tipo_negocio) : ""}</div>
      <div class="meta">
        <span class="pastilla">📅 ${NA.esc(NA.rangoFechas(o.fecha_inicio, o.fecha_fin))}</span>
        ${o.horario ? `<span class="pastilla">🕒 ${NA.esc(o.horario)}</span>` : ""}
        ${o.pago ? `<span class="pastilla ok">💵 ${NA.esc(o.pago)}</span>` : ""}
      </div>
      ${o.descripcion ? `<p>${NA.esc(o.descripcion)}</p>` : ""}
      <div class="pie">${extra}</div>
    </article>`;
  },

  // Ofertas activas y vigentes con los datos del negocio
  async ofertasActivas({ area = "", limite = 60 } = {}) {
    let q = sb.from("ofertas").select("*").eq("estado", "activa").gte("fecha_fin", NA.hoy())
      .order("fecha_inicio").limit(limite);
    if (area) q = q.eq("area", area);
    const { data: ofertas, error } = await q;
    if (error) throw error;
    const ids = [...new Set((ofertas || []).map(o => o.empresa_id))];
    let empresas = {};
    if (ids.length) {
      const { data } = await sb.from("empresas").select("*").in("perfil_id", ids);
      (data || []).forEach(e => (empresas[e.perfil_id] = e));
    }
    return { ofertas: ofertas || [], empresas };
  },

  pie() {
    const f = document.getElementById("pie");
    if (!f) return;
    f.innerHTML = `<div class="contenedor">
      <div><strong style="color:#fff">NosAyudamos</strong> · Trabajos por día en La Fortuna, San Carlos.<br>
      Somos solo un punto de encuentro: la contratación y sus condiciones son responsabilidad de cada negocio.</div>
      <div><a href="ofertas.html">Ver ofertas</a> · <a href="cuenta.html?modo=registro">Registrarme</a></div>
    </div>`;
  }
};

document.addEventListener("DOMContentLoaded", () => { NA.barra(); NA.pie(); });
