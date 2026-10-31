'use strict';

/**
 * Tests for `firestore.rules`.
 *
 * The payloads mirror what the app actually writes, so a rule that drifts away
 * from `lib/data/` shows up here as a failing test rather than as a permission
 * error in production.
 */

const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');

const { newFirestoreTestEnvironment } = require('./support/emulator');

const ADMIN_UID = 'admin-uid';
const ALICE = 'alice-uid';
const BOB = 'bob-uid';

// A fixed future day keeps the timestamp literals readable and stable.
const BOOKING_DATE = Timestamp.fromDate(new Date('2030-05-01T00:00:00Z'));
const SLOT = '9:00 AM';
const SLOT_ID = 'slot-20300501-9-00-AM';
const SLOT_PATH = `bookedSlots/${SLOT_ID}`;

let testEnv;

before(async () => {
  testEnv = await newFirestoreTestEnvironment();
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

/** Admin scope: signed in with the `admin: true` custom claim. */
function adminDb() {
  return testEnv.authenticatedContext(ADMIN_UID, { admin: true }).firestore();
}

/** A customer with no custom claims. */
function userDb(uid = ALICE) {
  return testEnv.authenticatedContext(uid).firestore();
}

/** Not signed in at all. */
function anonDb() {
  return testEnv.unauthenticatedContext().firestore();
}

/**
 * Writes documents the way a trusted backend would, bypassing the rules so a
 * test can start from an arbitrary state.
 */
async function seedDocuments(documents) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = writeBatch(db);
    for (const [path, data] of Object.entries(documents)) {
      batch.set(doc(db, path), data);
    }
    await batch.commit();
  });
}

/** A valid `appointments` document as written by the booking form. */
function appointmentData(uid = ALICE, overrides = {}) {
  return {
    appointmentDate: BOOKING_DATE,
    timeSlot: SLOT,
    customerName: 'Ada Lovelace',
    phone: '555-010-9999',
    streetAddress: '1 Analytical Way',
    city: 'Toronto',
    postalCode: 'M5V 2T6',
    issueDescription: 'Furnace will not start.',
    serviceType: 'maintain heat',
    userId: uid,
    createdAt: serverTimestamp(),
    status: 'scheduled',
    ...overrides,
  };
}

/** A blocked-off placeholder as written by the admin availability editor. */
function blockedOffData(uid = ADMIN_UID, overrides = {}) {
  return {
    appointmentDate: BOOKING_DATE,
    timeSlot: SLOT,
    status: 'blockedoff',
    createdBy: uid,
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

/**
 * Books a slot the way `createAppointment` does: the appointment and its
 * `bookedSlots` guard are written in one atomic batch.
 */
function bookSlot(db, uid, options = {}) {
  const {
    appointmentId = 'appointment-1',
    slotId = SLOT_ID,
    appointment = {},
    slot = {},
  } = options;

  const batch = writeBatch(db);
  batch.set(
    doc(db, `appointments/${appointmentId}`),
    appointmentData(uid, appointment),
  );
  batch.set(doc(db, `bookedSlots/${slotId}`), {
    appointmentDate: BOOKING_DATE,
    timeSlot: SLOT,
    appointmentId,
    ...slot,
  });
  return batch.commit();
}

/** Blocks a slot the way `updateBlockedOffTimes` does, in one batch. */
function blockSlot(db, uid, options = {}) {
  const {
    slotId = SLOT_ID,
    appointment = {},
    slot = {},
  } = options;

  const batch = writeBatch(db);
  batch.set(
    doc(db, `appointments/${slotId}`),
    blockedOffData(uid, appointment),
  );
  batch.set(doc(db, `bookedSlots/${slotId}`), {
    appointmentDate: BOOKING_DATE,
    timeSlot: SLOT,
    appointmentId: slotId,
    ...slot,
  });
  return batch.commit();
}


describe('publicContent', () => {
  const path = 'publicContent/notesAndPricing';

  function contentData(overrides = {}) {
    return {
      notes: 'Open Monday to Friday, 8am-5pm.',
      pricing: 'Diagnostic visit: $99',
      updatedAt: serverTimestamp(),
      updatedBy: ADMIN_UID,
      ...overrides,
    };
  }

  it('lets anyone read the notes and pricing document', async () => {
    await seedDocuments({ [path]: contentData() });

    await assertSucceeds(getDoc(doc(anonDb(), path)));
  });

  it('refuses to list the collection', async () => {
    await seedDocuments({ [path]: contentData() });

    await assertFails(getDocs(collection(userDb(), 'publicContent')));
    await assertFails(getDocs(collection(adminDb(), 'publicContent')));
  });

  it('lets an admin create the document', async () => {
    await assertSucceeds(setDoc(doc(adminDb(), path), contentData()));
  });

  it('lets an admin overwrite the document', async () => {
    await seedDocuments({ [path]: contentData() });

    await assertSucceeds(
      setDoc(doc(adminDb(), path), contentData({ notes: 'Summer hours.' })),
    );
  });

  it('refuses writes from customers and anonymous users', async () => {
    await assertFails(setDoc(doc(userDb(), path), contentData()));
    await assertFails(setDoc(doc(anonDb(), path), contentData()));
  });

  it('refuses writes that do not name the editor as the writer', async () => {
    await assertFails(
      setDoc(doc(adminDb(), path), contentData({ updatedBy: ALICE })),
    );
  });

  it('refuses writes with a missing or unexpected field', async () => {
    const { pricing: _omitted, ...missingPricing } = contentData();
    await assertFails(setDoc(doc(adminDb(), path), missingPricing));

    await assertFails(
      setDoc(doc(adminDb(), path), contentData({ internalCost: '$40' })),
    );
  });

  it('refuses content longer than 2000 characters', async () => {
    await assertFails(
      setDoc(doc(adminDb(), path), contentData({ notes: 'n'.repeat(2001) })),
    );
    await assertFails(
      setDoc(doc(adminDb(), path), contentData({ pricing: 'p'.repeat(2001) })),
    );
  });

  it('accepts content of exactly 2000 characters', async () => {
    await assertSucceeds(
      setDoc(doc(adminDb(), path), contentData({ notes: 'n'.repeat(2000) })),
    );
  });

  it('requires updatedAt to be the server timestamp', async () => {
    await assertFails(
      setDoc(
        doc(adminDb(), path),
        contentData({ updatedAt: Timestamp.fromDate(new Date('2020-01-01')) }),
      ),
    );
  });

  it('refuses writes to any other document in the collection', async () => {
    await assertFails(
      setDoc(doc(adminDb(), 'publicContent/other'), contentData()),
    );
  });

  it('refuses deletes, even for an admin', async () => {
    await seedDocuments({ [path]: contentData() });

    await assertFails(deleteDoc(doc(adminDb(), path)));
  });
});

describe('workNotes', () => {
  const path = 'workNotes/main';

  function notesData(overrides = {}) {
    return {
      notes: 'Replace the blower motor on Tuesday.',
      updatedAt: serverTimestamp(),
      updatedBy: ADMIN_UID,
      ...overrides,
    };
  }

  it('lets an admin read and list the notes', async () => {
    await seedDocuments({ [path]: notesData() });

    await assertSucceeds(getDoc(doc(adminDb(), path)));
    await assertSucceeds(getDocs(collection(adminDb(), 'workNotes')));
  });

  it('hides the notes from customers and anonymous users', async () => {
    await seedDocuments({ [path]: notesData() });

    await assertFails(getDoc(doc(userDb(), path)));
    await assertFails(getDocs(collection(userDb(), 'workNotes')));
    await assertFails(getDoc(doc(anonDb(), path)));
    await assertFails(getDocs(collection(anonDb(), 'workNotes')));
  });

  it('lets an admin save the notes', async () => {
    await assertSucceeds(setDoc(doc(adminDb(), path), notesData()));
  });

  it('refuses writes from customers', async () => {
    await assertFails(setDoc(doc(userDb(), path), notesData()));
  });

  it('refuses notes longer than 32000 characters', async () => {
    await assertFails(
      setDoc(doc(adminDb(), path), notesData({ notes: 'n'.repeat(32001) })),
    );
  });

  it('accepts notes of exactly 32000 characters', async () => {
    await assertSucceeds(
      setDoc(doc(adminDb(), path), notesData({ notes: 'n'.repeat(32000) })),
    );
  });

  it('refuses writes to any other document in the collection', async () => {
    await assertFails(
      setDoc(doc(adminDb(), 'workNotes/other'), notesData()),
    );
  });

  it('refuses deletes, even for an admin', async () => {
    await seedDocuments({ [path]: notesData() });

    await assertFails(deleteDoc(doc(adminDb(), path)));
  });
});

describe('appointments', () => {
  describe('booking', () => {
    it('lets a customer book a free slot', async () => {
      await assertSucceeds(bookSlot(userDb(), ALICE));
    });

    it('keeps the optional fields when they are provided', async () => {
      await assertSucceeds(
        bookSlot(userDb(), ALICE, {
          appointment: {
            userEmail: 'ada@example.com',
            photoPath: `appointment-photos/${ALICE}/appointment-1/photo.jpg`,
          },
        }),
      );
    });

    it('refuses a booking made in the name of another customer', async () => {
      await assertFails(bookSlot(userDb(), ALICE, { appointment: { userId: BOB } }));
    });

    it('refuses a booking that skips the scheduled status', async () => {
      await assertFails(
        bookSlot(userDb(), ALICE, { appointment: { status: 'completed' } }),
      );
      await assertFails(
        bookSlot(userDb(), ALICE, { appointment: { status: 'blockedoff' } }),
      );
    });

    it('refuses a booking with a missing required field', async () => {
      // Built by hand because `bookSlot` always starts from a complete draft.
      const db = userDb();
      const { serviceType: _omitted, ...withoutServiceType } = appointmentData(ALICE);
      const batch = writeBatch(db);
      batch.set(doc(db, 'appointments/missing-field'), withoutServiceType);
      batch.set(doc(db, `bookedSlots/${SLOT_ID}`), {
        appointmentDate: BOOKING_DATE,
        timeSlot: SLOT,
        appointmentId: 'missing-field',
      });

      await assertFails(batch.commit());
    });

    it('refuses a booking with an unexpected field', async () => {
      await assertFails(
        bookSlot(userDb(), ALICE, { appointment: { adminNote: 'vip' } }),
      );
    });

    it('refuses a booking with a value of the wrong type', async () => {
      await assertFails(
        bookSlot(userDb(), ALICE, {
          appointment: { appointmentDate: '2030-05-01' },
        }),
      );
      await assertFails(
        bookSlot(userDb(), ALICE, { appointment: { customerName: 42 } }),
      );
    });

    it('refuses a booking whose createdAt is not the server timestamp', async () => {
      await assertFails(
        bookSlot(userDb(), ALICE, {
          appointment: { createdAt: Timestamp.fromDate(new Date('2020-01-01')) },
        }),
      );
    });

    it('refuses a service type longer than 40 characters', async () => {
      await assertFails(
        bookSlot(userDb(), ALICE, { appointment: { serviceType: 's'.repeat(41) } }),
      );
    });

    it('refuses a booked slot that points at another customer appointment', async () => {
      await assertSucceeds(
        bookSlot(userDb(BOB), BOB, { appointmentId: 'bob-appointment' }),
      );

      await assertFails(
        bookSlot(userDb(), ALICE, {
          appointmentId: 'alice-appointment',
          slotId: 'slot-20300502-1-00-PM',
          slot: { appointmentId: 'bob-appointment' },
        }),
      );
    });

    it('refuses a booked slot that disagrees with its appointment', async () => {
      await assertFails(
        bookSlot(userDb(), ALICE, { slot: { timeSlot: '1:00 PM' } }),
      );
      await assertFails(
        bookSlot(userDb(), ALICE, {
          slot: {
            appointmentDate: Timestamp.fromDate(
              new Date('2030-05-02T00:00:00Z'),
            ),
          },
        }),
      );
    });

    it('refuses a booked slot with an unexpected field', async () => {
      await assertFails(
        bookSlot(userDb(), ALICE, { slot: { userId: ALICE } }),
      );
    });

    it('refuses a second booking for a slot that is already taken', async () => {
      await assertSucceeds(bookSlot(userDb(), ALICE, { appointmentId: 'a1' }));

      await assertFails(
        bookSlot(userDb(BOB), BOB, { appointmentId: 'a2', slotId: SLOT_ID }),
      );
    });

    it('refuses a booking from an anonymous visitor', async () => {
      await assertFails(bookSlot(anonDb(), ALICE));
    });
  });

  describe('reads', () => {
    beforeEach(async () => {
      await seedDocuments({
        'appointments/alice-appointment': appointmentData(ALICE),
      });
    });

    it('lets a customer read their own appointment', async () => {
      await assertSucceeds(
        getDoc(doc(userDb(), 'appointments/alice-appointment')),
      );
    });

    it('lets a customer list their own appointments', async () => {
      await assertSucceeds(
        getDocs(
          query(
            collection(userDb(), 'appointments'),
            where('userId', '==', ALICE),
          ),
        ),
      );
    });

    it("hides one customer's appointment from another", async () => {
      await assertFails(getDoc(doc(userDb(BOB), 'appointments/alice-appointment')));
      await assertFails(
        getDocs(
          query(collection(userDb(BOB), 'appointments'), where('userId', '==', ALICE)),
        ),
      );
    });

    it('hides appointments from anonymous visitors', async () => {
      await assertFails(getDoc(doc(anonDb(), 'appointments/alice-appointment')));
    });

    it('lets an admin read and list every appointment', async () => {
      await assertSucceeds(
        getDoc(doc(adminDb(), 'appointments/alice-appointment')),
      );
      await assertSucceeds(getDocs(collection(adminDb(), 'appointments')));
    });
  });

  describe('updates by the customer', () => {
    beforeEach(async () => {
      await seedDocuments({
        'appointments/alice-appointment': appointmentData(ALICE),
      });
    });

    it('lets a customer cancel their own scheduled appointment', async () => {
      await assertSucceeds(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          status: 'cancelled',
        }),
      );
    });

    it('refuses a status the customer may not set', async () => {
      await assertFails(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          status: 'completed',
        }),
      );
      await assertFails(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          status: 'blockedoff',
        }),
      );
    });

    it('refuses edits to an appointment that is no longer scheduled', async () => {
      await seedDocuments({
        'appointments/cancelled-appointment': appointmentData(ALICE, {
          status: 'cancelled',
        }),
      });

      await assertFails(
        updateDoc(doc(userDb(), 'appointments/cancelled-appointment'), {
          status: 'cancelled',
          customerName: 'Ada L.',
        }),
      );
    });

    it('lets a customer edit the name and the issue description', async () => {
      await assertSucceeds(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          customerName: 'Ada L.',
          issueDescription: 'Furnace rattles when it starts.',
        }),
      );
    });

    it('refuses a name longer than 80 characters', async () => {
      await assertFails(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          customerName: 'c'.repeat(81),
        }),
      );
    });

    it('refuses an issue description longer than 2000 characters', async () => {
      await assertFails(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          issueDescription: 'i'.repeat(2001),
        }),
      );
    });

    it('refuses edits to the booked slot or the owner', async () => {
      await assertFails(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          appointmentDate: Timestamp.fromDate(new Date('2030-06-01T00:00:00Z')),
        }),
      );
      await assertFails(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          userId: BOB,
        }),
      );
    });

    it('lets a customer attach a photo once', async () => {
      await assertSucceeds(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          photoPath: `appointment-photos/${ALICE}/alice-appointment/photo.jpg`,
        }),
      );
    });

    it('refuses replacing an existing photo', async () => {
      await seedDocuments({
        'appointments/photographed': appointmentData(ALICE, {
          photoPath: `appointment-photos/${ALICE}/photographed/first.jpg`,
        }),
      });

      await assertFails(
        updateDoc(doc(userDb(), 'appointments/photographed'), {
          photoPath: `appointment-photos/${ALICE}/photographed/second.jpg`,
        }),
      );
    });

    it("refuses edits to another customer's appointment", async () => {
      await assertFails(
        updateDoc(doc(userDb(BOB), 'appointments/alice-appointment'), {
          status: 'cancelled',
        }),
      );
    });

    it('refuses writing the admin note', async () => {
      await assertFails(
        updateDoc(doc(userDb(), 'appointments/alice-appointment'), {
          adminNote: 'called ahead',
        }),
      );
    });
  });

  describe('updates by the admin', () => {
    beforeEach(async () => {
      await seedDocuments({
        'appointments/alice-appointment': appointmentData(ALICE),
      });
    });

    it('lets an admin complete the appointment', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDb(), 'appointments/alice-appointment'), {
          status: 'completed',
        }),
      );
    });

    it('refuses an unknown status value', async () => {
      await assertFails(
        updateDoc(doc(adminDb(), 'appointments/alice-appointment'), {
          status: 'pending',
        }),
      );
    });

    it('lets an admin attach and clear a note', async () => {
      await assertSucceeds(
        updateDoc(doc(adminDb(), 'appointments/alice-appointment'), {
          adminNote: 'Customer has a dog.',
        }),
      );
      await assertSucceeds(
        updateDoc(doc(adminDb(), 'appointments/alice-appointment'), {
          adminNote: '',
        }),
      );
    });

    it('refuses an oversized admin note', async () => {
      await assertFails(
        updateDoc(doc(adminDb(), 'appointments/alice-appointment'), {
          adminNote: 'n'.repeat(2001),
        }),
      );
    });

    it('refuses admin edits to customer-supplied fields', async () => {
      await assertFails(
        updateDoc(doc(adminDb(), 'appointments/alice-appointment'), {
          customerName: 'Someone Else',
        }),
      );
    });

    it('lets an admin delete an appointment', async () => {
      await assertSucceeds(
        deleteDoc(doc(adminDb(), 'appointments/alice-appointment')),
      );
    });

    it('refuses deletes from customers', async () => {
      await assertFails(
        deleteDoc(doc(userDb(), 'appointments/alice-appointment')),
      );
    });
  });

  describe('blocked-off availability', () => {
    it('lets an admin block a free slot', async () => {
      await assertSucceeds(blockSlot(adminDb(), ADMIN_UID));
    });

    it('refuses a blocked slot with an unexpected field', async () => {
      await assertFails(
        blockSlot(adminDb(), ADMIN_UID, { appointment: { customerName: 'x' } }),
      );
    });

    it('refuses a blocked slot that is missing createdAt', async () => {
      // Built by hand because `blockSlot` always starts from a complete draft.
      const db = adminDb();
      const { createdAt: _omitted, ...withoutCreatedAt } = blockedOffData(
        ADMIN_UID,
      );
      const batch = writeBatch(db);
      batch.set(doc(db, `appointments/${SLOT_ID}`), withoutCreatedAt);
      batch.set(doc(db, SLOT_PATH), {
        appointmentDate: BOOKING_DATE,
        timeSlot: SLOT,
        appointmentId: SLOT_ID,
      });

      await assertFails(batch.commit());
    });

    it('refuses blocking from a customer', async () => {
      await assertFails(blockSlot(userDb(), ALICE));
      await assertFails(blockSlot(userDb(BOB), BOB));
    });

    it('lets an admin unblock a slot', async () => {
      await assertSucceeds(blockSlot(adminDb(), ADMIN_UID));

      const db = adminDb();
      const batch = writeBatch(db);
      batch.delete(doc(db, `appointments/${SLOT_ID}`));
      batch.delete(doc(db, SLOT_PATH));
      await assertSucceeds(batch.commit());
    });
  });
});

describe('bookedSlots', () => {
  async function seedBookedSlot({
    slotPath = SLOT_PATH,
    appointmentId = 'alice-appointment',
    uid = ALICE,
  } = {}) {
    await seedDocuments({
      [`appointments/${appointmentId}`]: appointmentData(uid),
      [slotPath]: {
        appointmentDate: BOOKING_DATE,
        timeSlot: SLOT,
        appointmentId,
      },
    });
  }

  it('lets any signed-in customer list the taken slots', async () => {
    await seedBookedSlot();

    await assertSucceeds(getDocs(collection(userDb(ALICE), 'bookedSlots')));
    await assertSucceeds(getDocs(collection(userDb(BOB), 'bookedSlots')));
  });

  it('hides the taken slots from anonymous visitors', async () => {
    await seedBookedSlot();

    await assertFails(getDocs(collection(anonDb(), 'bookedSlots')));
    await assertFails(getDoc(doc(anonDb(), SLOT_PATH)));
  });

  it('refuses a slot written without its appointment', async () => {
    const db = userDb();
    await assertFails(
      setDoc(doc(db, SLOT_PATH), {
        appointmentDate: BOOKING_DATE,
        timeSlot: SLOT,
        appointmentId: 'missing-appointment',
      }),
    );
  });

  it('lets a customer release their own slot', async () => {
    await seedBookedSlot();

    await assertSucceeds(deleteDoc(doc(userDb(), SLOT_PATH)));
  });

  it('refuses releasing a slot that belongs to another customer', async () => {
    await seedBookedSlot();

    await assertFails(deleteDoc(doc(userDb(BOB), SLOT_PATH)));
  });

  it('lets an admin release any slot', async () => {
    await seedBookedSlot();

    await assertSucceeds(deleteDoc(doc(adminDb(), SLOT_PATH)));
  });

  it('refuses edits to a taken slot', async () => {
    await seedBookedSlot();

    await assertFails(
      updateDoc(doc(userDb(), SLOT_PATH), { timeSlot: '1:00 PM' }),
    );
    await assertFails(
      updateDoc(doc(adminDb(), SLOT_PATH), { timeSlot: '1:00 PM' }),
    );
  });
});

describe('userSettings', () => {
  const settingsPath = (uid) => `userSettings/${uid}`;

  /** A settings document as written by `saveUserSettings`. */
  function settingsData(overrides = {}) {
    return { leftHanded: true, themeMode: 'dark', ...overrides };
  }

  it('lets a user read and write their own settings', async () => {
    const db = userDb(ALICE);

    await assertSucceeds(setDoc(doc(db, settingsPath(ALICE)), settingsData()));
    await assertSucceeds(getDoc(doc(db, settingsPath(ALICE))));
  });

  it('accepts every theme mode the app can store', async () => {
    const db = userDb(ALICE);

    for (const themeMode of ['system', 'light', 'dark']) {
      await assertSucceeds(
        setDoc(doc(db, settingsPath(ALICE)), settingsData({ themeMode })),
      );
    }
  });

  it('refuses settings the app never writes', async () => {
    const db = userDb(ALICE);

    await assertFails(
      setDoc(doc(db, settingsPath(ALICE)), settingsData({ leftHanded: 'yes' })),
    );
    await assertFails(
      setDoc(doc(db, settingsPath(ALICE)), settingsData({ themeMode: 'sepia' })),
    );
    await assertFails(
      setDoc(doc(db, settingsPath(ALICE)), settingsData({ extra: true })),
    );
    await assertFails(
      setDoc(doc(db, settingsPath(ALICE)), { leftHanded: true }),
    );
  });

  it("refuses another user's settings", async () => {
    await seedDocuments({ [settingsPath(ALICE)]: settingsData() });

    await assertFails(getDoc(doc(userDb(BOB), settingsPath(ALICE))));
    await assertFails(
      setDoc(doc(userDb(BOB), settingsPath(ALICE)), settingsData()),
    );
  });

  it('hides settings from anonymous visitors', async () => {
    await seedDocuments({ [settingsPath(ALICE)]: settingsData() });
    const db = anonDb();

    await assertFails(getDoc(doc(db, settingsPath(ALICE))));
    await assertFails(getDocs(collection(db, 'userSettings')));
    await assertFails(setDoc(doc(db, settingsPath(ALICE)), settingsData()));
  });

  it('refuses deleting a settings document', async () => {
    await seedDocuments({ [settingsPath(ALICE)]: settingsData() });

    await assertFails(deleteDoc(doc(userDb(ALICE), settingsPath(ALICE))));
    await assertFails(deleteDoc(doc(adminDb(), settingsPath(ALICE))));
  });
});

describe('the admin claim', () => {
  it('only accepts the boolean true value', async () => {
    const falseClaim = testEnv
      .authenticatedContext('false-admin', { admin: false })
      .firestore();
    const stringClaim = testEnv
      .authenticatedContext('string-admin', { admin: 'true' })
      .firestore();

    for (const db of [falseClaim, stringClaim]) {
      await assertFails(
        setDoc(doc(db, 'workNotes/main'), {
          notes: 'not allowed',
          updatedAt: serverTimestamp(),
          updatedBy: 'someone',
        }),
      );
    }
  });

  it('cannot be granted by writing a field into Firestore', async () => {
    // The rules read `request.auth.token.admin` only, so a document field with
    // the same name buys nothing; it is not even an allowed booking field.
    await assertFails(
      setDoc(
        doc(userDb(), 'appointments/a1'),
        appointmentData(ALICE, { admin: true }),
      ),
    );
  });
});
