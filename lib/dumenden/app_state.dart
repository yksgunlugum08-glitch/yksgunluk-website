import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  bool _isLoggedIn;
  String _userType = 'Öğrenci'; // Varsayılan kullanıcı tipi
  String _selectedBolum = '';
  List<String> _selectedDersler = [];
  String _hedefSiralama = '';
  String _bolumSor = '';

  AppState({bool isLoggedIn = false, String userType = 'Öğrenci'}) 
    : _isLoggedIn = isLoggedIn,
      _userType = userType {
    _loadPreferences();
  }

  bool get isLoggedIn => _isLoggedIn;
  String get userType => _userType;
  String get selectedBolum => _selectedBolum;
  List<String> get selectedDersler => _selectedDersler;
  String get hedefSiralama => _hedefSiralama;
  String get bolumSor => _bolumSor;

  void setLoggedIn(bool value) {
    _isLoggedIn = value;
    notifyListeners();
  }

  void setUserType(String type) {
    _userType = type;
    _savePreferences();
    notifyListeners();
  }

  void setSelectedBolum(String bolum) {
    _selectedBolum = bolum;
    _savePreferences();
    notifyListeners();
  }

  void toggleDers(String ders) {
    if (_selectedDersler.contains(ders)) {
      _selectedDersler.remove(ders);
    } else {
      if (_selectedDersler.length < 3) {
        _selectedDersler.add(ders);
      }
    }
    _savePreferences();
    notifyListeners();
  }

  Future<void> setHedefSiralama(String siralama) async {
    _hedefSiralama = siralama;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setBolumSor(String bolum) async {
    _bolumSor = bolum;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedBolum = prefs.getString('selectedBolum') ?? '';
    _selectedDersler = prefs.getStringList('selectedDersler') ?? [];
    _hedefSiralama = prefs.getString('hedefSiralama') ?? '';
    _bolumSor = prefs.getString('bolumSor') ?? '';
    _userType = prefs.getString('userType') ?? 'Öğrenci';
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedBolum', _selectedBolum);
    await prefs.setStringList('selectedDersler', _selectedDersler);
    await prefs.setString('hedefSiralama', _hedefSiralama);
    await prefs.setString('bolumSor', _bolumSor);
    await prefs.setString('userType', _userType);
  }
}