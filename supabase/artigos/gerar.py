import json, sys, glob, os
src = os.path.expanduser("~/Desktop/CLAUDE CODE/academy/conteudo/artigos")
def q(v):
    if v is None: return "null"
    s = str(v); tag = "$a$"
    return f"{tag}{s}{tag}"
pref = sys.argv[1]; out = sys.argv[2]
rows = []
for f in sorted(glob.glob(f"{src}/{pref}*.json"), key=lambda x: int(''.join(c for c in os.path.basename(x) if c.isdigit()) or 0)):
    a = json.load(open(f)); slug = os.path.basename(f)[:-5]
    ex = {k: a.get(k) for k in ("pontos_chave", "na_pratica", "numeros", "tags")}
    nivel = a.get("nivel_evidencia")
    rows.append(f"""insert into public.academy_artigos (slug,titulo_original,titulo_pt,autores,periodico,ano,doi,link_original,nivel_evidencia,tipo_estudo,tema,resumo_pt,texto_original,texto_pt,extras,pdf_path,etapa,publicado_em)
values ({q(slug)},{q(a.get('titulo_original') or a.get('titulo_pt'))},{q(a.get('titulo_pt'))},{q(a.get('autores'))},{q(a.get('periodico'))},{a.get('ano') or 'null'},{q(a.get('doi'))},{q('https://doi.org/'+a['doi'] if a.get('doi') else None)},{q(nivel)},{q(a.get('tipo_estudo'))},{q(a.get('tema'))},{q(a.get('resumo_1min'))},{q(a.get('texto_original'))},{q(a.get('texto_pt'))},{q(json.dumps(ex, ensure_ascii=False))}::jsonb,{q(slug+'.pdf' if os.path.exists(f'/Volumes/SSD iPhone/academy/pdfs/{slug}.pdf') else None)},'publicado',now())
on conflict (slug) do update set titulo_original=excluded.titulo_original,titulo_pt=excluded.titulo_pt,autores=excluded.autores,periodico=excluded.periodico,ano=excluded.ano,doi=excluded.doi,link_original=excluded.link_original,nivel_evidencia=excluded.nivel_evidencia,tipo_estudo=excluded.tipo_estudo,tema=excluded.tema,resumo_pt=excluded.resumo_pt,texto_original=excluded.texto_original,texto_pt=excluded.texto_pt,extras=excluded.extras,pdf_path=coalesce(excluded.pdf_path,academy_artigos.pdf_path),updated_at=now();""")
open(out, "w").write("\n\n".join(rows) + "\n")
print(len(rows), "artigos", os.path.getsize(out)//1024, "KB")
