# TASK-06: Currency Formatting Utility

> **Target Audience:** Small or free AI models.  
> **Self-Contained Rule:** This file contains all necessary code, context, exact paths, and step-by-step instructions. You do not need to look at any other documentation to complete this task.

---

## 1. Overview & Objectives

Currently, the Indian Rupee symbol `₹` is hardcoded across multiple UI pages and data models. This prevents users from configuring their preferred currency (such as `$`, `€`, `£`, etc.).

### What you will build:
1. Create a centralized currency utility in `lib/utils/currency.dart`.
2. Provide `formatCurrency(double amount, {String symbol = '₹'})` returning `'$symbol${amount.toStringAsFixed(2)}'`.
3. Provide `getCurrencySymbol()` and `setCurrencySymbol(String symbol)` using `SharedPreferences` with default `'₹'`.
4. Update `GroupBalanceView.balanceText` in `lib/models/group.dart` so it accepts the currency symbol as an optional parameter.
5. Replace every hardcoded `₹` across all 5 files in the app with the new utility function or configurable symbol.

---

## 2. Files Summary

### Files to CREATE:
- `/home/deval/Projects/expense-splitter/lib/utils/currency.dart`

### Files to MODIFY (all files containing `₹`):
1. `/home/deval/Projects/expense-splitter/lib/models/group.dart`
2. `/home/deval/Projects/expense-splitter/lib/pages/groups_list_page.dart`
3. `/home/deval/Projects/expense-splitter/lib/pages/create_group_page.dart`
4. `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`
5. `/home/deval/Projects/expense-splitter/lib/pages/add_expense_page.dart`

---

## 3. STEP 1: Create `lib/utils/currency.dart`

Create a new file at `/home/deval/Projects/expense-splitter/lib/utils/currency.dart` with the complete code below:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Default currency symbol used across the app
const String defaultCurrencySymbol = '₹';

/// Common currency symbols available for user selection
const List<String> supportedCurrencySymbols = [
  '₹', // Indian Rupee
  '\$', // US Dollar / Canadian Dollar / Australian Dollar
  '€', // Euro
  '£', // British Pound
  '¥', // Japanese Yen / Chinese Yuan
  '₩', // South Korean Won
  '฿', // Thai Baht
  'CHF', // Swiss Franc
];

/// Formats a numeric amount with a currency symbol and 2 decimal places.
///
/// Example:
/// ```dart
/// formatCurrency(150.0); // '₹150.00'
/// formatCurrency(49.9, symbol: '\$'); // '\$49.90'
/// ```
String formatCurrency(double amount, {String symbol = defaultCurrencySymbol}) {
  return '$symbol${amount.toStringAsFixed(2)}';
}

/// Reads user's preferred currency symbol from SharedPreferences.
/// Defaults to '₹' if not set.
Future<String> getCurrencySymbol() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('currencySymbol') ?? defaultCurrencySymbol;
  } catch (e) {
    return defaultCurrencySymbol;
  }
}

/// Saves user's preferred currency symbol into SharedPreferences.
Future<void> setCurrencySymbol(String symbol) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('currencySymbol', symbol);
}
```

---

## 4. STEP 2: Modify `lib/models/group.dart`

File to modify: `/home/deval/Projects/expense-splitter/lib/models/group.dart`

In `GroupBalanceView`, change the `balanceText` getter into a method taking an optional `symbol` parameter, with default `'₹'`.

### Locate lines 37 to 55:

**CURRENT CODE:**
```dart
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
```

**CHANGE TO:**
```dart
class GroupBalanceView {
  final Group group;
  final double netBalance;

  GroupBalanceView({
    required this.group,
    required this.netBalance,
  });

  String balanceText([String symbol = '₹']) {
    if (netBalance > 0) {
      return 'You are owed $symbol${netBalance.toStringAsFixed(2)}';
    } else if (netBalance < 0) {
      return 'You owe $symbol${(-netBalance).toStringAsFixed(2)}';
    } else {
      return 'Settled up';
    }
  }
}
```

---

## 5. STEP 3: Modify `lib/pages/groups_list_page.dart`

File to modify: `/home/deval/Projects/expense-splitter/lib/pages/groups_list_page.dart`

### 3.1 Add import
Add the currency utility import at the top of the file:
```dart
import '../utils/currency.dart';
```

### 3.2 Update `_buildOverallBalanceCard` (Lines 180 to 194)

**CURRENT CODE:**
```dart
    if (isOwed) {
      cardColor = Colors.green.shade50;
      balanceText = 'You are owed ₹${balance.toStringAsFixed(2)}';
    } else if (isNegative) {
      cardColor = Colors.red.shade50;
      balanceText = 'You owe ₹${(-balance).toStringAsFixed(2)}';
    } else {
      cardColor = Colors.grey.shade100;
      balanceText = 'Settled up';
    }
```

**CHANGE TO:**
```dart
    if (isOwed) {
      cardColor = Colors.green.shade50;
      balanceText = 'You are owed ${formatCurrency(balance)}';
    } else if (isNegative) {
      cardColor = Colors.red.shade50;
      balanceText = 'You owe ${formatCurrency(-balance)}';
    } else {
      cardColor = Colors.grey.shade100;
      balanceText = 'Settled up';
    }
```

### 3.3 Update `_buildGroupsList` (Line 292)

**CURRENT CODE:**
```dart
            subtitle: Text(
              groupBalance.balanceText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOwed
                        ? Colors.green.shade700
                        : isNegative
                            ? Colors.red.shade700
                            : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
```

**CHANGE TO:**
```dart
            subtitle: Text(
              groupBalance.balanceText(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOwed
                        ? Colors.green.shade700
                        : isNegative
                            ? Colors.red.shade700
                            : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
```

---

## 6. STEP 4: Modify `lib/pages/create_group_page.dart`

File to modify: `/home/deval/Projects/expense-splitter/lib/pages/create_group_page.dart`

### 4.1 Add import
Add the currency utility import at the top of the file:
```dart
import '../utils/currency.dart';
```

### 4.2 Replace `prefixText` in `_showAddFriendDialog` (Line 105)

**CURRENT CODE:**
```dart
                decoration: const InputDecoration(
                  labelText: 'Amount Paid',
                  hintText: 'Enter amount paid by friend',
                  prefixText: '₹ ',
                ),
```

**CHANGE TO:**
```dart
                decoration: const InputDecoration(
                  labelText: 'Amount Paid',
                  hintText: 'Enter amount paid by friend',
                  prefixText: '$defaultCurrencySymbol ',
                ),
```

### 4.3 Replace `prefixText` in `_showEditCreatorAmountDialog` (Line 174)

**CURRENT CODE:**
```dart
            decoration: const InputDecoration(
              labelText: 'Amount Paid',
              hintText: 'Enter amount you paid',
              prefixText: '₹ ',
            ),
```

**CHANGE TO:**
```dart
            decoration: const InputDecoration(
              labelText: 'Amount Paid',
              hintText: 'Enter amount you paid',
              prefixText: '$defaultCurrencySymbol ',
            ),
```

### 4.4 Replace Total Amount in Members header (Lines 317 to 323)

**CURRENT CODE:**
```dart
                        Text(
                          'Total: ₹${(_creatorAmountPaid + _friends.fold(0.0, (sum, friend) => sum + friend.amountPaid)).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                          ),
                        ),
```

**CHANGE TO:**
```dart
                        Text(
                          'Total: ${formatCurrency(_creatorAmountPaid + _friends.fold(0.0, (sum, friend) => sum + friend.amountPaid))}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                          ),
                        ),
```

### 4.5 Replace Creator Payment display (Lines 356 to 365)

**CURRENT CODE:**
```dart
                        Text(
                          'Paid: ₹${_creatorAmountPaid.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _creatorAmountPaid > 0 
                                    ? Colors.green[700] 
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                          ),
                        ),
```

**CHANGE TO:**
```dart
                        Text(
                          'Paid: ${formatCurrency(_creatorAmountPaid)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _creatorAmountPaid > 0 
                                    ? Colors.green[700] 
                                    : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                          ),
                        ),
```

### 4.6 Replace Friend Payment display (Lines 422 to 431)

**CURRENT CODE:**
```dart
                            Text(
                              'Paid: ₹${friend.amountPaid.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: friend.amountPaid > 0 
                                        ? Colors.green[700] 
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                ),
                            ),
```

**CHANGE TO:**
```dart
                            Text(
                              'Paid: ${formatCurrency(friend.amountPaid)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: friend.amountPaid > 0 
                                        ? Colors.green[700] 
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                ),
                            ),
```

---

## 7. STEP 5: Modify `lib/pages/group_details_page.dart`

File to modify: `/home/deval/Projects/expense-splitter/lib/pages/group_details_page.dart`

### 5.1 Add import
Add the currency utility import at the top of the file:
```dart
import '../utils/currency.dart';
```

### 5.2 Replace Total Amount and Fair Share in `_buildEventInfoCard` (Lines 256 to 271)

**CURRENT CODE:**
```dart
            // Total Amount
            _buildInfoRow(
              'Total Amount',
              '₹${totalAmount.toStringAsFixed(2)}',
              Icons.payments,
              Colors.green[700]!,
            ),
            const SizedBox(height: 12),

            // Fair Share
            _buildInfoRow(
              'Per Person Share',
              '₹${fairShare.toStringAsFixed(2)}',
              Icons.person,
              Colors.blue[700]!,
            ),
```

**CHANGE TO:**
```dart
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
```

### 5.3 Replace Member Payment in `_buildEventInfoCard` (Lines 322 to 330)

**CURRENT CODE:**
```dart
                      Text(
                        'Paid ₹${member.amountPaid.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: member.amountPaid > 0
                              ? Colors.green[700]
                              : Colors.grey[600],
                        ),
                      ),
```

**CHANGE TO:**
```dart
                      Text(
                        'Paid ${formatCurrency(member.amountPaid)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: member.amountPaid > 0
                              ? Colors.green[700]
                              : Colors.grey[600],
                        ),
                      ),
```

### 5.4 Replace Average Expense in `_buildStatsCard` (Lines 409 to 414)

**CURRENT CODE:**
```dart
            _buildInfoRow(
              'Average Expense',
              '₹${stats.averageExpense.toStringAsFixed(2)}',
              Icons.trending_up,
              Colors.teal[700]!,
            ),
```

**CHANGE TO:**
```dart
            _buildInfoRow(
              'Average Expense',
              formatCurrency(stats.averageExpense),
              Icons.trending_up,
              Colors.teal[700]!,
            ),
```

### 5.5 Replace Category Value in `_buildStatsCard` (Lines 447 to 452)

**CURRENT CODE:**
```dart
                          Text(
                            '₹${entry.value.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
```

**CHANGE TO:**
```dart
                          Text(
                            formatCurrency(entry.value),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
```

### 5.6 Replace Member Net Position in `_buildStatsCard` (Lines 505 to 512)

**CURRENT CODE:**
```dart
                      Text(
                        '$prefix₹${amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
```

**CHANGE TO:**
```dart
                      Text(
                        '$prefix${formatCurrency(amount)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
```

### 5.7 Replace Pending Settlement Amount in `_buildPendingSettlementsList` (Lines 639 to 647)

**CURRENT CODE:**
```dart
                      child: Text(
                        '₹${settlement.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                      ),
```

**CHANGE TO:**
```dart
                      child: Text(
                        formatCurrency(settlement.amount),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                      ),
```

### 5.8 Replace Completed Settlement Amount in `_buildCompletedSettlementsList` (Lines 727 to 734)

**CURRENT CODE:**
```dart
                Text(
                  '₹${settlement.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
```

**CHANGE TO:**
```dart
                Text(
                  formatCurrency(settlement.amount),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
```

### 5.9 Replace Amount in `_showMarkAsPaidDialog` (Lines 762 to 766)

**CURRENT CODE:**
```dart
              TextSpan(
                text: '₹${settlement.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
```

**CHANGE TO:**
```dart
              TextSpan(
                text: formatCurrency(settlement.amount),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
```

---

## 8. STEP 6: Modify `lib/pages/add_expense_page.dart`

File to modify: `/home/deval/Projects/expense-splitter/lib/pages/add_expense_page.dart`

### 6.1 Add import
Add the currency utility import at the top of the file:
```dart
import '../utils/currency.dart';
```

### 6.2 Update `_validateUnequalSplit` SnackBars (Lines 159 to 184)

**CURRENT CODE:**
```dart
    // Check if sum exceeds total
    if (enteredSum > totalAmount + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sum of consumption (₹${enteredSum.toStringAsFixed(2)}) exceeds total amount (₹${totalAmount.toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

    // If all fields are filled and sum doesn't match exactly
    if (emptyCount == 0 && (enteredSum - totalAmount).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sum of consumption (₹${enteredSum.toStringAsFixed(2)}) must equal total amount (₹${totalAmount.toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.orange[600],
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
```

**CHANGE TO:**
```dart
    // Check if sum exceeds total
    if (enteredSum > totalAmount + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sum of consumption (${formatCurrency(enteredSum)}) exceeds total amount (${formatCurrency(totalAmount)})',
          ),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

    // If all fields are filled and sum doesn't match exactly
    if (emptyCount == 0 && (enteredSum - totalAmount).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sum of consumption (${formatCurrency(enteredSum)}) must equal total amount (${formatCurrency(totalAmount)})',
          ),
          backgroundColor: Colors.orange[600],
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
```

### 6.3 Update Total Amount Field in `_buildExpenseDetailsCard` (Lines 420 to 425)

**CURRENT CODE:**
```dart
              decoration: InputDecoration(
                labelText: 'Amount *',
                hintText: 'Enter amount',
                prefixText: '₹ ',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
```

**CHANGE TO:**
```dart
              decoration: InputDecoration(
                labelText: 'Amount *',
                hintText: 'Enter amount',
                prefixText: '$defaultCurrencySymbol ',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
```

### 6.4 Update `_buildSplitInfoText` (Lines 894 to 900)

**CURRENT CODE:**
```dart
  String _buildSplitInfoText() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return '';

    final sharePerPerson = amount / _selectedParticipants.length;
    return 'Split equally: ₹${sharePerPerson.toStringAsFixed(2)} per person';
  }
```

**CHANGE TO:**
```dart
  String _buildSplitInfoText() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return '';

    final sharePerPerson = amount / _selectedParticipants.length;
    return 'Split equally: ${formatCurrency(sharePerPerson)} per person';
  }
```

### 6.5 Update Consumption TextField `prefixText` (Lines 975 to 978)

**CURRENT CODE:**
```dart
                        decoration: InputDecoration(
                          hintText: 'Amount',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
```

**CHANGE TO:**
```dart
                        decoration: InputDecoration(
                          hintText: 'Amount',
                          prefixText: '$defaultCurrencySymbol ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
```

### 6.6 Update Messages in `_buildConsumptionSummary` (Lines 1060 to 1090)

**CURRENT CODE:**
```dart
    if (enteredSum > totalAmount + 0.01) {
      // Exceeds total
      bgColor = Colors.red[50]!;
      borderColor = Colors.red[200]!;
      textColor = Colors.red[900]!;
      icon = Icons.error_outline;
      message =
          'Entered: ₹${enteredSum.toStringAsFixed(2)} | Exceeds total by ₹${(enteredSum - totalAmount).toStringAsFixed(2)}';
    } else if (emptyCount == 0 && (enteredSum - totalAmount).abs() > 0.01) {
      // All filled but doesn't match
      bgColor = Colors.orange[50]!;
      borderColor = Colors.orange[200]!;
      textColor = Colors.orange[900]!;
      icon = Icons.warning_amber;
      message =
          'Entered: ₹${enteredSum.toStringAsFixed(2)} | Missing: ₹${remaining.toStringAsFixed(2)}';
    } else if (emptyCount > 0 && remaining > 0) {
      // Will auto-distribute
      final autoShare = remaining / emptyCount;
      bgColor = Colors.blue[50]!;
      borderColor = Colors.blue[200]!;
      textColor = Colors.blue[900]!;
      icon = Icons.auto_fix_high;
      message =
          'Entered: ₹${enteredSum.toStringAsFixed(2)} | Remaining ₹${remaining.toStringAsFixed(2)} will be split among $emptyCount member${emptyCount > 1 ? 's' : ''} (₹${autoShare.toStringAsFixed(2)} each)';
    } else {
```

**CHANGE TO:**
```dart
    if (enteredSum > totalAmount + 0.01) {
      // Exceeds total
      bgColor = Colors.red[50]!;
      borderColor = Colors.red[200]!;
      textColor = Colors.red[900]!;
      icon = Icons.error_outline;
      message =
          'Entered: ${formatCurrency(enteredSum)} | Exceeds total by ${formatCurrency(enteredSum - totalAmount)}';
    } else if (emptyCount == 0 && (enteredSum - totalAmount).abs() > 0.01) {
      // All filled but doesn't match
      bgColor = Colors.orange[50]!;
      borderColor = Colors.orange[200]!;
      textColor = Colors.orange[900]!;
      icon = Icons.warning_amber;
      message =
          'Entered: ${formatCurrency(enteredSum)} | Missing: ${formatCurrency(remaining)}';
    } else if (emptyCount > 0 && remaining > 0) {
      // Will auto-distribute
      final autoShare = remaining / emptyCount;
      bgColor = Colors.blue[50]!;
      borderColor = Colors.blue[200]!;
      textColor = Colors.blue[900]!;
      icon = Icons.auto_fix_high;
      message =
          'Entered: ${formatCurrency(enteredSum)} | Remaining ${formatCurrency(remaining)} will be split among $emptyCount member${emptyCount > 1 ? 's' : ''} (${formatCurrency(autoShare)} each)';
    } else {
```

---

## 9. Testing Checklist

Execute these checks after making the changes:

- [ ] **Static Analysis:** Run `flutter analyze` and confirm zero errors or warnings.
- [ ] **Find & Replace Verification:**
  - Search all `.dart` files in `lib/` for the character `₹`.
  - Confirm the only remaining occurrences are inside `lib/utils/currency.dart` (as `defaultCurrencySymbol` and in `supportedCurrencySymbols`) and the default parameter in `GroupBalanceView.balanceText([String symbol = '₹'])`.
- [ ] **Overall Balance Display:**
  - Open app -> `GroupsListPage`.
  - Confirm the overall balance card displays amounts formatted as `₹123.45` (or `Settled up`).
  - Confirm each event card subtitle displays `balanceText()` formatted properly.
- [ ] **Create Event Page:**
  - Tap `+` to open `CreateGroupPage`.
  - Open "Your Payment" dialog -> confirm amount input prefix shows `₹ `.
  - Open "Add Friend" dialog -> confirm amount input prefix shows `₹ `.
  - Add friend with amount -> confirm total paid shows formatted amount `Total: ₹...`.
- [ ] **Group Details Page:**
  - Open any group.
  - Confirm "Total Amount", "Per Person Share", and member payments show formatted currency.
  - Confirm "Average Expense", category breakdown, and member net positions show formatted currency.
  - Confirm pending settlements and completed settlements show formatted currency.
  - Tap "Mark as Paid" -> confirm the confirmation dialog shows formatted currency.
- [ ] **Add Expense Page:**
  - Tap "Add Expense".
  - Amount input prefix shows `₹ `.
  - Equal split shows "Split equally: ₹... per person".
  - Unequal split consumption inputs show `₹ `.
  - Unequal split summary validation banner shows formatted currency amounts.
