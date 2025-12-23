import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

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

  void toggleTheme() async {
    // Prevent multiple rapid toggles
    if (_isLoading) return;

    _isLoading = true;

    try {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    } catch (e) {
      debugPrint('Error toggling theme: $e');
    } finally {
      _isLoading = false;
    }
  }

  void setThemeMode(ThemeMode mode) async {
    if (_isLoading || _themeMode == mode) return;

    _isLoading = true;

    try {
      _themeMode = mode;
      notifyListeners();

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', mode == ThemeMode.dark);
    } catch (e) {
      debugPrint('Error setting theme mode: $e');
    } finally {
      _isLoading = false;
    }
  }
}
