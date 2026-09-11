// routes/admin.js
//
// Área "por trás dos panos" — só quem tem ADMIN_USER/ADMIN_PASSWORD (no
// .env da VPS) consegue entrar aqui. Não tem nada a ver com contas de
// utilizador da app; é só para ti.
const express = require('express');
const path = require('path');
const { asyncRoute } = require('../lib/httpError');
const adminAuth = require('../middleware/adminAuth');
const { adminLimiter } = require('../middleware/rateLimiters');
const logReaderService = require('../services/logReaderService');
const userAdminService = require('../services/userAdminService');

const router = express.Router();

// A ordem importa: o limite de pedidos corre primeiro (mesmo antes de
// saber se a password está certa), depois a autenticação, só depois o
// conteúdo em si.
router.use('/admin', adminLimiter, adminAuth);
router.use('/admin', express.static(path.join(__dirname, '..', 'admin-public')));

router.get('/admin/api/logs', (req, res) => {
  const date = typeof req.query.date === 'string' ? req.query.date : new Date().toISOString().slice(0, 10);
  const limit = Math.min(Number(req.query.limit) || 200, 1000);
  const levelFilter = typeof req.query.level === 'string' ? req.query.level : null;

  // Lê mais do que o pedido antes de filtrar por nível, para não
  // devolver menos entradas do que o utilizador pediu só porque as
  // últimas N eram todas de outro nível.
  let entries = logReaderService.readEntriesForDate(date, limit * 5);

  const LEVEL_NUM = { debug: 20, info: 30, warn: 40, error: 50 };
  if (levelFilter && LEVEL_NUM[levelFilter]) {
    entries = entries.filter((e) => e.level >= LEVEL_NUM[levelFilter]);
  }
  entries = entries.slice(-limit);

  res.json({ date, availableDates: logReaderService.listAvailableDates(), entries });
});

router.get(
  '/admin/api/users',
  asyncRoute(async (req, res) => {
    const search = typeof req.query.search === 'string' ? req.query.search.trim() : '';
    const pageToken = typeof req.query.pageToken === 'string' ? req.query.pageToken : undefined;
    const result = await userAdminService.listUsers({ search: search || undefined, pageToken });
    res.json(result);
  }),
);

router.get(
  '/admin/api/users/:uid',
  asyncRoute(async (req, res) => {
    const detail = await userAdminService.getUserDetail(req.params.uid);
    res.json(detail);
  }),
);

module.exports = router;
