// index.js — arranque da aplicação. Só liga peças, não tem lógica
// nenhuma própria: se precisares de perceber "o que é que uma rota
// faz", o sítio certo é routes/ → services/, nunca aqui.
require('./carregar-env')(); // lê o .env sem precisar de nenhuma dependência externa

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');

const logger = require('./config/logger');
const requestLogger = require('./middleware/requestLogger');
const errorHandler = require('./middleware/errorHandler');

const authRoutes = require('./routes/auth');
const deviceRoutes = require('./routes/devices');
const profileRoutes = require('./routes/profile');
const commandRoutes = require('./routes/commands');
const historyRoutes = require('./routes/history');
const adminRoutes = require('./routes/admin');

const app = express();

// Atrás de um proxy reverso (Nginx, na VPS) — sem isto, `req.ip` mostra
// sempre o IP interno do Nginx, não o do utilizador real, o que
// partiria a verificação de localização no login e os limitadores de
// pedidos (rateLimiters.js).
app.set('trust proxy', true);

// Cabeçalhos de segurança HTTP standard (X-Content-Type-Options,
// X-Frame-Options, etc.) — sem custo nenhum, sem razão para não ter.
// `contentSecurityPolicy: false` porque isto é uma API, não serve HTML;
// o CSP por omissão do helmet é pensado para páginas web.
app.use(helmet({ contentSecurityPolicy: false }));

app.use(cors()); // A app mobile não tem "origem" no sentido do browser — ver nota no README sobre restringir isto se também servires um site a partir do mesmo domínio.

// Limite de tamanho do corpo do pedido — sem isto, um pedido com um
// corpo gigante ocupa memória do processo antes de qualquer validação
// correr. Nenhuma rota desta API precisa de mais do que uns poucos KB.
app.use(express.json({ limit: '100kb' }));

app.use(requestLogger);

app.get('/health', (req, res) => res.json({ ok: true }));

app.use(authRoutes);
app.use(deviceRoutes);
app.use(profileRoutes);
app.use(commandRoutes);
app.use(historyRoutes);
app.use(adminRoutes);

// Tem de ser o último `app.use` — ver middleware/errorHandler.js.
app.use(errorHandler);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info({ port: PORT }, 'SpeedLock backend a correr');
});

// Nunca deixar o processo morrer em silêncio por causa de uma promise
// rejeitada sem `.catch` algures fora do fluxo normal das rotas (essas
// já são apanhadas por `asyncRoute`) — regista antes de sair, para ficar
// no log o que aconteceu.
process.on('unhandledRejection', (reason) => {
  logger.error({ reason }, 'unhandled_rejection');
});
process.on('uncaughtException', (err) => {
  logger.error({ err }, 'uncaught_exception');
  process.exit(1);
});
