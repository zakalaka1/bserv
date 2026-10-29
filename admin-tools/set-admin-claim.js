#!/usr/bin/env node
'use strict';

/**
 * Grants or clears the `admin` custom claim that both security-rules files
 * check (`request.auth.token.admin == true`).
 *
 * Talks to the deployed project through a service account key. When
 * `FIREBASE_AUTH_EMULATOR_HOST` is set (which `firebase emulators:exec` does),
 * it talks to the local Auth emulator instead, and needs no credentials. That
 * is also how the app runs by default, so the admin screens can be exercised
 * locally.
 *
 * Nothing is written unless `--apply` is passed.
 */

const fs = require('node:fs');

const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

/** The only real project this script will touch. */
const PROJECT_ID = 'bserv-512916';

/** Throwaway project the Emulator Suite uses; see `.firebaserc`. */
const EMULATOR_PROJECT_ID = 'demo-bserv';

const USAGE = `Usage: node set-admin-claim.js (--uid <uid> | --email <email>) [options]

Grants the 'admin' custom claim to one user, or clears it with --revoke.
Prints the current and the resulting claims, and writes only with --apply.

Options:
  --uid <uid>          target the user with this UID
  --email <email>      target the user with this email instead
  --revoke             clear every custom claim instead of granting admin
  --apply              actually write the change; without it this is a dry run
  --credential <path>  service account key (default: $GOOGLE_APPLICATION_CREDENTIALS)
  --project <id>       override the project id (must still resolve to ${PROJECT_ID})
  -h, --help           show this message

Environment:
  FIREBASE_AUTH_EMULATOR_HOST    set by 'firebase emulators:exec'; switches the
                                 script to the local Auth emulator
  GOOGLE_APPLICATION_CREDENTIALS path to the service account key
`;

function fail(message) {
  console.error(`\nerror: ${message}\n`);
  process.exit(1);
}

/** `{}` prints as `(none)` so an empty result is never mistaken for silence. */
function describe(claims) {
  return Object.keys(claims).length === 0 ? '(none)' : JSON.stringify(claims);
}

function parseArgs(argv) {
  const options = {
    uid: null,
    email: null,
    credential: null,
    project: null,
    apply: false,
    revoke: false,
    help: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--apply') {
      options.apply = true;
    } else if (arg === '--revoke') {
      options.revoke = true;
    } else if (['--uid', '--email', '--credential', '--project'].includes(arg)) {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) {
        fail(`${arg} needs a value`);
      }
      options[arg.slice(2)] = value;
      i += 1;
    } else {
      fail(`unknown argument: ${arg}`);
    }
  }

  return options;
}

/**
 * The project id is read from the credential itself so the safety check below
 * compares what the key actually points at, not what we hope it points at.
 */
function projectIdFromCredential(path) {
  if (!fs.existsSync(path)) {
    fail(`nothing at the credential path ${path}`);
  }
  try {
    return JSON.parse(fs.readFileSync(path, 'utf8')).project_id;
  } catch {
    fail(`could not read ${path} as a service account key`);
  }
}

function resolveProjectId(options, emulatorHost) {
  if (options.project) return options.project;
  if (emulatorHost) return process.env.GCLOUD_PROJECT || EMULATOR_PROJECT_ID;

  const credentialPath =
    options.credential || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!credentialPath) return process.env.GCLOUD_PROJECT;

  return projectIdFromCredential(credentialPath) || process.env.GCLOUD_PROJECT;
}

async function resolveUser(auth, options) {
  try {
    return options.uid
      ? await auth.getUser(options.uid)
      : await auth.getUserByEmail(options.email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      fail(
        options.uid
          ? `no user has the uid ${options.uid}`
          : `no user has the email ${options.email}`,
      );
    }
    throw error;
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    console.log(USAGE);
    return;
  }

  if (options.uid && options.email) {
    fail('pass --uid or --email, not both');
  }
  if (!options.uid && !options.email) {
    fail('pass --uid or --email to choose the user');
  }

  const emulatorHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const projectId = resolveProjectId(options, Boolean(emulatorHost));

  if (!emulatorHost) {
    if (!options.credential && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      fail(
        'no service account key: set GOOGLE_APPLICATION_CREDENTIALS, pass --credential <path>,\n' +
          '       or start the Auth emulator to run this against the local project',
      );
    }
    if (projectId !== PROJECT_ID) {
      fail(
        `refusing to run against ${projectId || 'an unknown project'}, this script is pinned to ${PROJECT_ID}`,
      );
    }
  }

  const app = initializeApp(
    emulatorHost
      ? { projectId }
      : { projectId, credential: applicationDefault() },
  );
  const auth = getAuth(app);

  const user = await resolveUser(auth, options);
  const before = user.customClaims || {};
  const after = options.revoke ? {} : { ...before, admin: true };

  console.log(`\n  project : ${projectId}`);
  if (emulatorHost) console.log(`  backend : Auth emulator at ${emulatorHost}`);
  console.log(`  user    : ${user.uid}${user.email ? ` <${user.email}>` : ''}`);
  console.log(`  before  : ${describe(before)}`);
  console.log(`  after   : ${describe(after)}`);

  if (!options.apply) {
    console.log(
      '\n  dry run : nothing was written. Re-run with --apply to make this change.\n',
    );
    return;
  }

  await auth.setCustomUserClaims(user.uid, after);

  const updated = await auth.getUser(user.uid);
  console.log(
    `\n  written : ${options.revoke ? 'admin claim cleared' : 'admin claim granted'}`,
  );
  console.log(`  claims  : ${describe(updated.customClaims || {})}`);
  console.log(
    '\n  The claim travels inside the ID token, so sign in again (or refresh the\n' +
      '  token) before the app sees it. See admin-tools/README.md.\n',
  );
}

main().catch((error) => {
  console.error(`\nerror: ${error.message}\n`);
  process.exit(1);
});
