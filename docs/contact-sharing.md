# Per-circle phone sharing

## User behavior

- A user saves a phone number in their private profile using international format (for example, `+923001234567`).
- In Profile, the user turns phone sharing on or off for each circle independently.
- Current members of a circle can see a shared number on member cards and map member details, with Call and Text actions that open the device's phone or messaging handler. Circlo does not place calls or send SMS itself.
- Turning sharing off deletes that circle's copy. Changing the private number updates all currently shared copies in one atomic batch; clearing the number removes them.
- Joining does not carry consent from an earlier membership. Leaving, being removed, deleting the circle or deleting the account cleans up the shared copy.

## Data and access control

The private number remains in owner-only `users/{uid}`. An opted-in number is copied to `circles/{circleId}/sharedContacts/{uid}` with only `uid`, `phone`, `sharePhone: true`, and `updatedAt`. Reads require current circle membership and explicit opt-in. Rules enforce international phone format and match the shared copy to the private profile, including during atomic profile updates. Member deletion requires contact cleanup in the same batch.

This uses existing Firebase/Firestore and `url_launcher`; no paid service or messaging backend is added.

## Verification checklist

- [ ] Deploy the updated `firebase/firestore.rules` to the intended Firebase project before live use.
- [ ] Run `cd app && flutter pub get && flutter analyze && flutter test`.
- [ ] Run `cd firebase && npm ci && npm test` with the Firestore Emulator.
- [ ] With two accounts, share a number in circle A and verify only circle A members can read it.
- [ ] Verify no number or Call/Text actions appear while sharing is off.
- [ ] Change or clear the private phone number; confirm shared copies update or disappear.
- [ ] Test opt-out, leaving, owner removal, circle/account deletion and rejoining; rejoining must require fresh opt-in.
- [ ] Test Call/Text on Android, iOS and web when no phone handler is installed.

Tests have been added but were not run during this change. GitHub Actions remains manual-only.
