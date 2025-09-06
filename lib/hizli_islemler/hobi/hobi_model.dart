import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Hobby {
  final String id;
  final String name;
  final Color color;
  final double duration;
  final Map<String, bool> selectedDays;
  final String iconKey; // İkon tanımlayıcı anahtar

  Hobby({
    required this.id,
    required this.name,
    required this.color,
    required this.duration,
    required this.selectedDays,
    required this.iconKey,
  });

  // Kategori bazlı ikon eşleştirmeleri - derleme zamanında sabit
  static final Map<String, IconData> _iconMap = {
    // Kitap & Okuma
    'kitap': Icons.menu_book,
    'okuma': Icons.menu_book,
    'roman': Icons.auto_stories,
    'kütüphane': Icons.book,
    'edebiyat': Icons.menu_book,
    
    // Spor & Egzersiz
    'spor': Icons.sports,
    'basketbol': Icons.sports_basketball,
    'futbol': Icons.sports_football,
    'voleybol': Icons.sports_volleyball,
    'yüzme': Icons.pool,
    'koşu': Icons.directions_run,
    'tenis': Icons.sports_tennis,
    'yürüyüş': Icons.directions_walk,
    'bisiklet': Icons.pedal_bike,
    'fitness': Icons.fitness_center,
    'egzersiz': Icons.fitness_center,
    'gym': Icons.fitness_center,
    'yoga': Icons.self_improvement,
    
    // Müzik
    'müzik': Icons.music_note,
    'gitar': Icons.music_note,
    'piyano': Icons.piano,
    'şarkı': Icons.mic,
    'enstrüman': Icons.piano,
    'şarkı söyle': Icons.mic,
    'dinleme': Icons.headphones,
    'konser': Icons.music_note,
    
    // Sanat & El İşi
    'resim': Icons.brush,
    'çizim': Icons.brush,
    'boyama': Icons.palette,
    'sanat': Icons.palette,
    'el işi': Icons.architecture,
    'tasarım': Icons.design_services,
    'fotoğraf': Icons.camera_alt,
    'fotoğrafçılık': Icons.camera_alt,
    
    // Medya & Eğlence
    'film': Icons.movie,
    'dizi': Icons.tv,
    'sinema': Icons.movie,
    'televizyon': Icons.tv,
    'oyun': Icons.videogame_asset,
    'bilgisayar': Icons.computer,
    'video': Icons.videocam,
    
    // Doğa & Dışarı
    'bahçe': Icons.grass,
    'doğa': Icons.emoji_nature,
    'kamp': Icons.fire_extinguisher_outlined,
    'balık': Icons.phishing,
    'avcılık': Icons.tag,
    'yemek': Icons.restaurant,
    'kuş': Icons.emoji_nature,
    
    // Teknoloji & Bilim
    'programlama': Icons.code,
    'kodlama': Icons.code,
    'bilim': Icons.science,
    'teknoloji': Icons.computer,
    'robot': Icons.smart_toy,
    'elektronik': Icons.electrical_services,
    
    // Yaratıcı & Düşünsel
    'yazma': Icons.edit,
    'günlük': Icons.edit_note,
    'bulmaca': Icons.extension,
    'satranç': Icons.grid_on,
    'meditasyon': Icons.self_improvement,
    
    // Sosyal
    'arkadaş': Icons.people,
    'sohbet': Icons.chat,
    'buluşma': Icons.groups,
    'oyun gecesi': Icons.games,
    
    // Dil & İletişim
    'dil': Icons.language,
    'öğrenme': Icons.school,
    'yabancı': Icons.translate,
  };
  
  // Sabit bir haritadan ikon alındığı için tree-shake sorunsuz çalışır
  IconData get icon => _iconMap[iconKey] ?? Icons.local_cafe;
  
  // Kullanıcının girdiği hobi adından uygun ikon anahtarını bulur
  static String findBestIconKey(String hobbyName) {
    String lowerName = hobbyName.toLowerCase();
    
    // Tüm anahtar kelimeleri kontrol et
    for (String key in _iconMap.keys) {
      if (lowerName.contains(key)) {
        return key; // İlk eşleşen anahtar kelimeyi döndür
      }
    }
    
    // Eşleşme bulunamazsa varsayılan 'kahve/çay' ikonu
    return 'default';
  }

  factory Hobby.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final selectedDays = Map<String, bool>.from(data['selectedDays'] ?? {});
    
    // Geriye dönük uyumluluk için
    String iconKey;
    if (data.containsKey('iconKey')) {
      iconKey = data['iconKey'];
    } else if (data.containsKey('iconName')) {
      iconKey = data['iconName'];
    } else {
      // Hobi adına göre en uygun ikonu seç
      iconKey = findBestIconKey(data['name'] ?? '');
    }
    
    return Hobby(
      id: doc.id,
      name: data['name'] ?? '',
      color: Color(data['color'] ?? 0xFF43A047),
      duration: (data['duration'] ?? 30).toDouble(),
      selectedDays: selectedDays,
      iconKey: iconKey,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'color': color.value,
      'duration': duration,
      'selectedDays': selectedDays,
      'iconKey': iconKey,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}