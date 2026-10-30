// Configuração pública do FourLab Academy.
// Chaves PÚBLICAS por design (publishable). A segurança vem das políticas RLS no Supabase.
// NUNCA colocar a service_role key aqui.
window.ACADEMY_CONFIG = {
  SUPABASE_URL: "https://heelubwizluflohywlgy.supabase.co",
  SUPABASE_ANON_KEY: "sb_publishable_HO0Cn-5KTSQ2YMB9WXJyCA_hlzjycY6",
  // URL do player do Panda Video; {id} é trocado pelo ID do vídeo (Panda → vídeo → Embed)
  PANDA_EMBED: "https://player-vz-XXXXXXXX.tv.pandavideo.com.br/embed/?v={id}",
};
