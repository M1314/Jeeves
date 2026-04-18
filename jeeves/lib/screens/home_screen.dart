/// Root navigation scaffold for the Jeeves application.
///
/// [HomeScreen] owns a [NavigationBar] with three destinations:
///  1. **Search** ([SearchScreen]) — full-text search with filters.
///  2. **Analytics** ([AnalyticsScreen]) — charts and ranked lists.
///  3. **Settings** ([SettingsScreen]) — blog source management.
///
/// When the Search tab is active, a [FloatingActionButton.extended] is shown
/// that triggers a full sync of all enabled blog sources via [SyncService].
/// The FAB is disabled and shows an in-progress indicator while a sync is
/// running to prevent double-triggers.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';
import 'search_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

/// Top-level stateful widget that manages the active navigation tab and
/// conditionally renders the sync FAB.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Index of the currently selected [NavigationBar] destination.
  int _selectedIndex = 0;

  /// The three primary screens of the app.  Declared as a static const list
  /// so the same widget instances are reused when switching tabs, preserving
  /// each screen's scroll position and state.
  static const _screens = [
    SearchScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Watch SyncService so the FAB label and icon react to sync state changes
    // without rebuilding the entire screen tree.
    final sync = context.watch<SyncService>();

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      // The FAB is only shown on the Search tab; other tabs don't need it.
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              // Disable the button while a sync is running to prevent
              // concurrent overlapping syncs.
              onPressed: sync.isSyncing ? null : () => sync.syncAll(),
              icon: sync.isSyncing
                  // Show an indeterminate spinner inside the FAB while syncing.
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(sync.isSyncing ? 'Syncing…' : 'Sync now'),
            )
          : null,
    );
  }
}
