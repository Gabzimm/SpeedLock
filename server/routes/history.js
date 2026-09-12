// routes/history.js
const express = require('express');
const { asyncRoute } = require('../lib/httpError');
const { attachAuth, requireAuth } = require('../middleware/auth');
const historyService = require('../services/historyService');

const router = express.Router();
router.use(attachAuth);

router.post(
  '/listMyHistory',
  requireAuth,
  asyncRoute(async (req, res) => {
    res.json(await historyService.listMyHistory(req.auth.uid));
  }),
);

module.exports = router;
