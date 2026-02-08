class Group {
  final String id;
  final String name;
  final String? description;
  final int createdAt;
  final String createdBy;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: map['createdAt'] as int,
      createdBy: map['createdBy'] as String,
    );
  }
}

class GroupBalanceView {
  final Group group;
  final double netBalance;

  GroupBalanceView({
    required this.group,
    required this.netBalance,
  });

  String get balanceText {
    if (netBalance > 0) {
      return 'You are owed ₹${netBalance.toStringAsFixed(2)}';
    } else if (netBalance < 0) {
      return 'You owe ₹${(-netBalance).toStringAsFixed(2)}';
    } else {
      return 'Settled up';
    }
  }
}

class ExpenseSplit {
  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String? description;
  final int createdAt;

  ExpenseSplit({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'description': description,
      'createdAt': createdAt,
    };
  }

  factory ExpenseSplit.fromMap(Map<String, dynamic> map) {
    return ExpenseSplit(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      fromUserId: map['fromUserId'] as String,
      toUserId: map['toUserId'] as String,
      amount: map['amount'] as double,
      description: map['description'] as String?,
      createdAt: map['createdAt'] as int,
    );
  }
}
