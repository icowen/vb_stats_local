import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _serveKey = 'stat_group_serve_visible';
  static const String _passKey = 'stat_group_pass_visible';
  static const String _attackKey = 'stat_group_attack_visible';
  static const String _blockKey = 'stat_group_block_visible';
  static const String _digKey = 'stat_group_dig_visible';
  static const String _setKey = 'stat_group_set_visible';

  // Default all stat groups to visible
  bool _serveVisible = true;
  bool _passVisible = true;
  bool _attackVisible = true;
  bool _blockVisible = true;
  bool _digVisible = true;
  bool _setVisible = true;

  // Getters
  bool get serveVisible => _serveVisible;
  bool get passVisible => _passVisible;
  bool get attackVisible => _attackVisible;
  bool get blockVisible => _blockVisible;
  bool get digVisible => _digVisible;
  bool get setVisible => _setVisible;

  // Initialize settings from SharedPreferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _serveVisible = prefs.getBool(_serveKey) ?? true;
    _passVisible = prefs.getBool(_passKey) ?? true;
    _attackVisible = prefs.getBool(_attackKey) ?? true;
    _blockVisible = prefs.getBool(_blockKey) ?? true;
    _digVisible = prefs.getBool(_digKey) ?? true;
    _setVisible = prefs.getBool(_setKey) ?? true;
    notifyListeners();
  }

  // Toggle methods
  Future<void> toggleServeVisibility() async {
    _serveVisible = !_serveVisible;
    await _saveSetting(_serveKey, _serveVisible);
    notifyListeners();
  }

  Future<void> togglePassVisibility() async {
    _passVisible = !_passVisible;
    await _saveSetting(_passKey, _passVisible);
    notifyListeners();
  }

  Future<void> toggleAttackVisibility() async {
    _attackVisible = !_attackVisible;
    await _saveSetting(_attackKey, _attackVisible);
    notifyListeners();
  }

  Future<void> toggleBlockVisibility() async {
    _blockVisible = !_blockVisible;
    await _saveSetting(_blockKey, _blockVisible);
    notifyListeners();
  }

  Future<void> toggleDigVisibility() async {
    _digVisible = !_digVisible;
    await _saveSetting(_digKey, _digVisible);
    notifyListeners();
  }

  Future<void> toggleSetVisibility() async {
    _setVisible = !_setVisible;
    await _saveSetting(_setKey, _setVisible);
    notifyListeners();
  }

  // Helper method to save settings
  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // Reset all settings to default (all visible)
  Future<void> resetToDefaults() async {
    _serveVisible = true;
    _passVisible = true;
    _attackVisible = true;
    _blockVisible = true;
    _digVisible = true;
    _setVisible = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serveKey, true);
    await prefs.setBool(_passKey, true);
    await prefs.setBool(_attackKey, true);
    await prefs.setBool(_blockKey, true);
    await prefs.setBool(_digKey, true);
    await prefs.setBool(_setKey, true);

    notifyListeners();
  }
}
