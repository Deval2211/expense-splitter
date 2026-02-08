class FriendInput {
  final String name;
  final String? phone;
  final double amountPaid;

  FriendInput({
    required this.name,
    this.phone,
    this.amountPaid = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'amountPaid': amountPaid,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendInput && 
           other.name == name && 
           other.phone == phone && 
           other.amountPaid == amountPaid;
  }

  @override
  int get hashCode => Object.hash(name, phone, amountPaid);

  @override
  String toString() => 'FriendInput(name: $name, phone: $phone, amountPaid: $amountPaid)';
}