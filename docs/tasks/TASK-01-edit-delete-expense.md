# TASK-01: Edit and Delete Expense

## 1. Overview
In this task, you will implement the ability to **edit** and **delete** expenses in the Flutter expense-splitter application. 

Currently, users can add expenses, but cannot modify or delete them once created. After completing this task:
1. In the **Event Settlement (Group Details) page**, an **Expenses** section will display all expenses logged for the group.
2. Each expense card will feature an **Edit** button and a **Delete** button.
3. Tapping **Delete** will show a confirmation dialog. Upon confirmation, the expense and its participant entries will be deleted atomically via a database transaction, and the UI (balances, settlements, stats) will refresh.
4. Tapping **Edit** will open the `AddExpensePage` in edit mode, pre-populated with the expense's details (amount, description, category, note, payer, and participants). Saving updates the existing record and its participants in SQLite, then refreshes the group details.

---

## 2. Files to Modify (Full Paths)
1. `/home/deval/Projects/expense-splitter/lib/repositories/group_repository.dart`
   - Add `updateExpense(...)` method.
   - Add `deleteExpense(...)` method.
2. `/home/deval/Projects/expense-splitter/lib/pages/add_expense_page.dart`
   - Add optional `existingExpense` parameter to `AddExpensePage`.
   - Pre-populate form controllers and state variables when `existingExpense` is present.
   - Change AppBar title to "Edit Expense" and button text to "Update Expense".
   - Call `updateExpense` on `GroupRepository` when saving in edit mode.
3. `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`
   - Fetch and hold group expenses in state (`_expenses`).
   - Add an **Expenses** section to the UI displaying cards for each expense with Edit and Delete action buttons.
   - Implement `_showDeleteExpenseDialog` and `_deleteExpense`.
   - Implement `_navigateToEditExpense`.

---

## 3. Database Context & Schema
The SQLite database has two related tables for expenses:
- `expenses`:
  - `id` (TEXT PRIMARY KEY)
  - `groupId` (TEXT, FOREIGN KEY references groups(id))
  - `paidByUserId` (TEXT, FOREIGN KEY references users(id))
  - `amount` (REAL NOT NULL)
  - `description` (TEXT)
  - `category` (TEXT NOT NULL DEFAULT 'other')
  - `note` (TEXT)
  - `splitType` (TEXT NOT NULL DEFAULT 'equal')
  - `createdAt` (INTEGER NOT NULL)
- `expense_participants`:
  - `expenseId` (TEXT, FOREIGN KEY references expenses(id))
  - `userId` (TEXT, FOREIGN KEY references users(id))
  - PRIMARY KEY (`expenseId`, `userId`)

### Foreign Key & Transaction Rule:
- When deleting an expense, delete from `expense_participants` **first**, then delete from `expenses`. Both deletions MUST be in a single `db.transaction`.
- When updating an expense, update `expenses`, delete all rows from `expense_participants` matching `expenseId`, and re-insert the updated participants into `expense_participants`. All three operations MUST run in a single `db.transaction`.

---

## 4. Step-by-Step Implementation Instructions

### Step 1: Update `GroupRepository`
**Target File**: `/home/deval/Projects/expense-splitter/lib/repositories/group_repository.dart`

#### A. Locate the existing `addExpense` method (around line 487 to 541):
```dart
  /// Add a new expense with participants (atomic transaction)
  Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidByUserId,
    required List<String> participantIds,
    String category = 'other',
    String? note,
    String splitType = 'equal',
  }) async {
    final db = await _database.database;
    final expenseId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanedParticipantIds = participantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (amount <= 0) {
      throw ArgumentError('Expense amount must be greater than zero');
    }

    if (cleanedParticipantIds.isEmpty) {
      throw ArgumentError('At least one participant is required');
    }

    try {
      await db.transaction((txn) async {
        // 1. Insert the expense
        await txn.insert('expenses', {
          'id': expenseId,
          'groupId': groupId,
          'paidByUserId': paidByUserId,
          'amount': amount,
          'description': description,
          'category': category,
          'note': note,
          'splitType': splitType,
          'createdAt': now,
        });

        // 2. Insert all participants
        for (final participantId in cleanedParticipantIds) {
          await txn.insert('expense_participants', {
            'expenseId': expenseId,
            'userId': participantId,
          });
        }
      });
    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }
```

#### B. Add `updateExpense` and `deleteExpense` directly below `addExpense`:
Insert the following two methods immediately after `addExpense`:

```dart
  /// Update an existing expense with participants (atomic transaction)
  Future<void> updateExpense({
    required String expenseId,
    required String description,
    required double amount,
    required String paidByUserId,
    required List<String> participantIds,
    String category = 'other',
    String? note,
    String splitType = 'equal',
  }) async {
    final db = await _database.database;
    final cleanedParticipantIds = participantIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (amount <= 0) {
      throw ArgumentError('Expense amount must be greater than zero');
    }

    if (cleanedParticipantIds.isEmpty) {
      throw ArgumentError('At least one participant is required');
    }

    try {
      await db.transaction((txn) async {
        // 1. Update the expense row
        await txn.update(
          'expenses',
          {
            'paidByUserId': paidByUserId,
            'amount': amount,
            'description': description,
            'category': category,
            'note': note,
            'splitType': splitType,
          },
          where: 'id = ?',
          whereArgs: [expenseId],
        );

        // 2. Remove old participants
        await txn.delete(
          'expense_participants',
          where: 'expenseId = ?',
          whereArgs: [expenseId],
        );

        // 3. Re-insert new participants
        for (final participantId in cleanedParticipantIds) {
          await txn.insert('expense_participants', {
            'expenseId': expenseId,
            'userId': participantId,
          });
        }
      });
    } catch (e) {
      debugPrint('Error updating expense: $e');
      rethrow;
    }
  }

  /// Delete an expense and its participants (atomic transaction)
  Future<void> deleteExpense(String expenseId) async {
    final db = await _database.database;
    try {
      await db.transaction((txn) async {
        // 1. Delete participants first due to foreign key relation
        await txn.delete(
          'expense_participants',
          where: 'expenseId = ?',
          whereArgs: [expenseId],
        );

        // 2. Delete the expense
        await txn.delete(
          'expenses',
          where: 'id = ?',
          whereArgs: [expenseId],
        );
      });
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      rethrow;
    }
  }
```

---

### Step 2: Update `AddExpensePage` to Support Editing
**Target File**: `/home/deval/Projects/expense-splitter/lib/pages/add_expense_page.dart`

#### A. Update `AddExpensePage` widget class declaration
**CURRENT CODE (lines 25–33)**:
```dart
class AddExpensePage extends StatefulWidget {
  final GroupBalanceView groupBalanceView;

  const AddExpensePage({super.key, required this.groupBalanceView});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}
```

**REPLACE WITH**:
```dart
class AddExpensePage extends StatefulWidget {
  final GroupBalanceView groupBalanceView;
  final Expense? existingExpense;

  const AddExpensePage({
    super.key,
    required this.groupBalanceView,
    this.existingExpense,
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}
```

#### B. Update `initState` in `_AddExpensePageState`
Pre-fill the controllers and fields when `widget.existingExpense` is provided.

**CURRENT CODE (lines 57–62)**:
```dart
  @override
  void initState() {
    super.initState();
    final database = AppDatabase();
    _groupRepository = GroupRepository(database: database);
    _loadGroupMembers();
  }
```

**REPLACE WITH**:
```dart
  @override
  void initState() {
    super.initState();
    final database = AppDatabase();
    _groupRepository = GroupRepository(database: database);

    if (widget.existingExpense != null) {
      final exp = widget.existingExpense!;
      _amountController.text = exp.amount.toStringAsFixed(2);
      _descriptionController.text = exp.description ?? '';
      _noteController.text = exp.note ?? '';
      _selectedCategory = exp.category;
      _selectedPayerId = exp.paidByUserId;
      _splitType =
          exp.splitType == 'unequal' ? SplitType.unequal : SplitType.equal;
      _selectedParticipants = exp.participantIds.toSet();
    }

    _loadGroupMembers();
  }
```

#### C. Update `_loadGroupMembers` in `_AddExpensePageState`
Ensure member loading does NOT overwrite the pre-selected payer or participants when editing.

**CURRENT CODE (lines 86–103)**:
```dart
      setState(() {
        _members = members;
        // Default: select first member as payer
        if (_members.isNotEmpty) {
          _selectedPayerId = _members.first.userId;
        }
        // Default: all members selected as participants for equal split
        _selectedParticipants = _members.map((m) => m.userId).toSet();

        // Initialize consumption controllers for unequal split
        _memberConsumptions = _members
            .map(
              (m) => MemberConsumption(userId: m.userId, userName: m.userName),
            )
            .toList();

        _isLoading = false;
      });
```

**REPLACE WITH**:
```dart
      setState(() {
        _members = members;
        if (widget.existingExpense != null) {
          final exp = widget.existingExpense!;
          _selectedPayerId = exp.paidByUserId;
          _selectedParticipants = exp.participantIds.toSet();
        } else {
          // Default: select first member as payer
          if (_members.isNotEmpty) {
            _selectedPayerId = _members.first.userId;
          }
          // Default: all members selected as participants for equal split
          _selectedParticipants = _members.map((m) => m.userId).toSet();
        }

        // Initialize consumption controllers for unequal split
        _memberConsumptions = _members
            .map(
              (m) => MemberConsumption(userId: m.userId, userName: m.userName),
            )
            .toList();

        _isLoading = false;
      });
```

#### D. Update `_saveExpense` in `_AddExpensePageState`
Handle updating an existing expense.

**CURRENT CODE (lines 257–286)**:
```dart
      if (_splitType == SplitType.equal) {
        // Equal split - single expense with selected participants
        await _groupRepository.addExpense(
          groupId: widget.groupBalanceView.group.id,
          description: expenseDescription,
          amount: amount,
          paidByUserId: _selectedPayerId!,
          participantIds: _selectedParticipants.toList(),
          category: _selectedCategory,
          note: expenseNote,
          splitType: 'equal',
        );
      } else {
        // Unequal split - create individual expenses for each person's consumption
        // This allows the smart settlement merge to work correctly
        for (var consumption in _memberConsumptions) {
          if (consumption.amount != null && consumption.amount! > 0) {
            await _groupRepository.addExpense(
              groupId: widget.groupBalanceView.group.id,
              description: '$expenseDescription - ${consumption.userName}',
              amount: consumption.amount!,
              paidByUserId: _selectedPayerId!,
              participantIds: [consumption.userId], // Only this person consumed
              category: _selectedCategory,
              note: expenseNote,
              splitType: 'unequal',
            );
          }
        }
      }
```

**REPLACE WITH**:
```dart
      if (widget.existingExpense != null) {
        // Update existing expense
        final participantIds = _splitType == SplitType.equal
            ? _selectedParticipants.toList()
            : _memberConsumptions
                .where((c) => (c.amount ?? 0) > 0)
                .map((c) => c.userId)
                .toList();

        await _groupRepository.updateExpense(
          expenseId: widget.existingExpense!.id,
          description: expenseDescription,
          amount: amount,
          paidByUserId: _selectedPayerId!,
          participantIds: participantIds,
          category: _selectedCategory,
          note: expenseNote,
          splitType: _splitType == SplitType.equal ? 'equal' : 'unequal',
        );
      } else {
        if (_splitType == SplitType.equal) {
          // Equal split - single expense with selected participants
          await _groupRepository.addExpense(
            groupId: widget.groupBalanceView.group.id,
            description: expenseDescription,
            amount: amount,
            paidByUserId: _selectedPayerId!,
            participantIds: _selectedParticipants.toList(),
            category: _selectedCategory,
            note: expenseNote,
            splitType: 'equal',
          );
        } else {
          // Unequal split - create individual expenses for each person's consumption
          for (var consumption in _memberConsumptions) {
            if (consumption.amount != null && consumption.amount! > 0) {
              await _groupRepository.addExpense(
                groupId: widget.groupBalanceView.group.id,
                description: '$expenseDescription - ${consumption.userName}',
                amount: consumption.amount!,
                paidByUserId: _selectedPayerId!,
                participantIds: [consumption.userId],
                category: _selectedCategory,
                note: expenseNote,
                splitType: 'unequal',
              );
            }
          }
        }
      }
```

Also update the SnackBar message in `_saveExpense`:
**CURRENT CODE**:
```dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✓ Expense added successfully'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
```

**REPLACE WITH**:
```dart
        final isEditing = widget.existingExpense != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  isEditing
                      ? '✓ Expense updated successfully'
                      : '✓ Expense added successfully',
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
```

#### E. Update AppBar Title & Save Button in `AddExpensePage`
1. Update AppBar title (around line 326):
**CURRENT CODE**:
```dart
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
```
**REPLACE WITH**:
```dart
      appBar: AppBar(
        title: Text(widget.existingExpense != null ? 'Edit Expense' : 'Add Expense'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
```

2. Update Save Button text in `_buildSaveButton` (around lines 1137–1143):
**CURRENT CODE**:
```dart
        label: Text(
          _isSaving ? 'Saving...' : 'Save Expense',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
```
**REPLACE WITH**:
```dart
        label: Text(
          _isSaving
              ? 'Saving...'
              : (widget.existingExpense != null
                  ? 'Update Expense'
                  : 'Save Expense'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
```

---

### Step 3: Update `GroupDetailsPage`
**Target File**: `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`

#### A. Add `_expenses` state variable
In `_GroupDetailsPageState`:
**CURRENT CODE (lines 18–26)**:
```dart
class _GroupDetailsPageState extends State<GroupDetailsPage> {
  late GroupRepository _groupRepository;
  List<GroupMember> _members = [];
  List<Settlement> _pendingSettlements = [];
  List<Settlement> _completedSettlements = [];
  GroupExpenseStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;
```

**REPLACE WITH**:
```dart
class _GroupDetailsPageState extends State<GroupDetailsPage> {
  late GroupRepository _groupRepository;
  List<GroupMember> _members = [];
  List<Expense> _expenses = [];
  List<Settlement> _pendingSettlements = [];
  List<Settlement> _completedSettlements = [];
  GroupExpenseStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;
```

#### B. Load expenses in `_loadGroupData()`
In `_loadGroupData()`:
**CURRENT CODE (lines 41–68)**:
```dart
    try {
      // Load members with their payments
      final members = await _groupRepository.getGroupMembersWithPayments(
        widget.groupBalanceView.group.id,
      );

      // Load pending settlements
      final pending = await _groupRepository.calculatePendingSettlements(
        widget.groupBalanceView.group.id,
      );

      // Load completed settlements
      final completed = await _groupRepository.getGroupSettlements(
        widget.groupBalanceView.group.id,
      );

      // Load stats summary for this group
      final stats = await _groupRepository.getGroupExpenseStats(
        widget.groupBalanceView.group.id,
      );

      setState(() {
        _members = members;
        _pendingSettlements = pending;
        _completedSettlements = completed;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
```

**REPLACE WITH**:
```dart
    try {
      // Load members with their payments
      final members = await _groupRepository.getGroupMembersWithPayments(
        widget.groupBalanceView.group.id,
      );

      // Load all logged expenses
      final expenses = await _groupRepository.getGroupExpenses(
        widget.groupBalanceView.group.id,
      );

      // Load pending settlements
      final pending = await _groupRepository.calculatePendingSettlements(
        widget.groupBalanceView.group.id,
      );

      // Load completed settlements
      final completed = await _groupRepository.getGroupSettlements(
        widget.groupBalanceView.group.id,
      );

      // Load stats summary for this group
      final stats = await _groupRepository.getGroupExpenseStats(
        widget.groupBalanceView.group.id,
      );

      setState(() {
        _members = members;
        _expenses = expenses;
        _pendingSettlements = pending;
        _completedSettlements = completed;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
```

#### C. Add Edit and Delete Navigation / Dialog methods
Add these methods in `_GroupDetailsPageState` (below `_markAsPaid` around line 107):

```dart
  Future<void> _navigateToEditExpense(Expense expense) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddExpensePage(
          groupBalanceView: widget.groupBalanceView,
          existingExpense: expense,
        ),
      ),
    );

    if (result == true) {
      await _loadGroupData();
    }
  }

  void _showDeleteExpenseDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Are you sure you want to delete "${expense.description ?? 'Expense'}" (₹${expense.amount.toStringAsFixed(2)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteExpense(expense.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(String expenseId) async {
    try {
      await _groupRepository.deleteExpense(expenseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '✓ Expense deleted successfully',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await _loadGroupData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting expense: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }
```

#### D. Add Expenses UI Section to `build`
In `GroupDetailsPage.build()`, locate where the sections are rendered (around lines 167–176):
**CURRENT CODE**:
```dart
                      // Section 2: Pending Settlements
                      _buildSectionHeader(
                        'Pending Settlements',
                        _pendingSettlements.length,
                      ),
                      const SizedBox(height: 12),
                      _pendingSettlements.isEmpty
                          ? _buildAllSettledCard()
                          : _buildPendingSettlementsList(),
                      const SizedBox(height: 24),
```

**REPLACE WITH**:
```dart
                      // Section: Expenses List
                      _buildSectionHeader(
                        'Expenses',
                        _expenses.length,
                      ),
                      const SizedBox(height: 12),
                      _expenses.isEmpty
                          ? _buildNoExpensesCard()
                          : _buildExpensesList(),
                      const SizedBox(height: 24),

                      // Section 2: Pending Settlements
                      _buildSectionHeader(
                        'Pending Settlements',
                        _pendingSettlements.length,
                      ),
                      const SizedBox(height: 12),
                      _pendingSettlements.isEmpty
                          ? _buildAllSettledCard()
                          : _buildPendingSettlementsList(),
                      const SizedBox(height: 24),
```

#### E. Add `_buildExpensesList()` and `_buildNoExpensesCard()` widgets
Add these widget builder methods to `_GroupDetailsPageState`:

```dart
  Widget _buildNoExpensesCard() {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No expenses recorded yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesList() {
    return Column(
      children: _expenses.map((expense) {
        final date = DateTime.fromMillisecondsSinceEpoch(expense.createdAt);
        final dateStr = '${date.day}/${date.month}/${date.year}';
        final categoryLabel =
            expenseCategories[expense.category] ?? expense.category;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  child: Icon(
                    Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description?.isNotEmpty == true
                            ? expense.description!
                            : 'Expense',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paid by ${expense.paidByUserName} • $dateStr',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Category: $categoryLabel • ${expense.participantIds.length} participant${expense.participantIds.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                      if (expense.note != null &&
                          expense.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note: ${expense.note}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${expense.amount.toStringAsFixed(2)}',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _navigateToEditExpense(expense),
                          tooltip: 'Edit Expense',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _showDeleteExpenseDialog(expense),
                          tooltip: 'Delete Expense',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.red[600],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
```

---

## 5. Exact SQL Operations
The following SQLite operations are executed:

1. **Delete Expense**:
   ```sql
   BEGIN TRANSACTION;
   DELETE FROM expense_participants WHERE expenseId = ?;
   DELETE FROM expenses WHERE id = ?;
   COMMIT;
   ```

2. **Update Expense**:
   ```sql
   BEGIN TRANSACTION;
   UPDATE expenses SET 
     paidByUserId = ?, 
     amount = ?, 
     description = ?, 
     category = ?, 
     note = ?, 
     splitType = ? 
   WHERE id = ?;
   
   DELETE FROM expense_participants WHERE expenseId = ?;
   
   INSERT INTO expense_participants (expenseId, userId) VALUES (?, ?);
   -- (repeated for each participant in the cleaned list)
   COMMIT;
   ```

---

## 6. Testing Checklist

### Delete Expense
- [ ] Open an existing group with expenses.
- [ ] Verify each expense card displays a red trash icon.
- [ ] Tap the delete icon on an expense.
- [ ] Verify an `AlertDialog` pops up showing the expense description and amount with "Cancel" and "Delete" buttons.
- [ ] Tap "Cancel" and verify the expense remains intact.
- [ ] Tap "Delete" and verify:
  - SnackBar appears: "✓ Expense deleted successfully".
  - Expense card disappears from the list.
  - Total event amount and per-person share recalculate accurately.
  - Pending settlements update automatically.
  - Category breakdown stats update.
- [ ] Delete all expenses and verify the empty card displays "No expenses recorded yet".

### Edit Expense
- [ ] Tap the edit icon (blue pencil) on an expense card.
- [ ] Verify the `AddExpensePage` opens with:
  - Title: "Edit Expense"
  - Amount prefilled with the current amount
  - Description prefilled
  - Note prefilled (if exists)
  - Category dropdown matching current category
  - Paid By dropdown matching current payer
  - Participants checkboxes accurately checked
  - Save button label: "Update Expense"
- [ ] Modify the amount (e.g. change 100 to 250), edit description, toggle a participant, and tap "Update Expense".
- [ ] Verify SnackBar appears: "✓ Expense updated successfully".
- [ ] Verify returning to `GroupDetailsPage` reflects the updated amount and participant count.
- [ ] Verify pending settlements recalculate correctly based on the new amounts.
