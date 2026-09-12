// routes/devices.js
const express = require('express');
const { asyncRoute } = require('../lib/httpError');
const { attachAuth, requireAuth, isGuest } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const deviceService = require('../services/deviceService');
const {
  registerDeviceSchema,
  setStolenStatusSchema,
  requestDeviceAccessSchema,
  respondToAccessRequestSchema,
} = require('../validation/deviceSchemas');

const router = express.Router();
router.use(attachAuth);

router.post(
  '/registerDevice',
  requireAuth,
  validate(registerDeviceSchema),
  asyncRoute(async (req, res) => {
    res.json(await deviceService.registerDevice(req.auth.uid, isGuest(req), req.body));
  }),
);

router.post(
  '/listMyDevices',
  requireAuth,
  asyncRoute(async (req, res) => {
    res.json(await deviceService.listMyDevices(req.auth.uid));
  }),
);

router.post(
  '/setStolenStatus',
  requireAuth,
  validate(setStolenStatusSchema),
  asyncRoute(async (req, res) => {
    res.json(await deviceService.setStolenStatus(req.auth.uid, req.body));
  }),
);

router.post(
  '/requestDeviceAccess',
  requireAuth,
  validate(requestDeviceAccessSchema),
  asyncRoute(async (req, res) => {
    res.json(await deviceService.requestDeviceAccess(req.auth.uid, isGuest(req), req.body));
  }),
);

router.post(
  '/listIncomingAccessRequests',
  requireAuth,
  asyncRoute(async (req, res) => {
    res.json(await deviceService.listIncomingAccessRequests(req.auth.uid));
  }),
);

router.post(
  '/listMyAccessRequests',
  requireAuth,
  asyncRoute(async (req, res) => {
    res.json(await deviceService.listMyAccessRequests(req.auth.uid));
  }),
);

router.post(
  '/respondToAccessRequest',
  requireAuth,
  validate(respondToAccessRequestSchema),
  asyncRoute(async (req, res) => {
    res.json(await deviceService.respondToAccessRequest(req.auth.uid, req.body));
  }),
);

module.exports = router;
