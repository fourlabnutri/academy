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
// aceita o código ou o link completo do YouTube
const ytId = (v) => (String(v).match(/(?:youtu\.be\/|[?&]v=|embed\/|shorts\/)([\w-]{11})/) || [])[1] || v;
export const capaAula = (id) => `/assets/aulas/${ytId(id || "")}.jpg`;
export const pandaUrl = (id) => cfg.PANDA_EMBED.replace("{id}", encodeURIComponent(ytId(id)));

/* ---------- ícones (mesmo traço do hub) ---------- */
const I = {
  home: '<path d="M3 11.5 12 4l9 7.5"/><path d="M5.5 10v9.5h13V10"/>',
  play: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m10 9 5 3-5 3z"/>',
  doc: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h4"/>',
  award: '<circle cx="12" cy="9" r="5.5"/><path d="m9 14-1.5 7 4.5-2.5 4.5 2.5L15 14"/>',
  check: '<rect x="3" y="3" width="18" height="18" rx="5"/><path d="m8 12 3 3 5-6"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="m13.5 6.5 4 4"/>',
  out: '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l5-5-5-5M15 12H3"/>',
  chat: '<path d="M4 5h16v11H9l-5 4z"/>',
  rank: '<path d="M5 21v-7h4v7M10 21V9h4v12M15 21v-5h4v5"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.9 4.9 7 7M17 17l2.1 2.1M2 12h3M19 12h3M4.9 19.1 7 17M17 7l2.1-2.1"/>',
  pulse: '<path d="M3 12h4l3-7 4 14 3-7h4"/>',
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
  const { data: l } = await supabase.from("academy_live").select("modulos,visita_url").maybeSingle();
  p.mod = { artigos: true, forum: true, ranking: true, quiz: false, certificados: true, live: true, ...(l?.modulos || {}) };
  p.visita_url = l?.visita_url || "";
  return p;
}

/* ---------- sidebar ---------- */
export function shell(p, active) {
  const items = [
    ["Aprender"],
    ["inicio", "Início", "home"],
    ["live", "Aula inaugural", "play"],
    ["artigos", "Artigos", "doc"],
    ["forum", "Fórum", "chat"],
    ["ranking", "Ranking", "rank"],
    ["quiz", "Desafio", "check"],
    ["certificados", "Certificados", "award"],
  ].filter((i) => !i[1] || i[0] === "inicio" || STAFF.includes(p.role) || p.mod?.[i[0]] !== false);
  if (!STAFF.includes(p.role) && p.mod?.[active] === false) { location.replace(root + "inicio"); return; }
  const adm = [
    ["comercial", "admin"].includes(p.role) && ["admin/painel", "Painel", "rank"],
    STAFF.includes(p.role) && ["admin/uso", "Uso e engajamento", "pulse"],
    ["comercial", "admin"].includes(p.role) && ["admin/aprovacoes", "Acessos", "check"],
    ["editor", "revisor", "admin"].includes(p.role) && ["admin/conteudo", "Conteúdo", "edit"],
    STAFF.includes(p.role) && ["admin/live", "Lançamento e módulos", "play"],
  ].filter(Boolean);
  if (!adm.some((a) => a[0] === "admin/painel") && STAFF.includes(p.role)) adm.unshift(["admin/painel", "Painel", "rank"]);
  const nav = items.map(([href, label, ic]) => (label === undefined
    ? `<div class="nav-cap">${href}</div>`
    : `<a class="nav-btn ${href === active ? "active" : ""}" href="${root}${href}" title="${label}"><span class="ic">${svg(ic)}</span><span class="label">${label}</span></a>`)).join("");
  document.body.insertAdjacentHTML("afterbegin", `
    <aside class="sidebar" aria-label="Menu">
      <div class="sidebar-logo"><img class="mark" src="${root}assets/mark-f.png" alt=""><img src="${root}assets/logo-academy.png" alt="FourLab Academy"></div>
      <nav class="sidebar-nav">${nav}
        ${adm.length ? `<button class="nav-btn ${active.startsWith("admin/") ? "active" : ""}" id="admBtn" title="Administração"><span class="ic">${svg("gear")}</span><span class="label">Administração</span></button>` : ""}
        <button class="nav-btn" id="sair" title="Sair"><span class="ic">${svg("out")}</span><span class="label">Sair</span></button>
      </nav>
      <div class="sidebar-footer">${esc(p.nome)} · ${esc(p.role)}</div>
    </aside>
    ${adm.length ? `<aside class="adm-fly" id="admFly" hidden><div class="adm-fly-h">Administração</div>${adm.map(([h, l, ic]) => `<a class="adm-fly-a ${h === active ? "on" : ""}" href="${root}${h}"><span class="ic">${svg(ic)}</span>${l}</a>`).join("")}</aside>` : ""}`);
  const ab = document.getElementById("admBtn");
  if (ab) {
    const fly = document.getElementById("admFly");
    ab.onclick = (e) => { e.stopPropagation(); fly.hidden = !fly.hidden; };
    document.addEventListener("click", (e) => { if (!fly.hidden && !fly.contains(e.target)) fly.hidden = true; });
  }
  track(p);
  document.getElementById("sair").onclick = async () => { await supabase.auth.signOut(); location.href = root + "login"; };
  const av = document.getElementById("meAv");
  if (av) av.textContent = initials(p.nome);
}

export const isStaff = (p) => STAFF.includes(p.role);

/* ---------- rastreamento de uso ---------- */
let tracking = false;
function track(p) {
  if (tracking || !p?.id || p.demo_agora) return;
  tracking = true;
  let sessao = "";
  try { sessao = sessionStorage.getItem("ac_s") || ""; if (!sessao) { sessao = crypto.randomUUID(); sessionStorage.setItem("ac_s", sessao); } } catch { sessao = crypto.randomUUID(); }
  const pagina = location.pathname.replace(/^\/|\.html$/g, "") || "inicio";
  const disp = matchMedia("(max-width: 860px)").matches ? "mobile" : "desktop";
  const send = (tipo, alvo, seg = 0) => supabase.from("academy_uso").insert({ user_id: p.id, sessao, tipo, pagina, alvo: alvo ? String(alvo).slice(0, 120) : null, seg, disp }).then(() => {}, () => {});
  setTimeout(() => send("view", (document.title || "").replace(/ · FourLab Academy$/, "") || pagina), 1500);
  document.addEventListener("click", (e) => {
    const el = e.target.closest("[data-track],a,button,summary,input[type=radio],input[type=checkbox]");
    if (!el) return;
    const t = el.dataset.track || el.getAttribute("aria-label") || el.title || (el.textContent || "").replace(/\s+/g, " ").trim() || el.getAttribute("href");
    send("click", t);
  }, true);
  let last = Date.now(), acc = 0;
  ["mousemove", "keydown", "scroll", "touchstart"].forEach((ev) => addEventListener(ev, () => { last = Date.now(); }, { passive: true }));
  const flush = () => { if (acc >= 5) { send("tempo", null, Math.min(acc, 120)); } acc = 0; };
  setInterval(() => {
    const assistindo = document.querySelector("iframe") && document.activeElement?.tagName === "IFRAME";
    if (document.visibilityState === "visible" && (Date.now() - last < 90000 || assistindo)) acc += 15;
    if (acc >= 60) flush();
  }, 15000);
  addEventListener("visibilitychange", () => { if (document.visibilityState === "hidden") flush(); });
  addEventListener("pagehide", flush);
}
