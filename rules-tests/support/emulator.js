'use strict';

/**
 * Shared plumbing for the security-rules tests.
 *
 * The suite always runs inside `firebase emulators:exec`, which exports one
 * `<EMULATOR>_EMULATOR_HOST` variable per started emulator in `host:port`
 * form. Reading those keeps the tests in sync with `firebase.json` instead of
 * duplicating the ports here; when a spec is run directly the ports declared
 * in `firebase.json` are used instead.
 */

const fs = require('node:fs');
const path = require('node:path');

const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const repoRoot = path.resolve(__dirname, '..', '..');

/**
 * The `demo-` prefix tells the emulator suite not to look for real
 * credentials, so these tests can never touch production data.
 */
const projectId = process.env.GCLOUD_PROJECT || 'demo-bserv';

function emulatorEndpoint(environmentVariable, emulatorName) {
  const fromEnvironment = process.env[environmentVariable];
  if (fromEnvironment) {
    const [host, port] = fromEnvironment.split(':');
    return { host, port: Number(port) };
  }

  const firebaseJson = JSON.parse(
    fs.readFileSync(path.join(repoRoot, 'firebase.json'), 'utf8'),
  );
  const port = firebaseJson.emulators?.[emulatorName]?.port;
  if (!port) {
    throw new Error(
      `No ${emulatorName} emulator is configured. Run the suite through ` +
        '`firebase emulators:exec --only firestore,storage`, or add an ' +
        `"emulators.${emulatorName}.port" entry to firebase.json.`,
    );
  }
  return { host: '127.0.0.1', port };
}

function readRules(fileName) {
  return fs.readFileSync(path.join(repoRoot, fileName), 'utf8');
}

/** Test environment for `firestore.rules`; call from a `before` hook. */
function newFirestoreTestEnvironment() {
  return initializeTestEnvironment({
    projectId,
    firestore: {
      ...emulatorEndpoint('FIRESTORE_EMULATOR_HOST', 'firestore'),
      rules: readRules('firestore.rules'),
    },
  });
}

/** Test environment for `storage.rules`; call from a `before` hook. */
function newStorageTestEnvironment() {
  return initializeTestEnvironment({
    projectId,
    storage: {
      ...emulatorEndpoint('FIREBASE_STORAGE_EMULATOR_HOST', 'storage'),
      rules: readRules('storage.rules'),
    },
  });
}

module.exports = {
  newFirestoreTestEnvironment,
  newStorageTestEnvironment,
  projectId,
  repoRoot,
};
