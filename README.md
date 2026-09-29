# Expense Splitter

A Flutter app for splitting expenses among friends. Create groups, add expenses with equal or unequal splits, and let the app calculate who owes whom using smart debt simplification.

## Features

- **User Profiles** — Name + optional phone, stored locally
- **Groups (Events)** — Create events with friends, track payments
- **Expense Tracking** — Equal split or per-person consumption (unequal split)
- **Categories & Notes** — Categorize expenses (Food, Transport, etc.)
- **Smart Settlements** — Greedy debt-simplification algorithm minimizes payments
- **Expense Insights** — Category breakdown, member net positions
- **Cross-Platform** — Android, iOS, Windows, macOS, Linux

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.47+ / Dart 3.13+ |
| Database | SQLite via sqflite / sqflite_common_ffi |
| Session | SharedPreferences |
| IDs | UUID v4 |
| Design | Material 3 |

## Getting Started

```bash
# Clone and install
git clone <repo-url>
cd expense-splitter
flutter pub get

# Run on your platform
flutter run -d linux      # Desktop
flutter run -d <device>   # Android/iOS

# Check for issues
flutter analyze
flutter test
```

## Architecture

This project follows a **3-layer architecture**:

```
UI (Pages) → Repository → Database (SQLite)
```

- **Pages** (`lib/pages/`) — StatefulWidgets handling UI and user interaction
- **Repositories** (`lib/repositories/`) — Business logic and SQL operations
- **Database** (`lib/database/`) — SQLite singleton with schema and migrations
- **Models** (`lib/models/`) — Plain Dart classes with serialization

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full architecture reference, database schema, algorithm documentation, and coding conventions.

## Contributing (For AI Models & Developers)

Self-contained task files are in [`docs/tasks/`](docs/tasks/). Each task file contains everything needed to implement one feature:

| Task | Feature | Priority | Complexity |
|------|---------|----------|------------|
| [TASK-01](docs/tasks/TASK-01-edit-delete-expense.md) | Edit / Delete Expense | High | Medium |
| [TASK-02](docs/tasks/TASK-02-delete-group.md) | Delete Group | High | Low |
| [TASK-03](docs/tasks/TASK-03-edit-group.md) | Edit Group | Medium | Medium |
| [TASK-04](docs/tasks/TASK-04-expense-history.md) | Expense History Timeline | Medium | Low |
| [TASK-05](docs/tasks/TASK-05-profile-edit.md) | User Profile Edit | Low | Low |
| [TASK-06](docs/tasks/TASK-06-currency-formatting.md) | Currency Formatting | Low | Low |
| [TASK-07](docs/tasks/TASK-07-dark-theme.md) | Dark Theme | Low | Low |
| [TASK-08](docs/tasks/TASK-08-export-share.md) | Export / Share Summary | Low | Medium |
| [TASK-09](docs/tasks/TASK-09-percentage-split.md) | Percentage Split | Medium | Medium |
| [TASK-10](docs/tasks/TASK-10-search-filter.md) | Search & Filter | Low | Low |

**To assign a task to a small AI model**, just tell it:
> Read the file `docs/tasks/TASK-XX-<name>.md` and implement the feature described in it. Follow the coding conventions in `docs/ARCHITECTURE.md`.

### Coding Conventions

- Models: `lib/models/` — `toMap()`, `fromMap()`, `copyWith()`
- Repos: `lib/repositories/` — constructor takes `AppDatabase`, all SQL here
- Pages: `lib/pages/` — `StatefulWidget`, `_isLoading`/`_errorMessage` pattern
- Files: `snake_case.dart`, Classes: `PascalCase`
- Transactions: `db.transaction((txn) async { ... })` for multi-table ops
- Navigation: `Navigator.push()` with `MaterialPageRoute`, return `true` to signal refresh

## License

Private project — not published to pub.dev.
