# UI Redesign Review (ponytail lens)

**Scope:** full working-tree redesign of `lib/` (8 files restyled + new `lib/theme/app_theme.dart`, ~1484 ins / 1442 del) plus Event-page restructure into dashboard + 4 tabs.
**Baseline:** `e96a550` ("application v1"). Read-only review — no `lib/` or `test/` edits, no builds, git used read-only (`git diff HEAD`, `git show`).
**Verdict:** No blockers. One major visual defect (transparent bottom sheet) worth a one-line fix before shipping; everything else is nit/minor polish and deletable fat.

**Testing gates (not run by me):** I did not run `flutter` (lock contention, per instructions). Analyzer/tests were verified green by the **orchestrator at 14:1x** — gate-sized `execute_code` runs at 14:16:06 and 14:17:45 in `agent.log` (session `20261002_160804`), after the last source mtime (14:17). Last analyzer log I could actually read is `scratch/analyze_after.log` (13:30, "No issues found!") plus delegation log `deleg_b2f60241` (14:10 analyze clean / 14:12 `+4 All tests passed`). So: gates green per orchestrator, not independently re-verified by me.

## FINDINGS

| # | Sev | file:line | Issue | Smallest fix |
|---|-----|-----------|-------|--------------|
| 1 | **major** | `lib/theme/app_theme.dart:139` | `bottomSheetTheme.backgroundColor: Color(0x00000000)` makes every modal sheet see-through. Flutter resolves `backgroundColor ?? sheetTheme.modalBackgroundColor ?? sheetTheme.backgroundColor ?? defaults` (`bottom_sheet.dart:1145-1149`) and passes it to `Material(color: ...)` (`:387`). The Edit-Event sheet (`group_details_page.dart:218-374`) supplies no own background, so its text floats over the dimmed page — broken in both themes. | Delete line 139 (+ its comment) → M3 default `surfaceContainerLow` applies. 1-line revert. |
| 2 | minor | `group_details_page.dart:342, 990` | `fontSize: 12` — off the declared 13/16/20/32 scale. | `style: Theme.of(context).textTheme.labelLarge` (13/600); drop the `fontSize`. |
| 3 | minor | `group_details_page.dart:991, 1171, 1261, 1266, 1385, 1390, 1395` | `FontWeight.bold`/`w700` — spec allows 400/600 only. | `FontWeight.w600` (7 spots). |
| 4 | minor | `group_details_page.dart:974, 1091, 1138` | `textTheme.titleSmall` is **not defined** in `AppTheme._textTheme` (`app_theme.dart:199-245`); `ThemeData` merges defaults under it (`theme_data.dart:524`), so it renders M3 14px/400 — off-scale and not token-controlled. | Use `titleMedium` (20) or `labelLarge` (13) at those 3 call sites. |
| 5 | minor | `app_theme.dart:249-250` vs `login_page.dart:106`, `create_group_page.dart:439` | `warmOn()` is **dead code** — never called. Meanwhile the icon on the amber accent uses `scheme.onSurface`, which is white-on-amber in dark mode (≈1.9:1). | Call `AppTheme.warmOn(Theme.of(context).brightness)` for those two icon colors (helper already written). |
| 6 | minor | `groups_list_page.dart:137-163, 291` | `_loadHomeData` runs `getGroupMembersWithPayments` **once per event, sequentially** (2+ queries each) only to print "N members"; and the future is constructed inside `build`, so every rebuild re-queries. Cost didn't exist at baseline. | Delete `memberCounts` + the loop + the `_HomeData` field (~25 lines), or cache the future in a field. |
| 7 | minor | `group_details_page.dart:565` | `NavigationBar` renders during `_isLoading`/`_errorMessage` (it sits outside the body ternary at 519-564): tabs are tappable but the body never changes. | `bottomNavigationBar: _isLoading \|\| _errorMessage != null ? null : NavigationBar(...)`. |
| 8 | minor | `group_details_page.dart:691, 729, 751, 770` | Tab scroll views have `Padding(all:16)` while the FAB (587) floats over them — last card/settlement can hide behind it. | `EdgeInsets.fromLTRB(16, 16, 16, 88)` on the three FAB-bearing tabs. |
| 9 | nit | `group_details_page.dart:1192, 1197` | Count badge `vertical: 2` breaks the 8pt grid; radius 12 is off the 16/20/24 system. | `vertical: 8`, `circular(16)`. |
| 10 | nit | `expense_history_page.dart:333` | `SizedBox(height: 52)` chip row — off-grid. | `height: 56`. |
| 11 | nit | `app_theme.dart:34, 40, 48, 67, 77, 87, 96, 133, 134, 148` | `_textTheme(scheme)` is rebuilt ~9× although `t` already exists on line 34. | Replace every `_textTheme(scheme)` with `t`. |
| 12 | nit | `app_theme.dart:41` | `splashFactory: InkRipple.splashFactory` overrides the M3 default (`InkSparkle`) with no stated reason. | Delete line 41. |
| 13 | nit | `group_details_page.dart:646` | `Card(margin: EdgeInsets.zero)` duplicates `cardTheme.margin: EdgeInsets.zero` (`app_theme.dart:55`). | Delete line 646. |
| 14 | nit | `add_expense_page.dart:445` | Success-snack icon uses `colorScheme.primary` on `inverseSurface`; every other page uses `onInverseSurface`. | `scheme.onInverseSurface`. |
| 15 | nit | `main.dart:128, 233` | Web fallback still uses `headlineMedium` + `FontWeight.bold`/`w500` (off-scale). Web-only. | `titleLarge`/`labelLarge` if anyone cares. |

**Dark-mode grep (clean):** `Colors.` = **0**, `inversePrimary` = **0**, `Color(0x` = **0** outside `lib/theme/` (only `seed`, `warmAccent`, `warmOn` constants live there). The two `withValues(alpha: 0.1 / 0.6)` calls (`add_expense_page.dart:894, 1428`) are derived from `scheme.primary` → token-safe. The only hardcoded color that misbehaves in dark is finding #5's *absence* of usage, not a literal.

**8pt / type grid:** `EdgeInsets` ∈ {0, 2, 8, 16, 24, 32} (only the `2` at #9); `SizedBox` heights ∈ {8,16,24,32,56} + spinner sizes 20/22 (excluded); radii ∈ {16, 20} + 8/12 outliers (#9).

## What I would delete

1. `app_theme.dart:139` — the transparent sheet color (#1). Nothing to replace, default is correct.
2. `memberCounts` pipeline in `groups_list_page.dart` (#6) — ~25 lines, 2+ queries per event, buys a caption. `GroupBalanceView` already carries the balance chip.
3. The "Refresh" `ListTile` in `_moreTab` (`group_details_page.dart:790-795`) — the AppBar already has a refresh IconButton at 512-516. Same action, twice.
4. `AppTheme.warmOn` **or** its two unused call sites (#5) — a private helper nobody calls is inventory, not API.
5. `GroupBalanceView.balanceText()` (`models/group.dart:48`) — orphaned by the card rewrite in `groups_list_page.dart`; zero call sites left.
6. The duplicated `totalPaid`/`fairShare` folds: `_buildDashboardHeader:598-602` and `_buildEventInfoCard:919-923` compute the same thing → `double get _totalPaid`, `double get _fairShare`.
7. `_textTheme(scheme)` recomputes (#11) and `splashFactory` (#12) — pure noise.
8. Not redesign debt, but same bug class: `create_group_page.dart:64-66, 162` one-shot dialog controllers are still never disposed (identical at baseline) — while the F6 fix correctly disposed `group_details`' sheet/dialog controllers (`group_details_page.dart:377, 463-464`), history's `_searchController` (`expense_history_page.dart:63`), and add_expense's 5 (`add_expense_page.dart:107-117`). Worth a 5-line follow-up for consistency.

## Verified preserved (via `git diff HEAD`, not memory)

- **Add/edit expense:** `_saveExpense` still `Navigator.pop(true)` (`add_expense_page.dart:460`); edit path keys off `widget.existingExpense` (438, 521). Diff contains **zero** changed lines matching `validate|enteredSum|totalPercent|participantIds|splitType|Navigator` — validation and navigation are untouched; only `backgroundColor:` lines were removed.
- **Split validation (equal/unequal/percentage):** `_validateUnequalSplit` (193) and `_validatePercentageSplit` (257) are byte-identical except snackbar colors; the guard calls at 323/341 and every message string are unchanged. Summary bands `_buildSplitInfoText` (997) and `_buildPercentageSummary` (1333) keep the same four-way logic (`> +0.01`, `<= 0.01`, empty-count, perfect) — only `Colors.*` → `colorScheme.*Container`.
- **Delete expense:** dialog (`group_details:168-196`) → `_deleteExpense` (198-212) unchanged apart from snackbar source.
- **Mark as paid:** `_showMarkAsPaidDialog` (1373) → `_markAsPaid` (122) → `_loadGroupData()` reload intact.
- **Rename / add member:** `updateGroupName` (278) and `addNewMemberToGroup` (435) calls identical to baseline; `mounted`/`bottomSheetContext.mounted` guards kept (282, 287); controllers disposed at 377 / 463-464 (F6 confirmed).
- **Share/export:** `_shareGroupSummary` (139-151) moved from old AppBar (HEAD:648) to More tab (779-783); `generateGroupSummary` call unchanged.
- **History filtering:** `_getFilteredEntries` (105-112) is a whitespace-only hunk; category chips converted `ListView`→`ListView.builder` with identical add/remove semantics; `All` chip still clears the set; group name preserved in `_buildIntro` after the AppBar title was dropped.
- **Profile / currency / theme prefs:** `_saveProfile` → `pop(true)` (`profile_page.dart:125`); currency chip list untouched; theme dialog still calls `updateThemeMode(value)` (`groups_list_page.dart:90`) → `themeNotifier` + prefs (`main.dart:17-33`) unbroken; `GroupsListPage` refreshes unconditionally after profile (`groups_list_page.dart:69-74`).
- **Navigation contracts:** `result == true` refreshes kept at `group_details:163, 492` and `groups_list:130`; `create_group:245` `pop(true)`; `login:64` / `groups_list:53` `pushReplacement`.
- **Spec items:** debug banner off (`main.dart:97`), overscroll stretch removed app-wide via `scrollBehavior` (`main.dart:38-47, 96`), every color from `ColorScheme`, Event page restructured to `_buildDashboardHeader` + `IndexedStack` of `_settleTab/_expensesTab/_statsTab/_moreTab` + `NavigationBar` (551-586) with all baseline content still reachable (info card + stats → Stats tab; share/edit/history → More tab).
- **State:** `IndexedStack` + plain `int _tabIndex`/`_goToTab` (34, 497-502) has no mounted/`setState` hazards; all async `context` uses are `mounted`-guarded (126, 133, 147, 202, 208, 282, 291). Pre-existing, unchanged: `_loadGroupData` setState-after-await without a `mounted` guard (82, 94).

## Recommendation

**Fix #1 (one line, `app_theme.dart:139`), then ship.** No blockers; nothing here endangers data or flows. Findings #2-#5 are worth a single 15-minute polish pass (type scale + amber contrast), #6-#8 are the ones I'd actually *delete* rather than rework, and #9-#15 can ride in the next cleanup.
