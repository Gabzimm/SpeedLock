// middleware/rateLimiters.js
//
// Antes, o limite de tentativas (login, registo) era feito à mão: ler um
// array de timestamps de um documento Firestore, filtrar, escrever de
// volta. Isso custa uma leitura + escrita no Firestore por PEDIDO, em
// endpoints que são exatamente os mais visados por scripts a tentar
// muitas vezes seguidas — o pior sítio possível para teres uma operação
// cara. Também tinha uma janela de corrida: dois pedidos em simultâneo
// podem ler o mesmo array antes de qualquer um escrever, e nenhum vê a
// tentativa do outro.
//
// Isto troca isso por limitação em memória (`express-rate-limit`) —
// sem custo de Firestore nenhum, sem janela de corrida.
//
// AVISO IMPORTANTE: isto vive na memória deste processo Node. Enquanto
// correr como UM processo (é o que o teu main.py faz agora), os limites
// são exatos. Se um dia correres isto em vários processos ao mesmo
// tempo (cluster, ou várias instâncias atrás de um load balancer), CADA
// processo conta as tentativas por si — na prática o limite real passa
// a ser (limite configurado × número de processos). Nessa altura, trocar
// o "store" do express-rate-limit para um Redis partilhado resolve, sem
// precisar de mudar mais nada nas rotas.
const rateLimit = require('express-rate-limit');
const { httpError } = require('../lib/httpError');
const {
  LOGIN_ATTEMPTS_PER_HOUR,
  REGISTER_ATTEMPTS_PER_HOUR,
  PASSWORD_RESET_ATTEMPTS_PER_HOUR,
  COMMAND_REQUESTS_PER_MINUTE,
} = require('../config/constants');

// Handler comum: em vez do JSON por omissão do express-rate-limit,
// lançamos o mesmo HttpError que o resto do código usa — assim o
// cliente (ApiException no Flutter) vê sempre o mesmo formato de erro,
// venha de onde vier.
function rateLimitExceeded(req, res, next) {
  next(httpError('resource-exhausted', 'Demasiadas tentativas. Tenta novamente mais tarde.'));
}

const byIp = (req) => req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip;
const byUidOrIp = (req) => req.auth?.uid || byIp(req);

const loginLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: LOGIN_ATTEMPTS_PER_HOUR,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: byUidOrIp,
  handler: rateLimitExceeded,
});

const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: REGISTER_ATTEMPTS_PER_HOUR,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: byIp,
  handler: rateLimitExceeded,
});

const passwordResetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: PASSWORD_RESET_ATTEMPTS_PER_HOUR,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: byIp,
  handler: rateLimitExceeded,
});

// Guarda geral contra picos de pedidos de comando, além (não em vez) da
// deteção de comportamento suspeito que já existe em commandService —
// essa continua a tratar de "isto cheira mal", esta trata só de "isto é
// demasiados pedidos, sejam eles quais forem".
const commandLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: COMMAND_REQUESTS_PER_MINUTE,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: byUidOrIp,
  handler: rateLimitExceeded,
});

// Autenticação Básica HTTP não tem um "endpoint de login" próprio — a
// senha vai em cada pedido. Isto limita quantas vezes por IP se pode
// tentar adivinhar a password do painel de administração, antes de ter
// sequer confirmado se acertou.
const adminLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: byIp,
  handler: (req, res) => res.status(429).send('Demasiadas tentativas. Tenta novamente mais tarde.'),
});

module.exports = { loginLimiter, registerLimiter, passwordResetLimiter, commandLimiter, adminLimiter };
