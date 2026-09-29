# TASK-03: Edit Group (Rename + Add Members)

## 1. Overview
In this task, you will implement the ability to **edit an existing group (event)** in the Flutter expense-splitter application. 

Editing a group includes two key capabilities:
1. **Renaming the group**: Changing the event's display name.
2. **Adding new members**: Adding friends or contacts to an existing group after it has already been created.

After completing this task:
1. In the **Event Settlement (Group Details) page**, an **Edit** icon button will appear in the `AppBar` actions.
2. Tapping the Edit button opens an **Edit Event** bottom sheet or dialog displaying:
   - An editable text field with the current event name and a "Save Name" button.
   - The current list of group members.
   - An **"Add Member"** button that opens a dialog matching the friend-creation pattern in `create_group_page.dart`.
3. Adding a member checks if the user exists in SQLite (by name and phone). If they do not, it creates a new `users` record, then links them to the group in `group_members`.
4. Updating the name or adding members immediately refreshes the group details view (event title, member list, per-person share calculations, and stats).

---

## 2. Files to Modify (Full Paths)
1. `/home/deval/Projects/expense-splitter/lib/repositories/group_repository.dart`
   - Add `updateGroupName(String groupId, String newName)`.
   - Add `addNewMemberToGroup(String groupId, String name, String? phone)`.
2. `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`
   - Add local `_groupName` state variable to support dynamic renaming.
   - Add Edit icon button to `AppBar.actions`.
   - Implement `_showEditGroupBottomSheet()` or `_showEditGroupDialog()`.
   - Implement `_showAddMemberDialog()` following the `_showAddFriendDialog` pattern from `create_group_page.dart`.
   - Refresh group data upon successful name change or member addition.

---

## 3. Database Context & Schema
The relevant tables and columns:
- `groups`:
  - `id` (TEXT PRIMARY KEY)
  - `name` (TEXT NOT NULL)
  - `description` (TEXT)
  - `createdAt` (INTEGER NOT NULL)
  - `createdBy` (TEXT NOT NULL)
- `users`:
  - `id` (TEXT PRIMARY KEY)
  - `name` (TEXT NOT NULL)
  - `phone` (TEXT)
  - `createdAt` (INTEGER NOT NULL)
- `group_members`:
  - `id` (TEXT PRIMARY KEY)
  - `groupId` (TEXT, FOREIGN KEY references groups(id))
  - `userId` (TEXT, FOREIGN KEY references users(id))
  - UNIQUE(`groupId`, `userId`)

### Logic for `addNewMemberToGroup`:
1. Check if a user with the same `name` and `phone` already exists in `users`.
   - If yes: retrieve their existing `userId`.
   - If no: insert a new user row with a generated `Uuid().v4()` and `now`, and use the new `userId`.
2. Check if the user is already in `group_members` for this `groupId`.
   - If yes: throw an exception (`"User is already a member of this event"`).
3. Insert into `group_members` with a unique ID, `groupId`, and `userId`.
4. Execute steps in a single atomic database transaction.

---

## 4. Step-by-Step Implementation Instructions

### Step 1: Update `GroupRepository`
**Target File**: `/home/deval/Projects/expense-splitter/lib/repositories/group_repository.dart`

#### A. Locate the existing `addMemberToGroup` method (around lines 244–255):
```dart
  /// Add a member to a group
  Future<void> addMemberToGroup(String groupId, String userId) async {
    final db = await _database.database;
    final memberId =
        '${groupId}_${userId}_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('group_members', {
      'id': memberId,
      'groupId': groupId,
      'userId': userId,
    });
  }
```

#### B. Add `updateGroupName` and `addNewMemberToGroup`:
Insert the following two methods immediately below `addMemberToGroup`:

```dart
  /// Update the name of a group
  Future<void> updateGroupName(String groupId, String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }

    final db = await _database.database;
    await db.update(
      'groups',
      {'name': trimmedName},
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  /// Add a new member to an existing group, creating the user record if needed
  Future<void> addNewMemberToGroup(
    String groupId,
    String name,
    String? phone,
  ) async {
    final trimmedName = name.trim();
    final trimmedPhone =
        phone != null && phone.trim().isNotEmpty ? phone.trim() : null;

    if (trimmedName.isEmpty) {
      throw ArgumentError('Member name cannot be empty');
    }

    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.transaction((txn) async {
        // 1. Check if user already exists
        final existingUsers = await txn.query(
          'users',
          where: trimmedPhone != null
              ? 'name = ? AND phone = ?'
              : 'name = ? AND (phone IS NULL OR phone = "")',
          whereArgs: trimmedPhone != null
              ? [trimmedName, trimmedPhone]
              : [trimmedName],
        );

        String memberUserId;
        if (existingUsers.isNotEmpty) {
          memberUserId = existingUsers.first['id'] as String;
        } else {
          // Create new user
          memberUserId = const Uuid().v4();
          await txn.insert('users', {
            'id': memberUserId,
            'name': trimmedName,
            'phone': trimmedPhone,
            'createdAt': now,
          });
        }

        // 2. Check if user is already a member of this group
        final existingMembership = await txn.query(
          'group_members',
          where: 'groupId = ? AND userId = ?',
          whereArgs: [groupId, memberUserId],
        );

        if (existingMembership.isNotEmpty) {
          throw Exception('$trimmedName is already a member of this event');
        }

        // 3. Insert into group_members
        final memberId =
            '${groupId}_${memberUserId}_${DateTime.now().millisecondsSinceEpoch}';
        await txn.insert('group_members', {
          'id': memberId,
          'groupId': groupId,
          'userId': memberUserId,
        });
      });
    } catch (e) {
      debugPrint('Error adding new member to group: $e');
      rethrow;
    }
  }
```

---

### Step 2: Update `GroupDetailsPage`
**Target File**: `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`

#### A. Add `_groupName` state variable & initialize it
In `_GroupDetailsPageState`:
**CURRENT CODE (lines 18–33)**:
```dart
class _GroupDetailsPageState extends State<GroupDetailsPage> {
  late GroupRepository _groupRepository;
  List<GroupMember> _members = [];
  List<Settlement> _pendingSettlements = [];
  List<Settlement> _completedSettlements = [];
  GroupExpenseStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final database = AppDatabase();
    _groupRepository = GroupRepository(database: database);
    _loadGroupData();
  }
```

**REPLACE WITH**:
```dart
class _GroupDetailsPageState extends State<GroupDetailsPage> {
  late GroupRepository _groupRepository;
  late String _groupName;
  List<GroupMember> _members = [];
  List<Settlement> _pendingSettlements = [];
  List<Settlement> _completedSettlements = [];
  GroupExpenseStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupBalanceView.group.name;
    final database = AppDatabase();
    _groupRepository = GroupRepository(database: database);
    _loadGroupData();
  }
```

#### B. Update `_loadGroupData()` to also refresh `_groupName`
In `_loadGroupData()`:
**CURRENT CODE (lines 62–68)**:
```dart
      setState(() {
        _members = members;
        _pendingSettlements = pending;
        _completedSettlements = completed;
        _stats = stats;
        _isLoading = false;
      });
```

**REPLACE WITH**:
```dart
      final group = await _groupRepository.getGroupById(
        widget.groupBalanceView.group.id,
      );

      setState(() {
        if (group != null) {
          _groupName = group.name;
        }
        _members = members;
        _pendingSettlements = pending;
        _completedSettlements = completed;
        _stats = stats;
        _isLoading = false;
      });
```

#### C. Add Edit Icon Button to AppBar
In `GroupDetailsPage.build()`:
**CURRENT CODE (lines 112–122)**:
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

**REPLACE WITH**:
```dart
      appBar: AppBar(
        title: const Text('Event Settlement'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showEditGroupModal,
            tooltip: 'Edit Event',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupData,
            tooltip: 'Refresh',
          ),
        ],
      ),
```

#### D. Update `_buildEventInfoCard` to use `_groupName`
In `_buildEventInfoCard()` (around lines 242–248):
**CURRENT CODE**:
```dart
                Expanded(
                  child: Text(
                    widget.groupBalanceView.group.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
```

**REPLACE WITH**:
```dart
                Expanded(
                  child: Text(
                    _groupName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
```

#### E. Add `_showEditGroupModal` and `_showAddMemberDialog`
Add these methods inside `_GroupDetailsPageState`:

```dart
  void _showEditGroupModal() {
    final nameController = TextEditingController(text: _groupName);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Event',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Rename Event Section
                  Form(
                    key: formKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Event Name',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Event name cannot be empty';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              final newName = nameController.text.trim();
                              try {
                                await _groupRepository.updateGroupName(
                                  widget.groupBalanceView.group.id,
                                  newName,
                                );
                                setState(() {
                                  _groupName = newName;
                                });
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        '✓ Event name updated',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.green[600],
                                    ),
                                  );
                                }
                                Navigator.of(bottomSheetContext).pop();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Colors.red[600],
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Members Section Header with Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Members (${_members.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(bottomSheetContext).pop();
                          await _showAddMemberDialog();
                        },
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add Member'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Members List
                  ..._members.map((member) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(
                            member.userName.isNotEmpty
                                ? member.userName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(member.userName),
                        subtitle: Text(
                          member.amountPaid > 0
                              ? 'Paid ₹${member.amountPaid.toStringAsFixed(2)}'
                              : 'No payments yet',
                          style: TextStyle(
                            color: member.amountPaid > 0
                                ? Colors.green[700]
                                : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddMemberDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'Enter member\'s name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (Optional)',
                  hintText: 'Enter phone number',
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim();

                try {
                  await _groupRepository.addNewMemberToGroup(
                    widget.groupBalanceView.group.id,
                    name,
                    phone,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red[600],
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✓ Member added successfully'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await _loadGroupData();
    }
  }
```

---

## 5. Exact SQL Operations
The following SQLite statements are executed:

1. **Update Group Name**:
   ```sql
   UPDATE groups SET name = ? WHERE id = ?;
   ```

2. **Add New Member to Group**:
   ```sql
   BEGIN TRANSACTION;
   
   -- Step 1: Check existing user
   SELECT * FROM users WHERE name = ? AND phone = ?;
   -- (or WHERE name = ? AND (phone IS NULL OR phone = "") if phone is null)
   
   -- Step 2: Insert user if not found
   INSERT INTO users (id, name, phone, createdAt) VALUES (?, ?, ?, ?);
   
   -- Step 3: Check if already member
   SELECT * FROM group_members WHERE groupId = ? AND userId = ?;
   
   -- Step 4: Insert membership
   INSERT INTO group_members (id, groupId, userId) VALUES (?, ?, ?);
   
   COMMIT;
   ```

---

## 6. Testing Checklist

### Rename Event
- [ ] Open an event in `GroupDetailsPage`.
- [ ] Tap the edit icon in the top AppBar.
- [ ] Verify the bottom sheet opens with title "Edit Event".
- [ ] Verify the "Event Name" text field is populated with the current name.
- [ ] Clear the name and tap "Save" -> Verify validation error: "Event name cannot be empty".
- [ ] Change the name (e.g. from "Dinner" to "Weekend Trip") and tap "Save".
- [ ] Verify green SnackBar appears: "✓ Event name updated".
- [ ] Verify the Event Info Card immediately shows the new name "Weekend Trip".
- [ ] Navigate back to the Events list page and verify the updated name is displayed in the list.

### Add Member to Event
- [ ] Tap the edit icon in the AppBar.
- [ ] Verify the current list of members is shown under "Members (N)".
- [ ] Tap "+ Add Member".
- [ ] Verify the Add Member dialog appears with Name (required) and Phone (optional) fields.
- [ ] Try submitting with an empty name -> Verify validation error: "Name is required".
- [ ] Enter a new member name (e.g. "Charlie") and tap "Add".
- [ ] Verify green SnackBar appears: "✓ Member added successfully".
- [ ] Verify "Total Members" count in the Event Info Card increments by 1.
- [ ] Verify "Charlie" appears under Payment Details with "Paid ₹0.00".
- [ ] Verify the Per Person Share recalculates for the new member count.
- [ ] Tap "Add Expense" -> Verify the new member "Charlie" is now available in both the "Paid By" dropdown and the "Participants" selection list.
- [ ] Try adding a member with the exact same name/phone -> Verify error message: "Charlie is already a member of this event".
