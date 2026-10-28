// Firestore Security Rules tests for Circlo (Increment 1: accounts + circles).
// Run with: npm test   (starts the Firestore emulator via firebase-tools; needs Java)
import { readFileSync } from 'node:fs';
import { before, after, beforeEach, describe, it } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, writeBatch, collection, collectionGroup,
  query, where, serverTimestamp, Timestamp,
} from 'firebase/firestore';

const CODE_A = 'ABCDEFGHJK'; // valid format (10 chars, unambiguous alphabet)
const CODE_B = 'MNPQRSTUVW';
const CODE_NEW = 'XYZ2345678';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-circlo',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const db = (uid) => env.authenticatedContext(uid, { email_verified: true }).firestore();
const dbUnverified = (uid) => env.authenticatedContext(uid, { email_verified: false }).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const year = new Date().getFullYear();

/** Seed circle c1 owned by alice with code CODE_A; bob optional member. */
async function seed({ bob = false, codeExtra = {} } = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const now = Timestamp.now();
    await setDoc(doc(f, 'circles/c1'), { name: 'Family', ownerUid: 'alice', requiresApproval: false, joinCode: CODE_A, createdAt: now });
    await setDoc(doc(f, 'circles/c1/members/alice'), { uid: 'alice', role: 'owner', displayName: 'Alice', joinedAt: now });
    await setDoc(doc(f, `joinCodes/${CODE_A}`), { circleId: 'c1', createdBy: 'alice', revoked: false, createdAt: now, ...codeExtra });
    await setDoc(doc(f, 'circles/c2'), { name: 'Work', ownerUid: 'carol', requiresApproval: false, joinCode: CODE_B, createdAt: now });
    await setDoc(doc(f, 'circles/c2/members/carol'), { uid: 'carol', role: 'owner', displayName: 'Carol', joinedAt: now });
    await setDoc(doc(f, `joinCodes/${CODE_B}`), { circleId: 'c2', createdBy: 'carol', revoked: false, createdAt: now });
    if (bob) {
      await setDoc(doc(f, 'circles/c1/members/bob'), { uid: 'bob', role: 'member', displayName: 'Bob', joinedAt: now, joinCode: CODE_A });
    }
  });
}

const profile = (over = {}) => ({ displayName: 'Alice', birthYear: year - 30, createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over });
const joinDoc = (uid, code = CODE_A, over = {}) => ({ uid, role: 'member', displayName: uid, joinedAt: serverTimestamp(), joinCode: code, ...over });

describe('unauthenticated access', () => {
  it('cannot read or write anything', async () => {
    await seed();
    await assertFails(getDoc(doc(anon(), 'users/alice')));
    await assertFails(getDoc(doc(anon(), 'circles/c1')));
    await assertFails(getDoc(doc(anon(), `joinCodes/${CODE_A}`)));
    await assertFails(setDoc(doc(anon(), 'users/alice'), profile()));
  });
  it('default-denies unknown collections', async () => {
    await assertFails(setDoc(doc(db('alice'), 'whatever/x'), { a: 1 }));
    await assertFails(getDoc(doc(db('alice'), 'whatever/x')));
  });
});

describe('users profile', () => {
  it('creates and reads own profile', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile({ phone: '+923001234567' })));
    await assertSucceeds(getDoc(doc(db('alice'), 'users/alice')));
  });
  it("cannot create or read another user's profile", async () => {
    await assertFails(setDoc(doc(db('mallory'), 'users/alice'), profile()));
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile()));
    await assertFails(getDoc(doc(db('mallory'), 'users/alice')));
  });
  it('rejects users under the minimum age (13) and invalid fields', async () => {
    await assertFails(setDoc(doc(db('kid'), 'users/kid'), profile({ birthYear: year - 10 })));
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), profile({ displayName: '' })));
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), profile({ phone: '12345' })));
    await assertFails(setDoc(doc(db('alice'), 'users/alice'), profile({ extra: true })));
  });
  it('allows a 13-year-old', async () => {
    await assertSucceeds(setDoc(doc(db('teen'), 'users/teen'), profile({ birthYear: year - 14 })));
  });
  it('cannot change birth year or createdAt later', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile()));
    await assertFails(updateDoc(doc(db('alice'), 'users/alice'), { birthYear: year - 20, updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(db('alice'), 'users/alice'), { displayName: 'Al', updatedAt: serverTimestamp() }));
  });
  it("cannot delete someone else's profile", async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile()));
    await assertFails(deleteDoc(doc(db('mallory'), 'users/alice')));
  });
});

describe('create circle', () => {
  const create = (uid, { code = CODE_A, circleOver = {}, memberOver = {}, skipMember = false, skipCode = false, cid = 'c9' } = {}) => {
    const f = db(uid);
    const b = writeBatch(f);
    b.set(doc(f, `circles/${cid}`), { name: 'Family', ownerUid: uid, requiresApproval: false, joinCode: code, createdAt: serverTimestamp(), ...circleOver });
    if (!skipMember) b.set(doc(f, `circles/${cid}/members/${uid}`), { uid, role: 'owner', displayName: 'Alice', joinedAt: serverTimestamp(), ...memberOver });
    if (!skipCode) b.set(doc(f, `joinCodes/${code}`), { circleId: cid, createdBy: uid, revoked: false, createdAt: serverTimestamp() });
    return b.commit();
  };
  it('succeeds with circle + owner membership + code in one batch', async () => {
    await assertSucceeds(create('alice'));
  });
  it('fails when ownerUid is someone else, approval is on, name empty, or code malformed', async () => {
    await assertFails(create('mallory', { circleOver: { ownerUid: 'alice' } }));
    await assertFails(create('alice', { circleOver: { requiresApproval: true } }));
    await assertFails(create('alice', { circleOver: { name: '' } }));
    await assertFails(create('alice', { code: 'abc' }));
  });
  it('fails without the owner membership or without the code document', async () => {
    await assertFails(create('alice', { skipMember: true }));
    await assertFails(create('alice', { skipCode: true }));
  });
  it('cannot reuse (overwrite) an existing code of another circle', async () => {
    await seed();
    await assertFails(create('mallory', { code: CODE_A }));
  });
  it('cannot claim owner membership of an existing circle', async () => {
    await seed();
    await assertFails(setDoc(doc(db('mallory'), 'circles/c1/members/mallory'),
      { uid: 'mallory', role: 'owner', displayName: 'M', joinedAt: serverTimestamp() }));
  });
});

describe('join circle', () => {
  it('joins with a valid code', async () => {
    await seed();
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob')));
    await assertSucceeds(getDoc(doc(db('bob'), 'circles/c1')));
  });
  it('rejects wrong, revoked, expired, or other-circle codes', async () => {
    await seed();
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_NEW))); // does not exist
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_B)));   // other circle's code
    await env.clearFirestore(); await seed({ codeExtra: { revoked: true } });
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob')));
    await env.clearFirestore(); await seed({ codeExtra: { expiresAt: Timestamp.fromMillis(Date.now() - 60_000) } });
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob')));
  });
  it('accepts a code that has not expired yet', async () => {
    await seed({ codeExtra: { expiresAt: Timestamp.fromMillis(Date.now() + 3_600_000) } });
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob')));
  });
  it('cannot join as owner, for someone else, or without a code', async () => {
    await seed();
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_A, { role: 'owner' })));
    await assertFails(setDoc(doc(db('mallory'), 'circles/c1/members/bob'), joinDoc('bob')));
    const noCode = joinDoc('bob'); delete noCode.joinCode;
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), noCode));
  });
  it('can look up a code (get) but never list codes', async () => {
    await seed();
    await assertSucceeds(getDoc(doc(db('bob'), `joinCodes/${CODE_A}`)));
    await assertFails(getDocs(collection(db('bob'), 'joinCodes')));
  });
});

describe('reading circle data is membership-scoped', () => {
  it('non-members cannot read the circle or its members; members can', async () => {
    await seed({ bob: true });
    await assertFails(getDoc(doc(db('mallory'), 'circles/c1')));
    await assertFails(getDocs(collection(db('mallory'), 'circles/c1/members')));
    await assertSucceeds(getDoc(doc(db('bob'), 'circles/c1')));
    await assertSucceeds(getDocs(collection(db('bob'), 'circles/c1/members')));
  });
  it('a member of circle 1 cannot read circle 2', async () => {
    await seed({ bob: true });
    await assertFails(getDoc(doc(db('bob'), 'circles/c2')));
    await assertFails(getDocs(collection(db('bob'), 'circles/c2/members')));
  });
  it('circles cannot be listed', async () => {
    await seed({ bob: true });
    await assertFails(getDocs(collection(db('bob'), 'circles')));
  });
  it('a user can list only their own memberships via the collection group', async () => {
    await seed({ bob: true });
    await assertSucceeds(getDocs(query(collectionGroup(db('bob'), 'members'), where('uid', '==', 'bob'))));
    await assertFails(getDocs(query(collectionGroup(db('bob'), 'members'), where('uid', '==', 'alice'))));
    await assertFails(getDocs(collectionGroup(db('bob'), 'members')));
  });
});

describe('membership changes', () => {
  it('members cannot change their role or edit others', async () => {
    await seed({ bob: true });
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { role: 'owner' }));
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/members/alice'), { displayName: 'X' }));
    await assertSucceeds(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { displayName: 'Bobby' }));
  });
  it('member can leave; owner can remove a member; others cannot', async () => {
    await seed({ bob: true });
    await assertFails(deleteDoc(doc(db('mallory'), 'circles/c1/members/bob')));
    await assertFails(deleteDoc(doc(db('bob'), 'circles/c1/members/alice')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'circles/c1/members/bob')));
    await env.clearFirestore(); await seed({ bob: true });
    await assertSucceeds(deleteDoc(doc(db('bob'), 'circles/c1/members/bob')));
  });
  it('removed or departed members lose access immediately', async () => {
    await seed({ bob: true });
    await assertSucceeds(getDoc(doc(db('bob'), 'circles/c1')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'circles/c1/members/bob')));
    await assertFails(getDoc(doc(db('bob'), 'circles/c1')));
  });
  it('the owner cannot simply leave, and only the owner can delete the circle', async () => {
    await seed();
    await assertFails(deleteDoc(doc(db('alice'), 'circles/c1/members/alice')));
    await assertFails(deleteDoc(doc(db('mallory'), 'circles/c1')));
  });
});

describe('join code management', () => {
  it('only the owner can revoke; revoked codes cannot be un-revoked', async () => {
    await seed({ bob: true });
    await assertFails(updateDoc(doc(db('bob'), `joinCodes/${CODE_A}`), { revoked: true }));
    await assertSucceeds(updateDoc(doc(db('alice'), `joinCodes/${CODE_A}`), { revoked: true }));
    await assertFails(updateDoc(doc(db('alice'), `joinCodes/${CODE_A}`), { revoked: false }));
  });
  it('owner can rotate the code (revoke old, create new, update circle) in one batch', async () => {
    await seed();
    const f = db('alice'); const b = writeBatch(f);
    b.update(doc(f, `joinCodes/${CODE_A}`), { revoked: true });
    b.set(doc(f, `joinCodes/${CODE_NEW}`), { circleId: 'c1', createdBy: 'alice', revoked: false, createdAt: serverTimestamp() });
    b.update(doc(f, 'circles/c1'), { joinCode: CODE_NEW });
    await assertSucceeds(b.commit());
    // old code no longer admits new members
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_A)));
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_NEW)));
  });
  it('a non-owner cannot create a code for a circle or rotate it', async () => {
    await seed({ bob: true });
    const f = db('bob');
    await assertFails(setDoc(doc(f, `joinCodes/${CODE_NEW}`), { circleId: 'c1', createdBy: 'bob', revoked: false, createdAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(f, 'circles/c1'), { joinCode: CODE_NEW }));
  });
  it('owner cannot change ownerUid via a plain update', async () => {
    await seed();
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1'), { ownerUid: 'bob' }));
    await assertSucceeds(updateDoc(doc(db('alice'), 'circles/c1'), { name: 'Family 2' }));
  });
});

describe('live location sharing (circle-scoped)', () => {
  const loc = (uid, over = {}) => ({ uid, lat: 31.5204, lng: 74.3587, accuracy: 12, sharing: true, updatedAt: serverTimestamp(), ...over });
  const locRef = (f, cid, uid) => doc(f, `circles/${cid}/locations/${uid}`);
  const setSharing = (uid, cid, over) => env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), `circles/${cid}/members/${uid}`), over);
  });

  it('cannot publish a location until sharing is switched on for that circle', async () => {
    await seed({ bob: true });
    await assertFails(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
  });
  it('cannot publish while paused', async () => {
    await seed({ bob: true });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: true });
    await assertFails(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
  });
  it('sharing in circle A does not allow publishing into circle B', async () => {
    await seed({ bob: true });
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'circles/c2/members/bob'), { uid: 'bob', role: 'member', displayName: 'Bob', joinedAt: Timestamp.now(), joinCode: CODE_B });
    });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
    await assertFails(setDoc(locRef(db('bob'), 'c2', 'bob'), loc('bob'))); // c2 sharing still off
  });
  it('cannot write for another user, for a non-member circle, or with invalid data', async () => {
    await seed({ bob: true });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertFails(setDoc(locRef(db('mallory'), 'c1', 'bob'), loc('bob')));
    await assertFails(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob', { lat: 123 })));
    await assertFails(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob', { lng: -200 })));
    await assertFails(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob', { accuracy: -1 })));
    await assertFails(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob', { extra: 'x' })));
    await assertFails(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob', { updatedAt: Timestamp.fromMillis(1) })));
    await assertFails(setDoc(locRef(db('mallory'), 'c1', 'mallory'), loc('mallory')));
  });
  it('only members of that circle can read its locations', async () => {
    await seed({ bob: true });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
    await assertSucceeds(getDoc(locRef(db('alice'), 'c1', 'bob')));
    await assertSucceeds(getDocs(query(collection(db('alice'), 'circles/c1/locations'), where('sharing', '==', true))));
    await assertFails(getDoc(locRef(db('carol'), 'c1', 'bob')));              // member of c2 only
    await assertFails(getDocs(collection(db('carol'), 'circles/c1/locations')));
    await assertFails(getDoc(locRef(db('mallory'), 'c1', 'bob')));
  });
  it('does not allow a user to turn sharing off or pause while leaving a location document behind', async () => {
    await seed({ bob: true });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));

    // The member flag cannot be changed to off independently of location deletion.
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { sharesLocation: false }));
    const stop = writeBatch(db('bob'));
    stop.update(doc(db('bob'), 'circles/c1/members/bob'), { sharesLocation: false, paused: false });
    stop.delete(locRef(db('bob'), 'c1', 'bob'));
    await assertSucceeds(stop.commit());
    await assertFails(getDoc(locRef(db('alice'), 'c1', 'bob')));

    // Pausing has the same atomic deletion requirement.
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { paused: true }));
    const pause = writeBatch(db('bob'));
    pause.update(doc(db('bob'), 'circles/c1/members/bob'), { paused: true });
    pause.delete(locRef(db('bob'), 'c1', 'bob'));
    await assertSucceeds(pause.commit());
    await assertFails(getDoc(locRef(db('alice'), 'c1', 'bob')));
  });

  it('legacy location documents without the active-sharing marker are not readable or queried', async () => {
    await seed({ bob: true });
    await env.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      // Simulate a legacy doc whose member has since enabled sharing again.
      await updateDoc(doc(f, 'circles/c1/members/bob'), { sharesLocation: true, paused: false });
      await setDoc(locRef(f, 'c1', 'bob'), {
        uid: 'bob',
        lat: 31.5204,
        lng: 74.3587,
        accuracy: 12,
        updatedAt: Timestamp.now(),
      });
    });
    await assertFails(getDoc(locRef(db('alice'), 'c1', 'bob')));
    const activeOnly = await getDocs(query(
      collection(db('alice'), 'circles/c1/locations'),
      where('sharing', '==', true),
    ));
    if (!activeOnly.empty) throw new Error('legacy location must be excluded from the active query');
  });

  it('stopping sharing (member flag + delete in one batch) removes the location', async () => {
    await seed({ bob: true });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
    const f = db('bob'); const b = writeBatch(f);
    b.update(doc(f, 'circles/c1/members/bob'), { sharesLocation: false, paused: false });
    b.delete(locRef(f, 'c1', 'bob'));
    await assertSucceeds(b.commit());
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(locRef(ctx.firestore(), 'c1', 'bob'));
      if (snap.exists()) throw new Error('location should be gone');
    });
    await assertFails(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
  });
  it('members can toggle only their own sharing flags, and only with booleans', async () => {
    await seed({ bob: true });
    await assertSucceeds(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { sharesLocation: true }));
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { sharesLocation: 'yes' }));
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1/members/bob'), { sharesLocation: true })); // even the owner
    await assertFails(updateDoc(doc(db('mallory'), 'circles/c1/members/bob'), { sharesLocation: true }));
  });
  it('new members cannot be created already sharing', async () => {
    await seed();
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_A, { sharesLocation: true })));
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_A, { sharesLocation: false, paused: false })));
  });
  it('leaving (batch) and owner removal can delete the departing member\'s location', async () => {
    await seed({ bob: true });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
    const f = db('bob'); const b = writeBatch(f);
    b.delete(doc(f, 'circles/c1/members/bob'));
    b.delete(locRef(f, 'c1', 'bob'));
    await assertSucceeds(b.commit());
    // owner cleanup path
    await env.clearFirestore(); await seed({ bob: true });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));
    await assertFails(deleteDoc(locRef(db('mallory'), 'c1', 'bob')));
    await assertSucceeds(deleteDoc(locRef(db('alice'), 'c1', 'bob')));
  });
  it('membership removal requires the member location to be deleted first', async () => {
    await seed({ bob: true });
    await setSharing('bob', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('bob'), 'c1', 'bob'), loc('bob')));

    await assertFails(deleteDoc(doc(db('alice'), 'circles/c1/members/bob')));
    await assertSucceeds(deleteDoc(locRef(db('alice'), 'c1', 'bob')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'circles/c1/members/bob')));
  });

  it('a removed member can no longer read locations', async () => {
    await seed({ bob: true });
    await setSharing('alice', 'c1', { sharesLocation: true, paused: false });
    await assertSucceeds(setDoc(locRef(db('alice'), 'c1', 'alice'), loc('alice')));
    await assertSucceeds(getDoc(locRef(db('bob'), 'c1', 'alice')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'circles/c1/members/bob')));
    await assertFails(getDoc(locRef(db('bob'), 'c1', 'alice')));
  });
});

describe('saved places, subscriptions and events (Increment 3)', () => {
  const placeData = (uid, over = {}) => ({ name: 'School', lat: 31.5, lng: 74.3, radiusM: 150, createdBy: uid, createdAt: serverTimestamp(), ...over });
  const sub = (uid, pid, over = {}) => ({ subscriberUid: uid, placeId: pid, arrive: true, leave: true, allMembers: true, memberUids: [], updatedAt: serverTimestamp(), ...over });
  const evt = (uid, pid, over = {}) => ({ placeId: pid, placeName: 'School', memberUid: uid, memberName: uid === 'bob' ? 'Bob' : 'Alice', type: 'arrive', visitId: '1760000000000', occurredAt: serverTimestamp(), ...over });
  const evtId = (uid, pid, visit = '1760000000000', type = 'arrive') => `${uid}_${pid}_${visit}_${type}`;

  async function seedPlace(cid = 'c1', pid = 'p1', creator = 'alice') {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `circles/${cid}/places/${pid}`), { name: 'School', lat: 31.5, lng: 74.3, radiusM: 150, createdBy: creator, createdAt: Timestamp.now() });
    });
  }
  const shareOn = (uid, over = {}) => env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), `circles/c1/members/${uid}`), { sharesLocation: true, paused: false, ...over });
  });

  it('members can create valid places; non-members and invalid data are rejected', async () => {
    await seed({ bob: true });
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/places/p1'), placeData('bob')));
    await assertFails(setDoc(doc(db('mallory'), 'circles/c1/places/p2'), placeData('mallory')));
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/places/p3'), placeData('alice')));            // createdBy spoof
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/places/p4'), placeData('bob', { radiusM: 50 })));
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/places/p5'), placeData('bob', { radiusM: 5000 })));
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/places/p6'), placeData('bob', { lat: 95 })));
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/places/p7'), placeData('bob', { name: '' })));
  });
  it('places are readable only by members of that circle', async () => {
    await seed({ bob: true }); await seedPlace();
    await assertSucceeds(getDoc(doc(db('bob'), 'circles/c1/places/p1')));
    await assertSucceeds(getDocs(collection(db('bob'), 'circles/c1/places')));
    await assertFails(getDoc(doc(db('carol'), 'circles/c1/places/p1')));
    await assertFails(getDocs(collection(db('mallory'), 'circles/c1/places')));
  });
  it('only the creator or the circle owner can edit/delete a place', async () => {
    await seed({ bob: true }); await seedPlace('c1', 'p1', 'bob');
    await assertSucceeds(updateDoc(doc(db('bob'), 'circles/c1/places/p1'), { name: 'School 2' }));
    await assertSucceeds(updateDoc(doc(db('alice'), 'circles/c1/places/p1'), { radiusM: 200 })); // owner
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/places/p1'), { createdBy: 'alice' }));
    await env.clearFirestore(); await seed({ bob: true }); await seedPlace('c1', 'p1', 'alice');
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/places/p1'), { name: 'X' }));
    await assertFails(deleteDoc(doc(db('bob'), 'circles/c1/places/p1')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'circles/c1/places/p1')));
  });
  it('subscriptions are private to the subscriber and well-formed', async () => {
    await seed({ bob: true }); await seedPlace();
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/placeSubscriptions/bob_p1'), sub('bob', 'p1')));
    await assertFails(getDoc(doc(db('alice'), 'circles/c1/placeSubscriptions/bob_p1')));
    await assertSucceeds(getDoc(doc(db('bob'), 'circles/c1/placeSubscriptions/bob_p1')));
    await assertFails(setDoc(doc(db('alice'), 'circles/c1/placeSubscriptions/bob_p1'), sub('bob', 'p1')));   // for someone else
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/placeSubscriptions/wrongid'), sub('bob', 'p1')));
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/placeSubscriptions/bob_p1'), sub('bob', 'p1', { arrive: 'yes' })));
    await assertFails(setDoc(doc(db('mallory'), 'circles/c1/placeSubscriptions/mallory_p1'), sub('mallory', 'p1')));
  });
  it('a user can list only their own subscriptions via the collection group', async () => {
    await seed({ bob: true }); await seedPlace();
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/placeSubscriptions/bob_p1'), sub('bob', 'p1')));
    await assertSucceeds(getDocs(query(collectionGroup(db('bob'), 'placeSubscriptions'), where('subscriberUid', '==', 'bob'))));
    await assertFails(getDocs(query(collectionGroup(db('bob'), 'placeSubscriptions'), where('subscriberUid', '==', 'alice'))));
  });
  it('a sharing member can publish their own arrival event; it is idempotent', async () => {
    await seed({ bob: true }); await seedPlace(); await shareOn('bob');
    const ref = doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'p1')}`);
    await assertSucceeds(setDoc(ref, evt('bob', 'p1')));
    await assertFails(setDoc(ref, evt('bob', 'p1')));    // retry/duplicate is rejected (no updates)
    await assertSucceeds(setDoc(doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'p1', '1760000000000', 'leave')}`), evt('bob', 'p1', { type: 'leave' })));
  });
  it('events cannot be forged: other member, not sharing, paused, bad id/name/place', async () => {
    await seed({ bob: true }); await seedPlace();
    await assertFails(setDoc(doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'p1')}`), evt('bob', 'p1')));   // not sharing
    await shareOn('bob', { paused: true });
    await assertFails(setDoc(doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'p1')}`), evt('bob', 'p1')));   // paused
    await shareOn('bob');
    await assertFails(setDoc(doc(db('alice'), `circles/c1/placeEvents/${evtId('bob', 'p1')}`), evt('bob', 'p1'))); // as someone else
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/placeEvents/random-id'), evt('bob', 'p1')));
    await assertFails(setDoc(doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'p1')}`), evt('bob', 'p1', { placeName: 'Fake' })));
    await assertFails(setDoc(doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'nope')}`), evt('bob', 'nope')));
    await assertFails(setDoc(doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'p1')}`), evt('bob', 'p1', { memberName: 'Alice' })));
    await assertFails(setDoc(doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'p1', '1760000000000', 'visit')}`), evt('bob', 'p1', { type: 'visit' })));
    await assertFails(setDoc(doc(db('bob'), `circles/c1/placeEvents/${evtId('bob', 'p1')}`), evt('bob', 'p1', { occurredAt: Timestamp.fromMillis(1) })));
  });
  it('events are readable only by circle members and cannot be edited', async () => {
    await seed({ bob: true }); await seedPlace(); await shareOn('bob');
    const id = evtId('bob', 'p1');
    await assertSucceeds(setDoc(doc(db('bob'), `circles/c1/placeEvents/${id}`), evt('bob', 'p1')));
    await assertSucceeds(getDoc(doc(db('alice'), `circles/c1/placeEvents/${id}`)));
    await assertSucceeds(getDocs(collection(db('alice'), 'circles/c1/placeEvents')));
    await assertFails(getDoc(doc(db('carol'), `circles/c1/placeEvents/${id}`)));
    await assertFails(getDocs(collection(db('mallory'), 'circles/c1/placeEvents')));
    await assertFails(updateDoc(doc(db('bob'), `circles/c1/placeEvents/${id}`), { type: 'leave' }));
    await assertFails(deleteDoc(doc(db('alice'), `circles/c1/placeEvents/${id}`)));   // not the actor
    await assertSucceeds(deleteDoc(doc(db('bob'), `circles/c1/placeEvents/${id}`)));
  });
  it('a member can query their own latest events (state restore) but not others\'', async () => {
    await seed({ bob: true }); await seedPlace(); await shareOn('bob');
    await assertSucceeds(getDocs(query(collection(db('bob'), 'circles/c1/placeEvents'), where('memberUid', '==', 'bob'))));
    await assertFails(getDocs(query(collection(db('carol'), 'circles/c1/placeEvents'), where('memberUid', '==', 'bob'))));
  });
});

describe('travel history (Increment 4)', () => {
  const dayDoc = (uid, day = '20261013', over = {}) => ({
    uid, day, tzOffsetMin: 300, visits: [{ name: 'Home', lat: 31.5, lng: 74.3, arrivedAt: 1, leftAt: null }],
    route: [{ lat: 31.5, lng: 74.3, t: 1 }], lastSeen: 2, updatedAt: serverTimestamp(), ...over,
  });
  const seedUser = (uid, extra = {}) => env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), { displayName: uid, birthYear: year - 30, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...extra });
  });
  const flags = (uid, over) => env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), `circles/c1/members/${uid}`), over);
  });
  const copy = (f, uid, day = '20261013') => doc(f, `circles/c1/history/${uid}_${day}`);

  it('profile accepts keepHistory and retentionDays 7/30/90 only', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile({ keepHistory: true, retentionDays: 30 })));
    await assertFails(setDoc(doc(db('bob'), 'users/bob'), profile({ retentionDays: 45 })));
    await assertFails(setDoc(doc(db('bob'), 'users/bob'), profile({ keepHistory: 'yes' })));
  });
  it('private master copy: only the owner, only when keepHistory is on, valid shape', async () => {
    await seedUser('bob');
    const ref = (f) => doc(f, 'users/bob/history/20261013');
    await assertFails(setDoc(ref(db('bob')), dayDoc('bob')));                      // keepHistory off
    await seedUser('bob', { keepHistory: true });
    await assertSucceeds(setDoc(ref(db('bob')), dayDoc('bob')));
    await assertSucceeds(getDoc(ref(db('bob'))));
    await assertFails(getDoc(ref(db('alice'))));
    await assertFails(setDoc(ref(db('alice')), dayDoc('bob')));
    await assertFails(setDoc(ref(db('bob')), dayDoc('bob', '20261013', { day: '2026-10-13' })));
    await assertFails(setDoc(ref(db('bob')), dayDoc('bob', '20261014')));          // day != doc id
    await assertFails(setDoc(ref(db('bob')), dayDoc('bob', '20261013', { route: Array.from({ length: 401 }, (_, i) => ({ lat: 1, lng: 1, t: i })) })));
    await assertFails(setDoc(ref(db('bob')), dayDoc('bob', '20261013', { tzOffsetMin: 99999 })));
    await assertFails(setDoc(ref(db('bob')), dayDoc('bob', '20261013', { extra: 1 })));
    await assertSucceeds(getDocs(collection(db('bob'), 'users/bob/history')));
    await assertFails(getDocs(collection(db('alice'), 'users/bob/history')));
    await assertSucceeds(deleteDoc(ref(db('bob'))));
  });
  it('history sharing is a separate opt-in and cannot start enabled', async () => {
    await seed();
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_A, { historyShared: true })));
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_A, { historyShared: false })));
    await assertSucceeds(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { historyShared: true }));
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { historyShared: 'yes' }));
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1/members/bob'), { historyShared: true }));
  });
  it('circle copy needs sharing on, not paused and historyShared on for that circle', async () => {
    await seed({ bob: true });
    await assertFails(setDoc(copy(db('bob'), 'bob'), dayDoc('bob')));
    await flags('bob', { sharesLocation: true, paused: false, historyShared: false });
    await assertFails(setDoc(copy(db('bob'), 'bob'), dayDoc('bob')));
    await flags('bob', { historyShared: true, paused: true });
    await assertFails(setDoc(copy(db('bob'), 'bob'), dayDoc('bob')));
    await flags('bob', { paused: false });
    await assertSucceeds(setDoc(copy(db('bob'), 'bob'), dayDoc('bob')));
    await assertFails(setDoc(copy(db('alice'), 'bob'), dayDoc('bob')));            // someone else
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/history/bob_20261014'), dayDoc('bob', '20261013')));  // id mismatch
    await assertFails(setDoc(doc(db('bob'), 'circles/c2/history/bob_20261013'), dayDoc('bob')));              // not in c2
  });
  it('members read a copy only while the owner keeps history and sharing on; outsiders never', async () => {
    await seed({ bob: true });
    await flags('bob', { sharesLocation: true, paused: false, historyShared: true });
    await assertSucceeds(setDoc(copy(db('bob'), 'bob'), dayDoc('bob')));
    await assertSucceeds(getDoc(copy(db('alice'), 'bob')));
    await assertSucceeds(getDoc(copy(db('bob'), 'bob')));
    await assertFails(getDoc(copy(db('carol'), 'bob')));                           // other circle's member
    await assertFails(getDoc(copy(db('mallory'), 'bob')));
    await assertFails(getDocs(collection(db('alice'), 'circles/c1/history')));     // no list
    await flags('bob', { historyShared: false });                                  // revoke
    await assertFails(getDoc(copy(db('alice'), 'bob')));
    await assertSucceeds(getDoc(copy(db('bob'), 'bob')));                          // owner still reads own
    await flags('bob', { historyShared: true, sharesLocation: false });            // sharing off also hides it
    await assertFails(getDoc(copy(db('alice'), 'bob')));
  });
  it('copies can be deleted by their owner (even if absent) and by the circle owner; not by others', async () => {
    await seed({ bob: true });
    await assertSucceeds(deleteDoc(copy(db('bob'), 'bob', '20200101')));           // nonexistent: batch-safe
    await assertFails(deleteDoc(copy(db('carol'), 'bob')));
    await assertFails(deleteDoc(copy(db('mallory'), 'bob')));
    await assertSucceeds(deleteDoc(copy(db('alice'), 'bob')));                     // circle owner cleanup
  });
  it('removed members lose access to history copies', async () => {
    await seed({ bob: true });
    await flags('alice', { sharesLocation: true, paused: false, historyShared: true });
    await assertSucceeds(setDoc(copy(db('alice'), 'alice'), dayDoc('alice')));
    await assertSucceeds(getDoc(copy(db('bob'), 'alice')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'circles/c1/members/bob')));
    await assertFails(getDoc(copy(db('bob'), 'alice')));
  });
});

describe('circle lifecycle (Increment 5)', () => {
  const CODE_EXP = 'ABCDEFGHJM';
  const flagsFor = (uid, over) => env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), `circles/c1/members/${uid}`), over);
  });
  const setCircle = (over) => env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'circles/c1'), over);
  });
  const reqDoc = (uid, over = {}) => ({ uid, displayName: uid, joinCode: CODE_A, status: 'pending', createdAt: serverTimestamp(), ...over });
  const reqRef = (f, uid) => doc(f, `circles/c1/joinRequests/${uid}`);

  it('email verification is required to create or join a circle', async () => {
    await seed();
    const f = dbUnverified('dave'); const b = writeBatch(f);
    b.set(doc(f, 'circles/c9'), { name: 'X', ownerUid: 'dave', requiresApproval: false, joinCode: CODE_NEW, createdAt: serverTimestamp() });
    b.set(doc(f, 'circles/c9/members/dave'), { uid: 'dave', role: 'owner', displayName: 'Dave', joinedAt: serverTimestamp() });
    b.set(doc(f, `joinCodes/${CODE_NEW}`), { circleId: 'c9', createdBy: 'dave', revoked: false, createdAt: serverTimestamp() });
    await assertFails(b.commit());
    await assertFails(setDoc(doc(dbUnverified('bob'), 'circles/c1/members/bob'), joinDoc('bob')));
    await assertSucceeds(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob')));
  });

  it('join-code expiry must be a future timestamp within 31 days', async () => {
    await seed();
    const mk = (exp) => { const f = db('alice'); const b = writeBatch(f);
      b.update(doc(f, `joinCodes/${CODE_A}`), { revoked: true });
      b.set(doc(f, `joinCodes/${CODE_EXP}`), { circleId: 'c1', createdBy: 'alice', revoked: false, createdAt: serverTimestamp(), expiresAt: exp });
      b.update(doc(f, 'circles/c1'), { joinCode: CODE_EXP });
      return b.commit(); };
    await assertFails(mk(Timestamp.fromMillis(Date.now() - 1000)));
    await assertFails(mk(Timestamp.fromMillis(Date.now() + 40 * 86400000)));
    await assertFails(mk('tomorrow'));
    await assertSucceeds(mk(Timestamp.fromMillis(Date.now() + 86400000)));
  });

  it('owner can switch approval on/off; others cannot', async () => {
    await seed({ bob: true });
    await assertSucceeds(updateDoc(doc(db('alice'), 'circles/c1'), { requiresApproval: true }));
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1'), { requiresApproval: false }));
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1'), { requiresApproval: 'yes' }));
  });

  it('approval flow: direct join is blocked, request -> approve -> join', async () => {
    await seed(); await setCircle({ requiresApproval: true });
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob')));          // code alone is not enough
    await assertSucceeds(setDoc(reqRef(db('bob'), 'bob'), reqDoc('bob')));
    await assertFails(setDoc(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob')));          // still pending
    await assertFails(updateDoc(reqRef(db('bob'), 'bob'), { status: 'approved' }));               // cannot self-approve
    await assertFails(updateDoc(reqRef(db('mallory'), 'bob'), { status: 'approved' }));
    await assertSucceeds(updateDoc(reqRef(db('alice'), 'bob'), { status: 'approved' }));
    const f = db('bob'); const b = writeBatch(f);
    b.set(doc(f, 'circles/c1/members/bob'), joinDoc('bob'));
    b.delete(reqRef(f, 'bob'));
    await assertSucceeds(b.commit());
    await assertSucceeds(getDoc(doc(db('bob'), 'circles/c1')));
  });

  it('join requests need a valid code, an approval circle, verification and the requester themself', async () => {
    await seed();
    await assertFails(setDoc(reqRef(db('bob'), 'bob'), reqDoc('bob')));                           // circle does not require approval
    await setCircle({ requiresApproval: true });
    await assertFails(setDoc(reqRef(db('bob'), 'bob'), reqDoc('bob', { joinCode: CODE_NEW })));  // bad code
    await assertFails(setDoc(reqRef(db('bob'), 'bob'), reqDoc('bob', { status: 'approved' })));
    await assertFails(setDoc(reqRef(db('mallory'), 'bob'), reqDoc('bob')));
    await assertFails(setDoc(reqRef(dbUnverified('bob'), 'bob'), reqDoc('bob')));
    await assertSucceeds(setDoc(reqRef(db('bob'), 'bob'), reqDoc('bob')));
  });

  it('only the owner lists requests; requester reads own; collection group is own-only', async () => {
    await seed({ bob: true }); await setCircle({ requiresApproval: true });
    await assertSucceeds(setDoc(reqRef(db('dave'), 'dave'), reqDoc('dave')));
    await assertSucceeds(getDocs(collection(db('alice'), 'circles/c1/joinRequests')));
    await assertFails(getDocs(collection(db('bob'), 'circles/c1/joinRequests')));
    await assertSucceeds(getDoc(reqRef(db('dave'), 'dave')));
    await assertFails(getDoc(reqRef(db('bob'), 'dave')));
    await assertSucceeds(getDocs(query(collectionGroup(db('dave'), 'joinRequests'), where('uid', '==', 'dave'))));
    await assertFails(getDocs(query(collectionGroup(db('dave'), 'joinRequests'), where('uid', '==', 'bob'))));
    await assertSucceeds(deleteDoc(reqRef(db('alice'), 'dave')));                                  // reject
  });

  it('ownership transfer needs one batch flipping ownerUid and both roles', async () => {
    await seed({ bob: true });
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1'), { ownerUid: 'bob' }));            // circle only
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { role: 'owner' }));    // self-promotion
    const f = db('alice'); const b = writeBatch(f);
    b.update(doc(f, 'circles/c1'), { ownerUid: 'bob' });
    b.update(doc(f, 'circles/c1/members/bob'), { role: 'owner' });
    b.update(doc(f, 'circles/c1/members/alice'), { role: 'member' });
    await assertSucceeds(b.commit());
    await assertSucceeds(updateDoc(doc(db('bob'), 'circles/c1'), { name: 'Bob family' }));        // new owner works
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1'), { name: 'Nope' }));               // old owner does not
    await assertSucceeds(deleteDoc(doc(db('alice'), 'circles/c1/members/alice')));                // old owner can now leave
  });

  it('transfer to a non-member or with a missing role flip is rejected', async () => {
    await seed({ bob: true });
    const f = db('alice'); const b = writeBatch(f);
    b.update(doc(f, 'circles/c1'), { ownerUid: 'mallory' });
    await assertFails(b.commit());
    const b2 = writeBatch(f);
    b2.update(doc(f, 'circles/c1'), { ownerUid: 'bob' });
    b2.update(doc(f, 'circles/c1/members/bob'), { role: 'owner' });   // old owner not demoted
    await assertFails(b2.commit());
  });

  it('owner can delete the circle with everything under it in one batch; others cannot', async () => {
    await seed({ bob: true });
    // Deleting only the parent would strand subcollection data, so it is denied.
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'circles/c1/places/p1'), { name: 'School', lat: 31.5, lng: 74.3, radiusM: 150, createdBy: 'bob', createdAt: Timestamp.now() });
      await setDoc(doc(ctx.firestore(), 'circles/c1/placeSubscriptions/bob_p1'), { subscriberUid: 'bob', placeId: 'p1', arrive: true, leave: true, allMembers: true, memberUids: [], updatedAt: Timestamp.now() });
      await setDoc(doc(ctx.firestore(), 'circles/c1/placeEvents/bob_p1_1_arrive'), { placeId: 'p1', placeName: 'School', memberUid: 'bob', memberName: 'Bob', type: 'arrive', visitId: '1', occurredAt: Timestamp.now() });
      await setDoc(doc(ctx.firestore(), 'circles/c1/locations/bob'), { uid: 'bob', lat: 1, lng: 1, accuracy: 1, updatedAt: Timestamp.now() });
    });
    await assertFails(deleteDoc(doc(db('bob'), 'circles/c1')));
    await assertFails(deleteDoc(doc(db('mallory'), 'circles/c1')));
    await assertFails(deleteDoc(doc(db('alice'), 'circles/c1'))); // parent cannot be removed alone
    const f = db('alice'); const b = writeBatch(f);
    b.delete(doc(f, 'circles/c1/placeEvents/bob_p1_1_arrive'));
    b.delete(doc(f, 'circles/c1/placeSubscriptions/bob_p1'));
    b.delete(doc(f, 'circles/c1/places/p1'));
    b.delete(doc(f, 'circles/c1/locations/bob'));
    b.delete(doc(f, 'circles/c1/members/bob'));
    b.delete(doc(f, 'circles/c1/members/alice'));
    b.delete(doc(f, `joinCodes/${CODE_A}`));
    b.delete(doc(f, 'circles/c1'));
    await assertSucceeds(b.commit());
  });

  it('orphaned child location documents are unreadable when the parent circle is missing', async () => {
    await seed({ bob: true });
    await env.withSecurityRulesDisabled(async (ctx) => {
      const f = ctx.firestore();
      await updateDoc(doc(f, 'circles/c1/members/bob'), { sharesLocation: true, paused: false });
      await setDoc(locRef(f, 'c1', 'bob'), {
        uid: 'bob',
        lat: 31.5204,
        lng: 74.3587,
        accuracy: 12,
        sharing: true,
        updatedAt: Timestamp.now(),
      });
      await deleteDoc(doc(f, 'circles/c1')); // simulate an out-of-band / legacy orphan
    });

    await assertFails(getDoc(locRef(db('alice'), 'c1', 'bob')));
    await assertFails(getDocs(query(
      collection(db('alice'), 'circles/c1/locations'),
      where('sharing', '==', true),
    )));
  });

  it('the owner cannot leave on their own while the circle still exists', async () => {
    await seed();
    await assertFails(deleteDoc(doc(db('alice'), 'circles/c1/members/alice')));
  });

  it('users can delete their own profile but nobody else\'s', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile()));
    await assertFails(deleteDoc(doc(db('mallory'), 'users/alice')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'users/alice')));
  });
});

describe('activity feed, notification prefs and timed pause (Increment 6)', () => {
  const act = (over = {}) => ({ type: 'joined', actorUid: 'bob', actorName: 'Bob', occurredAt: serverTimestamp(), ...over });
  const aref = (f, id = 'a1') => doc(f, `circles/c1/activity/${id}`);

  it("'joined' is only valid together with the actor's own membership creation", async () => {
    await seed();
    const f = db('bob'); const b = writeBatch(f);
    b.set(doc(f, 'circles/c1/members/bob'), joinDoc('bob', CODE_A, { displayName: 'Bob' }));
    b.set(aref(f), act());
    await assertSucceeds(b.commit());
    await env.clearFirestore(); await seed();
    await assertFails(setDoc(aref(db('bob')), act()));                                   // not joining
    const b2 = writeBatch(db('bob'));                                                    // wrong name
    b2.set(doc(db('bob'), 'circles/c1/members/bob'), joinDoc('bob', CODE_A, { displayName: 'Bob' }));
    b2.set(aref(db('bob')), act({ actorName: 'Alice' }));
    await assertFails(b2.commit());
  });
  it("'left' needs the actor's membership removed in the same batch", async () => {
    await seed({ bob: true });
    const f = db('bob'); const b = writeBatch(f);
    b.delete(doc(f, 'circles/c1/members/bob'));
    b.set(aref(f), act({ type: 'left' }));
    await assertSucceeds(b.commit());
    await env.clearFirestore(); await seed({ bob: true });
    await assertFails(setDoc(aref(db('bob')), act({ type: 'left' })));                   // still a member
  });
  it("'removed' only by the owner, for a member removed in the same batch", async () => {
    await seed({ bob: true });
    const f = db('alice'); const b = writeBatch(f);
    b.delete(doc(f, 'circles/c1/members/bob'));
    b.set(aref(f), act({ type: 'removed', actorUid: 'alice', actorName: 'Alice', subjectUid: 'bob', subjectName: 'Bob' }));
    await assertSucceeds(b.commit());
    await env.clearFirestore(); await seed({ bob: true });
    const fb = db('bob'); const b2 = writeBatch(fb);
    b2.delete(doc(fb, 'circles/c1/members/alice'));
    b2.set(aref(fb), act({ type: 'removed', actorName: 'Bob', subjectUid: 'alice', subjectName: 'Alice' }));
    await assertFails(b2.commit());                                                      // not the owner
  });
  it("'sharing_started/stopped' must match the member's sharing switch in the same batch", async () => {
    await seed({ bob: true });
    const f = db('bob'); const b = writeBatch(f);
    b.update(doc(f, 'circles/c1/members/bob'), { sharesLocation: true });
    b.set(aref(f), act({ type: 'sharing_started' }));
    await assertSucceeds(b.commit());
    await assertFails(setDoc(aref(f, 'a2'), act({ type: 'sharing_started', actorUid: 'alice', actorName: 'Alice' })));  // spoofed actor
    const b2 = writeBatch(f);
    b2.update(doc(f, 'circles/c1/members/bob'), { sharesLocation: false });
    b2.set(aref(f, 'a3'), act({ type: 'sharing_started' }));                              // says started, switch says stopped
    await assertFails(b2.commit());
  });
  it('activity is readable only by circle members and immutable', async () => {
    await seed({ bob: true });
    const f = db('bob'); const b = writeBatch(f);
    b.update(doc(f, 'circles/c1/members/bob'), { sharesLocation: true });
    b.set(aref(f), act({ type: 'sharing_started' }));
    await assertSucceeds(b.commit());
    await assertSucceeds(getDocs(collection(db('alice'), 'circles/c1/activity')));
    await assertFails(getDocs(collection(db('carol'), 'circles/c1/activity')));
    await assertFails(updateDoc(aref(db('bob')), { type: 'left' }));
    await assertFails(deleteDoc(aref(db('bob'))));
    await assertSucceeds(deleteDoc(aref(db('alice'))));
  });
  it('profile accepts notification preferences with sane bounds', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile({ notifOff: ['sharing'], notifMuted: ['c1'], notifSeenAt: Timestamp.now() })));
    await assertFails(setDoc(doc(db('bob'), 'users/bob'), profile({ notifOff: Array.from({ length: 11 }, (_, i) => `t${i}`) })));
    await assertFails(setDoc(doc(db('bob'), 'users/bob'), profile({ notifSeenAt: 'yesterday' })));
  });
  it('timed pause: members set pausedUntil on themselves as a timestamp only', async () => {
    await seed({ bob: true });
    await assertSucceeds(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { paused: true, pausedUntil: Timestamp.fromMillis(Date.now() + 3600000) }));
    await assertFails(updateDoc(doc(db('bob'), 'circles/c1/members/bob'), { pausedUntil: 'soon' }));
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1/members/bob'), { pausedUntil: Timestamp.now() }));
  });
});
