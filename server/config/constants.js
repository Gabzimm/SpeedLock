// config/constants.js
//
// Todos os valores ajustáveis do backend, num único sítio. Antes estavam
// espalhados dentro de lib/helpers.js junto com lógica — agora é só
// configuração, sem nenhuma função aqui dentro.

module.exports = {
  // --- Verificação de login / recuperação de senha ---
  TRUSTED_DEVICE_DAYS: 30,
  CODE_TTL_MINUTES: 10,
  MAX_CODE_ATTEMPTS: 5,

  // --- Limites de pedidos (rate limiting) ---
  // Nota: aplicados em memória (middleware/rateLimiters.js), não no
  // Firestore — ver o aviso nesse ficheiro sobre o que isso implica se
  // um dia isto correr em mais do que um processo Node ao mesmo tempo.
  LOGIN_ATTEMPTS_PER_HOUR: 8,
  REGISTER_ATTEMPTS_PER_HOUR: 5,
  PASSWORD_RESET_ATTEMPTS_PER_HOUR: 5,
  COMMAND_REQUESTS_PER_MINUTE: 60,

  // --- Comandos ao dispositivo ---
  COMMAND_SIGNING_KEY: process.env.COMMAND_SIGNING_KEY || 'dev-only-change-me',
  OFFLINE_SIGNING_KEY: process.env.OFFLINE_SIGNING_KEY || 'dev-only-offline-key-change-me',
  OFFLINE_TOKEN_VALID_DAYS: 7,
  COMMAND_TOKEN_VALID_MS: 15000,
  FLAG_THRESHOLD: 3,

  MIN_LEVEL_FOR_COMMAND: {
    lock: 'limited',
    unlock: 'user',
    setSpeedLimit: 'admin',
    lights: 'limited',
    horn: 'limited',
  },
  LEVEL_RANK: { limited: 0, temporary: 1, user: 2, admin: 3, owner: 4 },
  VALID_LEVELS: ['limited', 'temporary', 'user', 'admin'],

  // --- Perfil ---
  HEX_COLOR_RE: /^#[0-9A-Fa-f]{6}$/,
  MAX_BIO_LENGTH: 160,

  // --- Nomes de coleções Firestore (num só sítio, para nunca escrever
  // o nome errado à mão em dois sítios diferentes) ---
  COLLECTIONS: {
    USERS: 'users',
    DEVICES: 'devices',
    ACCESS_REQUESTS: 'accessRequests',
    VERIFICATIONS: 'verifications',
    PASSWORD_RESETS: 'passwordResets',
    SUSPICIOUS_ACTIVITY: 'suspiciousActivity',
  },

  // --- Cache em memória (lib/cache.js) ---
  USER_LOOKUP_CACHE_TTL_MS: 5 * 60 * 1000, // 5 minutos
};
