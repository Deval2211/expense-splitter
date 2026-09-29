# TASK-07: Dark Theme Support

> **Target Model:** Small / Free AI Models  
> **Status:** Ready for implementation  
> **Complexity:** Low  
> **Target Path:** `/home/deval/Projects/expense-splitter/docs/tasks/TASK-07-dark-theme.md`

---

## 1. Overview

This task adds **Dark Theme support** to the Expense Splitter Flutter app.
Users can switch between **System Default**, **Light**, and **Dark** theme modes via a new **Theme** menu option in the home page (`GroupsListPage`) AppBar.
The selected theme mode is stored locally in `SharedPreferences` under the key `'themeMode'` with values `'system'`, `'light'`, or `'dark'`, ensuring the user's choice is remembered across app restarts.

---

## 2. Files to Modify

1. `/home/deval/Projects/expense-splitter/lib/main.dart`
2. `/home/deval/Projects/expense-splitter/lib/pages/groups_list_page.dart`

No new packages or database migrations are required.

---

## 3. Step-by-Step Implementation Instructions

### Step 1: Modify `/home/deval/Projects/expense-splitter/lib/main.dart`

We need to:
1. Create a top-level `ValueNotifier<ThemeMode> themeNotifier` to broadcast theme changes throughout the widget tree.
2. Create an `updateThemeMode(ThemeMode mode)` helper function to change the value and persist it to `SharedPreferences` (`'themeMode'`: `'light'`, `'dark'`, or `'system'`).
3. In `main()`, load the saved preference before calling `runApp()`.
4. Update `MyApp` with `ValueListenableBuilder<ThemeMode>` wrapping `MaterialApp`.
5. Add `darkTheme` with `ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark)` and set `themeMode: currentMode`.

#### Full CURRENT Code of `lib/main.dart` (Lines 1 to 40):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'pages/login_page.dart';
import 'pages/groups_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite based on platform
  if (!kIsWeb) {
    // Only use FFI for desktop platforms (Windows, macOS, Linux)
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // For Android and iOS, sqflite works natively without FFI
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Splitter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: kIsWeb ? const WebFallbackPage() : const AppEntry(),
    );
  }
}
```

#### EXACT REPLACEMENT for `lib/main.dart` (Lines 1 to 40):

Replace lines 1 to 40 in `/home/deval/Projects/expense-splitter/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'pages/login_page.dart';
import 'pages/groups_list_page.dart';

/// Global notifier to manage and notify theme mode changes across the app
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

/// Updates the active theme mode and persists the preference to SharedPreferences
Future<void> updateThemeMode(ThemeMode mode) async {
  themeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  String value;
  switch (mode) {
    case ThemeMode.light:
      value = 'light';
      break;
    case ThemeMode.dark:
      value = 'dark';
      break;
    case ThemeMode.system:
      value = 'system';
      break;
  }
  await prefs.setString('themeMode', value);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('themeMode') ?? 'system';
    if (savedTheme == 'light') {
      themeNotifier.value = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      themeNotifier.value = ThemeMode.dark;
    } else {
      themeNotifier.value = ThemeMode.system;
    }
  } catch (e) {
    debugPrint('Error loading theme preference: $e');
  }
  
  // Initialize sqflite based on platform
  if (!kIsWeb) {
    // Only use FFI for desktop platforms (Windows, macOS, Linux)
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // For Android and iOS, sqflite works natively without FFI
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Expense Splitter',
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: kIsWeb ? const WebFallbackPage() : const AppEntry(),
        );
      },
    );
  }
}
```

---

### Step 2: Modify `/home/deval/Projects/expense-splitter/lib/pages/groups_list_page.dart`

We need to:
1. Import `../main.dart` to access `themeNotifier` and `updateThemeMode()`.
2. Add a `Theme` option to the AppBar's `PopupMenuButton`.
3. Add a helper method `_showThemeDialog()` that lets the user choose between `System Default`, `Light`, and `Dark`.

#### Current Imports in `lib/pages/groups_list_page.dart` (Lines 1 to 9):

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

#### Replacement Imports:

Replace lines 1 to 9 with:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import '../models/group.dart';
import '../main.dart';
import 'create_group_page.dart';
import 'group_details_page.dart';
import 'login_page.dart';
```

---

#### Current AppBar Code in `lib/pages/groups_list_page.dart` (Lines 89 to 108):

```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
        ],
      ),
```

#### Replacement AppBar Code:

Replace lines 89 to 108 with:

```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'theme') {
                _showThemeDialog();
              } else if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.brightness_6, size: 20),
                    SizedBox(width: 12),
                    Text('Theme'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
```

---

#### Add Method `_showThemeDialog()` inside `_GroupsListPageState`:

Add this method to `_GroupsListPageState` (for instance, right after `_handleLogout()` around line 57):

```dart
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Choose Theme'),
          // RadioGroup owns groupValue/onChanged for the tiles below.
          // The tiles must NOT set groupValue or onChanged themselves:
          // those parameters were deprecated after Flutter v3.32.0.
          content: RadioGroup<ThemeMode>(
            groupValue: themeNotifier.value,
            onChanged: (ThemeMode? value) {
              if (value != null) {
                updateThemeMode(value);
                Navigator.pop(dialogContext);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                RadioListTile<ThemeMode>(
                  title: Text('System Default'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Light'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Dark'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
```

> **Note:** `RadioGroup<T>` is exported from `package:flutter/material.dart` (defined in `flutter/lib/src/widgets/radio_group.dart`). No extra import is required.
> The original per-tile `groupValue` + `onChanged` approach also triggered a dead `setDialogState(() {})` call, because the dialog was popped immediately afterwards. `RadioGroup` removes the need for that entirely.

---

## 4. Testing Checklist

Execute these checks after applying the changes:

- [ ] **Run Code Analysis**: Run `flutter analyze`. There must be 0 errors and 0 warnings.
- [ ] **Menu Presence**: Open the app to the home screen (`GroupsListPage`), tap the three-dots menu icon in the AppBar, and ensure both "Theme" and "Logout" appear.
- [ ] **Open Theme Dialog**: Tap "Theme". An `AlertDialog` titled "Choose Theme" must appear showing three radio options:
  - System Default
  - Light
  - Dark
- [ ] **Switch to Dark Mode**:
  - Tap "Dark".
  - The dialog must dismiss immediately.
  - The app must immediately switch to dark colors (dark background, dark AppBar, dark card surfaces).
- [ ] **Switch to Light Mode**:
  - Tap the menu, tap "Theme", and select "Light".
  - The app must immediately revert to light theme.
- [ ] **Switch to System Default**:
  - Tap "Theme", select "System Default".
  - The app must match the host OS theme setting (light if OS is light, dark if OS is dark).
- [ ] **Verify Persistence**:
  - Select "Dark" mode.
  - Fully quit/close the application.
  - Restart the application.
  - Confirm the app starts immediately in Dark Mode without flickering back to Light.
