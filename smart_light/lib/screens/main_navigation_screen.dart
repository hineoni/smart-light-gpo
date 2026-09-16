import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import 'device_list_screen.dart';
import 'positioning_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    const DeviceListScreen(),
    const PositioningScreen(),
    SettingsScreen(settings: AppSettings.instance),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: _screens,
      ),
      bottomNavigationBar: _AppNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: _selectPage,
      ),
    );
  }
}

class _AppNavigationBar extends StatelessWidget {
  const _AppNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _icons = [
    Icons.devices_outlined,
    Icons.hub_outlined,
    Icons.settings_outlined,
  ];
  static const _selectedIcons = [
    Icons.devices_other,
    Icons.hub,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox(
        height: 96,
        child: Container(
          color: colors.surface,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 26),
          child: Row(
            children: List.generate(_icons.length, (index) {
              final selected = index == selectedIndex;
              return Expanded(
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onSelected(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: selected ? colors.primaryContainer : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        selected ? _selectedIcons[index] : _icons[index],
                        color: selected
                            ? colors.onPrimaryContainer
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
