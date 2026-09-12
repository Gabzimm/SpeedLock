// routes/commands.js
const express = require('express');
const { asyncRoute } = require('../lib/httpError');
const { attachAuth, requireAuth, isGuest } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { commandLimiter } = require('../middleware/rateLimiters');
const commandService = require('../services/commandService');
const { requestDeviceCommandSchema, issueOfflineSpeedLimitTokenSchema } = require('../validation/commandSchemas');

const router = express.Router();
router.use(attachAuth);

router.post(
  '/requestDeviceCommand',
  requireAuth,
  commandLimiter,
  validate(requestDeviceCommandSchema),
  asyncRoute(async (req, res) => {
    res.json(await commandService.requestDeviceCommand(req.auth.uid, isGuest(req), req.body));
  }),
);

router.post(
  '/issueOfflineSpeedLimitToken',
  requireAuth,
  validate(issueOfflineSpeedLimitTokenSchema),
  asyncRoute(async (req, res) => {
    res.json(await commandService.issueOfflineSpeedLimitToken(req.auth.uid, isGuest(req), req.body));
  }),
);

module.exports = router;
