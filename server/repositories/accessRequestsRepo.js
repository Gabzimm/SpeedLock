// repositories/accessRequestsRepo.js
const db = require('./db');
const { COLLECTIONS } = require('../config/constants');

const col = () => db.collection(COLLECTIONS.ACCESS_REQUESTS);

function create(data) {
  return col().add(data);
}

function get(requestId) {
  return col().doc(requestId).get();
}

function update(requestId, fields) {
  return col().doc(requestId).update(fields);
}

function findPendingByRequester(deviceId, requesterUid) {
  return col()
    .where('deviceId', '==', deviceId)
    .where('requesterUid', '==', requesterUid)
    .where('status', '==', 'pending')
    .limit(1)
    .get();
}

function findPendingForOwner(ownerUid) {
  return col().where('ownerUid', '==', ownerUid).where('status', '==', 'pending').get();
}

function findAllByRequester(requesterUid) {
  return col().where('requesterUid', '==', requesterUid).get();
}

module.exports = { create, get, update, findPendingByRequester, findPendingForOwner, findAllByRequester };
