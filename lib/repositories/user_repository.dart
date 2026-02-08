import 'package:uuid/uuid.dart';
import '../database/database.dart';

class User {
  final String id;
  final String name;
  final String? phone;
  final int createdAt;

  User({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'createdAt': createdAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      createdAt: map['createdAt'] as int,
    );
  }
}

class UserRepository {
  final AppDatabase _database;

  UserRepository({required AppDatabase database}) : _database = database;

  /// Creates a new user and returns the user ID
  Future<String> createUser(String name, String? phone) async {
    final userId = const Uuid().v4();
    final createdAt = DateTime.now().millisecondsSinceEpoch;

    final db = await _database.database;

    await db.insert(
      'users',
      {
        'id': userId,
        'name': name,
        'phone': phone,
        'createdAt': createdAt,
      },
    );

    return userId;
  }

  /// Retrieves a user by ID
  Future<User?> getUserById(String userId) async {
    final db = await _database.database;

    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (result.isEmpty) {
      return null;
    }

    return User.fromMap(result.first);
  }

  /// Retrieves all users
  Future<List<User>> getAllUsers() async {
    final db = await _database.database;

    final result = await db.query('users');

    return result.map((map) => User.fromMap(map)).toList();
  }

  /// Updates a user
  Future<void> updateUser(User user) async {
    final db = await _database.database;

    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Deletes a user
  Future<void> deleteUser(String userId) async {
    final db = await _database.database;

    await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
