# TASK-05: User Profile Edit Page

> **Target Audience:** Small or free AI models.  
> **Self-Contained Rule:** This file contains all necessary code, context, exact paths, and step-by-step instructions. You do not need to look at any other documentation to complete this task.

---

## 1. Overview & Objectives

When users first launch the Expense Splitter app, they enter their name and optional phone number on the Login page (`LoginPage`). However, after this initial setup, there is currently no way for users to view or update their profile details.

### What you will build:
1. A new screen: `ProfilePage` in `lib/pages/profile_page.dart`.
2. Automatic pre-filling of the user's existing name and phone number loaded from SQLite database via `UserRepository.getUserById()`.
3. An edit form with validation (name required, phone optional).
4. Profile update logic calling `UserRepository.updateUser()` with the modified `User` object.
5. Navigation integration: Add a "Profile" option to the `PopupMenuButton` in `GroupsListPage` (`lib/pages/groups_list_page.dart`), situated above "Logout".
6. Return a boolean `true` on pop so `GroupsListPage` refreshes its data if the name changed.

---

## 2. File Operations Summary

| Action | File Path |
|---|---|
| **CREATE** | `/home/deval/Projects/expense-splitter/lib/pages/profile_page.dart` |
| **MODIFY** | `/home/deval/Projects/expense-splitter/lib/pages/groups_list_page.dart` |

---

## 3. Data Models & Architecture Reference

### Session Management
The logged-in user's ID is stored in `SharedPreferences` with the key `'currentUserId'`:
```dart
final prefs = await SharedPreferences.getInstance();
final currentUserId = prefs.getString('currentUserId');
```

### `User` Model (`lib/repositories/user_repository.dart`)
Defined in `lib/repositories/user_repository.dart`:
```dart
class User {
  final String id;
  final String name;
  final String? phone;
  final int createdAt;

  User({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'createdAt': createdAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      createdAt: map['createdAt'] as int,
    );
  }
}
```

### `UserRepository` Methods (`lib/repositories/user_repository.dart`)
Instantiated with `UserRepository(database: AppDatabase())`.
- `Future<User?> getUserById(String userId)`: Retrieves existing user by ID.
- `Future<void> updateUser(User user)`: Updates the record in the SQLite `users` table matching `user.id`.

---

## 4. STEP 1: Create `lib/pages/profile_page.dart`

Create `/home/deval/Projects/expense-splitter/lib/pages/profile_page.dart` with the complete, self-contained code below:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../repositories/user_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  late UserRepository _userRepository;
  User? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final database = AppDatabase();
    _userRepository = UserRepository(database: database);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('currentUserId');

      if (currentUserId == null) {
        setState(() {
          _errorMessage = 'No active user session found.';
          _isLoading = false;
        });
        return;
      }

      final user = await _userRepository.getUserById(currentUserId);

      if (user == null) {
        setState(() {
          _errorMessage = 'User profile not found.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentUser = user;
        _nameController.text = user.name;
        _phoneController.text = user.phone ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedName = _nameController.text.trim();
      final updatedPhone = _phoneController.text.trim();

      final updatedUser = User(
        id: _currentUser!.id,
        name: updatedName,
        phone: updatedPhone.isEmpty ? null : updatedPhone,
        createdAt: _currentUser!.createdAt,
      );

      await _userRepository.updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Profile updated successfully'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );

        // Pop back to GroupsListPage and pass true to trigger reload
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile: ${e.toString()}';
        _isSaving = false;
      });
    }
  }

  String _formatDate(int timestamp) {
    if (timestamp <= 0) return 'Unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _currentUser == null) {
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
                onPressed: _loadUserProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final initialLetter = (_currentUser?.name.isNotEmpty ?? false)
        ? _currentUser!.name[0].toUpperCase()
        : 'U';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),

            // Profile Avatar
            CircleAvatar(
              radius: 46,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                initialLetter,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Member Info Card
            Card(
              elevation: 0,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Member Since',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(_currentUser?.createdAt ?? 0),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 24, width: 1, color: Colors.grey[400]),
                    Column(
                      children: [
                        Text(
                          'Account ID',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser != null && _currentUser!.id.length >= 8
                              ? '${_currentUser!.id.substring(0, 8)}...'
                              : 'Local User',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Name Field
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Full Name *',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !_isSaving,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Phone Field
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Phone Number (Optional)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                hintText: 'Enter your phone number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.phone,
              enabled: !_isSaving,
            ),
            const SizedBox(height: 24),

            // Error Display (if saving fails)
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _isSaving ? 'Saving Changes...' : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 5. STEP 2: Modify `lib/pages/groups_list_page.dart`

File to modify: `/home/deval/Projects/expense-splitter/lib/pages/groups_list_page.dart`

### Change 1: Add import for `profile_page.dart`
Locate the imports at the top of the file (lines 1 to 8):

**CURRENT CODE:**
```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import '../models/group.dart';
import 'create_group_page.dart';
import 'group_details_page.dart';
import 'login_page.dart';
```

**CHANGE TO:**
```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import '../models/group.dart';
import 'create_group_page.dart';
import 'group_details_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
```

---

### Change 2: Add `_navigateToProfile` method to `_GroupsListPageState`
Locate `_handleLogout` and `_navigateToCreateGroup` in `_GroupsListPageState` (around line 56 to 77):

**CURRENT CODE:**
```dart
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserId');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    }
  }

  void _refreshData() {
    setState(() {
      _refreshKey++;
    });
  }

  Future<void> _navigateToCreateGroup() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupPage(),
      ),
    );

    // If a group was created successfully, refresh the data
    if (result == true) {
      _refreshData();
    }
  }
```

**CHANGE TO:**
```dart
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('currentUserId');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    }
  }

  void _refreshData() {
    setState(() {
      _refreshKey++;
    });
  }

  Future<void> _navigateToProfile() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfilePage(),
      ),
    );

    // If profile was updated, refresh the page data
    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _navigateToCreateGroup() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupPage(),
      ),
    );

    // If a group was created successfully, refresh the data
    if (result == true) {
      _refreshData();
    }
  }
```

---

### Change 3: Update `PopupMenuButton` in AppBar
Locate the `PopupMenuButton` inside the `AppBar` (lines 94 to 106):

**CURRENT CODE:**
```dart
          PopupMenuButton(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
```

**CHANGE TO:**
```dart
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                _navigateToProfile();
              } else if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
```

---

## 6. Testing Checklist

Execute these checks after making the changes:

- [ ] **Static Analysis:** Run `flutter analyze` and confirm zero errors or warnings.
- [ ] **Menu Option:**
  - Launch app and log in (or enter existing session).
  - On the `Events` screen (`GroupsListPage`), tap the three-dots menu icon in the top-right corner.
  - Verify two items are visible: "Profile" (with person icon) and "Logout" (with logout icon).
- [ ] **Profile Data Loading:**
  - Tap "Profile".
  - Confirm `ProfilePage` opens with the AppBar title "Edit Profile".
  - Verify the avatar letter matches the first letter of user's name.
  - Verify the "Full Name" field contains the current user's name.
  - Verify the "Phone Number" field contains the current user's phone (or is blank if none was set).
- [ ] **Form Validation:**
  - Clear the "Full Name" field and tap "Save Changes".
  - Verify that the validation error "Name is required" appears and no save occurs.
- [ ] **Successful Update:**
  - Change the name to a new name (e.g., from "John" to "John Doe").
  - Enter or edit a phone number (e.g., "9876543210").
  - Tap "Save Changes".
  - Verify the loading indicator displays briefly.
  - Verify a green SnackBar "Profile updated successfully" appears.
  - Verify the screen automatically pops back to `GroupsListPage`.
- [ ] **Persistence:**
  - Re-open "Profile" from the menu.
  - Confirm that the new name and phone number are persisted in the form fields.
  - Restart the app and verify the updated profile remains saved in SQLite.
