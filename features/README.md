# Developing features on this Telegram fork

This repository is a **fork of upstream [DrKLO/Telegram](https://github.com/DrKLO/Telegram)** (git remote `telegram`). Upstream ships frequently as large squashed imports — the `master` history is a wall of `update to 12.x.y (NNNN)` commits, each touching thousands of files. The single biggest source of pain when maintaining a fork is **re-merging those imports on top of your own edits**.

This document is the playbook for adding features so that upstream merges stay (almost) conflict-free. Every feature also gets its own page in this folder.

## The core idea

> **A merge conflict can only happen on a line that both you and upstream changed.**
> So: change as few upstream lines as possible, and put everything else in files upstream never touches.

Each feature should be ~90% new files and ~10% tiny, marked edits to existing files.

## Where conflicts actually come from (history analysis)

Churn over the last ~300 commits — the files most likely to conflict (touch count):

| File | Touches |
|---|---|
| `ui/ChatActivity.java` | 204 |
| `messenger/BuildVars.java` | 201 |
| `ui/Cells/ChatMessageCell.java` | 171 |
| **`res/values/strings.xml`** | **162** |
| `ui/ProfileActivity.java` | 160 |
| `messenger/MessagesController.java` | 158 |
| `ui/DialogsActivity.java` | 157 |
| `ui/LaunchActivity.java` | 155 |
| `messenger/MessagesStorage.java` | 152 |
| `messenger/MessageObject.java` | 144 |
| `ui/ActionBar/Theme.java` | 127 |
| `ui/Cells/DialogCell.java` | 114 |
| `messenger/SharedConfig.java` | 91 |

Takeaways:
- **`strings.xml` is the #1 resource hotspot.** Never add your strings there.
- The big controllers/cells/activities change constantly. Touch them as little as possible, and never reformat or move their code.
- `BuildVars.java` / signing config / `gradle.properties` are import-managed — keep fork build config in `local.properties` (gitignored) and out of tracked files where possible.

## Rules

### 1. Put all real logic in new files
New classes don't conflict — ever. Prefer a `XxxController` / helper class over inlining logic into an existing one. Reach existing per-account services via `BaseController` rather than editing them. (Example: `UnreadMarkTimeTracker`, `UnreadMarkBadge`.)

### 2. Keep edits to existing files tiny, localized, and **marked**
When you must edit a hot file:
- Make the smallest possible change — ideally a single call into your new class.
- **Make every edit site grep-able** so you can find them all after a merge. Either give your additions a unique, feature-specific identifier prefix (the unread-age-badge feature uses `unreadMarkAge…` everywhere, so `git grep -i unreadmarkage` finds every touch point), or — when an edit introduces no such identifier — drop a marker comment `// feature: <feature-name>`. Avoid adding marker comments purely for the sake of it: extra lines in hot files are themselves small conflict risks.
- **Append, don't insert.** Add new enum/row/case entries at the *end* of a list, not in the middle — adjacent-line edits are what actually collide.
- Never reformat, re-order, or rename surrounding upstream code.

### 3. Resources go in dedicated, feature-prefixed files
Android merges every `<resources>` file in a `values*/` folder, so you never need to edit `strings.xml`:
- Put strings in `res/values[-locale]/strings_<feature>.xml`.
- Prefix keys with the feature name (`UnreadAgeBadge…`) so they can't duplicate an upstream key.
- Same for colors/dimens/drawables — a dedicated file per feature.
- Reusing a *stable, long-standing* upstream key (e.g. `ShortHoursAgo`) is fine; just don't redefine it.

### 4. One branch per feature
Branch `claude/0N-<feature>` (continue the global number sequence; don't restart at 01). Keep features independent so they can be merged, reordered, or dropped without entangling each other.

### 5. Document every feature here
Add `features/<feature>.md` containing: what it does, a screenshot (store images in `/docs`), the new files, and a **"touched upstream files" merge checklist**. After an upstream merge, that checklist + the `feature: <name>` markers tell you exactly what to re-verify.

### 6. Prefer extension points over edits
If the code already offers a hook (a `NotificationCenter` event, an overridable method, a registration list, a resource the runtime looks up by name), use it instead of editing the call site.

## Merging upstream with minimal pain

```bash
git fetch telegram
git checkout master && git merge telegram/master      # update the fork baseline
# then bring each feature branch up to date:
git checkout claude/06-read-later-age-badge
git rebase master           # or: git merge master
```

When conflicts appear they should be confined to the handful of hot files each feature's checklist already names. For each:
1. `git grep "feature: <name>"` to relocate your edits.
2. Re-apply the tiny hunk next to upstream's new code (your feature doc says what it should look like).
3. Rebuild the obfuscated release and sanity-check on device.

Because the logic is in new files, the conflict is almost always just "re-place this one call / one row again," not a semantic merge.

## Feature index

- [Unread age badge](unread-age-badge.md) — age-colored unread badges (blue→red) on every unread chat.
