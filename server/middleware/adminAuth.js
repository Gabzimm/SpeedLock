// middleware/adminAuth.js
//
// Protege a área de administração (por agora, só os logs) com
// autenticação HTTP Basic — pede utilizador/senha ao navegador, sem
// precisar de nenhuma página de login própria. Só funciona bem sobre
// HTTPS (que já tens, via Nginx + certbot) — sem isso, a senha viaja
// em como texto simples, só codificada em base64.
//
// As credenciais nunca são comparadas com `===` — isso permite um
// "ataque de temporização" (medir quanto tempo a comparação demora para
// adivinhar caracteres um a um). `crypto.timingSafeEqual` compara
// sempre no mesmo tempo, seja a resposta certa ou completamente errada.
const crypto = require('crypto');
const logger = require('../config/logger');

function timingSafeEqualStr(a, b) {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) {
    // Mesmo quando os tamanhos já não batem certo (o que por si só
    // podia vazar informação por temporização), corre à mesma uma
    // comparação de tamanho fixo, para não sair daqui mais depressa.
    crypto.timingSafeEqual(bufA, bufA);
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}

function requireBasicAuth(res) {
  res.set('WWW-Authenticate', 'Basic realm="SpeedLock Admin"');
  return res.status(401).send('Autenticação necessária.');
}

function adminAuth(req, res, next) {
  const expectedUser = process.env.ADMIN_USER || '';
  const expectedPass = process.env.ADMIN_PASSWORD || '';
  if (!expectedUser || !expectedPass) {
    logger.error('admin_auth_not_configured');
    return res.status(500).send('Painel de administração não configurado (falta ADMIN_USER/ADMIN_PASSWORD no .env).');
  }

  const header = req.headers.authorization || '';
  const [scheme, encoded] = header.split(' ');
  if (scheme !== 'Basic' || !encoded) {
    return requireBasicAuth(res);
  }

  let decoded;
  try {
    decoded = Buffer.from(encoded, 'base64').toString('utf8');
  } catch (err) {
    return requireBasicAuth(res);
  }
  const sepIndex = decoded.indexOf(':');
  if (sepIndex === -1) return requireBasicAuth(res);

  const user = decoded.slice(0, sepIndex);
  const pass = decoded.slice(sepIndex + 1);

  const userOk = timingSafeEqualStr(user, expectedUser);
  const passOk = timingSafeEqualStr(pass, expectedPass);
  if (!userOk || !passOk) {
    logger.warn({ ip: req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip }, 'admin_auth_failed');
    return requireBasicAuth(res);
  }

  next();
}

module.exports = adminAuth;
