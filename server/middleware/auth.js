// middleware/auth.js
const admin = require('../firebaseAdmin');
const { httpError } = require('../lib/httpError');

/// Verifica o token da Firebase enviado no cabeçalho Authorization (a
/// app envia sempre que há sessão — ver ApiClient no Flutter). Se não
/// houver token ou for inválido, `req.auth` fica `null` em vez de
/// rejeitar logo — algumas rotas (registerUser, requestPasswordReset)
/// são chamadas sem sessão de propósito.
async function attachAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer (.+)$/);
  if (!match) {
    req.auth = null;
    return next();
  }
  try {
    const decoded = await admin.auth().verifyIdToken(match[1]);
    // Mesma forma que `request.auth` tinha nas Cloud Functions — em
    // particular `token.firebase.sign_in_provider` continua a existir,
    // por isso o resto do código (deteção de convidado anónimo) não
    // precisa de mudar nada.
    req.auth = { uid: decoded.uid, token: decoded };
  } catch (err) {
    req.auth = null;
  }
  next();
}

function requireAuth(req, res, next) {
  if (!req.auth) return next(httpError('unauthenticated', 'Login necessário.'));
  next();
}

/// Antes duplicada em routes/devices.js e routes/commands.js — só existe
/// aqui agora, os dois sítios que precisam disto importam-na.
function isGuest(req) {
  return req.auth?.token?.firebase?.sign_in_provider === 'anonymous';
}

module.exports = { attachAuth, requireAuth, isGuest };
