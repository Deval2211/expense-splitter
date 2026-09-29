# TASK-10: Search & Filter Expenses

> **Target Model:** Small / Free AI Models  
> **Status:** Ready for implementation  
> **Complexity:** Low to Medium  
> **Target Path:** `/home/deval/Projects/expense-splitter/docs/tasks/TASK-10-search-filter.md`

---

## 1. Overview

This task adds **Search by Description** and **Filter by Category** to the Expense History timeline in a group.
Users will be able to:
- Type in a search bar to instantly find expenses matching keywords in description, payer name, or notes.
- Select one or more category chips (e.g., Food and Drinks, Transport, Accommodation) from a horizontally scrolling chip bar.
- See the active filter count (e.g. "Showing 3 of 12 items").
- Clear active search queries and filters with a single tap.

> [!NOTE]
> **Dependency Note:** This feature lives on the **Expense History** page (`lib/pages/expense_history_page.dart`). If this page does not yet exist in your codebase (Task 4), **Step 1 provides the complete code to create it** with search and filter fully integrated.

---

## 2. Files to Create or Modify

1. **CREATE or MODIFY**: `/home/deval/Projects/expense-splitter/lib/pages/expense_history_page.dart`
2. **MODIFY**: `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart` (to add navigation to the history page)

---

## 3. Step-by-Step Implementation Instructions

### Step 1: Create or Update `lib/pages/expense_history_page.dart`

Check if `/home/deval/Projects/expense-splitter/lib/pages/expense_history_page.dart` exists in your project.

#### If the file DOES NOT exist:
Create `/home/deval/Projects/expense-splitter/lib/pages/expense_history_page.dart` with the complete code below. It contains the history timeline, client-side search, category filter chips, and item count badge:

```dart
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';

enum HistoryItemType { expense, settlement }

/// Unified timeline entry for both expenses and settlements
class HistoryTimelineItem {
  final String id;
  final HistoryItemType type;
  final String title;
  final String subtitle;
  final double amount;
  final String category; // category key from expenseCategories or 'settlement'
  final String? note;
  final int createdAt;

  HistoryTimelineItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.category,
    this.note,
    required this.createdAt,
  });
}

class ExpenseHistoryPage extends StatefulWidget {
  final GroupBalanceView groupBalanceView;

  const ExpenseHistoryPage({super.key, required this.groupBalanceView});

  @override
  State<ExpenseHistoryPage> createState() => _ExpenseHistoryPageState();
}

class _ExpenseHistoryPageState extends State<ExpenseHistoryPage> {
  late GroupRepository _groupRepository;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCategories = {};

  List<HistoryTimelineItem> _allItems = [];
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
      final expenses = await _groupRepository.getGroupExpenses(groupId);
      final settlements = await _groupRepository.getGroupSettlements(groupId);

      final List<HistoryTimelineItem> items = [];

      for (final exp in expenses) {
        items.add(
          HistoryTimelineItem(
            id: exp.id,
            type: HistoryItemType.expense,
            title: (exp.description != null && exp.description!.trim().isNotEmpty)
                ? exp.description!
                : 'Expense',
            subtitle: 'Paid by ${exp.paidByUserName}',
            amount: exp.amount,
            category: exp.category,
            note: exp.note,
            createdAt: exp.createdAt,
          ),
        );
      }

      for (final s in settlements) {
        items.add(
          HistoryTimelineItem(
            id: s.id,
            type: HistoryItemType.settlement,
            title: '${s.fromUserName} paid ${s.toUserName}',
            subtitle: 'Settlement Payment',
            amount: s.amount,
            category: 'settlement',
            note: null,
            createdAt: s.paidAt ?? 0,
          ),
        );
      }

      // Sort chronological descending (most recent first)
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _allItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load history: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<HistoryTimelineItem> _getFilteredItems() {
    final query = _searchController.text.trim().toLowerCase();

    return _allItems.where((item) {
      // 1. Text Search query matching title, subtitle, or note
      final matchesQuery = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query) ||
          (item.note != null && item.note!.toLowerCase().contains(query));

      // 2. Category filter matching
      final matchesCategory = _selectedCategories.isEmpty ||
          _selectedCategories.contains(item.category);

      return matchesQuery && matchesCategory;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategories.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final hasActiveFilter =
        _searchController.text.isNotEmpty || _selectedCategories.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryData,
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
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadHistoryData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Search bar
                    _buildSearchBar(),

                    // Category filter chips
                    _buildCategoryChips(),

                    // Results counter and clear filter button
                    _buildFilterSummaryBar(
                      totalCount: _allItems.length,
                      filteredCount: filteredItems.length,
                      hasActiveFilter: hasActiveFilter,
                    ),

                    const Divider(height: 1),

                    // Filtered list or empty state
                    Expanded(
                      child: filteredItems.isEmpty
                          ? _buildEmptyState(hasActiveFilter)
                          : ListView.builder(
                              itemCount: filteredItems.length,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              itemBuilder: (context, index) {
                                return _buildTimelineCard(filteredItems[index]);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search description, payer, note...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
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
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _selectedCategories.isEmpty,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategories.clear();
                  });
                }
              },
            ),
          ),
          // Chips from expenseCategories map
          ...expenseCategories.entries.map((entry) {
            final isSelected = _selectedCategories.contains(entry.key);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: isSelected,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildTimelineCard(HistoryTimelineItem item) {
    final isExpense = item.type == HistoryItemType.expense;
    final date = DateTime.fromMillisecondsSinceEpoch(
      item.createdAt > 0 ? item.createdAt : DateTime.now().millisecondsSinceEpoch,
    );
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final categoryLabel = expenseCategories[item.category] ??
        (item.category == 'settlement' ? 'Settlement' : item.category);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isExpense ? Colors.indigo[50] : Colors.green[50],
              child: Icon(
                isExpense ? Icons.receipt_long : Icons.check_circle,
                color: isExpense ? Colors.indigo[700] : Colors.green[700],
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  if (item.note != null && item.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Note: ${item.note}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${item.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isExpense ? Colors.black87 : Colors.green[700],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasActiveFilter) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilter ? Icons.search_off : Icons.receipt_long_outlined,
              size: 56,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilter
                  ? 'No matching expenses found'
                  : 'No expenses or settlements yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilter
                  ? 'Try changing your search query or category filters'
                  : 'Add expenses from the event details page to see them here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
            if (hasActiveFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

### Step 2: Add Navigation to History in `lib/pages/group_details_page.dart`

To allow users to access the Expense History page, add an action button to the AppBar in `lib/pages/group_details_page.dart`.

#### A. Import `expense_history_page.dart`
At the top of `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`, add:

```dart
import 'expense_history_page.dart';
```

#### B. Current AppBar Code (Lines 111 to 122):

```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Settlement'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupData,
            tooltip: 'Refresh',
          ),
        ],
      ),
```

#### C. Replacement AppBar Code:

Add the History icon button (`Icons.history`):

```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Settlement'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ExpenseHistoryPage(
                    groupBalanceView: widget.groupBalanceView,
                  ),
                ),
              );
            },
            tooltip: 'Expense History',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupData,
            tooltip: 'Refresh',
          ),
        ],
      ),
```

---

## 4. Testing Checklist

Execute these checks after applying the changes:

- [ ] **Run Code Analysis**: Run `flutter analyze` and confirm 0 errors or warnings.
- [ ] **History Button in AppBar**: Open any event/group details page. Verify an `Icons.history` button is visible in the AppBar.
- [ ] **Navigate to History**: Tap the history button. The `ExpenseHistoryPage` opens showing the search bar, category chips, and list of expenses.
- [ ] **Text Search by Description**:
  - Type a partial description (e.g. "dinner" or "hotel").
  - Verify that only expenses containing that substring appear.
  - Test case-insensitivity: typing "DINNER" or "dinner" should yield the same results.
  - Tap the 'X' button on the search field. The search field clears and all expenses return.
- [ ] **Category Filter Chips**:
  - Tap the "Food and Drinks" chip.
  - Verify only expenses belonging to "food" category are shown.
  - Tap another chip (e.g. "Transport"). Verify expenses in *either* Food or Transport are shown (multi-category selection).
  - Tap the "All" chip. Verify all categories are deselected and all items return.
- [ ] **Combined Search & Category Filter**:
  - Select "Food and Drinks" AND type a search keyword.
  - Verify only items matching *both* the search query and the selected category appear.
- [ ] **Results Counter**:
  - Verify that the summary bar displays `Showing X of Y items` when filtering, and `Total Y items` when unfiltered.
  - Tap "Clear Filters" when filters are active; verify that search is cleared, categories are reset, and all items are displayed.
- [ ] **Empty State**:
  - Search for a nonsense string (e.g. `xyz123abc`).
  - Verify the empty search state appears with message "No matching expenses found" and a "Clear Filters" button.
