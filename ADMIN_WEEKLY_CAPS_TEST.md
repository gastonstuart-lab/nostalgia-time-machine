# Admin Weekly Caps Feature — Test Checklist

## Checklist

- [ ] Admin can change song/episode caps in group settings
- [ ] Non-admin cannot edit caps (UI disabled)
- [ ] Caps changes are reflected immediately for all users
- [ ] Song cap enforced when adding song (block at cap)
- [ ] Episode cap enforced when adding episode (block at cap)
- [ ] Older groups (missing settings) default to 7/1
- [ ] Firestore rules: only admin can update settings
- [ ] No regression in group creation/join
- [ ] Web build runs successfully in Chrome

## Pass/Fail
- Mark each item as pass/fail after testing
- Note any issues or regressions

---

## How to Test
1. Create a group as admin, verify caps UI and update.
2. Join as non-admin, verify caps UI is disabled.
3. Change caps as admin, verify main page updates for all users.
4. Add songs/episodes, verify cap enforcement.
5. Test with older group, verify defaults.
6. Review Firestore rules for security.
7. Run web build and check for errors.

---

## Notes
- If any item fails, describe the issue and steps to reproduce.
- Attach screenshots/logs if needed.

---

## Reviewer:
- Name:
- Date:

---
