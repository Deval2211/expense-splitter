/// Model representing a single expense in a group
class Expense {
  final String id;
  final String groupId;
  final String? description;
  final double amount;
  final String paidByUserId;
  final String paidByUserName;
  final List<String> participantIds;
  final List<String> participantNames;
  final int createdAt;

  Expense({
    required this.id,
    required this.groupId,
    this.description,
    required this.amount,
    required this.paidByUserId,
    required this.paidByUserName,
    required this.participantIds,
    required this.participantNames,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'paidByUserId': paidByUserId,
      'amount': amount,
      'description': description,
      'createdAt': createdAt,
    };
  }

  factory Expense.fromMap(
    Map<String, dynamic> map,
    String paidByName,
    List<String> participantIds,
    List<String> participantNames,
  ) {
    return Expense(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      description: map['description'] as String?,
      amount: (map['amount'] as num).toDouble(),
      paidByUserId: map['paidByUserId'] as String,
      paidByUserName: paidByName,
      participantIds: participantIds,
      participantNames: participantNames,
      createdAt: map['createdAt'] as int,
    );
  }

  /// Calculate share per participant
  double get sharePerParticipant {
    if (participantIds.isEmpty) return 0.0;
    return amount / participantIds.length;
  }

  Expense copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    String? paidByUserId,
    String? paidByUserName,
    List<String>? participantIds,
    List<String>? participantNames,
    int? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      paidByUserName: paidByUserName ?? this.paidByUserName,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Model for representing an expense participant
class ExpenseParticipant {
  final String expenseId;
  final String userId;

  ExpenseParticipant({
    required this.expenseId,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'userId': userId,
    };
  }

  factory ExpenseParticipant.fromMap(Map<String, dynamic> map) {
    return ExpenseParticipant(
      expenseId: map['expenseId'] as String,
      userId: map['userId'] as String,
    );
  }
}
