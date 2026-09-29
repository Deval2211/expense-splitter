# TASK-02: Delete Group

## 1. Overview
In this task, you will implement the ability to **delete an entire group (event)** from the Flutter expense-splitter application.

Currently, groups can be created, but there is no mechanism to remove them. After completing this task:
1. In the **Events (Groups List) page**, long-pressing on any group card will display a confirmation dialog.
2. The confirmation dialog will show the event name and warn the user that all associated expenses, settlements, and member records will be permanently removed.
3. Upon confirming, `deleteGroup(groupId)` will execute an atomic database transaction that cleanly deletes all related records in the proper cascading order.
4. The list of groups and the overall balance card will automatically refresh to reflect the deletion.

---

## 2. Files to Modify (Full Paths)
1. `/home/deval/Projects/expense-splitter/lib/repositories/group_repository.dart`
   - Add `deleteGroup(String groupId)` method with multi-table cascading deletion inside an atomic transaction.
2. `/home/deval/Projects/expense-splitter/lib/pages/groups_list_page.dart`
   - Add `onLongPress` handler to the group card `ListTile`.
   - Implement `_showDeleteGroupDialog(BuildContext context, Group group)` with confirmation UI.
   - Implement `_deleteGroup(String groupId)` to invoke the repository method and refresh the page.

---

## 3. Database Context & Deletion Order
The SQLite schema has foreign key relationships that require an exact deletion sequence when SQLite foreign keys are enforced or to prevent orphaned records:

### Tables and Foreign Keys:
- `groups`: `id` (PK)
- `group_members`: `groupId` (FK -> `groups.id`)
- `expenses`: `id` (PK), `groupId` (FK -> `groups.id`)
- `expense_participants`: `expenseId` (FK -> `expenses.id`)
- `expense_splits`: `groupId` (FK -> `groups.id`)
- `settlements`: `groupId` (FK -> `groups.id`)

### Required Deletion Sequence:
1. **`settlements`**: Delete rows where `groupId = ?`.
2. **`expense_participants`**: Delete rows where `expenseId IN (SELECT id FROM expenses WHERE groupId = ?)`. (Must be deleted **before** `expenses` because `expense_participants` has a foreign key referencing `expenses.id`).
3. **`expense_splits`**: Delete rows where `groupId = ?`.
4. **`expenses`**: Delete rows where `groupId = ?`.
5. **`group_members`**: Delete rows where `groupId = ?`.
6. **`groups`**: Delete row where `id = ?`.

All 6 delete operations MUST be executed within a single `db.transaction((txn) async { ... })` so that if any step fails, the entire deletion rolls back safely.

---

## 4. Step-by-Step Implementation Instructions

### Step 1: Add `deleteGroup` to `GroupRepository`
**Target File**: `/home/deval/Projects/expense-splitter/lib/repositories/group_repository.dart`

#### A. Locate the `createGroup` / `createGroupWithMembers` methods (around lines 29–48):
```dart
  /// Create a new group
  Future<String> createGroup(
    String groupId,
    String name,
    String? description,
    String createdBy,
  ) async {
    final db = await _database.database;

    await db.insert('groups', {
      'id': groupId,
      'name': name,
      'description': description,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'createdBy': createdBy,
    });

    return groupId;
  }
```

#### B. Add `deleteGroup` to `GroupRepository`:
Insert the following method directly below `createGroup` (or below `createGroupWithMembers` around line 140):

```dart
  /// Delete a group and all associated records in cascading order (atomic transaction)
  Future<void> deleteGroup(String groupId) async {
    final db = await _database.database;

    try {
      await db.transaction((txn) async {
        // 1. Delete settlements associated with this group
        await txn.delete(
          'settlements',
          where: 'groupId = ?',
          whereArgs: [groupId],
        );

        // 2. Delete expense participants for all expenses in this group
        // Note: Must be deleted before expenses due to foreign key
        await txn.delete(
          'expense_participants',
          where: 'expenseId IN (SELECT id FROM expenses WHERE groupId = ?)',
          whereArgs: [groupId],
        );

        // 3. Delete expense splits for this group
        await txn.delete(
          'expense_splits',
          where: 'groupId = ?',
          whereArgs: [groupId],
        );

        // 4. Delete expenses for this group
        await txn.delete(
          'expenses',
          where: 'groupId = ?',
          whereArgs: [groupId],
        );

        // 5. Delete group members
        await txn.delete(
          'group_members',
          where: 'groupId = ?',
          whereArgs: [groupId],
        );

        // 6. Delete the group record itself
        await txn.delete(
          'groups',
          where: 'id = ?',
          whereArgs: [groupId],
        );
      });
    } catch (e) {
      debugPrint('Error deleting group: $e');
      rethrow;
    }
  }
```

---

### Step 2: Update `GroupsListPage` with Long-Press Delete
**Target File**: `/home/deval/Projects/expense-splitter/lib/pages/groups_list_page.dart`

#### A. Add `_showDeleteGroupDialog` and `_deleteGroup` to `_GroupsListPageState`
Add these two helper methods inside `_GroupsListPageState` (for example, right after `_navigateToCreateGroup` around line 76):

```dart
  Future<void> _deleteGroup(String groupId) async {
    try {
      await _groupRepository.deleteGroup(groupId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✓ Event deleted successfully'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }

      _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _showDeleteGroupDialog(Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${group.name}"?\n\nThis will permanently delete all expenses, settlements, and member records for this event. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteGroup(group.id);
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
```

#### B. Attach `onLongPress` to the Group Card `ListTile`
Locate `_buildGroupsList` in `groups_list_page.dart` (around lines 260–319):

**CURRENT CODE**:
```dart
  Widget _buildGroupsList(
    BuildContext context,
    List<GroupBalanceView> groupsWithBalance,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupsWithBalance.length,
      itemBuilder: (context, index) {
        final groupBalance = groupsWithBalance[index];
        final balance = groupBalance.netBalance;
        final isOwed = balance > 0;
        final isNegative = balance < 0;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            title: Text(
              groupBalance.group.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            subtitle: Text(
              groupBalance.balanceText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOwed
                        ? Colors.green.shade700
                        : isNegative
                            ? Colors.red.shade700
                            : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GroupDetailsPage(groupBalanceView: groupBalance),
                ),
              );
            },
          ),
        );
      },
    );
  }
```

**REPLACE WITH**:
```dart
  Widget _buildGroupsList(
    BuildContext context,
    List<GroupBalanceView> groupsWithBalance,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupsWithBalance.length,
      itemBuilder: (context, index) {
        final groupBalance = groupsWithBalance[index];
        final balance = groupBalance.netBalance;
        final isOwed = balance > 0;
        final isNegative = balance < 0;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            title: Text(
              groupBalance.group.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            subtitle: Text(
              groupBalance.balanceText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOwed
                        ? Colors.green.shade700
                        : isNegative
                            ? Colors.red.shade700
                            : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GroupDetailsPage(groupBalanceView: groupBalance),
                ),
              );
            },
            onLongPress: () => _showDeleteGroupDialog(groupBalance.group),
          ),
        );
      },
    );
  }
```

---

## 5. Exact SQL Operations
The following sequence of SQL statements is executed atomically inside a transaction:

```sql
BEGIN TRANSACTION;

-- 1. Remove recorded settlements
DELETE FROM settlements WHERE groupId = ?;

-- 2. Remove participants for all expenses belonging to this group
DELETE FROM expense_participants 
WHERE expenseId IN (SELECT id FROM expenses WHERE groupId = ?);

-- 3. Remove expense splits
DELETE FROM expense_splits WHERE groupId = ?;

-- 4. Remove all expenses for this group
DELETE FROM expenses WHERE groupId = ?;

-- 5. Remove member memberships for this group
DELETE FROM group_members WHERE groupId = ?;

-- 6. Remove the group itself
DELETE FROM groups WHERE id = ?;

COMMIT;
```

---

## 6. Testing Checklist

- [ ] **Long Press Trigger**:
  - Open the Events list page.
  - Long press on any event card.
  - Verify an `AlertDialog` pops up with title "Delete Event".
  - Verify the dialog content explicitly names the event being deleted.
- [ ] **Cancel Action**:
  - In the delete dialog, tap "Cancel".
  - Verify the dialog closes.
  - Verify the event remains in the list unchanged.
- [ ] **Confirm Delete**:
  - Long press on an event with multiple members, expenses, and settlements.
  - Tap "Delete".
  - Verify green SnackBar appears: "✓ Event deleted successfully".
  - Verify the deleted event immediately vanishes from the events list.
  - Verify the "Your overall balance" card at the top recalculates immediately.
- [ ] **Delete Last Event**:
  - Delete all remaining events in the list.
  - Verify the empty state widget ("No events yet. Tap + to create your first event") is displayed.
  - Verify overall balance reflects ₹0.00 ("Settled up").
- [ ] **Database Integrity**:
  - Create a new event, add expenses, and delete the event.
  - Check that no SQLite foreign key constraint exception is thrown during deletion.
