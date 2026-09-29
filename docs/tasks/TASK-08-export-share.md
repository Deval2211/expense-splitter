# TASK-08: Export / Share Group Summary

> **Target Model:** Small / Free AI Models  
> **Status:** Ready for implementation  
> **Complexity:** Medium  
> **Target Path:** `/home/deval/Projects/expense-splitter/docs/tasks/TASK-08-export-share.md`

---

## 1. Overview

This task adds an **Export / Share Group Summary** feature to the Expense Splitter app.  
Users can share a neatly structured text summary of any group/event (including total group expenses, individual member contributions, pending settlements, and completed settlements) to external apps (such as WhatsApp, Email, Notes, SMS, or Telegram) using the system's native share sheet.

---

## 2. Files to Create and Modify

1. **CREATE**: `/home/deval/Projects/expense-splitter/lib/utils/export.dart`
2. **MODIFY**: `/home/deval/Projects/expense-splitter/pubspec.yaml`
3. **MODIFY**: `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`

---

## 3. Summary Text Template

The summary text produced by `generateGroupSummary` must follow this exact format:

```text
📊 Group Summary: Trip to Goa
----------------------------------------
💰 Total Expenses: ₹15,450.00
👥 Total Members: 4

💳 Member Contributions:
  • Alice: Paid ₹8,000.00
  • Bob: Paid ₹5,000.00
  • Charlie: Paid ₹2,450.00
  • Dave: Paid ₹0.00

⏳ Pending Settlements:
  • Dave owes Alice: ₹3,862.50
  • Charlie owes Bob: ₹1,412.50

✅ Completed Settlements:
  • Dave paid Charlie: ₹500.00
----------------------------------------
Shared via Expense Splitter
```

*Note:*
- If there are no pending settlements, show: `  All settled up! 🎉`
- If there are no completed settlements, show: `  No completed settlements yet.`

---

## 4. Step-by-Step Implementation Instructions

### Step 1: Add `share_plus` to `pubspec.yaml`

Open `/home/deval/Projects/expense-splitter/pubspec.yaml`.

#### Current Dependencies in `pubspec.yaml` (Lines 30 to 45):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_web_plugins:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0
  path: ^1.8.3
  shared_preferences: ^2.2.2
  uuid: ^4.0.0
```

#### Replacement Code in `pubspec.yaml`:

Add `share_plus: ^10.0.0` under `dependencies:` as shown below:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_web_plugins:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0
  path: ^1.8.3
  shared_preferences: ^2.2.2
  uuid: ^4.0.0
  share_plus: ^10.0.0
```

After modifying `pubspec.yaml`, run in terminal:
```bash
flutter pub get
```

---

### Step 2: Create `lib/utils/export.dart`

Create a new file at `/home/deval/Projects/expense-splitter/lib/utils/export.dart` with the complete code below:

```dart
import '../repositories/group_repository.dart';

/// Generates a clean, readable plain-text summary of a group's expenses and settlements.
Future<String> generateGroupSummary(GroupRepository repo, String groupId) async {
  final group = await repo.getGroupById(groupId);
  final groupName = group?.name ?? 'Group';

  final members = await repo.getGroupMembersWithPayments(groupId);
  final pending = await repo.calculatePendingSettlements(groupId);
  final completed = await repo.getGroupSettlements(groupId);

  final totalAmount = members.fold<double>(
    0.0,
    (sum, m) => sum + m.amountPaid,
  );

  final buffer = StringBuffer();
  buffer.writeln('📊 Group Summary: $groupName');
  buffer.writeln('----------------------------------------');
  buffer.writeln('💰 Total Expenses: ₹${totalAmount.toStringAsFixed(2)}');
  buffer.writeln('👥 Total Members: ${members.length}');
  buffer.writeln();

  buffer.writeln('💳 Member Contributions:');
  if (members.isEmpty) {
    buffer.writeln('  No members recorded.');
  } else {
    for (final member in members) {
      buffer.writeln('  • ${member.userName}: Paid ₹${member.amountPaid.toStringAsFixed(2)}');
    }
  }
  buffer.writeln();

  buffer.writeln('⏳ Pending Settlements:');
  if (pending.isEmpty) {
    buffer.writeln('  All settled up! 🎉');
  } else {
    for (final s in pending) {
      buffer.writeln('  • ${s.fromUserName} owes ${s.toUserName}: ₹${s.amount.toStringAsFixed(2)}');
    }
  }
  buffer.writeln();

  buffer.writeln('✅ Completed Settlements:');
  if (completed.isEmpty) {
    buffer.writeln('  No completed settlements yet.');
  } else {
    for (final s in completed) {
      buffer.writeln('  • ${s.fromUserName} paid ${s.toUserName}: ₹${s.amount.toStringAsFixed(2)}');
    }
  }

  buffer.writeln('----------------------------------------');
  buffer.writeln('Shared via Expense Splitter');

  return buffer.toString();
}
```

---

### Step 3: Modify `lib/pages/group_details_page.dart`

We need to:
1. Import `package:share_plus/share_plus.dart` and `../utils/export.dart`.
2. Add a Share icon button to the `AppBar` `actions` list.
3. Add a `_shareGroupSummary()` method in `_GroupDetailsPageState`.

#### Current Imports in `lib/pages/group_details_page.dart` (Lines 1 to 8):

```dart
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/settlement.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import 'add_expense_page.dart';
```

#### Replacement Imports:

Replace lines 1 to 8 with:

```dart
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/settlement.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import '../utils/export.dart';
import 'add_expense_page.dart';
```

---

#### Current AppBar Code in `lib/pages/group_details_page.dart` (Lines 111 to 122):

```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Settlement'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupData,
            tooltip: 'Refresh',
          ),
        ],
      ),
```

#### Replacement AppBar Code:

Replace lines 111 to 122 with:

```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Settlement'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareGroupSummary,
            tooltip: 'Share Summary',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupData,
            tooltip: 'Refresh',
          ),
        ],
      ),
```

---

#### Add Method `_shareGroupSummary()` inside `_GroupDetailsPageState`:

Add the following method inside `_GroupDetailsPageState` (for instance, right after `_markAsPaid()` around line 107):

```dart
  Future<void> _shareGroupSummary() async {
    try {
      final summary = await generateGroupSummary(
        _groupRepository,
        widget.groupBalanceView.group.id,
      );
      await Share.share(
        summary,
        subject: '${widget.groupBalanceView.group.name} - Summary',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share summary: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }
```

---

## 5. Testing Checklist

Execute these checks after applying the changes:

- [ ] **Dependencies Resolved**: Run `flutter pub get` and verify it exits with code 0.
- [ ] **Run Code Analysis**: Run `flutter analyze` and confirm 0 errors or warnings.
- [ ] **AppBar Share Icon**: Open any group details page (`GroupDetailsPage`). Confirm a Share icon (`Icons.share`) appears in the top-right AppBar alongside the Refresh icon.
- [ ] **Trigger Share**: Tap the Share icon:
  - Verify that the native system share sheet opens.
  - The shared text contains the group name, total expenses, member contributions, pending settlements, and completed settlements.
- [ ] **Verify Empty / Settled States**:
  - Open a group that has no pending settlements. Tap Share and verify the text shows `All settled up! 🎉`.
  - Open a group with pending settlements. Tap Share and verify each debtor-creditor pair is listed correctly with amounts formatted as `₹XX.XX`.
  - Mark a settlement as paid, tap Share again, and verify the completed settlement appears under `✅ Completed Settlements`.
