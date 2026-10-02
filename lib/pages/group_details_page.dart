import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/settlement.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import '../utils/currency.dart';
import '../utils/export.dart';
import 'add_expense_page.dart';
import 'expense_history_page.dart';

class GroupDetailsPage extends StatefulWidget {
  final GroupBalanceView groupBalanceView;

  const GroupDetailsPage({super.key, required this.groupBalanceView});

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  late GroupRepository _groupRepository;
  late String _groupName;
  List<GroupMember> _members = [];
  List<Expense> _expenses = [];
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

  Future<void> _loadGroupData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load members with their payments
      final members = await _groupRepository.getGroupMembersWithPayments(
        widget.groupBalanceView.group.id,
      );

      // Load all logged expenses
      final expenses = await _groupRepository.getGroupExpenses(
        widget.groupBalanceView.group.id,
      );

      // Load pending settlements
      final pending = await _groupRepository.calculatePendingSettlements(
        widget.groupBalanceView.group.id,
      );

      // Load completed settlements
      final completed = await _groupRepository.getGroupSettlements(
        widget.groupBalanceView.group.id,
      );

      // Load stats summary for this group
      final stats = await _groupRepository.getGroupExpenseStats(
        widget.groupBalanceView.group.id,
      );

      // Load the group itself so renames are reflected
      final group = await _groupRepository.getGroupById(
        widget.groupBalanceView.group.id,
      );

      setState(() {
        if (group != null) {
          _groupName = group.name;
        }
        _members = members;
        _expenses = expenses;
        _pendingSettlements = pending;
        _completedSettlements = completed;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load group data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsPaid(Settlement settlement) async {
    try {
      await _groupRepository.markSettlementAsPaid(settlement);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Settlement marked as paid',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Reload data to reflect changes
      await _loadGroupData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Future<void> _shareGroupSummary() async {
    try {
      final summary = await generateGroupSummary(
        _groupRepository,
        widget.groupBalanceView.group.id,
      );
      await Share.share(
        summary,
        subject: '$_groupName - Summary',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share summary: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  Future<void> _navigateToEditExpense(Expense expense) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddExpensePage(
          groupBalanceView: widget.groupBalanceView,
          existingExpense: expense,
        ),
      ),
    );

    if (result == true) {
      await _loadGroupData();
    }
  }

  void _showDeleteExpenseDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Are you sure you want to delete "${expense.description ?? 'Expense'}" (${formatCurrency(expense.amount)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteExpense(expense.id);
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

  Future<void> _deleteExpense(String expenseId) async {
    try {
      await _groupRepository.deleteExpense(expenseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '✓ Expense deleted successfully',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await _loadGroupData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting expense: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

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
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            final newName = nameController.text.trim();
                            try {
                              await _groupRepository.updateGroupName(
                                widget.groupBalanceView.group.id,
                                newName,
                              );
                              if (!mounted) return;
                              setState(() {
                                _groupName = newName;
                              });
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    '✓ Event name updated',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.green[600],
                                ),
                              );
                              if (bottomSheetContext.mounted) {
                                Navigator.of(bottomSheetContext).pop();
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red[600],
                                ),
                              );
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
                  ..._members.map(
                    (member) => ListTile(
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
                            ? 'Paid ${formatCurrency(member.amountPaid)}'
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
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                        ),
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

  Widget _buildNoExpensesCard() {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No expenses recorded yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesList() {
    return Column(
      children: _expenses.map((expense) {
        final date = DateTime.fromMillisecondsSinceEpoch(expense.createdAt);
        final dateStr = '${date.day}/${date.month}/${date.year}';
        final categoryLabel =
            expenseCategories[expense.category] ?? expense.category;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  child: Icon(
                    Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description?.isNotEmpty == true
                            ? expense.description!
                            : 'Expense',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paid by ${expense.paidByUserName} • $dateStr',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Category: $categoryLabel • ${expense.participantIds.length} participant${expense.participantIds.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                      if (expense.note != null &&
                          expense.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note: ${expense.note}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(expense.amount),
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _navigateToEditExpense(expense),
                          tooltip: 'Edit Expense',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _showDeleteExpenseDialog(expense),
                          tooltip: 'Delete Expense',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.red[600],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Settlement'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareGroupSummary,
            tooltip: 'Share Summary',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showEditGroupModal,
            tooltip: 'Edit Event',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ExpenseHistoryPage(
                    groupBalanceView: widget.groupBalanceView,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadGroupData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadGroupData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Event Info Card
                      _buildEventInfoCard(),
                      const SizedBox(height: 24),

                      if (_stats?.hasData ?? false) ...[
                        _buildStatsCard(),
                        const SizedBox(height: 24),
                      ],

                      // Section: Expenses List
                      _buildSectionHeader(
                        'Expenses',
                        _expenses.length,
                      ),
                      const SizedBox(height: 12),
                      _expenses.isEmpty
                          ? _buildNoExpensesCard()
                          : _buildExpensesList(),
                      const SizedBox(height: 24),

                      // Section 2: Pending Settlements
                      _buildSectionHeader(
                        'Pending Settlements',
                        _pendingSettlements.length,
                      ),
                      const SizedBox(height: 12),
                      _pendingSettlements.isEmpty
                          ? _buildAllSettledCard()
                          : _buildPendingSettlementsList(),
                      const SizedBox(height: 24),

                      // Section 3: Completed Settlements
                      if (_completedSettlements.isNotEmpty) ...[
                        const Divider(height: 32),
                        _buildSectionHeader(
                          'Completed Settlements',
                          _completedSettlements.length,
                        ),
                        const SizedBox(height: 12),
                        _buildCompletedSettlementsList(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _navigateToAddExpense() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AddExpensePage(groupBalanceView: widget.groupBalanceView),
      ),
    );

    // Refresh data if expense was added
    if (result == true) {
      await _loadGroupData();
    }
  }

  Widget _buildEventInfoCard() {
    final totalAmount = _members.fold<double>(
      0.0,
      (sum, member) => sum + member.amountPaid,
    );
    final fairShare = _members.isNotEmpty ? totalAmount / _members.length : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Name
            Row(
              children: [
                Icon(
                  Icons.event,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _groupName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Total Amount
            _buildInfoRow(
              'Total Amount',
              formatCurrency(totalAmount),
              Icons.payments,
              Colors.green[700]!,
            ),
            const SizedBox(height: 12),

            // Fair Share
            _buildInfoRow(
              'Per Person Share',
              formatCurrency(fairShare),
              Icons.person,
              Colors.blue[700]!,
            ),
            const SizedBox(height: 12),

            // Members Count
            _buildInfoRow(
              'Total Members',
              '${_members.length}',
              Icons.group,
              Colors.orange[700]!,
            ),

            // Members List
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              ..._members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: member.amountPaid > 0
                            ? Colors.green[100]
                            : Colors.grey[200],
                        child: Text(
                          member.userName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: member.amountPaid > 0
                                ? Colors.green[900]
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          member.userName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        'Paid ${formatCurrency(member.amountPaid)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: member.amountPaid > 0
                              ? Colors.green[700]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final stats = _stats;
    if (stats == null || !stats.hasData) {
      return const SizedBox.shrink();
    }

    final maxCategorySpend = stats.categoryTotals.values.fold<double>(
      0.0,
      (maxValue, value) => value > maxValue ? value : maxValue,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Expense Insights',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Expenses Logged',
              '${stats.expenseCount}',
              Icons.receipt_long,
              Colors.indigo[700]!,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Average Expense',
              formatCurrency(stats.averageExpense),
              Icons.trending_up,
              Colors.teal[700]!,
            ),
            if (stats.categoryTotals.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Category Breakdown',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ...stats.categoryTotals.entries.map((entry) {
                final label = expenseCategories[entry.key] ?? entry.key;
                final progress = maxCategorySpend <= 0
                    ? 0.0
                    : entry.value / maxCategorySpend;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            formatCurrency(entry.value),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: progress,
                          backgroundColor: Colors.grey[200],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (stats.memberStats.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Member Net Position',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              ...stats.memberStats.map((memberStat) {
                final net = memberStat.netBalance;
                final amount = net.abs();
                final color = net > 0
                    ? Colors.green[700]!
                    : net < 0
                    ? Colors.red[700]!
                    : Colors.grey[700]!;
                final prefix = net > 0
                    ? '+'
                    : net < 0
                    ? '-'
                    : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          memberStat.userName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '$prefix${formatCurrency(amount)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.orange[100] : Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: count > 0 ? Colors.orange[900] : Colors.green[900],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllSettledCard() {
    return Card(
      elevation: 0,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.celebration, size: 48, color: Colors.green[600]),
            const SizedBox(height: 12),
            Text(
              'All Settled! 🎉',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending payments',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.green[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSettlementsList() {
    return Column(
      children: _pendingSettlements.map((settlement) {
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: settlement.fromUserName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' owes '),
                            TextSpan(
                              text: settlement.toUserName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatCurrency(settlement.amount),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showMarkAsPaidDialog(settlement),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark as Paid'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompletedSettlementsList() {
    return Column(
      children: _completedSettlements.map((settlement) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          settlement.paidAt ?? DateTime.now().millisecondsSinceEpoch,
        );
        final dateStr = '${date.day}/${date.month}/${date.year}';

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                          children: [
                            TextSpan(
                              text: settlement.fromUserName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' paid '),
                            TextSpan(
                              text: settlement.toUserName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatCurrency(settlement.amount),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showMarkAsPaidDialog(Settlement settlement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyLarge,
            children: [
              const TextSpan(text: 'Mark payment from '),
              TextSpan(
                text: settlement.fromUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' to '),
              TextSpan(
                text: settlement.toUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' of '),
              TextSpan(
                text: formatCurrency(settlement.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' as paid?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _markAsPaid(settlement);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
