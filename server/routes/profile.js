// routes/profile.js
const express = require('express');
const { asyncRoute } = require('../lib/httpError');
const { attachAuth, requireAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validate');
const profileService = require('../services/profileService');
const { updateProfileSchema, getDeviceMembersProfilesSchema } = require('../validation/profileSchemas');

const router = express.Router();
router.use(attachAuth);

router.post(
  '/updateProfile',
  requireAuth,
  validate(updateProfileSchema),
  asyncRoute(async (req, res) => {
    res.json(await profileService.updateProfile(req.auth.uid, req.body));
  }),
);

router.post(
  '/getDeviceMembersProfiles',
  requireAuth,
  validate(getDeviceMembersProfilesSchema),
  asyncRoute(async (req, res) => {
    res.json(await profileService.getDeviceMembersProfiles(req.auth.uid, req.body));
  }),
);

module.exports = router;
