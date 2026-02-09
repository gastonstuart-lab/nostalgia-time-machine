import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nostalgia_time_machine/state.dart';
import 'package:nostalgia_time_machine/theme.dart';

/// A reusable theme toggle button that switches between light and dark mode
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NostalgiaProvider>();
    final isDark = provider.themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: () => provider.toggleTheme(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface,
            width: 2,
          ),
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: isDark ? AppTheme.darkOnSurface : AppTheme.lightOnSurface,
          size: 20,
        ),
      ),
    );
  }
}
