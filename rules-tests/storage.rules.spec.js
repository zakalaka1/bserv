'use strict';

/**
 * Tests for `storage.rules`.
 *
 * Only appointment photos live in the bucket, so everything is scoped to
 * `appointment-photos/<uid>/…`.
 */

const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  deleteObject,
  getBytes,
  ref,
  uploadBytes,
} = require('firebase/storage');

const { newStorageTestEnvironment } = require('./support/emulator');

const ADMIN_UID = 'admin-uid';
const ALICE = 'alice-uid';
const BOB = 'bob-uid';

const TEN_MEGABYTES = 10 * 1024 * 1024;
const JPEG = { contentType: 'image/jpeg' };

const alicePhoto = `appointment-photos/${ALICE}/appointment-1/photo.jpg`;

let testEnv;

before(async () => {
  testEnv = await newStorageTestEnvironment();
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

function adminStorage() {
  return testEnv.authenticatedContext(ADMIN_UID, { admin: true }).storage();
}

function userStorage(uid = ALICE) {
  return testEnv.authenticatedContext(uid).storage();
}

function anonStorage() {
  return testEnv.unauthenticatedContext().storage();
}

/** Uploads as `uid` so a test can start from an existing object. */
async function seedPhoto(uid = ALICE, path = alicePhoto) {
  await uploadBytes(ref(userStorage(uid), path), new Uint8Array(16), JPEG);
}

describe('appointment photos', () => {
  it('lets the owner upload an image', async () => {
    await assertSucceeds(
      uploadBytes(ref(userStorage(), alicePhoto), new Uint8Array(16), JPEG),
    );
  });

  it('accepts every image subtype the picker can return', async () => {
    for (const contentType of ['image/png', 'image/webp', 'image/gif']) {
      const extension = contentType.split('/')[1];
      await assertSucceeds(
        uploadBytes(
          ref(userStorage(), `appointment-photos/${ALICE}/appointment-1/${extension}`),
          new Uint8Array(16),
          { contentType },
        ),
      );
    }
  });

  it('refuses uploads that are not images', async () => {
    await assertFails(
      uploadBytes(ref(userStorage(), alicePhoto), new Uint8Array(16), {
        contentType: 'application/pdf',
      }),
    );
  });

  it('refuses uploads without a content type', async () => {
    await assertFails(
      uploadBytes(ref(userStorage(), alicePhoto), new Uint8Array(16)),
    );
  });

  it("refuses uploads into another customer's folder", async () => {
    await assertFails(
      uploadBytes(
        ref(userStorage(BOB), alicePhoto),
        new Uint8Array(16),
        JPEG,
      ),
    );
  });

  it('refuses uploads from anonymous visitors', async () => {
    await assertFails(
      uploadBytes(ref(anonStorage(), alicePhoto), new Uint8Array(16), JPEG),
    );
  });

  it('refuses uploads of 10 MB or more', async () => {
    await assertFails(
      uploadBytes(
        ref(userStorage(), alicePhoto),
        new Uint8Array(TEN_MEGABYTES),
        JPEG,
      ),
    );
  });

  it('accepts an upload just under the 10 MB limit', async () => {
    await assertSucceeds(
      uploadBytes(
        ref(userStorage(), alicePhoto),
        new Uint8Array(TEN_MEGABYTES - 1),
        JPEG,
      ),
    );
  });

  it('lets the owner read their photo back', async () => {
    await seedPhoto();

    await assertSucceeds(getBytes(ref(userStorage(), alicePhoto)));
  });

  it('lets an admin read any photo', async () => {
    await seedPhoto();

    await assertSucceeds(getBytes(ref(adminStorage(), alicePhoto)));
  });

  it("hides one customer's photo from another", async () => {
    await seedPhoto();

    await assertFails(getBytes(ref(userStorage(BOB), alicePhoto)));
  });

  it('hides photos from anonymous visitors', async () => {
    await seedPhoto();

    await assertFails(getBytes(ref(anonStorage(), alicePhoto)));
  });

  it('lets the owner delete their photo', async () => {
    await seedPhoto();

    await assertSucceeds(deleteObject(ref(userStorage(), alicePhoto)));
  });

  it("refuses deleting another customer's photo", async () => {
    await seedPhoto();

    await assertFails(deleteObject(ref(userStorage(BOB), alicePhoto)));
  });

  it('lets an admin delete any photo', async () => {
    await seedPhoto();

    await assertSucceeds(deleteObject(ref(adminStorage(), alicePhoto)));
  });

  it('refuses writes outside the appointment-photos prefix', async () => {
    await assertFails(
      uploadBytes(ref(userStorage(), 'avatars/photo.jpg'), new Uint8Array(16), JPEG),
    );
  });
});
