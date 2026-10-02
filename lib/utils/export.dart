import '../repositories/group_repository.dart';
import 'currency.dart';

/// Generates a clean, readable plain-text summary of a group's expenses and settlements.
Future<String> generateGroupSummary(GroupRepository repo, String groupId) async {
  final group = await repo.getGroupById(groupId);
  final groupName = group?.name ?? 'Group';

  final members = await repo.getGroupMembersWithPayments(groupId);
  final pending = await repo.calculatePendingSettlements(groupId);
  final completed = await repo.getGroupSettlements(groupId);

  final totalAmount = members.fold<double>(
    0.0,
    (sum, m) => sum + m.amountPaid,
  );

  final buffer = StringBuffer();
  buffer.writeln('📊 Group Summary: $groupName');
  buffer.writeln('----------------------------------------');
  buffer.writeln('💰 Total Expenses: ${formatCurrency(totalAmount)}');
  buffer.writeln('👥 Total Members: ${members.length}');
  buffer.writeln();

  buffer.writeln('💳 Member Contributions:');
  if (members.isEmpty) {
    buffer.writeln('  No members recorded.');
  } else {
    for (final member in members) {
      buffer.writeln(
        '  • ${member.userName}: Paid ${formatCurrency(member.amountPaid)}',
      );
    }
  }
  buffer.writeln();

  buffer.writeln('⏳ Pending Settlements:');
  if (pending.isEmpty) {
    buffer.writeln('  All settled up! 🎉');
  } else {
    for (final s in pending) {
      buffer.writeln(
        '  • ${s.fromUserName} owes ${s.toUserName}: ${formatCurrency(s.amount)}',
      );
    }
  }
  buffer.writeln();

  buffer.writeln('✅ Completed Settlements:');
  if (completed.isEmpty) {
    buffer.writeln('  No completed settlements yet.');
  } else {
    for (final s in completed) {
      buffer.writeln(
        '  • ${s.fromUserName} paid ${s.toUserName}: ${formatCurrency(s.amount)}',
      );
    }
  }

  buffer.writeln('----------------------------------------');
  buffer.writeln('Shared via Expense Splitter');

  return buffer.toString();
}
