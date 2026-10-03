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

  // Which of the 4 bottom tabs is visible (Settle / Expenses / Stats / More).
  int _tabIndex = 0;

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

  /// Shared snackbar helper — uses the theme's SnackBar (inverseSurface), so
  /// the same message reads correctly in light AND dark mode.
  void _showSnack(String message, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle,
              color: scheme.onInverseSurface,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _markAsPaid(Settlement settlement) async {
    try {
      await _groupRepository.markSettlementAsPaid(settlement);

      if (mounted) {
        _showSnack('✓ Settlement marked as paid');
      }

      // Reload data to reflect changes
      await _loadGroupData();
    } catch (e) {
      if (mounted) {
        _showSnack('Error: ${e.toString()}', error: true);
      }
    }
  }

  Future<void> _shareGroupSummary() async {
    try {
      final summary = await generateGroupSummary(
        _groupRepository,
        widget.groupBalanceView.group.id,
      );
      await Share.share(summary, subject: '$_groupName - Summary');
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to share summary: ${e.toString()}', error: true);
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
    final scheme = Theme.of(context).colorScheme;
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
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
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
        _showSnack('✓ Expense deleted successfully');
      }

      await _loadGroupData();
    } catch (e) {
      if (mounted) {
        _showSnack('Error deleting expense: ${e.toString()}', error: true);
      }
    }
  }

  Future<void> _showEditGroupModal() async {
    final nameController = TextEditingController(text: _groupName);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                        style: Theme.of(context).textTheme.titleLarge,
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
                              _showSnack('✓ Event name updated');
                              if (bottomSheetContext.mounted) {
                                Navigator.of(bottomSheetContext).pop();
                              }
                            } catch (e) {
                              if (!mounted) return;
                              _showSnack('Error: ${e.toString()}', error: true);
                            }
                          },
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
                        style: Theme.of(context).textTheme.titleMedium,
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
                  const SizedBox(height: 16),

                  // Members List
                  ..._members.map(
                    (member) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: member.amountPaid > 0
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        child: Text(
                          member.userName.isNotEmpty
                              ? member.userName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 13,
                            color: member.amountPaid > 0
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(member.userName),
                      subtitle: Text(
                        member.amountPaid > 0
                            ? 'Paid ${formatCurrency(member.amountPaid)}'
                            : 'No payments yet',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: member.amountPaid > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );

    // F6 fix: one-shot controller is released once the sheet closes.
    nameController.dispose();
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

    // F6 fix: one-shot controllers are released once the dialog closes.
    nameController.dispose();
    phoneController.dispose();

    if (added == true) {
      if (mounted) {
        _showSnack('✓ Member added successfully');
      }
      await _loadGroupData();
    }
  }

  void _navigateToHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ExpenseHistoryPage(groupBalanceView: widget.groupBalanceView),
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

  void _goToTab(int index) {
    if (_tabIndex == index) return;
    setState(() {
      _tabIndex = index;
    });
  }

  // ────────────────────────── Shell: dashboard + tabs ───────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_groupName),
        actions: [
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
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
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
          : Column(
              children: [
                _buildDashboardHeader(),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _settleTab(),
                      _expensesTab(),
                      _statsTab(),
                      _moreTab(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'Settle',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Stats',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }

  /// Compact always-visible dashboard: three tappable summary cards that jump
  /// straight to the matching tab (the user asked for dashboard + tabs, together).
  Widget _buildDashboardHeader() {
    final totalPaid = _members.fold<double>(
      0.0,
      (sum, m) => sum + m.amountPaid,
    );
    final fairShare = _members.isNotEmpty ? totalPaid / _members.length : 0.0;
    final pending = _pendingSettlements.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _dashboardCard(
              value: formatCurrency(totalPaid),
              label: 'Spent',
              onTap: () => _goToTab(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dashboardCard(
              value: pending > 0 ? '$pending' : '🎉',
              label: pending > 0 ? 'to settle' : 'All settled',
              highlight: pending > 0,
              onTap: () => _goToTab(0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dashboardCard(
              value: formatCurrency(fairShare),
              label: 'per person',
              onTap: () => _goToTab(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard({
    required String value,
    required String label,
    VoidCallback? onTap,
    bool highlight = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: highlight ? scheme.primaryContainer : scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FittedBox guards long currency strings from overflowing the
              // narrow one-third-width card.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: highlight ? scheme.onPrimaryContainer : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: highlight ? scheme.onPrimaryContainer : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── Tab 1: Settle ──────────────────────────────

  Widget _settleTab() {
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Pending Settlements',
                _pendingSettlements.length,
              ),
              const SizedBox(height: 16),
              _pendingSettlements.isEmpty
                  ? _buildAllSettledCard()
                  : _buildPendingSettlementsList(),
              if (_completedSettlements.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                _buildSectionHeader(
                  'Completed Settlements',
                  _completedSettlements.length,
                ),
                const SizedBox(height: 16),
                _buildCompletedSettlementsList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Tab 2: Expenses ──────────────────────────────

  Widget _expensesTab() {
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Expenses', _expenses.length),
              const SizedBox(height: 16),
              _expenses.isEmpty ? _buildNoExpensesCard() : _buildExpensesList(),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────── Tab 3: Stats ────────────────────────────────

  Widget _statsTab() {
    return RefreshIndicator(
      onRefresh: _loadGroupData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEventInfoCard(),
              const SizedBox(height: 16),
              if (_stats?.hasData ?? false) _buildStatsCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────── Tab 4: More ─────────────────────────────────

  /// Share / edit / history moved out of the crowded AppBar into rows here.
  Widget _moreTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Edit event'),
          subtitle: const Text('Rename this event or manage members'),
          onTap: _showEditGroupModal,
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Share summary'),
          subtitle: const Text('Send the breakdown to your friends'),
          onTap: _shareGroupSummary,
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Activity history'),
          subtitle: const Text('Every expense and payment, in order'),
          onTap: _navigateToHistory,
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Refresh'),
          subtitle: const Text('Reload this event'),
          onTap: _loadGroupData,
        ),
      ],
    );
  }

  // ─────────────────────────── Section builders ─────────────────────────────

  Widget _buildNoExpensesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No expenses yet — tap + to add the first one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesList() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: _expenses.map((expense) {
        final date = DateTime.fromMillisecondsSinceEpoch(expense.createdAt);
        final dateStr = '${date.day}/${date.month}/${date.year}';
        final categoryLabel =
            expenseCategories[expense.category] ?? expense.category;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.receipt_long,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description?.isNotEmpty == true
                            ? expense.description!
                            : 'Expense',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Paid by ${expense.paidByUserName} • $dateStr',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Category: $categoryLabel • ${expense.participantIds.length} participant${expense.participantIds.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      if (expense.note != null &&
                          expense.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: ${expense.note}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontStyle: FontStyle.italic),
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
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
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _showDeleteExpenseDialog(expense),
                          tooltip: 'Delete Expense',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: scheme.error,
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

  Widget _buildEventInfoCard() {
    final scheme = Theme.of(context).colorScheme;
    final totalAmount = _members.fold<double>(
      0.0,
      (sum, member) => sum + member.amountPaid,
    );
    final fairShare = _members.isNotEmpty ? totalAmount / _members.length : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Name
            Row(
              children: [
                Icon(Icons.event, color: scheme.primary, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _groupName,
                    style: Theme.of(context).textTheme.titleLarge,
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
            ),
            const SizedBox(height: 16),

            // Fair Share
            _buildInfoRow(
              'Per Person Share',
              formatCurrency(fairShare),
              Icons.person,
            ),
            const SizedBox(height: 16),

            // Members Count
            _buildInfoRow('Total Members', '${_members.length}', Icons.group),

            // Members List
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Payment Details',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ..._members.map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: member.amountPaid > 0
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                        child: Text(
                          member.userName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: member.amountPaid > 0
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
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
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final scheme = Theme.of(context).colorScheme;
    final stats = _stats;
    if (stats == null || !stats.hasData) {
      return const SizedBox.shrink();
    }

    final maxCategorySpend = stats.categoryTotals.values.fold<double>(
      0.0,
      (maxValue, value) => value > maxValue ? value : maxValue,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: scheme.primary, size: 24),
                const SizedBox(width: 16),
                Text(
                  'Expense Insights',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Expenses Logged',
              '${stats.expenseCount}',
              Icons.receipt_long,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Average Expense',
              formatCurrency(stats.averageExpense),
              Icons.trending_up,
            ),
            if (stats.categoryTotals.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Category Breakdown',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...stats.categoryTotals.entries.map((entry) {
                final label = expenseCategories[entry.key] ?? entry.key;
                final progress = maxCategorySpend <= 0
                    ? 0.0
                    : entry.value / maxCategorySpend;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            formatCurrency(entry.value),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: progress,
                          backgroundColor: scheme.surfaceContainerHighest,
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
              const SizedBox(height: 16),
              Text(
                'Member Net Position',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...stats.memberStats.map((memberStat) {
                final net = memberStat.netBalance;
                final amount = net.abs();
                final color = net > 0
                    ? scheme.primary
                    : net < 0
                    ? scheme.error
                    : scheme.onSurfaceVariant;
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
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '$prefix${formatCurrency(amount)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: count > 0
                ? scheme.tertiaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: count > 0
                  ? scheme.onTertiaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllSettledCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.celebration, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'All Settled! 🎉',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending payments',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSettlementsList() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: _pendingSettlements.map((settlement) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyLarge,
                    children: [
                      TextSpan(
                        text: settlement.fromUserName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: ' owes '),
                      TextSpan(
                        text: settlement.toUserName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        formatCurrency(settlement.amount),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onTertiaryContainer,
                            ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showMarkAsPaidDialog(settlement),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark as Paid'),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: _completedSettlements.map((settlement) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          settlement.paidAt ?? DateTime.now().millisecondsSinceEpoch,
        );
        final dateStr = '${date.day}/${date.month}/${date.year}';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: scheme.primary, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
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
                      const SizedBox(height: 8),
                      Text(
                        dateStr,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  formatCurrency(settlement.amount),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
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
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: ' to '),
              TextSpan(
                text: settlement.toUserName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: ' of '),
              TextSpan(
                text: formatCurrency(settlement.amount),
                style: const TextStyle(fontWeight: FontWeight.w600),
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
