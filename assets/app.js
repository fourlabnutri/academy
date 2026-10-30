import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cfg = window.ACADEMY_CONFIG;
export const supabase = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true },
});

/* ---------- helpers ---------- */
export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
export const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
export const fmtDate = (iso) => (iso ? new Date(iso).toLocaleDateString("pt-BR") : "—");
export const fmtDur = (s) => (s ? `${Math.floor(s / 60)} min` : "");
export const qs = (k) => new URLSearchParams(location.search).get(k);
export const initials = (n) => (n || "?").split(" ").filter(Boolean).slice(0, 2).map((x) => x[0]).join("").toUpperCase();
export function showMsg(node, text, kind = "err") {
  node.textContent = text;
  node.className = `msg show ${kind}`;
}
export const pandaUrl = (id) => cfg.PANDA_EMBED.replace("{id}", encodeURIComponent(id));

/* ---------- ícones (mesmo traço do hub) ---------- */
const I = {
  home: '<path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10v9.5h13V10"/>',
  play: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m10 9 5 3-5 3z"/>',
  doc: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h4"/>',
  award: '<circle cx="12" cy="9" r="5.5"/><path d="m9 14-1.5 7 4.5-2.5 4.5 2.5L15 14"/>',
  check: '<rect x="3" y="3" width="18" height="18" rx="5"/><path d="m8 12 3 3 5-6"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  out: '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l5-5-5-5M15 12H3"/>',
  arrow: '<path d="M7 17 17 7M8 7h9v9"/>',
};
export const svg = (k, s = 18) => `<svg viewBox="0 0 24 24" width="${s}" height="${s}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${I[k]}</svg>`;

/* ---------- sessão / perfil ---------- */
export async function getProfile() {
  const { data } = await supabase.auth.getSession();
  const user = data.session?.user;
  if (!user) return null;
  const { data: p } = await supabase.from("academy_profiles").select("*").eq("id", user.id).maybeSingle();
  return p ? { ...p, user } : { user, status: "sem_perfil" };
}

const STAFF = ["editor", "revisor", "comercial", "admin"];
const root = location.pathname.includes("/admin/") ? "../" : "./";

// Protege a página: sem login → login; pendente → pendente; papel errado → início.
export async function guard(roles) {
  const p = await getProfile();
  if (!p) { location.replace(root + "login"); return null; }
  if (p.status !== "aprovado") { location.replace(root + "pendente"); return null; }
  if (roles && !roles.includes(p.role)) { location.replace(root + "inicio"); return null; }
  return p;
}

/* ---------- sidebar ---------- */
export function shell(p, active) {
  const items = [
    ["Aprender"],
    ["inicio", "Início", "home"],
    ["artigos", "Artigos", "doc"],
    ["certificados", "Certificados", "award"],
  ];
  if (["comercial", "admin"].includes(p.role)) items.push(["Administração"], ["admin/aprovacoes", "Aprovações", "check"]);
  if (["editor", "revisor", "admin"].includes(p.role)) {
    if (!items.some((i) => i[0] === "Administração")) items.push(["Administração"]);
    items.push(["admin/conteudo", "Conteúdo", "edit"]);
  }
  const nav = items.map(([href, label, ic]) => (label === undefined
    ? `<div class="nav-cap">${href}</div>`
    : `<a class="nav-btn ${href === active ? "active" : ""}" href="${root}${href}" title="${label}"><span class="ic">${svg(ic)}</span><span class="label">${label}</span></a>`)).join("");
  document.body.insertAdjacentHTML("afterbegin", `
    <aside class="sidebar" aria-label="Menu">
      <div class="sidebar-logo"><svg class="mark" viewBox="0 0 120 150" aria-hidden="true"><defs><linearGradient id="mk1" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#f5d02a"/><stop offset="1" stop-color="#ee6a12"/></linearGradient><linearGradient id="mk2" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#ea1166"/><stop offset="1" stop-color="#fff"/></linearGradient></defs><line x1="22" y1="78" x2="72" y2="28" stroke="url(#mk1)" stroke-width="30" stroke-linecap="round"/><line x1="24" y1="128" x2="98" y2="54" stroke="url(#mk2)" stroke-width="30" stroke-linecap="round"/></svg><img src="${root}assets/logo-academy.png" alt="FourLab Academy"></div>
      <nav class="sidebar-nav">${nav}
        <button class="nav-btn" id="sair" title="Sair"><span class="ic">${svg("out")}</span><span class="label">Sair</span></button>
      </nav>
      <div class="sidebar-footer">${esc(p.nome)} · ${esc(p.role)}</div>
    </aside>`);
  document.getElementById("sair").onclick = async () => { await supabase.auth.signOut(); location.href = root + "login"; };
  const av = document.getElementById("meAv");
  if (av) av.textContent = initials(p.nome);
}

export const isStaff = (p) => STAFF.includes(p.role);
