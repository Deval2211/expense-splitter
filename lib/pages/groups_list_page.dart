import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../repositories/group_repository.dart';
import '../models/group.dart';
import 'create_group_page.dart';
import 'group_details_page.dart';
import 'login_page.dart';

class GroupsListPage extends StatefulWidget {
  const GroupsListPage({Key? key}) : super(key: key);

  @override
  State<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  late GroupRepository _groupRepository;
  String? _currentUserId; // Make nullable to handle loading state
  int _refreshKey = 0; // Add refresh key to trigger rebuilds

  @override
  void initState() {
    super.initState();
    final database = AppDatabase();
    _groupRepository = GroupRepository(database: database);
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('currentUserId');
      if (userId != null) {
        setState(() {
          _currentUserId = userId;
        });
      }
    } catch (e) {
      debugPrint('Error loading current user ID: $e');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    // Show loading indicator until current user ID is loaded
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
      body: FutureBuilder<double>(
        key: ValueKey(_refreshKey), // Add key to force rebuild on refresh
        future: _groupRepository.getOverallNetBalance(_currentUserId!),
        builder: (context, overallBalanceSnapshot) {
          return FutureBuilder<List<GroupBalanceView>>(
            key: ValueKey('groups_$_refreshKey'), // Add key to force rebuild on refresh
            future: _groupRepository.getGroupsWithBalance(_currentUserId!),
            builder: (context, groupsSnapshot) {
              if (overallBalanceSnapshot.connectionState ==
                      ConnectionState.waiting ||
                  groupsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (overallBalanceSnapshot.hasError ||
                  groupsSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading events',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                );
              }

              final overallBalance = overallBalanceSnapshot.data ?? 0;
              final groupsWithBalance = groupsSnapshot.data ?? [];

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overall balance card
                      _buildOverallBalanceCard(context, overallBalance),
                      const SizedBox(height: 24),

                      // Divider
                      Divider(
                        color: Colors.grey[300],
                        thickness: 1,
                      ),
                      const SizedBox(height: 16),

                      // Groups list or empty state
                      if (groupsWithBalance.isEmpty)
                        _buildEmptyState(context)
                      else
                        _buildGroupsList(context, groupsWithBalance),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateGroup,
        tooltip: 'Add Event',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOverallBalanceCard(BuildContext context, double balance) {
    final isOwed = balance > 0;
    final isNegative = balance < 0;

    Color cardColor;
    String balanceText;

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

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your overall balance',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              balanceText,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isOwed
                        ? Colors.green.shade700
                        : isNegative
                            ? Colors.red.shade700
                            : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No events yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first event',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList(
    BuildContext context,
    List<GroupBalanceView> groupsWithBalance,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupsWithBalance.length,
      itemBuilder: (context, index) {
        final groupBalance = groupsWithBalance[index];
        final balance = groupBalance.netBalance;
        final isOwed = balance > 0;
        final isNegative = balance < 0;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            title: Text(
              groupBalance.group.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
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
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GroupDetailsPage(groupBalanceView: groupBalance),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
