import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  void _selectPage(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: _AppNavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
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
