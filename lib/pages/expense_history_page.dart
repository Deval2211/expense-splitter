import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/settlement.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import '../utils/currency.dart';

/// Type of entry in the activity timeline
enum TimelineEntryType { expense, settlement }

/// Unified wrapper representing either an Expense or a Settlement
class TimelineEntry {
  final TimelineEntryType type;
  final Expense? expense;
  final Settlement? settlement;
  final int timestamp;

  TimelineEntry.fromExpense(Expense item)
      : type = TimelineEntryType.expense,
        expense = item,
        settlement = null,
        timestamp = item.createdAt;

  TimelineEntry.fromSettlement(Settlement item)
      : type = TimelineEntryType.settlement,
        expense = null,
        settlement = item,
        timestamp = item.paidAt ?? 0;

  bool get isExpense => type == TimelineEntryType.expense;
  bool get isSettlement => type == TimelineEntryType.settlement;
}

class ExpenseHistoryPage extends StatefulWidget {
  final GroupBalanceView groupBalanceView;

  const ExpenseHistoryPage({
    super.key,
    required this.groupBalanceView,
  });

  @override
  State<ExpenseHistoryPage> createState() => _ExpenseHistoryPageState();
}

class _ExpenseHistoryPageState extends State<ExpenseHistoryPage> {
  late GroupRepository _groupRepository;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCategories = {};
  List<TimelineEntry> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final database = AppDatabase();
    _groupRepository = GroupRepository(database: database);
    _loadHistoryData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groupId = widget.groupBalanceView.group.id;

      // 1. Fetch expenses and completed settlements from database
      final expenses = await _groupRepository.getGroupExpenses(groupId);
      final settlements = await _groupRepository.getGroupSettlements(groupId);

      // 2. Merge into unified list
      final List<TimelineEntry> combined = [
        ...expenses.map((e) => TimelineEntry.fromExpense(e)),
        ...settlements.map((s) => TimelineEntry.fromSettlement(s)),
      ];

      // 3. Sort chronologically descending (most recent first)
      combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _entries = combined;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load history: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Client-side filter: description/payer/note search + category chips.
  List<TimelineEntry> _getFilteredEntries() {
    final query = _searchController.text.trim().toLowerCase();

    return _entries.where((entry) {
      final matchesQuery = query.isEmpty || _matchesQuery(entry, query);
      // Settlements carry no category, so a category filter shows expenses only.
      final matchesCategory = _selectedCategories.isEmpty ||
          (entry.isExpense &&
              _selectedCategories.contains(entry.expense!.category));
      return matchesQuery && matchesCategory;
    }).toList();
  }

  bool _matchesQuery(TimelineEntry entry, String query) {
    if (entry.isExpense) {
      final expense = entry.expense!;
      return (expense.description ?? '').toLowerCase().contains(query) ||
          expense.paidByUserName.toLowerCase().contains(query) ||
          (expense.note ?? '').toLowerCase().contains(query);
    }
    final settlement = entry.settlement!;
    return settlement.fromUserName.toLowerCase().contains(query) ||
        settlement.toUserName.toLowerCase().contains(query);
  }

  bool get _hasActiveFilter =>
      _searchController.text.trim().isNotEmpty ||
      _selectedCategories.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategories.clear();
    });
  }

  String _formatDateTime(int timestamp) {
    if (timestamp <= 0) return 'Date unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;

    final hourInt = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final hour = hourInt.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year $hour:$minute $period';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'accommodation':
        return Icons.hotel;
      case 'entertainment':
        return Icons.movie;
      case 'groceries':
        return Icons.shopping_basket;
      case 'utilities':
        return Icons.power;
      case 'shopping':
        return Icons.shopping_bag;
      case 'health':
        return Icons.local_hospital;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.groupBalanceView.group.name;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              groupName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                onPressed: _loadHistoryData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Activity Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Expenses and completed settlements will appear here in chronological order.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredEntries = _getFilteredEntries();
    final hasActiveFilter = _hasActiveFilter;

    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryChips(),
        _buildFilterSummaryBar(
          totalCount: _entries.length,
          filteredCount: filteredEntries.length,
          hasActiveFilter: hasActiveFilter,
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredEntries.isEmpty
              ? _buildNoMatchesState()
              : RefreshIndicator(
                  onRefresh: _loadHistoryData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredEntries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      if (entry.isExpense) {
                        return _buildExpenseCard(entry.expense!);
                      } else {
                        return _buildSettlementCard(entry.settlement!);
                      }
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search description, payer, note...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _selectedCategories.isEmpty,
              onSelected: (selected) {
                if (selected) {
                  setState(_selectedCategories.clear);
                }
              },
            ),
          ),
          ...expenseCategories.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: _selectedCategories.contains(entry.key),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedCategories.add(entry.key);
                    } else {
                      _selectedCategories.remove(entry.key);
                    }
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterSummaryBar({
    required int totalCount,
    required int filteredCount,
    required bool hasActiveFilter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            hasActiveFilter
                ? 'Showing $filteredCount of $totalCount items'
                : 'Total $totalCount items',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (hasActiveFilter)
            TextButton(
              onPressed: _clearFilters,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildNoMatchesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No matching expenses found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing your search query or category filters',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final categoryLabel = expenseCategories[expense.category] ?? expense.category;
    final dateStr = _formatDateTime(expense.createdAt);
    final description = (expense.description != null && expense.description!.isNotEmpty)
        ? expense.description!
        : 'Expense';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paid by ${expense.paidByUserName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatCurrency(expense.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    categoryLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ],
            ),
            if (expense.note != null && expense.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${expense.note!}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementCard(Settlement settlement) {
    final dateStr = _formatDateTime(settlement.paidAt ?? 0);

    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.green.shade100,
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: settlement.fromUserName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' paid '),
                            TextSpan(
                              text: settlement.toUserName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Settlement',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatCurrency(settlement.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade800,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
