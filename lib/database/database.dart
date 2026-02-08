import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  factory AppDatabase() {
    return _instance;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'expense_splitter.db');

      debugPrint('Database path: $path');

      return await openDatabase(
        path,
        version: 3,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
        onOpen: (db) {
          debugPrint('Database opened successfully');
        },
      );
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _createTables(Database db, int version) async {
    // Create User table
    await db.execute('''
      CREATE TABLE users(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');

    // Create Group table
    await db.execute('''
      CREATE TABLE groups(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        createdAt INTEGER NOT NULL,
        createdBy TEXT NOT NULL,
        FOREIGN KEY (createdBy) REFERENCES users(id)
      )
    ''');

    // Create GroupMember table
    await db.execute('''
      CREATE TABLE group_members(
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        userId TEXT NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups(id),
        FOREIGN KEY (userId) REFERENCES users(id),
        UNIQUE(groupId, userId)
      )
    ''');

    // Create Expense table (tracks individual expenses/payments)
    await db.execute('''
      CREATE TABLE expenses(
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        paidByUserId TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups(id),
        FOREIGN KEY (paidByUserId) REFERENCES users(id)
      )
    ''');

    // Create ExpenseSplit table (tracks who owes whom)
    await db.execute('''
      CREATE TABLE expense_splits(
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        fromUserId TEXT NOT NULL,
        toUserId TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups(id),
        FOREIGN KEY (fromUserId) REFERENCES users(id),
        FOREIGN KEY (toUserId) REFERENCES users(id)
      )
    ''');

    // Create Settlement table (tracks payments made)
    await db.execute('''
      CREATE TABLE settlements(
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        fromUserId TEXT NOT NULL,
        toUserId TEXT NOT NULL,
        amount REAL NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups(id),
        FOREIGN KEY (fromUserId) REFERENCES users(id),
        FOREIGN KEY (toUserId) REFERENCES users(id)
      )
    ''');

    // Create ExpenseParticipants table (tracks who participated in each expense)
    await db.execute('''
      CREATE TABLE expense_participants(
        expenseId TEXT NOT NULL,
        userId TEXT NOT NULL,
        FOREIGN KEY (expenseId) REFERENCES expenses(id),
        FOREIGN KEY (userId) REFERENCES users(id),
        PRIMARY KEY (expenseId, userId)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add expenses table for version 2
      await db.execute('''
        CREATE TABLE expenses(
          id TEXT PRIMARY KEY,
          groupId TEXT NOT NULL,
          paidByUserId TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          createdAt INTEGER NOT NULL,
          FOREIGN KEY (groupId) REFERENCES groups(id),
          FOREIGN KEY (paidByUserId) REFERENCES users(id)
        )
      ''');
      debugPrint('Database upgraded to version 2: expenses table added');
    }
    if (oldVersion < 3) {
      // Add expense_participants table for version 3
      await db.execute('''
        CREATE TABLE expense_participants(
          expenseId TEXT NOT NULL,
          userId TEXT NOT NULL,
          FOREIGN KEY (expenseId) REFERENCES expenses(id),
          FOREIGN KEY (userId) REFERENCES users(id),
          PRIMARY KEY (expenseId, userId)
        )
      ''');
      debugPrint('Database upgraded to version 3: expense_participants table added');
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
    _database = null;
  }
}
