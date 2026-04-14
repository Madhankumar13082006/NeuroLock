import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'home_screen.dart';
import 'usage_tab_screen.dart';
import 'limits_tab_screen.dart';
import 'inbox_tab_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: IndexedStack(
        index: _index,
        children: const [
          UsageTabScreen(),
          LimitsTabScreen(),
          HomeScreen(),
          InboxTabScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Usage',
          ),
          NavigationDestination(
            icon: Icon(Icons.hourglass_empty_rounded),
            selectedIcon: Icon(Icons.hourglass_bottom_rounded),
            label: 'Limits',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Block',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline_rounded),
            selectedIcon: Icon(Icons.mail_rounded),
            label: 'Inbox',
          ),
        ],
      ),
    );
  }
}
