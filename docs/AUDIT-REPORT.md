# AUDIT — TASK-01 … TASK-10 (expense-splitter)

- **Auditor:** AUDITOR subagent (read-only), lens: `ponytail/skills/ponytail`
- **Tree audited:** working tree on top of `717b2a4 documentation create` (git status/diff clean-read only; no state-changing git command was run)
- **Diff size:** 16 files changed, +1733 / −203 (incl. generated plugin registrants + `pubspec.lock`); `lib/` only: 7 modified files +1547/−201 and 3 new files (`expense_history_page.dart` 658 L, `profile_page.dart` 423 L, `utils/currency.dart` 59 L, `utils/export.dart` 64 L)
- **Only dependency added:** `share_plus: ^10.0.0` (TASK-08, requested); everything else in the lock diff is transitive (`path_provider`, `url_launcher`, `mime`, `cross_file`, `jni`, `objective_c`, …)
- **Files I modified:** `docs/AUDIT-REPORT.md` (this file) — nothing else

**Verdict rubric:** `FAIL` = carries a P0/P1 · `PASS WITH NITS` = only P2/P3 · `PASS` = clean.

---

## 1. Verdict per task

| Task | Verdict | Evidence (one line) |
|---|---|---|
| **TASK-01** edit/delete expense | **FAIL** | All doc steps present (`group_repository.dart:685,749`; `group_details_page.dart:167-224,527-641`; `add_expense_page.dart:86-99,369-396`) **but** editing any `splitType='unequal'` row rewrites its participants and moves real money (Finding **F1**, probe below: X's balance swings 375.00 on a no-op edit). |
| **TASK-02** delete group | **PASS** | Cascade is byte-for-byte the doc's 6-table sequence inside one `db.transaction` (`group_repository.dart:142-194`), covers every FK incl. `expense_splits` (`:163-167`), and `groups_list_page.dart:174-201,473` has the long-press dialog + snackbar. |
| **TASK-03** edit group | **PASS WITH NITS** | Rename modal + validation + `_groupName` refresh + duplicate-member error all present (`group_details_page.dart:226-403,405-506`, `group_repository.dart:312,328`); nit: two `TextEditingController`s created per dialog and never disposed (F6). |
| **TASK-04** expense history | **PASS WITH NITS** | Page + timeline merge + AppBar history button implemented (`expense_history_page.dart:1-307`, `group_details_page.dart:660-672`); nit: `setState` after `await` with no `mounted` guard (F7). |
| **TASK-05** profile edit | **PASS WITH NITS** | Profile menu item, load, validation, save, `pop(true)` all per doc (`groups_list_page.dart:67-79,230-239`, `profile_page.dart:85-132`); nits: unrequested currency block (F8) + no refresh when currency-only change returns (F5). |
| **TASK-06** currency formatting | **PASS WITH NITS** | `grep '₹' lib/` outside `lib/utils/currency.dart` → **0 hits** (checklist item passed); all 5 doc files + 2 files the doc didn't know about (`expense_history_page.dart`, `export.dart`) swept; nit: doc's `{String symbol = '₹'}` signature replaced by a module-level cached symbol (F9 — better for integration, but `symbol:` params now have zero callers). |
| **TASK-07** dark theme | **PASS** | `themeNotifier` + persistence + `ValueListenableBuilder` + `darkTheme` exactly per doc (`main.dart:11-30,36-48,71-94`), dialog at `groups_list_page.dart:81-125`, no new deps. |
| **TASK-08** export/share | **PASS** | `lib/utils/export.dart:5-64` matches the template (only `₹`→`formatCurrency`, correct TASK-06 integration), `share_plus` in `pubspec.yaml:44`, share button `group_details_page.dart:650-654`, all 5 platform registrants regenerated. |
| **TASK-09** percentage split | **PASS WITH NITS** | 3-way selector, `MemberPercentage`, sum-to-100 validation (0.01 margin), per-member row write, disposal, `build()`/`_saveExpense()` branches all present (`add_expense_page.dart:9,27-39,257-304,427-445,540-545,1377-1444`); nits: non-atomic N-row write (F4), split silently opens as *Equal* in edit mode (F3). |
| **TASK-10** search/filter | **PASS** | Search bar + multi-select category chips + AND-combination + counter + clear/no-match states + `Icons.history` button all present and wired to a `setState`-driven filter (`expense_history_page.dart:104-138,271-307,309-414`). |

---

## 2. Ranked findings

### F1 — P1 — Editing an unequal-split expense silently redistributes it across the whole group
`lib/pages/add_expense_page.dart:96-97` × `:243-250` × `:371-381`

- **What's wrong:** An unequal split is stored as **one row per consumer** (`add_expense_page.dart:410-426`, participant list = 1). In edit mode `initState` maps `splitType=='unequal'` → `SplitType.unequal` (`:96-97`) but `_memberConsumptions` is rebuilt **empty** for all members (`:144-149`, no prefill). Hitting *Update Expense* runs `_validateUnequalSplit`, whose auto-distribute branch (`:243-250`) sees "0 entered, 4 empty" and assigns `total/4` to every member; the update branch (`:378-381`) then writes **all four members as participants** while the row keeps its original amount. `calculatePendingSettlements` (`group_repository.dart:503-519`) divides `amount/participants.length`, so who-owes-whom changes even if the user only edited the description.
- **Real output** (probe replicating `add_expense_page.dart:243-250` + `group_repository.dart:503-519`, run with `dart run`):
  ```
  before edit (participants=[X]): X=-500.00 Y=0.00 Z=0.00 W=0.00
  after auto-distribute: participants=[X, Y, Z, W] share=125.0
  after edit (participants=[X, Y, Z, W]): X=-125.00 Y=375.00 Z=-125.00 W=-125.00
  DELTA X: 375.00 (user only meant to change the description)
  ```
- **Root cause ownership:** TASK-01's doc prescribed the `splitType` mapping and TASK-01's doc did *not* prescribe prefilling `_memberConsumptions`; the auto-distribute is pre-existing. Neither doc's checklist edits an unequal expense, so six workers walked past it.
- **Smallest fix (6 lines, preserves semantics + `splitType` label)** — inside the existing `setState` in `_loadGroupMembers`, right after `_memberConsumptions = …` (`add_expense_page.dart:149`):
  ```dart
  final exp0 = widget.existingExpense;
  if (exp0 != null && exp0.splitType == 'unequal' && exp0.participantIds.length == 1) {
    _memberConsumptions.firstWhere((c) => c.userId == exp0.participantIds.first)
        .controller.text = exp0.amount.toStringAsFixed(2);
  }
  ```
  (`enteredSum == total` → the auto-distribute branch stays shut → participants remain `[X]`.)
- **Even smaller fallback (1 line):** change `:97` to `_splitType = SplitType.equal;` — every stored row is single-participant by construction, so Equal with only that member checked is money-identical. Cost: the row's internal `splitType` becomes `'equal'` (nothing reads it back except this same `initState`, verified by grep).

### F2 — P2 — No test covers any of the new money paths
`test/widget_test.dart` (1 test, login smoke) is the whole suite; `updateExpense`, `deleteExpense`, `deleteGroup` cascade, and `_validatePercentageSplit` have zero coverage. `flutter analyze` is green but proves nothing about the transaction round-trip.
- **Smallest fix:** one `test/split_money_test.dart` (~30 lines) using `sqflite_common_ffi` — **already a main dependency**, no new package: `databaseFactory = databaseFactoryFfi` → `addExpense` → `updateExpense` → assert participants/amount round-trip → `deleteExpense` → assert `expenses` + `expense_participants` empty.

### F3 — P2 — Multi-row split writes are not atomic
`add_expense_page.dart:410-426` (unequal) and `:427-444` (percentage) loop over N `addExpense()` calls, each opening its **own** `db.transaction` (`group_repository.dart:655-677`). A crash/error after row 3 of 5 persists a partial split → group total silently ≠ the amount the user typed. (Inherited pattern: unequal has always done this; TASK-09 copied it, so it is now the pattern for two split types.)
- **Smallest fix:** add `Future<void> addExpenses(List<ExpenseInsert> rows)` to `GroupRepository` that runs one `db.transaction` and inserts all rows; point both loops at it (~20 lines, and the per-row `try/catch + debugPrint + rethrow` goes away).

### F4 — P2 — Changing currency from Profile doesn't refresh the Events screen
`groups_list_page.dart:76-78` — `_navigateToProfile` only calls `_refreshData()` when `result == true`, i.e. only after *Save Changes*. `_selectCurrency` (`profile_page.dart:134-137`) writes the pref and never pops with `true`, so popping back bumps nothing and `formatCurrency` keeps returning the old symbol on every already-built widget until the next `_refreshData()` (open+close an event, delete, etc.).
- **Smallest fix (deletes the condition):**
  ```dart
  await Navigator.push<bool>(...);
  _refreshData();   // was: if (result == true) { _refreshData(); }
  ```

### F5 — P3 — Percentage tolerance lets the stored total drift from the entered amount
`add_expense_page.dart:290` accepts `|Σ% − 100| ≤ 0.01` (percent units) and `:432` stores `amount * pct/100` per row, so a "99.995 % / 100.005 %" entry persists rows summing to `amount ± amount×1e-4`. Probe output:
```
amount=1000.0 pct=100.005 -> stored rows sum=1000.0500000000 drift=0.0500000000
amount=1000.0 pct=99.995  -> stored rows sum=999.9500000000 drift=-0.0500000000
```
(= ±₹0.10 on a ₹1 000 expense, ±₹1 on a ₹10 000 one). Spec-prescribed margin, so a nit — **smallest fix:** tighten the margin to `> 0.0001` at `:290`, or add the last member's share as `amount − Σ(others)`.

### F6 — P3 — Undisposed `TextEditingController`s in dialog/bottom-sheet helpers
`group_details_page.dart:227` (rename modal), `:406-407` (add-member dialog) — controllers are created inside one-shot methods and never `dispose()`d. Page-scoped controllers *are* disposed correctly (`add_expense_page.dart:105-116`, `expense_history_page.dart:64-67`, `profile_page.dart:35-39`) — this is the only leak.
- **Smallest fix:** `nameController.dispose();` after `await showDialog`/after the bottom sheet closes, or hoist them into the State and dispose in `dispose()`.

### F7 — P3 — `setState` after `await` without `mounted` in the new pages
`expense_history_page.dart:91,96`, `profile_page.dart:71,78`, `add_expense_page.dart:129,161` (pattern copied from the pre-existing `group_details_page.dart:79,91`). Only bites if the route is popped mid-query; pre-existing style, propagated to 3 new files.
- **Smallest fix:** `if (!mounted) return;` before each post-await `setState`.

### F8 — P3 — Currency picker on Profile is unrequested (but is the only setter)
`profile_page.dart:336-358`. Neither TASK-05 nor TASK-06 specifies any UI for `setCurrencySymbol` — without this block the pref would be un-writable, so it is the *right* unrequested code. Flagged because it is unowned: no doc says who maintains it, and it is why F4 exists.

### F9 — P3 — TASK-06's public signature was changed
Spec: `formatCurrency(double, {String symbol = '₹'})` and `balanceText([String symbol = '₹'])`. Impl: `formatCurrency(double, {String? symbol})` + module-level cached `_currentSymbol` (`currency.dart:23-39`) and `balanceText([String? symbol])` (`group.dart:48`), so the checklist line about "the default parameter in `GroupBalanceView.balanceText`" no longer matches. The impl is the better design (call sites don't have to thread the symbol), but `symbol:` now has **zero callers** — either delete the param (ponytail: dead code) or keep it and update the doc's checklist line.

### F10 — P3 (informational, pre-existing, NOT introduced by these tasks)
- **Dead code from before the work:** `addExpenseSplit` (`group_repository.dart:621-625`, zero callers), `ExpenseParticipant` (`models/expense.dart:105-121`), `Expense.copyWith` (`models/expense.dart:73-101`). None appear in the diff — out of scope, delete if anyone wants the line count back.
- **Duplicated helpers:** three date formatters (`group_details_page.dart:531` inline, `expense_history_page.dart:140`, `profile_page.dart:139`) and five copies of the "icon + message + Retry" error block. Not worth touching now (different formats/uses), listed so nobody "cleans up" one and breaks another.
- **Hardcoded light-tinted surfaces** (`Colors.grey[100]`, `Colors.green[50]`, `Colors.blue[50]` ≈ 10 sites incl. new ones at `group_details_page.dart:511,1123`) will render as bright cards on dark theme, and `TextStyle(color: Colors.grey)` on `grey[100]` is ~2.4:1 contrast even in light mode. TASK-07's scope was explicitly *only* mode switching, so this is out-of-scope polish, not a miss.

---

## 3. Skipped vs task doc

**Nothing a task doc required is missing from the code.** Every step and every testing-checklist bullet I could map to code is present; the only deltas are *additions* beyond the docs:

| Doc requirement | Status | Note |
|---|---|---|
| TASK-01 §4 Steps 1–3 (repo methods, edit-mode `AddExpensePage`, expenses section, delete dialog, SnackBars, title/button text) | ✅ all present | — |
| TASK-01 checklist: edit an *unequal* expense | ⚠️ not covered by the doc, broken in code | See F1 — doc's own checklist only exercises equal splits |
| TASK-02 §3 6-step cascade in one transaction | ✅ byte-for-byte | `group_repository.dart:146-189` |
| TASK-03 Steps 1–2 incl. duplicate-member error text | ✅ | `group_repository.dart:378-380` → surfaced as "X is already a member of this event" (`group_details_page.dart:473`) |
| TASK-04 page + AppBar history button + "Activity History" title + event subtitle | ✅ | — |
| TASK-05 menu = Profile + Logout | ✅ (plus Theme, from TASK-07) | 3 items, not a conflict |
| TASK-06: `₹` only inside `currency.dart` | ✅ (stricter than spec — 0 occurrences even in `balanceText`) | Signature deviates, see F9 |
| TASK-06 `formatCurrency` / `getCurrencySymbol` / `setCurrencySymbol` contracts | ⚠️ impl adds caching + nullable `symbol` | Better for integration; doc checklist line now stale |
| TASK-06 file list = 5 files | ✅ + 2 extra files swept (`expense_history_page.dart`, `export.dart`) | Correct: those files didn't exist when the doc was written and both contained `₹` |
| TASK-07 Step 1–2 (`themeNotifier`, persistence, `darkTheme`, dialog) | ✅ | — |
| TASK-08 `export.dart` template (exact text format) | ✅ except `₹` → `formatCurrency` | Correct integration with TASK-06; the doc's "exact template" is stale |
| TASK-09 Steps 1–5 (enum, state, disposal, selector, validation, save branches) | ✅ | — |
| TASK-09 checklist "settlements reflect 60/40" | ✅ logically (single-participant rows) | No automated check exists — see F2 |
| TASK-10 search/chips/counter/clear/no-match | ✅ | — |
| *(not in any doc)* currency picker UI | ➕ added anyway | F8 — without it `setCurrencySymbol` is unreachable |

---

## 4. Cross-task integration (the wave seams)

1. **TASK-01 edit mode × TASK-09 percentage split** — merged, but only half-safe. Percentage rows map to Equal (`add_expense_page.dart:93-98`) with an explicit comment: money-preserving (participant list is already `[X]`, amount unchanged) at the cost of the internal `splitType` label being rewritten to `'equal'` at `:391-395` (nothing reads it back). **Unequal rows take the other branch and are corrupted — F1.**
2. **TASK-01 delete × TASK-08 share × TASK-06 currency in `group_details_page.dart`** — the file got four independent edits and they coexist cleanly: AppBar `actions` = share `:650` → edit `:655` → history `:660` → refresh `:673`; delete dialog uses `formatCurrency` `:173`; expenses list amount `:603`; export summary uses `formatCurrency` (`export.dart:21,31,43,55`, a deviation from TASK-08's literal-₹ template that is correct here). `flutter analyze` clean = no lost/overwritten hunk.
3. **TASK-04/10 history × TASK-06 currency sweep** — `expense_history_page.dart:504,631` use `formatCurrency`; TASK-06's file list didn't know this file existed but the sweep reached it. Grep for `₹` outside `currency.dart` → **0**.
4. **TASK-07 theme × TASK-06 currency × TASK-05 profile** — no collision: `groups_list_page.dart` popup = Profile (`:230`) / Theme (`:240`) / Logout (`:250`), `main.dart` holds `themeNotifier`+`updateThemeMode` imported at `groups_list_page.dart:6`, currency lives in `utils/currency.dart` with the setter on the profile page. Theme pref and currency pref use different keys (`'themeMode'` vs `'currencySymbol'`) — no overwrite.
5. **TASK-02 cascade × schema (`database.dart`)** — complete. FKs on `groups`: `group_members`, `expenses`, `expense_splits`, `settlements` (all four deleted, `:148-181`); FK on `expenses`: only `expense_participants` (deleted via sub-select **before** `expenses`, `:156-174`); `groups` last (`:184-188`); `expense_splits` **is** handled (`:163-167`). Single `db.transaction`. `deleteExpense` needs only `expense_participants` → `expenses`, which is what it does (`:749-771`). Nothing missed.
6. **Money/settlement consistency (`ARCHITECTURE.md` §6.3/§13)** — **unchanged, neither better nor worse, except one hygiene win.**
   - `getUserNetBalanceForGroup` (`group_repository.dart:215-258`) reads `expense_splits`, which **no code path ever writes** (`addExpenseSplit` at `:621` has zero callers; `createGroupWithMembers` writes `expenses`, not `expense_splits`). With `credit = debit = 0` the formula degenerates to `settlementOut − settlementIn`, so the Events-screen "Your overall balance" ignores expenses entirely *and* moves the wrong way when you pay a settlement. Pre-existing (`ARCHITECTURE.md:544`), untouched by the diff (the `group_repository.dart` diff is 3 pure-addition hunks: `deleteGroup`, `updateGroupName`/`addNewMemberToGroup`, `updateExpense`/`deleteExpense`).
   - `calculatePendingSettlements` recomputes from `expenses` + `expense_participants` on every `_loadGroupData`, so edit (`group_details_page.dart:162-164`) and delete (`:213`) propagate correctly — pending settlements, stats and per-person share all refresh. Deletion leaves no dangling rows (participants first, in one txn).
   - **Net effect of these 10 tasks on §13 item 3: neutral-to-slightly-better** — TASK-02 now also purges `expense_splits` rows when a group is deleted, so the dead table can no longer accumulate orphans. The two functions remain mutually inconsistent exactly as before, because tasks were never asked to fix them.

---

## 5. Leftover grep results (worker debris)

```
=== hardcoded ₹ outside lib/utils/currency.dart ===   (none)
=== TODO / FIXME / XXX / HACK in lib/ ===            (none)
=== bare print( in lib/ ===                          (none)   [debugPrint: 19 total, all in pre-existing files/paths]
=== duplicate category maps ===                      (none)   [single source: lib/models/expense.dart:124 expenseCategories]
=== unused imports ===                               (none)   [flutter analyze reports unused_import; tree is clean]
=== new dependencies ===                             share_plus: ^10.0.0 only (requested by TASK-08)
```

---

## 6. Gates — real output

`flutter analyze` (exit 0):
```
Analyzing expense-splitter...
No issues found! (ran in 2.0s)
```

`flutter test` (exit 0):
```
00:00 +0: loading /home/deval/Projects/expense-splitter/test/widget_test.dart
00:00 +0: Login page smoke test
00:00 +1: All tests passed!
```

Notes on the gates:
- The pre-existing template test **passes** — it is not the stock counter test but a `Login page smoke test` (`test/widget_test.dart`), and no task broke it. Nothing failed, so there is no "pre-existing vs new code" attribution to make.
- Zero analyzer issues means: no unused imports, no `unused_element`, no deprecation warnings — `RadioGroup` (`groups_list_page.dart:90`) and `DropdownButtonFormField(initialValue:)` are valid on this SDK (Dart 3.13.4 / Flutter 3.38.x).
- Coverage caveat: green gates prove *compilation and the login smoke path*; they say nothing about the money paths (F2).

---

## 7. Recommended order of work (smallest first)

1. **F1** — 6-line prefill (or 1-line `SplitType.equal`) in `add_expense_page.dart` → clears TASK-01's FAIL.
2. **F4** — delete one `if (result == true)` in `groups_list_page.dart:76`.
3. **F2** — one 30-line ffi test for the transaction round-trip.
4. **F3** — batch `addExpenses` (only if you want split writes crash-safe; doc-prescribed today).
5. F5–F10 when touching those lines anyway.
