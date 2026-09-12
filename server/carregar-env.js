// carregar-env.js — lê o arquivo .env e coloca cada linha em process.env.
// Feito à mão (sem instalar a lib "dotenv") pra ter uma dependência a menos.
const fs = require('fs');
const path = require('path');

module.exports = function carregarEnv() {
  const caminho = path.join(__dirname, '.env');
  if (!fs.existsSync(caminho)) {
    console.warn('⚠️ Nenhum arquivo .env encontrado em ' + caminho + ' — usando só as variáveis já definidas no ambiente.');
    return;
  }

  const conteudo = fs.readFileSync(caminho, 'utf8');
  conteudo.split('\n').forEach(function(linhaBruta) {
    const linha = linhaBruta.trim();
    if (!linha || linha.startsWith('#')) return; // ignora vazias e comentários

    const igual = linha.indexOf('=');
    if (igual === -1) return;

    const chave = linha.slice(0, igual).trim();
    let valor = linha.slice(igual + 1).trim();

    // remove aspas envolvendo o valor, se tiver ("valor" ou 'valor')
    if ((valor.startsWith('"') && valor.endsWith('"')) || (valor.startsWith("'") && valor.endsWith("'"))) {
      valor = valor.slice(1, -1);
    }

    if (!(chave in process.env)) process.env[chave] = valor; // não sobrescreve se já veio do painel
  });
};
