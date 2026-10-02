import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_splitter/database/database.dart';
import 'package:expense_splitter/repositories/group_repository.dart';

const _payer = 'user-payer';
const _alice = 'user-alice';
const _bob = 'user-bob';
const _groupId = 'group-1';
const _childTables = ['group_members', 'expenses', 'expense_participants',
    'expense_splits', 'settlements'];

Future<List<String>> participantsOf(Database db, String expenseId) async {
  final rows = await db.query('expense_participants',
      where: 'expenseId = ?', whereArgs: [expenseId]);
  return rows.map((r) => r['userId'] as String).toList()..sort();
}

Future<String> onlyExpenseId(Database db) async {
  final rows = await db.query('expenses');
  expect(rows, hasLength(1));
  return rows.first['id'] as String;
}

void main() {
  late Directory tempDir;
  late AppDatabase appDb;
  late GroupRepository repo;
  late Database db;

  setUpAll(() => tempDir = Directory.systemTemp.createTempSync('split_money_test'));

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(tempDir.path);
    appDb = AppDatabase();
    repo = GroupRepository(database: appDb);
    db = await appDb.database;
    for (final t in ['expense_participants', 'expenses', 'expense_splits',
        'settlements', 'group_members', 'groups', 'users']) {
      await db.delete(t);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final u in [_payer, _alice, _bob]) {
      await db.insert('users', {'id': u, 'name': u, 'createdAt': now});
      await db.insert('group_members',
          {'id': '$_groupId-$u', 'groupId': _groupId, 'userId': u});
    }
    await db.insert('groups',
        {'id': _groupId, 'name': 'Trip', 'createdAt': now, 'createdBy': _payer});
  });

  tearDownAll(() async {
    await appDb.close();
    tempDir.deleteSync(recursive: true);
  });

  test('addExpense -> updateExpense round-trips participants and amount', () async {
    await repo.addExpense(groupId: _groupId, description: 'Dinner', amount: 500.0,
        paidByUserId: _payer, participantIds: [_alice], splitType: 'unequal');
    final id = await onlyExpenseId(db);
    expect(await participantsOf(db, id), [_alice]);

    // No-op edit (the F1 scenario): participants come back exactly as passed,
    // never silently widened to every group member.
    await repo.updateExpense(expenseId: id, description: 'Dinner (edited)',
        amount: 475.5, paidByUserId: _payer, participantIds: [_alice], splitType: 'equal');
    expect(await participantsOf(db, id), [_alice]);
    final updated = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
    expect(updated, hasLength(1));
    expect((updated.first['amount'] as num).toDouble(), 475.5);

    // A deliberate change comes back exactly as written too.
    await repo.updateExpense(expenseId: id, description: 'Dinner (edited)',
        amount: 475.5, paidByUserId: _payer, participantIds: [_alice, _bob],
        splitType: 'equal');
    expect(await participantsOf(db, id), [_alice, _bob]);
    expect(await db.query('expenses'), hasLength(1));
  });

  test('deleteExpense removes the expense row and its participant rows', () async {
    await repo.addExpense(groupId: _groupId, description: 'Cab', amount: 120.0,
        paidByUserId: _payer, participantIds: [_alice, _bob]);
    final id = await onlyExpenseId(db);
    expect(await db.query('expense_participants',
        where: 'expenseId = ?', whereArgs: [id]), hasLength(2));

    await repo.deleteExpense(id);

    expect(await db.query('expenses', where: 'id = ?', whereArgs: [id]), isEmpty);
    expect(await db.query('expense_participants',
        where: 'expenseId = ?', whereArgs: [id]), isEmpty);
  });

  test('deleteGroup empties every child table', () async {
    await repo.addExpense(groupId: _groupId, description: 'Dinner', amount: 500.0,
        paidByUserId: _payer, participantIds: [_alice], splitType: 'unequal');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('expense_splits', {'id': 'split-1', 'groupId': _groupId,
        'fromUserId': _alice, 'toUserId': _payer, 'amount': 100.0, 'createdAt': now});
    await db.insert('settlements', {'id': 'settle-1', 'groupId': _groupId,
        'fromUserId': _alice, 'toUserId': _payer, 'amount': 50.0, 'createdAt': now});

    await repo.deleteGroup(_groupId);

    for (final table in _childTables) {
      expect(await db.query(table), isEmpty,
          reason: '$table must be empty after deleteGroup');
    }
  });
}
