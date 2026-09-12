// services/logReaderService.js
//
// Lê os ficheiros que config/logger.js já escreve em server/logs/ — o
// painel de administração usa isto para mostrar o histórico sem
// precisares de entrar na VPS por SSH.
const fs = require('fs');
const path = require('path');

const LOGS_DIR = path.join(__dirname, '..', 'logs');
const FILENAME_DATE_RE = /^speedlock\.(\d{4}-\d{2}-\d{2})/;

function listLogFiles() {
  if (!fs.existsSync(LOGS_DIR)) return [];
  return fs.readdirSync(LOGS_DIR).filter((f) => f.endsWith('.log'));
}

/// Datas com pelo menos um ficheiro de log, mais recente primeiro — para
/// preencher o seletor de data no painel.
function listAvailableDates() {
  const dates = new Set();
  listLogFiles().forEach((file) => {
    const match = file.match(FILENAME_DATE_RE);
    if (match) dates.add(match[1]);
  });
  return [...dates].sort().reverse();
}

/// Lê as últimas `limit` entradas de um dia (pode haver mais do que um
/// ficheiro no mesmo dia, se tiver rodado por tamanho a meio do dia).
/// Linhas que não sejam JSON válido são ignoradas em silêncio — nunca
/// deve ser possível um log mal formado partir o painel.
function readEntriesForDate(date, limit) {
  const files = listLogFiles()
    .filter((f) => f.startsWith(`speedlock.${date}`))
    .sort();

  const entries = [];
  for (const file of files) {
    const content = fs.readFileSync(path.join(LOGS_DIR, file), 'utf8');
    for (const line of content.split('\n')) {
      if (!line.trim()) continue;
      try {
        entries.push(JSON.parse(line));
      } catch (err) {
        // Linha corrompida/incompleta (pode acontecer se lermos a meio
        // de uma escrita) — ignorar, nunca deixar cair o painel por isto.
      }
    }
  }
  return entries.slice(-limit);
}

module.exports = { listAvailableDates, readEntriesForDate };
