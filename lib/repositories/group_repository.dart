import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/group.dart';
import '../models/friend_input.dart';
import '../models/settlement.dart';
import '../models/expense.dart';

class GroupRepository {
  final AppDatabase _database;

  GroupRepository({required AppDatabase database}) : _database = database;

  /// Get all groups that contain the current user
  Future<List<Group>> getAllGroupsForUser(String userId) async {
    final db = await _database.database;

    final result = await db.query(
      'groups',
      where: 'id IN (SELECT groupId FROM group_members WHERE userId = ?)',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return result.map((map) => Group.fromMap(map)).toList();
  }

  /// Create a new group
  Future<String> createGroup(
    String groupId,
    String name,
    String? description,
    String createdBy,
  ) async {
    final db = await _database.database;

    await db.insert(
      'groups',
      {
        'id': groupId,
        'name': name,
        'description': description,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'createdBy': createdBy,
      },
    );

    return groupId;
  }

  /// Create a comprehensive group with members (atomic transaction)
  Future<void> createGroupWithMembers({
    required String name,
    required String currentUserId,
    required List<FriendInput> friends,
    double creatorAmountPaid = 0.0,
  }) async {
    final db = await _database.database;
    final groupId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.transaction((txn) async {
        // 1. Insert the group
        await txn.insert('groups', {
          'id': groupId,
          'name': name,
          'description': null,
          'createdAt': now,
          'createdBy': currentUserId,
        });

        // 2. Ensure current user exists and add them as member
        await txn.insert(
          'group_members',
          {
            'id': const Uuid().v4(),
            'groupId': groupId,
            'userId': currentUserId,
          },
        );

        // 3. Process friends
        for (final friend in friends) {
          // Check if user already exists
          final existingUsers = await txn.query(
            'users',
            where: 'name = ? AND phone = ?',
            whereArgs: [friend.name, friend.phone],
          );

          String friendUserId;

          if (existingUsers.isNotEmpty) {
            // User already exists
            friendUserId = existingUsers.first['id'] as String;
          } else {
            // Create new user
            friendUserId = const Uuid().v4();
            await txn.insert('users', {
              'id': friendUserId,
              'name': friend.name,
              'phone': friend.phone,
              'createdAt': now,
            });
          }

          // Add friend as group member
          await txn.insert('group_members', {
            'id': const Uuid().v4(),
            'groupId': groupId,
            'userId': friendUserId,
          });

          // Store friend's payment as expense if amount > 0
          if (friend.amountPaid > 0) {
            await txn.insert('expenses', {
              'id': const Uuid().v4(),
              'groupId': groupId,
              'paidByUserId': friendUserId,
              'amount': friend.amountPaid,
              'description': 'Initial payment',
              'createdAt': now,
            });
          }
        }

        // 4. Store creator's payment as expense if amount > 0
        if (creatorAmountPaid > 0) {
          await txn.insert('expenses', {
            'id': const Uuid().v4(),
            'groupId': groupId,
            'paidByUserId': currentUserId,
            'amount': creatorAmountPaid,
            'description': 'Initial payment',
            'createdAt': now,
          });
        }
      });
    } catch (e) {
      debugPrint('Error creating group: $e');
      rethrow;
    }
  }

  /// Get a single group by ID
  Future<Group?> getGroupById(String groupId) async {
    final db = await _database.database;

    final result = await db.query(
      'groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );

    if (result.isEmpty) {
      return null;
    }

    return Group.fromMap(result.first);
  }

  /// Calculate user's net balance in a specific group
  /// net = credit - debit - settlement_in + settlement_out
  Future<double> getUserNetBalanceForGroup(
    String groupId,
    String userId,
  ) async {
    final db = await _database.database;

    // Credit: amount owed to user
    final creditResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expense_splits '
      'WHERE groupId = ? AND toUserId = ?',
      [groupId, userId],
    );
    final credit = (creditResult.first['total'] as num).toDouble();

    // Debit: amount user owes
    final debitResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM expense_splits '
      'WHERE groupId = ? AND fromUserId = ?',
      [groupId, userId],
    );
    final debit = (debitResult.first['total'] as num).toDouble();

    // Settlement in: payments received by user
    final settlementInResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM settlements '
      'WHERE groupId = ? AND toUserId = ?',
      [groupId, userId],
    );
    final settlementIn =
        (settlementInResult.first['total'] as num).toDouble();

    // Settlement out: payments made by user
    final settlementOutResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM settlements '
      'WHERE groupId = ? AND fromUserId = ?',
      [groupId, userId],
    );
    final settlementOut =
        (settlementOutResult.first['total'] as num).toDouble();

    // Formula: credit - debit - settlement_in + settlement_out
    final netBalance = credit - debit - settlementIn + settlementOut;

    return netBalance;
  }

  /// Calculate overall net balance across all groups
  Future<double> getOverallNetBalance(String userId) async {
    try {
      final groups = await getAllGroupsForUser(userId);

      double totalBalance = 0;

      for (final group in groups) {
        final balance = await getUserNetBalanceForGroup(group.id, userId);
        totalBalance += balance;
      }

      return totalBalance;
    } catch (e) {
      debugPrint('Error calculating overall balance: $e');
      return 0;
    }
  }

  /// Get groups with balance view (includes calculated balance)
  Future<List<GroupBalanceView>> getGroupsWithBalance(String userId) async {
    try {
      final groups = await getAllGroupsForUser(userId);

      final List<GroupBalanceView> result = [];

      for (final group in groups) {
        final balance = await getUserNetBalanceForGroup(group.id, userId);
        result.add(
          GroupBalanceView(
            group: group,
            netBalance: balance,
          ),
        );
      }

      return result;
    } catch (e) {
      debugPrint('Error fetching groups with balance: $e');
      return [];
    }
  }

  /// Add a member to a group
  Future<void> addMemberToGroup(String groupId, String userId) async {
    final db = await _database.database;
    final memberId = '${groupId}_${userId}_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert(
      'group_members',
      {
        'id': memberId,
        'groupId': groupId,
        'userId': userId,
      },
    );
  }

  /// Get group members with their payment details
  Future<List<GroupMember>> getGroupMembersWithPayments(String groupId) async {
    final db = await _database.database;

    // Get all members in the group
    final membersResult = await db.rawQuery('''
      SELECT DISTINCT u.id, u.name 
      FROM users u
      INNER JOIN group_members gm ON u.id = gm.userId
      WHERE gm.groupId = ?
    ''', [groupId]);

    final List<GroupMember> members = [];

    for (final memberRow in membersResult) {
      final userId = memberRow['id'] as String;
      final userName = memberRow['name'] as String;

      // Get total amount paid by this user in this group
      final expensesResult = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total
        FROM expenses
        WHERE groupId = ? AND paidByUserId = ?
      ''', [groupId, userId]);

      final amountPaid = (expensesResult.first['total'] as num).toDouble();

      members.add(GroupMember(
        userId: userId,
        userName: userName,
        amountPaid: amountPaid,
      ));
    }

    return members;
  }

  /// Get existing settlements for a group
  Future<List<Settlement>> getGroupSettlements(String groupId) async {
    final db = await _database.database;

    final result = await db.rawQuery('''
      SELECT s.*, 
             u1.name as fromName,
             u2.name as toName
      FROM settlements s
      INNER JOIN users u1 ON s.fromUserId = u1.id
      INNER JOIN users u2 ON s.toUserId = u2.id
      WHERE s.groupId = ?
      ORDER BY s.createdAt DESC
    ''', [groupId]);

    return result.map((map) => Settlement.fromMap(
      map,
      map['fromName'] as String,
      map['toName'] as String,
    )).toList();
  }

  /// Calculate pending settlements for a group
  /// Uses the "debt simplification" algorithm with smart merge logic
  Future<List<Settlement>> calculatePendingSettlements(String groupId) async {
    try {
      // Get all group members
      final membersResult = await (await _database.database).rawQuery('''
        SELECT DISTINCT u.id, u.name 
        FROM users u
        INNER JOIN group_members gm ON u.id = gm.userId
        WHERE gm.groupId = ?
      ''', [groupId]);

      if (membersResult.isEmpty) {
        return [];
      }

      // Initialize balance tracking
      final Map<String, double> balances = {};
      final Map<String, String> userNames = {};

      for (final member in membersResult) {
        final userId = member['id'] as String;
        final userName = member['name'] as String;
        balances[userId] = 0.0;
        userNames[userId] = userName;
      }

      // Get all expenses for the group
      final expenses = await getGroupExpenses(groupId);

      // Calculate balances from all expenses
      for (final expense in expenses) {
        final sharePerParticipant = expense.sharePerParticipant;

        // The payer should receive money from all other participants
        for (final participantId in expense.participantIds) {
          if (participantId == expense.paidByUserId) {
            // Payer paid their own share, net effect is they paid for others
            balances[participantId] = 
                (balances[participantId] ?? 0) + 
                (expense.amount - sharePerParticipant);
          } else {
            // Other participants owe their share to the payer
            balances[participantId] = 
                (balances[participantId] ?? 0) - sharePerParticipant;
          }
        }
      }

      // Apply existing settlements to adjust balances
      final existingSettlements = await getGroupSettlements(groupId);
      for (final settlement in existingSettlements) {
        // When someone pays a settlement:
        // - The payer (fromUser) has paid, so their net balance increases
        // - The receiver (toUser) has received, so their net balance decreases
        balances[settlement.fromUserId] = 
            (balances[settlement.fromUserId] ?? 0) + settlement.amount;
        balances[settlement.toUserId] = 
            (balances[settlement.toUserId] ?? 0) - settlement.amount;
      }

      // Separate creditors (people who are owed) and debtors (people who owe)
      final List<MapEntry<String, double>> creditors = [];
      final List<MapEntry<String, double>> debtors = [];

      balances.forEach((userId, balance) {
        // Only consider significant amounts (ignore very small differences due to rounding)
        if (balance > 0.01) {
          creditors.add(MapEntry(userId, balance));
        } else if (balance < -0.01) {
          debtors.add(MapEntry(userId, -balance)); // Convert to positive for easier calculation
        }
      });

      // Generate minimal settlements using greedy algorithm
      final List<Settlement> pendingSettlements = [];

      int creditorIdx = 0;
      int debtorIdx = 0;

      while (creditorIdx < creditors.length && debtorIdx < debtors.length) {
        final creditor = creditors[creditorIdx];
        final debtor = debtors[debtorIdx];

        final amountToSettle = creditor.value < debtor.value 
            ? creditor.value 
            : debtor.value;

        // Create settlement: debtor pays creditor
        pendingSettlements.add(Settlement.calculated(
          fromUserId: debtor.key,
          fromUserName: userNames[debtor.key]!,
          toUserId: creditor.key,
          toUserName: userNames[creditor.key]!,
          amount: amountToSettle,
          groupId: groupId,
        ));

        // Update remaining amounts
        creditors[creditorIdx] = MapEntry(
          creditor.key,
          creditor.value - amountToSettle,
        );
        debtors[debtorIdx] = MapEntry(
          debtor.key,
          debtor.value - amountToSettle,
        );

        // Move to next creditor/debtor if current one is settled
        if (creditors[creditorIdx].value < 0.01) {
          creditorIdx++;
        }
        if (debtors[debtorIdx].value < 0.01) {
          debtorIdx++;
        }
      }

      return pendingSettlements;
    } catch (e) {
      debugPrint('Error calculating settlements: $e');
      return [];
    }
  }

  /// Mark a settlement as paid
  Future<void> markSettlementAsPaid(Settlement settlement) async {
    final db = await _database.database;

    await db.insert('settlements', {
      'id': const Uuid().v4(),
      'groupId': settlement.groupId,
      'fromUserId': settlement.fromUserId,
      'toUserId': settlement.toUserId,
      'amount': settlement.amount,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Add an expense split
  Future<void> addExpenseSplit(ExpenseSplit split) async {
    final db = await _database.database;

    await db.insert('expense_splits', split.toMap());
  }

  /// Add a new expense with participants (atomic transaction)
  Future<void> addExpense({
    required String groupId,
    required String description,
    required double amount,
    required String paidByUserId,
    required List<String> participantIds,
  }) async {
    final db = await _database.database;
    final expenseId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.transaction((txn) async {
        // 1. Insert the expense
        await txn.insert('expenses', {
          'id': expenseId,
          'groupId': groupId,
          'paidByUserId': paidByUserId,
          'amount': amount,
          'description': description,
          'createdAt': now,
        });

        // 2. Insert all participants
        for (final participantId in participantIds) {
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

  /// Get all expenses for a group
  Future<List<Expense>> getGroupExpenses(String groupId) async {
    final db = await _database.database;

    // Get all expenses for the group
    final expensesResult = await db.query(
      'expenses',
      where: 'groupId = ?',
      whereArgs: [groupId],
      orderBy: 'createdAt DESC',
    );

    final List<Expense> expenses = [];

    for (final expenseMap in expensesResult) {
      final expenseId = expenseMap['id'] as String;
      final paidByUserId = expenseMap['paidByUserId'] as String;

      // Get payer name
      final payerResult = await db.query(
        'users',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [paidByUserId],
      );
      final payerName = payerResult.isNotEmpty
          ? payerResult.first['name'] as String
          : 'Unknown';

      // Get participants
      final participantsResult = await db.rawQuery('''
        SELECT u.id, u.name
        FROM users u
        INNER JOIN expense_participants ep ON u.id = ep.userId
        WHERE ep.expenseId = ?
      ''', [expenseId]);

      final participantIds = participantsResult
          .map((row) => row['id'] as String)
          .toList();
      final participantNames = participantsResult
          .map((row) => row['name'] as String)
          .toList();

      expenses.add(Expense.fromMap(
        expenseMap,
        payerName,
        participantIds,
        participantNames,
      ));
    }

    return expenses;
  }
}
