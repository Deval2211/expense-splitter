# TASK-04: Expense History Timeline Page

> **Target Audience:** Small or free AI models.  
> **Self-Contained Rule:** This file contains all necessary code, context, exact paths, and step-by-step instructions. You do not need to look at any other documentation to complete this task.

---

## 1. Overview & Objectives

In the Expense Splitter app, groups (also called "Events") allow members to record expenses and settle debts. Currently, the Group Details page displays pending and completed settlements, but there is no chronological timeline showing the complete history of all transactions (expenses logged + settlements made).

### What you will build:
1. A new screen: `ExpenseHistoryPage` in `lib/pages/expense_history_page.dart`.
2. A unified activity list merging both `Expense` records and `Settlement` records into a single timeline sorted chronologically (newest first).
3. Visual cards for each entry:
   - **Expense:** shows description, total amount, payer name, category chip with category icon, and formatted date/time.
   - **Settlement:** shows "{from} paid {to}", amount, green checkmark icon, "Settlement" badge, and formatted date/time.
4. An empty state when no expenses or settlements exist.
5. Navigation: A history icon button in the top AppBar of `GroupDetailsPage` (`lib/pages/group_details_page.dart`) that opens `ExpenseHistoryPage`.

---

## 2. File Operations Summary

| Action | File Path |
|---|---|
| **CREATE** | `/home/deval/Projects/expense-splitter/lib/pages/expense_history_page.dart` |
| **MODIFY** | `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart` |

---

## 3. Data Models & Architecture Reference

The app uses SQLite via `AppDatabase` (`lib/database/database.dart`) and `GroupRepository` (`lib/repositories/group_repository.dart`).

### Available Repository Methods
`GroupRepository` provides these two methods for fetching group data:
- `Future<List<Expense>> getGroupExpenses(String groupId)`
- `Future<List<Settlement>> getGroupSettlements(String groupId)`

### `Expense` Model (`lib/models/expense.dart`)
Key fields:
- `id` (`String`): UUID of the expense
- `groupId` (`String`): ID of the group
- `description` (`String?`): Optional description (e.g., "Dinner", "Fuel")
- `category` (`String`): Category key, default `'other'` (e.g. `'food'`, `'transport'`)
- `note` (`String?`): Optional extra details
- `amount` (`double`): Total amount paid
- `paidByUserId` (`String`): Payer user ID
- `paidByUserName` (`String`): Payer name
- `participantIds` (`List<String>`): List of participant IDs
- `createdAt` (`int`): Milliseconds since epoch

Category dictionary available via `expenseCategories` in `lib/models/expense.dart`:
```dart
const Map<String, String> expenseCategories = {
  'food': 'Food and Drinks',
  'transport': 'Transport',
  'accommodation': 'Accommodation',
  'entertainment': 'Entertainment',
  'groceries': 'Groceries',
  'utilities': 'Utilities',
  'shopping': 'Shopping',
  'health': 'Health',
  'other': 'Other',
};
```

### `Settlement` Model (`lib/models/settlement.dart`)
Key fields:
- `id` (`String`): UUID of the settlement
- `groupId` (`String`): ID of the group
- `fromUserId` (`String`): Payer user ID
- `fromUserName` (`String`): Payer name
- `toUserId` (`String`): Recipient user ID
- `toUserName` (`String`): Recipient name
- `amount` (`double`): Amount settled
- `isPaid` (`bool`): Settlement completed status
- `paidAt` (`int?`): Milliseconds since epoch when payment was marked as paid

### `GroupBalanceView` (`lib/models/group.dart`)
Passed as parameter to `ExpenseHistoryPage`:
- `group.id` (`String`): ID of group
- `group.name` (`String`): Name of group
- `netBalance` (`double`): User's net balance in group

---

## 4. STEP 1: Create `lib/pages/expense_history_page.dart`

Create `/home/deval/Projects/expense-splitter/lib/pages/expense_history_page.dart` with the complete, self-contained code below:

```dart
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/settlement.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';

/// Type of entry in the activity timeline
enum TimelineEntryType { expense, settlement }

/// Unified wrapper representing either an Expense or a Settlement
class TimelineEntry {
  final TimelineEntryType type;
  final Expense? expense;
  final Settlement? settlement;
  final int timestamp;

  TimelineEntry.fromExpense(Expense item)
      : type = TimelineEntryType.expense,
        expense = item,
        settlement = null,
        timestamp = item.createdAt;

  TimelineEntry.fromSettlement(Settlement item)
      : type = TimelineEntryType.settlement,
        expense = null,
        settlement = item,
        timestamp = item.paidAt ?? 0;

  bool get isExpense => type == TimelineEntryType.expense;
  bool get isSettlement => type == TimelineEntryType.settlement;
}

class ExpenseHistoryPage extends StatefulWidget {
  final GroupBalanceView groupBalanceView;

  const ExpenseHistoryPage({
    super.key,
    required this.groupBalanceView,
  });

  @override
  State<ExpenseHistoryPage> createState() => _ExpenseHistoryPageState();
}

class _ExpenseHistoryPageState extends State<ExpenseHistoryPage> {
  late GroupRepository _groupRepository;
  List<TimelineEntry> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final database = AppDatabase();
    _groupRepository = GroupRepository(database: database);
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groupId = widget.groupBalanceView.group.id;

      // 1. Fetch expenses and completed settlements from database
      final expenses = await _groupRepository.getGroupExpenses(groupId);
      final settlements = await _groupRepository.getGroupSettlements(groupId);

      // 2. Merge into unified list
      final List<TimelineEntry> combined = [
        ...expenses.map((e) => TimelineEntry.fromExpense(e)),
        ...settlements.map((s) => TimelineEntry.fromSettlement(s)),
      ];

      // 3. Sort chronologically descending (most recent first)
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _entries = combined;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load history: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(int timestamp) {
    if (timestamp <= 0) return 'Date unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;

    final hourInt = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year $hour:$minute $period';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'accommodation':
        return Icons.hotel;
      case 'entertainment':
        return Icons.movie;
      case 'groceries':
        return Icons.shopping_basket;
      case 'utilities':
        return Icons.power;
      case 'shopping':
        return Icons.shopping_bag;
      case 'health':
        return Icons.local_hospital;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.groupBalanceView.group.name;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              groupName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadHistoryData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Activity Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Expenses and completed settlements will appear here in chronological order.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistoryData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _entries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          if (entry.isExpense) {
            return _buildExpenseCard(entry.expense!);
          } else {
            return _buildSettlementCard(entry.settlement!);
          }
        },
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final categoryLabel = expenseCategories[expense.category] ?? expense.category;
    final dateStr = _formatDateTime(expense.createdAt);
    final description = (expense.description != null && expense.description!.isNotEmpty)
        ? expense.description!
        : 'Expense';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paid by ${expense.paidByUserName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${expense.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    categoryLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ],
            ),
            if (expense.note != null && expense.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${expense.note!}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementCard(Settlement settlement) {
    final dateStr = _formatDateTime(settlement.paidAt ?? 0);

    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.green.shade100,
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: settlement.fromUserName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' paid '),
                            TextSpan(
                              text: settlement.toUserName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Settlement',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${settlement.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade800,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 5. STEP 2: Modify `lib/pages/group_details_page.dart`

File to modify: `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`

### Change 1: Add import statement
Locate the imports at the top of the file (lines 1 to 7):

**CURRENT CODE:**
```dart
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/settlement.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import 'add_expense_page.dart';
```

**CHANGE TO:**
```dart
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/settlement.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import 'add_expense_page.dart';
import 'expense_history_page.dart';
```

---

### Change 2: Add history IconButton to the AppBar actions
Locate the `AppBar` definition (lines 112 to 122):

**CURRENT CODE:**
```dart
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

**CHANGE TO:**
```dart
      appBar: AppBar(
        title: const Text('Event Settlement'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ExpenseHistoryPage(
                    groupBalanceView: widget.groupBalanceView,
                  ),
                ),
              );
            },
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

## 6. Testing Checklist

Execute these checks after making the changes:

- [ ] **Static Analysis:** Run `flutter analyze` and confirm zero errors or warnings.
- [ ] **Navigation Check:**
  - Launch app, tap any existing event on the Groups page.
  - Verify that a clock/history icon (`Icons.history`) is visible in the AppBar.
  - Tap the history button. Confirm `ExpenseHistoryPage` opens and displays the event name in the AppBar subtitle.
- [ ] **Empty State:**
  - In an event with no expenses or settlements, confirm the "No Activity Yet" empty state illustration and text is shown.
- [ ] **Expense Display:**
  - Add an expense in the event.
  - Open the history timeline.
  - Confirm the expense card displays:
    - Description (or "Expense" fallback)
    - Payer name ("Paid by {name}")
    - Category chip with correct category label
    - Correct amount formatted with `₹`
    - Formatted date and time
- [ ] **Settlement Display:**
  - Settle a debt in the event (tap "Mark as Paid").
  - Open the history timeline.
  - Confirm a light-green settlement card displays:
    - Checkmark icon
    - "{fromUser} paid {toUser}"
    - "Settlement" label badge
    - Amount formatted with `₹`
    - Formatted timestamp
- [ ] **Ordering:**
  - Ensure newest entries appear at the top and older entries appear below.
- [ ] **Pull to Refresh:**
  - Drag down the list to verify `RefreshIndicator` triggers and reloads the data.
- [ ] **Back Navigation:**
  - Tap the AppBar back arrow and verify smooth return to `GroupDetailsPage`.
