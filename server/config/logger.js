// config/logger.js
//
// Log estruturado (JSON, uma linha por evento) em vez de `console.log`
// espalhado — com milhares de pedidos por dia, texto livre torna-se
// impossível de filtrar. `pino` é rápido (não bloqueia o event loop) e
// cada linha já sai pronta para outra ferramenta ler, se um dia
// quiseres mandar os logs para fora da VPS.
//
// Escreve para DOIS sítios ao mesmo tempo:
//  1. A consola (stdout) — continuas a ver tudo ao vivo através do teu
//     main.py, exatamente como já vias.
//  2. Ficheiro, em server/logs/ — histórico que sobrevive a reiniciares
//     o processo ou fechares a consola. Roda automaticamente todos os
//     dias (um ficheiro por dia) e também se um único dia passar de
//     20MB — e apaga sozinho ficheiros com mais de 30 dias, para nunca
//     encheres o disco da VPS sem reparares.
//
// Nota técnica: NÃO uses um `formatters.level` personalizado aqui — foi
// testado e quebra os dois destinos em silêncio (nenhum erro, os logs
// simplesmente desaparecem), porque uma função não consegue atravessar
// a fronteira para a thread do pino-roll. Por isso o campo `level` sai
// como número (30=info, 40=warn, 50=error), não como texto.
//
// LOG_LEVEL no .env controla o volume: 'info' no dia a dia, 'debug'
// só quando precisares de investigar algo a fundo.
const path = require('path');
const pino = require('pino');

const level = process.env.LOG_LEVEL || 'info';
const logsDir = path.join(__dirname, '..', 'logs');

const transport = pino.transport({
  targets: [
    {
      target: 'pino/file',
      level,
      options: { destination: 1 }, // 1 = stdout — o que o main.py já mostra
    },
    {
      target: 'pino-roll',
      level,
      options: {
        file: path.join(logsDir, 'speedlock'),
        frequency: 'daily',
        size: '20m',
        mkdir: true,
        dateFormat: 'yyyy-MM-dd',
        limit: { count: 30 }, // guarda os últimos 30 ficheiros, apaga o resto sozinho
      },
    },
  ],
});

const logger = pino(
  {
    level,
    timestamp: pino.stdTimeFunctions.isoTime,
  },
  transport,
);

module.exports = logger;
