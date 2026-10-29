# Per-circle phone sharing

## User behavior

- A user saves an international phone number in their private profile.
- On the Profile screen, they explicitly turn phone sharing on or off for each circle independently.
- Other current members of that circle see the shared number on the circle's member cards, with Call and Text actions. The device opens its dialer or messaging app; Circlo does not place calls or send SMS itself.
- Turning sharing off deletes that circle's copy. Changing or clearing the private phone number updates or removes all currently shared copies atomically.
- Joining a circle never carries phone-sharing consent from an earlier membership. Leaving, being removed, or deleting the account also removes that circle's copy.

## Data and access control

The private number remains in `users/{uid}`, which is owner-only. An opted-in number is copied to `circles/{circleId}/sharedContacts/{uid}`; documents contain only `uid`, `phone`, `sharePhone: true`, and `updatedAt`. All read queries filter to `sharePhone == true`. Firestore Rules only permit the contact owner to opt in/update their number, verify that the copy matches their private profile, and allow current circle members to read opted-in contacts. Member deletion rules require the contact copy to be removed as well.

This uses existing Firebase/Firestore and `url_launcher`; it adds no paid service or notification backend.

## Verification checklist

- [ ] Deploy the repository's updated `firebase/firestore.rules` to the intended Firebase project before trying the feature in the live app.
- [ ] Run `cd app && flutter pub get && flutter analyze && flutter test`.
- [ ] Run `cd firebase && npm ci && npm test` with the Firestore Emulator.
- [ ] With two accounts, share a number in circle A and verify that only circle A's members can read it.
- [ ] Verify no number or Call/Text action appears when sharing is off.
- [ ] Change the private number and verify the shared copy updates; clear the number and verify sharing is removed.
- [ ] Test opt-out, leaving, owner removal, account deletion and rejoining; rejoining must require fresh opt-in.
- [ ] Test Call/Text actions on Android, iOS and web, including a browser/device without a configured phone handler.

The automated tests have been added but have **not** been run as part of this change. GitHub Actions remains manual-only.
