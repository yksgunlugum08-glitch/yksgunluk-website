import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  // Varsayılan renkler
  static Color primaryColor = Colors.blue; // Birincil renk: Mavi
  static Color secondaryColor = Colors.white; // İkincil renk: Beyaz
  static Color tertiaryColor = Colors.indigo; // Üçüncül renk: Indigo

  // 🎯 RENK PALETİ - ÖZELLEŞTİRME SAYFASI İÇİN
  static final List<Map<String, Color>> colorPalettes = [
    {
      'primary': Colors.blue,
      'secondary': Colors.blue.shade100,
      'tertiary': Colors.blue.shade800,
    },
    {
      'primary': Colors.indigo,
      'secondary': Colors.indigo.shade100,
      'tertiary': Colors.indigo.shade800,
    },
    {
      'primary': Colors.teal,
      'secondary': Colors.teal.shade100,
      'tertiary': Colors.teal.shade800,
    },
    {
      'primary': Colors.green,
      'secondary': Colors.green.shade100,
      'tertiary': Colors.green.shade800,
    },
    {
      'primary': Colors.orange,
      'secondary': Colors.orange.shade100,
      'tertiary': Colors.orange.shade800,
    },
    {
      'primary': Colors.red,
      'secondary': Colors.red.shade100,
      'tertiary': Colors.red.shade800,
    },
    {
      'primary': Colors.purple,
      'secondary': Colors.purple.shade100,
      'tertiary': Colors.purple.shade800,
    },
    {
      'primary': Colors.pink,
      'secondary': Colors.pink.shade100,
      'tertiary': Colors.pink.shade800,
    },
  ];

  // 🎯 RENK PALETİ İNDEXİ İLE TEMA KAYDET
  static Future<void> saveThemeIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_theme_index', index);
      
      print('🎨 Tema kaydedildi: Index $index'); // DEBUG
      
      // Seçilen temayı yükle
      await loadColors();
      
    } catch (e) {
      print('❌ Tema kaydedilirken hata: $e');
    }
  }

  // 🎯 RENKLERI YÜKLE (DÜZELTİLDİ)
  static Future<void> loadColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Seçilen tema indexini al (varsayılan: 0 - mavi)
      final selectedIndex = prefs.getInt('selected_theme_index') ?? 0;
      
      print('🎨 Tema yükleniyor: Index $selectedIndex'); // DEBUG
      
      // Index geçerliyse o temayı kullan
      if (selectedIndex >= 0 && selectedIndex < colorPalettes.length) {
        final selectedPalette = colorPalettes[selectedIndex];
        primaryColor = selectedPalette['primary']!;
        secondaryColor = selectedPalette['secondary']!;
        tertiaryColor = selectedPalette['tertiary']!;
        
        print('🎨 Tema yüklendi: Primary: $primaryColor'); // DEBUG
      } else {
        // Geçersiz index, varsayılan tema kullan
        print('⚠️ Geçersiz tema index, varsayılan tema kullanılıyor');
        primaryColor = Colors.blue;
        secondaryColor = Colors.white;
        tertiaryColor = Colors.indigo;
      }
      
    } catch (e) {
      print('❌ Tema yüklenirken hata: $e');
      // Hata durumunda varsayılan renkler
      primaryColor = Colors.blue;
      secondaryColor = Colors.white;
      tertiaryColor = Colors.indigo;
    }
  }

  // 🎯 ESKİ RENK KAYDETME FONKSİYONU (KULLANMA ARTIK!)
  static Future<void> saveColors(Color primary, Color secondary, Color tertiary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primaryColor', primary.value);
    await prefs.setInt('secondaryColor', secondary.value);
    await prefs.setInt('tertiaryColor', tertiary.value);

    // 🎯 BURADA SORUN VARDI! (DÜZELTİLDİ)
    primaryColor = primary;    // ❌ ÖNCEDEN: Colors.blue
    secondaryColor = secondary; // ❌ ÖNCEDEN: Colors.white  
    tertiaryColor = tertiary;   // ❌ ÖNCEDEN: Colors.lightGreen
  }

  // 🎯 SEÇİLEN TEMA İNDEXİNİ AL
  static Future<int> getSelectedThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('selected_theme_index') ?? 0;
  }
}