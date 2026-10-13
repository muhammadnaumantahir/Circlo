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

const db = (uid) => env.authenticatedContext(uid).firestore();
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
  it('cannot delete profile yet', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'users/alice'), profile()));
    await assertFails(deleteDoc(doc(db('alice'), 'users/alice')));
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
  it('the owner cannot leave (no transfer/delete yet) and the circle cannot be deleted', async () => {
    await seed();
    await assertFails(deleteDoc(doc(db('alice'), 'circles/c1/members/alice')));
    await assertFails(deleteDoc(doc(db('alice'), 'circles/c1')));
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
  it('owner cannot change ownerUid or approval flag via update', async () => {
    await seed();
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1'), { ownerUid: 'bob' }));
    await assertFails(updateDoc(doc(db('alice'), 'circles/c1'), { requiresApproval: true }));
    await assertSucceeds(updateDoc(doc(db('alice'), 'circles/c1'), { name: 'Family 2' }));
  });
});
