// Confere, de fora, que o banco NÃO entrega nada a quem não está logado.
// Uso:  node supabase/verificar-seguranca.mjs <SUPABASE_URL> <ANON_KEY>
const [url, key] = process.argv.slice(2);
if (!url || !key) { console.log('Uso: node supabase/verificar-seguranca.mjs <SUPABASE_URL> <ANON_KEY>'); process.exit(1); }
const h = { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' };
let falhas = 0;
function resultado(nome, ok, detalhe) { console.log((ok ? 'OK    ' : 'FALHA ') + nome + (detalhe ? '  -> ' + detalhe : '')); if (!ok) falhas++; }

async function t(nome, req, esperaVazio) {
  const r = await fetch(url + req.path, { method: req.method || 'GET', headers: h, body: req.body });
  const txt = await r.text();
  let corpo; try { corpo = JSON.parse(txt); } catch { corpo = txt; }
  const bloqueado = !r.ok || (Array.isArray(corpo) && corpo.length === 0);
  resultado(nome, esperaVazio ? bloqueado : !r.ok, 'HTTP ' + r.status + (Array.isArray(corpo) ? ' (' + corpo.length + ' linhas)' : ''));
}

await t('Sem login, ler registros do negócio', { path: '/rest/v1/registros?select=*&limit=5' }, true);
await t('Sem login, ler lista de acessos', { path: '/rest/v1/membros?select=*&limit=5' }, true);
await t('Sem login, gravar um registro', { path: '/rest/v1/registros', method: 'POST', body: JSON.stringify({ colecao: 'pedidos', id: 'teste-seguranca', dados: {} }) }, false);
await t('Sem login, alterar acessos', { path: '/rest/v1/membros?user_id=not.is.null', method: 'PATCH', body: JSON.stringify({ ativo: true }) }, true);
console.log(falhas ? '\n' + falhas + ' verificação(ões) FALHARAM — não use o app com dados reais até corrigir.' : '\nTudo certo: sem login, nada é lido nem gravado.');
process.exit(falhas ? 1 : 0);
