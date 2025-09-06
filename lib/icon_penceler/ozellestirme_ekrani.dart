import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static Color primaryColor = Colors.blue; // Varsayılan değer
  static Color secondaryColor = Colors.green; // Varsayılan değer
  static Color tertiaryColor = Colors.orange; // Varsayılan değer

  static Future<void> loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    primaryColor = Color(prefs.getInt('primaryColor') ?? Colors.blue.value);
    secondaryColor = Color(prefs.getInt('secondaryColor') ?? Colors.green.value);
    tertiaryColor = Color(prefs.getInt('tertiaryColor') ?? Colors.orange.value);
  }

  static Future<void> saveColors(Color primary, Color secondary, Color tertiary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', primary.value);
    await prefs.setInt('secondaryColor', secondary.value);
    await prefs.setInt('tertiaryColor', tertiary.value);
    primaryColor = primary;
    secondaryColor = secondary;
    tertiaryColor = tertiary;
  }
}

class OzellistirmeEkrani extends StatefulWidget {
  @override
  _OzellistirmeEkraniState createState() => _OzellistirmeEkraniState();
}

class _OzellistirmeEkraniState extends State<OzellistirmeEkrani> {
  late Color _primaryColor;
  late Color _secondaryColor;
  late Color _tertiaryColor;

  @override
  void initState() {
    super.initState();
    _loadColors();
  }

  void _loadColors() {
    setState(() {
      _primaryColor = ThemeManager.primaryColor;
      _secondaryColor = ThemeManager.secondaryColor;
      _tertiaryColor = ThemeManager.tertiaryColor;
    });
  }

  void _pickColor(Color currentColor, ValueChanged<Color> onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Renk Seç'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: onColorChanged,
            showLabel: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            child: Text('Tamam'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveColors() async {
    await ThemeManager.saveColors(_primaryColor, _secondaryColor, _tertiaryColor);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Renkler kaydedildi!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Özelleştirme Ekranı'),
        backgroundColor: _primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildColorTile('Birincil Renk', _primaryColor, (color) {
              setState(() {
                _primaryColor = color;
              });
            }),
            _buildColorTile('İkincil Renk', _secondaryColor, (color) {
              setState(() {
                _secondaryColor = color;
              });
            }),
            _buildColorTile('Üçüncül Renk', _tertiaryColor, (color) {
              setState(() {
                _tertiaryColor = color;
              });
            }),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveColors,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor, // Modern API ile güncellendi
              ),
              child: Text(
                'Renkleri Kaydet',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorTile(String title, Color color, ValueChanged<Color> onColorChanged) {
    return ListTile(
      title: Text(title),
      trailing: CircleAvatar(
        backgroundColor: color,
      ),
      onTap: () => _pickColor(color, onColorChanged),
    );
  }
}