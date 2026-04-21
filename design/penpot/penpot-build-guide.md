# Expense Splitter - Penpot As-Built Design Guide

This guide maps the design directly to the current Flutter implementation in this repository.

Reference date: 18 April 2026.

## Source Of Truth

Use these files as source of truth for UI behavior:

1. lib/main.dart
2. lib/pages/login_page.dart
3. lib/pages/groups_list_page.dart
4. lib/pages/create_group_page.dart
5. lib/pages/group_details_page.dart
6. lib/pages/add_expense_page.dart
7. lib/models/expense.dart

Design only what exists in code today. Do not add speculative features.

## Theme Baseline (As Implemented)

1. Theme engine: Flutter Material 3 (`useMaterial3: true`).
2. Seed color: `Colors.deepPurple`.
3. App bar fill: `colorScheme.inversePrimary`.
4. Typography: default Material text theme (system Roboto on Android).
5. Surfaces: white and light neutral cards.
6. State/status colors used in code:
- Positive: green shades.
- Negative/error: red shades.
- Pending/warning: orange shades.
- Informational: blue shades.

## Files

1. expense-splitter-as-built-tokens.json
2. penpot-build-guide.md

## Import Tokens In Penpot

1. Open Penpot and create or open file `Expense Splitter`.
2. Open the Tokens panel.
3. Click Tools > Import.
4. Select `expense-splitter-as-built-tokens.json`.
5. Confirm import.

After import:

1. Theme group `Mode` appears.
2. Theme `Light` is active by default.

## Build Pages In Penpot

1. 00 Cover - As Built
2. 01 Foundations
3. 02 Components
4. 03 Screens Mobile
5. 04 Flows And States
6. 05 Web Fallback (Optional)

## Frame Sizes

1. Mobile primary frame: 390 x 844.
2. Optional web fallback reference: 1280 x 900.

## Layout And Sizing Rules (From Code)

1. Standard screen padding: 16.
2. Login screen padding: horizontal 24, vertical 40.
3. Common section gap: 24.
4. Input/button corner radius: mostly 8.
5. Card corner radius: 8 or 12 depending on screen.
6. Primary CTA height: 48.
7. Save Expense CTA height: 50.
8. Minimum touch target: 44.
9. FAB size: Material default (56).

## Components To Build (Only Implemented Variants)

1. App Bars
- Title only.
- Title + popup menu (Logout on Events Home).
- Title + refresh icon (Event Settlement).

2. Buttons
- Elevated primary.
- Elevated icon (refresh, mark as paid, add expense).
- Outlined button (Add Friend).
- Text button (dialog cancel/select actions).
- FloatingActionButton and FloatingActionButton.extended.
- Disabled/loading states for Continue, Create Event, Save Expense.

3. Form Inputs
- Text field (name, event name, description).
- Phone field.
- Amount field with `₹` prefix.
- Dropdown field (Category, Paid By).
- Multiline note field.
- Inline validator/error text.

4. Cards
- Overall balance summary card (owed/owe/settled).
- Event list card.
- Member cards (creator/friends).
- Event info card.
- Expense insights card.
- Pending settlement card.
- Completed settlement card.
- All settled success card.

5. List Items And Rows
- Event rows with chevron.
- Pending settlement rows with amount badge and CTA.
- Completed settlement rows with date.
- Member rows with avatar and paid amount.
- Participant selection rows with checkbox.
- Unequal consumption rows with compact amount field.

6. Chips/Badges
- Pending/settled count chip in section headers.
- Amount badges in settlement cards.

7. Dialogs
- Add Friend dialog.
- Your Payment dialog.
- Confirm Payment dialog.

8. Feedback/States
- Full page loading spinner.
- Inline button loading spinner.
- Retry error block (icon + message + retry button).
- Empty events state.
- Snackbars: success, warning, error.

## Screens To Design Exactly

1. Profile Setup (`LoginPage`)
- Title: `Welcome`.
- Subtitle: `Let's set up your profile`.
- Inputs: `Name`, `Phone (Optional)`.
- CTA: `Continue`.
- Error banner container for profile creation failure.

2. Events Home (`GroupsListPage`)
- App bar title: `Events`.
- Overflow menu item: `Logout`.
- Summary card title: `Your overall balance`.
- Balance text states:
	- `You are owed ₹...`
	- `You owe ₹...`
	- `Settled up`
- Event cards with status subtitle + chevron.
- Empty state copy:
	- `No events yet`
	- `Tap + to create your first event`
- FAB tooltip/action: `Add Event`.

3. Create Event (`CreateGroupPage`)
- Section: `Event Details`.
- Input: `Event Name *`.
- Section: `Members` with live member count and total paid.
- Creator card with editable `Paid: ₹...`.
- Friend rows with optional phone and remove action.
- `Add Friend` outlined button.
- CTA: `Create Event`.
- Error container + loading state.

4. Add Friend Dialog
- Title: `Add Friend`.
- Inputs: `Name *`, `Phone (Optional)`, `Amount Paid`.
- Actions: `Cancel`, `Add`.

5. Your Payment Dialog
- Title: `Your Payment`.
- Input: `Amount Paid`.
- Actions: `Cancel`, `Save`.

6. Event Settlement (`GroupDetailsPage`)
- App bar title: `Event Settlement` + refresh icon.
- Event info card with:
	- Event name.
	- `Total Amount`.
	- `Per Person Share`.
	- `Total Members`.
	- `Payment Details` member list.
- Conditional `Expense Insights` card with:
	- `Expenses Logged`.
	- `Average Expense`.
	- `Category Breakdown` with progress bars.
	- `Member Net Position`.
- Pending settlements section + count chip.
- Pending rows: `A owes B`, amount badge, `Mark as Paid` button.
- Empty pending variant card:
	- `All Settled! 🎉`
	- `No pending payments`
- Completed settlements section + rows with date and amount.
- Extended FAB: `Add Expense`.
- Pull-to-refresh behavior.

7. Confirm Payment Dialog
- Title: `Confirm Payment`.
- Message confirms debtor, creditor, amount.
- Actions: `Cancel`, `Confirm`.

8. Add Expense (`AddExpensePage`)
- Card: `Expense Details`.
- Fields:
	- `Amount *`
	- `Description`
	- `Category`
	- `Note (Optional)`
	- `Paid By *`
- Card: `Split Type` with two selectable tiles:
	- `Equal Split` / `Divide equally`
	- `Unequal Split` / `By consumption`
- Equal split card:
	- Participant rows with checkbox.
	- `Select All` and `Clear All` actions.
	- Split info banner when amount + participants exist.
- Unequal split card:
	- Member consumption input rows.
	- Dynamic summary states:
		- Error: exceeds total.
		- Warning: missing amount.
		- Info: auto-distribution.
		- Success: perfect match.
- CTA: `Save Expense` with loading label `Saving...`.

9. Web Fallback (Optional, `WebFallbackPage`)
- App bar: `Expense Splitter`.
- Hero labels: `Expense Splitter`, `Web Demo Mode`.
- Info panel: `Local Storage Required`.
- Platform chips: Android, iOS, Windows, macOS, Linux.
- CTA: `Get Native App`.

## Navigation Flow (As-Built)

1. App start checks `currentUserId` in SharedPreferences.
2. If no user: Profile Setup screen.
3. If user exists: Events Home.
4. Events Home `+` -> Create Event.
5. Event card tap -> Event Settlement.
6. Create Event `Add Friend` -> Add Friend dialog.
7. Event Settlement `Add Expense` -> Add Expense.
8. Pending settlement `Mark as Paid` -> Confirm Payment dialog.

## Motion

1. No custom animation system is implemented.
2. Use default Material motion behavior for buttons, dialogs, page transitions, and refresh indicator.

## Content Rules

1. Currency is always Indian Rupee with 2 decimals (example: `₹1240.00`).
2. Keep labels and CTA copy exactly as in code for parity.
3. Maintain minimum 44 touch targets and readable contrast.

## Deliverables

1. Full mobile flow that matches coded screens and labels exactly.
2. Component page with implemented states only.
3. Foundations page driven by `expense-splitter-as-built-tokens.json`.
4. Optional web fallback artboard.
