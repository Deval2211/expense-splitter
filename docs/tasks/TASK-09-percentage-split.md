# TASK-09: Percentage-Based Split Type

> **Target Model:** Small / Free AI Models  
> **Status:** Ready for implementation  
> **Complexity:** Medium  
> **Target Path:** `/home/deval/Projects/expense-splitter/docs/tasks/TASK-09-percentage-split.md`

---

## 1. Overview

Currently, users can add expenses using **Equal Split** (divided equally among selected participants) or **Unequal Split** (exact currency amounts consumed per member).

This task introduces a third split option: **Percentage Split**.
When selecting "Percentage", users enter a percentage share for each group member.
- The entered percentages must sum to **100%** (validated within a `0.01` margin of error).
- When saved, each member's share amount is calculated as:
  $$\text{memberAmount} = \text{totalAmount} \times \left(\frac{\text{percentage}}{100}\right)$$
- Each member's calculated share is saved as an individual expense entry with `splitType: 'percentage'` (following the exact same database pattern as unequal split).

---

## 2. Files to Modify

Only one file needs modification:
- `/home/deval/Projects/expense-splitter/lib/pages/add_expense_page.dart`

---

## 3. Step-by-Step Implementation Instructions

### Step 1: Update `SplitType` Enum and Add `MemberPercentage` Model

Open `/home/deval/Projects/expense-splitter/lib/pages/add_expense_page.dart`.

#### Current Code (Lines 8 to 23):

```dart
enum SplitType { equal, unequal }

/// Model for tracking individual consumption in unequal split
class MemberConsumption {
  final String userId;
  final String userName;
  final TextEditingController controller;
  double? amount;

  MemberConsumption({required this.userId, required this.userName})
    : controller = TextEditingController();

  void dispose() {
    controller.dispose();
  }
}
```

#### Replacement Code:

Replace lines 8 to 23 with:

```dart
enum SplitType { equal, unequal, percentage }

/// Model for tracking individual consumption in unequal split
class MemberConsumption {
  final String userId;
  final String userName;
  final TextEditingController controller;
  double? amount;

  MemberConsumption({required this.userId, required this.userName})
    : controller = TextEditingController();

  void dispose() {
    controller.dispose();
  }
}

/// Model for tracking individual percentage in percentage split
class MemberPercentage {
  final String userId;
  final String userName;
  final TextEditingController controller;
  double? percentage;

  MemberPercentage({required this.userId, required this.userName})
    : controller = TextEditingController();

  void dispose() {
    controller.dispose();
  }
}
```

---

### Step 2: Add State Variable, Lifecycle Disposals, and Initialization

Inside `_AddExpensePageState`:

#### A. Add State Variable:
Around line 50, below `List<MemberConsumption> _memberConsumptions = [];`, add:

```dart
  // For percentage split
  List<MemberPercentage> _memberPercentages = [];
```

#### B. Update `dispose()`:
Find the `dispose()` method in `_AddExpensePageState` (around line 64):

**Current Code:**
```dart
  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    for (var consumption in _memberConsumptions) {
      consumption.dispose();
    }
    super.dispose();
  }
```

**Replacement Code:**
```dart
  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    for (var consumption in _memberConsumptions) {
      consumption.dispose();
    }
    for (var p in _memberPercentages) {
      p.dispose();
    }
    super.dispose();
  }
```

#### C. Update `_loadGroupMembers()`:
Find `_loadGroupMembers()` where `_memberConsumptions` is initialized (around line 95):

**Current Code:**
```dart
        // Initialize consumption controllers for unequal split
        _memberConsumptions = _members
            .map(
              (m) => MemberConsumption(userId: m.userId, userName: m.userName),
            )
            .toList();

        _isLoading = false;
```

**Replacement Code:**
```dart
        // Initialize consumption controllers for unequal split
        _memberConsumptions = _members
            .map(
              (m) => MemberConsumption(userId: m.userId, userName: m.userName),
            )
            .toList();

        // Initialize percentage controllers for percentage split
        _memberPercentages = _members
            .map(
              (m) => MemberPercentage(userId: m.userId, userName: m.userName),
            )
            .toList();

        _isLoading = false;
```

---

### Step 3: Replace `_buildSplitTypeSelector()` with 3-Option Cards

Replace the existing `_buildSplitTypeSelector()` (lines 564 to 721) with the following implementation that displays three options (**Equal**, **Unequal**, and **Percentage**):

```dart
  Widget _buildSplitTypeSelector() {
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
                  Icons.splitscreen,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Split Type',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3 Split type options
            Row(
              children: [
                _buildSplitOptionCard(
                  type: SplitType.equal,
                  icon: Icons.pie_chart,
                  title: 'Equal',
                  subtitle: 'Divide equally',
                ),
                const SizedBox(width: 8),
                _buildSplitOptionCard(
                  type: SplitType.unequal,
                  icon: Icons.calculate,
                  title: 'Unequal',
                  subtitle: 'By amount',
                ),
                const SizedBox(width: 8),
                _buildSplitOptionCard(
                  type: SplitType.percentage,
                  icon: Icons.percent,
                  title: 'Percentage',
                  subtitle: 'By % share',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitOptionCard({
    required SplitType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _splitType == type;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: InkWell(
        onTap: _isSaving
            ? null
            : () {
                setState(() {
                  _splitType = type;
                });
              },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey[300]!,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 28,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSelected ? Colors.white : Colors.grey[800],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? Colors.white70 : Colors.grey[600],
                      fontSize: 11,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
```

---

### Step 4: Add `_buildPercentageSplitSection()` and Validation

Add the following methods to `_AddExpensePageState`:

```dart
  Widget _buildPercentageSplitSection() {
    final totalAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;

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
                  Icons.percent,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Percentage Split',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter percentage for each person (must sum to 100%)',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Members Percentage inputs
            ..._memberPercentages.map((item) {
              final pct = double.tryParse(item.controller.text.trim()) ?? 0.0;
              final calculatedShare =
                  totalAmount > 0 ? (totalAmount * pct / 100.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      child: Text(
                        item.userName[0].toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.userName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          if (totalAmount > 0 && pct > 0)
                            Text(
                              '≈ ₹${calculatedShare.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        controller: item.controller,
                        decoration: InputDecoration(
                          hintText: '0',
                          suffixText: '%',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: !_isSaving,
                        onChanged: (value) {
                          setState(() {}); // Refresh calculated shares and summary
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            _buildPercentageSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentageSummary() {
    double totalPercent = 0.0;
    int enteredCount = 0;

    for (var item in _memberPercentages) {
      final text = item.controller.text.trim();
      if (text.isNotEmpty) {
        final val = double.tryParse(text);
        if (val != null) {
          totalPercent += val;
          enteredCount++;
        }
      }
    }

    final diff = 100.0 - totalPercent;
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String message;

    if (totalPercent > 100.01) {
      bgColor = Colors.red[50]!;
      borderColor = Colors.red[200]!;
      textColor = Colors.red[900]!;
      icon = Icons.error_outline;
      message =
          'Total: ${totalPercent.toStringAsFixed(1)}% | Exceeds 100% by ${(totalPercent - 100).toStringAsFixed(1)}%';
    } else if (diff.abs() <= 0.01 && enteredCount > 0) {
      bgColor = Colors.green[50]!;
      borderColor = Colors.green[200]!;
      textColor = Colors.green[900]!;
      icon = Icons.check_circle_outline;
      message = 'Total: 100% — Exact match!';
    } else {
      bgColor = Colors.orange[50]!;
      borderColor = Colors.orange[200]!;
      textColor = Colors.orange[900]!;
      icon = Icons.warning_amber;
      message =
          'Total: ${totalPercent.toStringAsFixed(1)}% | Remaining: ${diff.toStringAsFixed(1)}%';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validates percentage split: ensures positive expense amount and that percentages sum to 100
  bool _validatePercentageSplit() {
    final totalAmount = double.tryParse(_amountController.text.trim());
    if (totalAmount == null || totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid expense amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    double totalPercent = 0.0;
    for (var item in _memberPercentages) {
      final text = item.controller.text.trim();
      if (text.isNotEmpty) {
        final val = double.tryParse(text);
        if (val == null || val < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid percentage for ${item.userName}'),
              backgroundColor: Colors.red[600],
            ),
          );
          return false;
        }
        totalPercent += val;
        item.percentage = val;
      } else {
        item.percentage = null;
      }
    }

    if ((totalPercent - 100.0).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Percentages must sum to 100%. Current total: ${totalPercent.toStringAsFixed(1)}%',
          ),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

    return true;
  }
```

---

### Step 5: Update `build()` and `_saveExpense()`

#### In `build()`:
Find where the split section is conditionally rendered (around line 373):

**Current Code:**
```dart
                      // Section 3: Participants/Consumption based on split type
                      if (_splitType == SplitType.equal)
                        _buildEqualSplitSection()
                      else
                        _buildUnequalSplitSection(),
                      const SizedBox(height: 32),
```

**Replacement Code:**
```dart
                      // Section 3: Participants/Consumption based on split type
                      if (_splitType == SplitType.equal)
                        _buildEqualSplitSection()
                      else if (_splitType == SplitType.unequal)
                        _buildUnequalSplitSection()
                      else
                        _buildPercentageSplitSection(),
                      const SizedBox(height: 32),
```

---

#### In `_saveExpense()`:
Find the split type validation block (lines 214 to 244):

**Current Code:**
```dart
    // Validation based on split type
    if (_splitType == SplitType.equal) {
      if (_selectedParticipants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one participant'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else {
      // Unequal split validation
      if (!_validateUnequalSplit()) {
        return;
      }

      // Check if at least one person has consumption
      final hasConsumption = _memberConsumptions.any(
        (c) => c.amount != null && c.amount! > 0,
      );
      if (!hasConsumption) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter consumption for at least one person'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
```

**Replacement Code:**
```dart
    // Validation based on split type
    if (_splitType == SplitType.equal) {
      if (_selectedParticipants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one participant'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_splitType == SplitType.unequal) {
      // Unequal split validation
      if (!_validateUnequalSplit()) {
        return;
      }

      // Check if at least one person has consumption
      final hasConsumption = _memberConsumptions.any(
        (c) => c.amount != null && c.amount! > 0,
      );
      if (!hasConsumption) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter consumption for at least one person'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_splitType == SplitType.percentage) {
      // Percentage split validation
      if (!_validatePercentageSplit()) {
        return;
      }
    }
```

---

#### Next, in `_saveExpense()` saving logic:
Find the database saving block (lines 257 to 286):

**Current Code:**
```dart
      if (_splitType == SplitType.equal) {
        // Equal split - single expense with selected participants
        await _groupRepository.addExpense(
          groupId: widget.groupBalanceView.group.id,
          description: expenseDescription,
          amount: amount,
          paidByUserId: _selectedPayerId!,
          participantIds: _selectedParticipants.toList(),
          category: _selectedCategory,
          note: expenseNote,
          splitType: 'equal',
        );
      } else {
        // Unequal split - create individual expenses for each person's consumption
        // This allows the smart settlement merge to work correctly
        for (var consumption in _memberConsumptions) {
          if (consumption.amount != null && consumption.amount! > 0) {
            await _groupRepository.addExpense(
              groupId: widget.groupBalanceView.group.id,
              description: '$expenseDescription - ${consumption.userName}',
              amount: consumption.amount!,
              paidByUserId: _selectedPayerId!,
              participantIds: [consumption.userId], // Only this person consumed
              category: _selectedCategory,
              note: expenseNote,
              splitType: 'unequal',
            );
          }
        }
      }
```

**Replacement Code:**
```dart
      if (_splitType == SplitType.equal) {
        // Equal split - single expense with selected participants
        await _groupRepository.addExpense(
          groupId: widget.groupBalanceView.group.id,
          description: expenseDescription,
          amount: amount,
          paidByUserId: _selectedPayerId!,
          participantIds: _selectedParticipants.toList(),
          category: _selectedCategory,
          note: expenseNote,
          splitType: 'equal',
        );
      } else if (_splitType == SplitType.unequal) {
        // Unequal split - create individual expenses for each person's consumption
        for (var consumption in _memberConsumptions) {
          if (consumption.amount != null && consumption.amount! > 0) {
            await _groupRepository.addExpense(
              groupId: widget.groupBalanceView.group.id,
              description: '$expenseDescription - ${consumption.userName}',
              amount: consumption.amount!,
              paidByUserId: _selectedPayerId!,
              participantIds: [consumption.userId],
              category: _selectedCategory,
              note: expenseNote,
              splitType: 'unequal',
            );
          }
        }
      } else if (_splitType == SplitType.percentage) {
        // Percentage split - convert percentage to amount for each member
        for (var p in _memberPercentages) {
          if (p.percentage != null && p.percentage! > 0) {
            final memberAmount = amount * (p.percentage! / 100.0);
            await _groupRepository.addExpense(
              groupId: widget.groupBalanceView.group.id,
              description: '$expenseDescription - ${p.userName}',
              amount: memberAmount,
              paidByUserId: _selectedPayerId!,
              participantIds: [p.userId],
              category: _selectedCategory,
              note: expenseNote,
              splitType: 'percentage',
            );
          }
        }
      }
```

---

## 4. Testing Checklist

Execute these checks after applying the changes:

- [ ] **Run Code Analysis**: Run `flutter analyze` and confirm 0 errors or warnings.
- [ ] **Split Type Selector**:
  - Open a group and tap "Add Expense".
  - Verify that the Split Type section shows 3 options side by side: **Equal**, **Unequal**, and **Percentage**.
- [ ] **Switching to Percentage**:
  - Tap "Percentage".
  - The card below changes to "Percentage Split" with input fields ending in `%` for each group member.
- [ ] **Calculated Share Display**:
  - Enter total amount: `1000`.
  - For member 1, enter `50`. Observe the helper text displaying `≈ ₹500.00`.
  - Notice the summary card shows `Total: 50.0% | Remaining: 50.0%`.
- [ ] **Validation - Total Exceeds 100%**:
  - Enter `70` for member 1 and `40` for member 2 (Total = 110%).
  - The summary banner turns red indicating `Exceeds 100% by 10.0%`.
  - Tap "Save Expense". Verify that a snackbar appears and saving is prevented.
- [ ] **Validation - Total Less Than 100%**:
  - Enter `50` for member 1 and `30` for member 2 (Total = 80%).
  - Tap "Save Expense". Verify that a snackbar appears stating percentages must sum to 100%.
- [ ] **Successful Save**:
  - Enter percentages summing to 100% (e.g. `60%` and `40%`).
  - Summary banner turns green with `Total: 100% — Exact match!`.
  - Tap "Save Expense".
  - Confirm expense is saved and page navigates back with success message.
  - Verify on the Event Settlement page that settlements reflect the 60/40 ratio.
