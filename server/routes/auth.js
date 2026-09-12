// routes/auth.js
const express = require('express');
const { asyncRoute } = require('../lib/httpError');
const { attachAuth, requireAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const { loginLimiter, registerLimiter, passwordResetLimiter } = require('../middleware/rateLimiters');
const authService = require('../services/authService');
const {
  registerUserSchema,
  checkLoginLocationSchema,
  confirmLoginVerificationSchema,
  requestPasswordResetSchema,
  confirmPasswordResetSchema,
  finalizeGuestRegistrationSchema,
} = require('../validation/authSchemas');

const router = express.Router();
router.use(attachAuth);

router.post(
  '/registerUser',
  registerLimiter,
  validate(registerUserSchema),
  asyncRoute(async (req, res) => {
    res.json(await authService.registerUser(req, req.body));
  }),
);

router.post(
  '/checkLoginLocation',
  requireAuth,
  loginLimiter,
  validate(checkLoginLocationSchema),
  asyncRoute(async (req, res) => {
    res.json(await authService.checkLoginLocation(req, req.auth.uid, req.body));
  }),
);

router.post(
  '/confirmLoginVerification',
  requireAuth,
  validate(confirmLoginVerificationSchema),
  asyncRoute(async (req, res) => {
    res.json(await authService.confirmLoginVerification(req.auth.uid, req.body));
  }),
);

// Sem rate limit próprio antes — qualquer um conseguia mandar emails de
// recuperação sem limite nenhum. Agora partilha o mesmo limitador por IP
// que os outros fluxos sensíveis de autenticação.
router.post(
  '/requestPasswordReset',
  passwordResetLimiter,
  validate(requestPasswordResetSchema),
  asyncRoute(async (req, res) => {
    res.json(await authService.requestPasswordReset(req.body));
  }),
);

router.post(
  '/confirmPasswordReset',
  validate(confirmPasswordResetSchema),
  asyncRoute(async (req, res) => {
    res.json(await authService.confirmPasswordReset(req.body));
  }),
);

router.post(
  '/finalizeGuestRegistration',
  requireAuth,
  validate(finalizeGuestRegistrationSchema),
  asyncRoute(async (req, res) => {
    res.json(await authService.finalizeGuestRegistration(req, req.auth.uid, req.body));
  }),
);

module.exports = router;
