import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  bool get isLoading => _isLoading;

  ThemeProvider() {
    _loadThemePreference();
  }

  void _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> toggleTheme() async {
    // Prevent multiple rapid toggles
    if (_isLoading) {
      debugPrint('⏳ Theme toggle already in progress, ignoring request');
      return;
    }

    _isLoading = true;
    debugPrint('🔄 Starting theme toggle...');

    try {
      final newMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

      // Save preference FIRST before updating state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', newMode == ThemeMode.dark);
      debugPrint(
          '✅ Theme preference saved: ${newMode == ThemeMode.dark ? "Dark" : "Light"}');

      // Small delay to ensure SharedPreferences write is truly complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Update state only AFTER successful save
      _themeMode = newMode;
      notifyListeners();
      debugPrint('🎨 Theme updated and listeners notified');
    } catch (e) {
      debugPrint('❌ Error toggling theme: $e');
    } finally {
      // Ensure _isLoading is reset
      _isLoading = false;
      debugPrint('✓ Theme toggle complete');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_isLoading) {
      debugPrint('⏳ Theme change already in progress, ignoring request');
      return;
    }

    if (_themeMode == mode) {
      debugPrint(
          'ℹ️ Already in ${mode == ThemeMode.dark ? "dark" : "light"} mode');
      return;
    }

    _isLoading = true;
    debugPrint(
        '🔄 Starting theme change to ${mode == ThemeMode.dark ? "dark" : "light"}...');

    try {
      // Save preference FIRST before updating state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
      debugPrint(
          '✅ Theme preference saved: ${mode == ThemeMode.dark ? "Dark" : "Light"}');

      // Small delay to ensure SharedPreferences write is truly complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Update state only AFTER successful save
      _themeMode = mode;
      notifyListeners();
      debugPrint('🎨 Theme changed and listeners notified');
    } catch (e) {
      debugPrint('❌ Error setting theme mode: $e');
    } finally {
      // Ensure _isLoading is reset
      _isLoading = false;
      debugPrint('✓ Theme change complete');
    }
  }
}
