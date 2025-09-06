import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class YKSGunlugumPage extends StatefulWidget {
  final String ay;
  final Function(String) onTopicAdded;
  final Function(String) onTopicRemoved;

  YKSGunlugumPage({
    required this.ay,
    required this.onTopicAdded,
    required this.onTopicRemoved,
    Key? key,
  }) : super(key: key);

  @override
  _YKSGunlugumPageState createState() => _YKSGunlugumPageState();
}

class _YKSGunlugumPageState extends State<YKSGunlugumPage> with TickerProviderStateMixin {
  bool _isTYT = true;

  final Map<String, List<String>> _tytSubjects = {
    'Matematik': ['Temel Kavramlar', 'Sayı Basamakları', 'Bölme Bölünebilme Kurallları', 'EBOB-EKOD', 'Rasyonel Sayılar', 'Rayonel Sayılar','Basit Eşitsizlikler', 'Mutlak Değer','Mutlak Değer', 'Üslü Sayılar', 'Köklü Sayılar', 'Çarpanlara Ayırma', 'Oran Orantı', 'Denklem Çözme', 'Problemler'],
    'Türkçe': ['Sözcükte Anlam', 'Cümlede Anlam', 'Anlatım Bozuklukları', 'Tamlamalar', 'Yazım Kuralları', 'Noktalama İşaretleri', 'Fiiller', 'Cümle Çeşitleri', 'Sözcük Türleri', 'Sözcükte Anlam', 'Ekler', 'Cümlede Anlam', 'Ses Bilgisi', 'Cümlenin Ögeleri'],
    'Fizik': ['Fizik Bilime Giriş', 'Madde ve Özellikleri', 'Sıvıların Kaldırma Kuvveti', 'Basınç', 'Isı Sıcaklık ve Genleşme', 'Haraket ve Kuvvet', 'Dinamik', 'İş Güç ve Enerji','Elektrik', 'Manyetizma','Dalgalar','Optik'],
    'Kimya': ['Kimya Bilimi', 'Atom ve Yapısı', 'Periyodik Sitem', 'Kimyasal Türler Arası Etkileşimler', 'Maddenin Halleri', 'Kimyanin Temel Kanunları','Aistler Bazlar ve Tuzlar', 'Kimyasal Hesaplamalar', 'Karışımlar','Endüstiride ve Canlılarda Enerji', 'Kimya Her Yerde'],
    'Biyoloji': ['Canlıların Ortak Özellikleri', 'Canlıların Temel Bileşenleri', 'Hücre ve Organeller – Madde Geçişleri', 'Canlıların Sınıflandırılması', 'Hücrede Bölünme – Üreme', 'Kalıtım', 'Bitki Biyolojisi', 'Ekosistem'],
    
  };

  final Map<String, Map<String, List<String>>> _aytSubjects = {
    'Sayısal': {
      'Matematik': ['Mantık', 'Fonksiyonlar', 'Polinomlar', '2. Dereceden Denklemler', 'Permütasyon Kombinasyon', 'Binom ve Olasılık', 'İstatistik', 'Karmaşık Sayılar', '2. Dereceden Eşitsizlikler', 'Parabol', 'Logaritma', 'Limit ve Süreklilik', 'Türev', 'İntegral', 'Diziler', 'Trigonometri', 'Analitik Geometri'],
      
      'Fizik': [
        'Fizik Bilimine Giriş', 
        'Madde ve Özellikleri', 
        'Sıvıların Kaldırma Kuvveti', 
        'Basınç',
        'Elektrostatik', 
        'Elektrik Akımı ve Devreler', 
        'Manyetizma ve Elektromanyetik İndüksiyon', 
        'Dalga Mekaniği',
        'Atom Fiziği', 
        'Çekirdek Fiziği', 
        'Modern Fizik Uygulamaları', 
        'Düzgün Dairesel Hareket',
        'Basit Harmonik Hareket',
        'Işık ve Optik',
        'Kütle Çekim ve Kepler Kanunları'
      ],
      
      'Kimya': [
        'Kimyanın Temel Kanunları',
        'Atom Modelleri',
        'Periyodik Sistem',
        'Kimyasal Türler Arası Etkileşimler',
        'Kimyasal Hesaplamalar',
        'Asit-Baz Dengesi',
        'Çözünürlük Dengesi',
        'Kimyasal Tepkimelerde Hız',
        'Kimyasal Tepkimelerde Denge',
        'Indirgenme-Yükseltgenme Tepkimeleri',
        'Elektrokimya',
        'Karbon Kimyası ve Organik Bileşikler',
        'Organik Reaksiyonlar',
        'Enerji Kaynakları ve Bilimsel Gelişmeler',
        'Polimer, Adezyon, Kohezyon'
      ],
      
      'Biyoloji': [
        'Hücre Bölünmeleri',
        'Kalıtımın Genel İlkeleri',
        'Ekosistem Ekolojisi ve Güncel Çevre Sorunları',
        'Bitki Biyolojisi',
        'Canlılar ve Çevre',
        'İnsan Fizyolojisi',
        'Metabolizma',
        'Sinir Sistemi',
        'Duyu Organları',
        'Endokrin Sistem',
        'Üreme Sistemi ve Embriyonik Gelişim',
        'Komünite ve Popülasyon Ekolojisi',
        'Genetik Mühendisliği ve Biyoteknoloji',
        'Fotosentez ve Kemosentez',
        'Solunum'
      ],
    },
    
    'Eşit Ağırlık': {
      'Matematik': ['Mantık', 'Fonksiyonlar', 'Polinomlar', '2. Dereceden Denklemler', 'Permütasyon Kombinasyon', 'Binom ve Olasılık', 'İstatistik', 'Karmaşık Sayılar', '2. Dereceden Eşitsizlikler', 'Parabol', 'Logaritma', 'Limit ve Süreklilik', 'Türev', 'İntegral', 'Diziler', 'Trigonometri', 'Analitik Geometri'],
      
      'Tarih': [
        'Tarih ve Zaman',
        'İnsanlığın İlk Dönemleri',
        "Orta Çağ'da Dünya",
        'İlk ve Orta Çağlarda Türk Dünyası',
        'İslam Medeniyeti ve Türkler',
        'Türkiye Tarihi (11-13. Yüzyıl)',
        'Beylikten Devlete (1300-1453)',
        'Dünya Gücü Osmanlı (1453-1600)',
        'Yeni Çağda Avrupa',
        'Sultan ve Diplomasi',
        'Değişim Çağında Avrupa ve Osmanlı',
        'Uluslararası İlişkilerde Denge (1774-1914)',
        'XX. Yüzyıl Başlarında Osmanlı Devleti',
        'Millî Mücadele',
        'Türk İnkılabı',
        'Atatürkçülük ve Atatürk İlkeleri',
        'İkinci Dünya Savaşı Sonrası Dönem'
      ],
      
      'Coğrafya': [
        'Doğal Sistemler',
        'Beşeri Sistemler',
        'Mekânsal Sentez: Türkiye',
        'Küresel Ortam: Ülkeler ve Bölgeler',
        'Çevre ve Toplum',
        "Türkiye'nin Fiziki Coğrafyası",
        "Türkiye'nin Beşeri ve Ekonomik Coğrafyası",
        'Bölgesel Kalkınma ve Bölgelerarası İlişkiler',
        'Küresel Ortam ve Türkiye',
        'İklim Değişikliği ve İnsan',
        'Doğal Kaynaklar ve Sürdürülebilirlik',
        'Nüfus Politikaları',
        'Şehirleşme ve Planlama',
        'Uluslararası Ulaşım Hatları',
        'Bölgesel Kalkınma Projeleri'
      ],
      
      'Edebiyat': [
        'Edebiyat ve Toplum',
        'Hikâye',
        'Şiir',
        'Roman',
        'Tiyatro',
        'İslamiyet Öncesi Türk Edebiyatı',
        'İslami Dönem Türk Edebiyatı',
        'Divan Edebiyatı',
        'Halk Edebiyatı',
        'Tanzimat Dönemi Edebiyatı',
        'Servet-i Fünun Edebiyatı',
        'Milli Edebiyat Dönemi',
        'Cumhuriyet Dönemi Türk Edebiyatı (1923-1940)',
        'Cumhuriyet Dönemi Türk Edebiyatı (1940-1960)',
        'Cumhuriyet Dönemi Türk Edebiyatı (1960 sonrası)',
        'Dünya Edebiyatı'
      ],
    },
    
    'Sözel': {
      'Edebiyat': [
        'Edebiyat ve Toplum',
        'Hikâye',
        'Şiir',
        'Roman',
        'Tiyatro',
        'İslamiyet Öncesi Türk Edebiyatı',
        'İslami Dönem Türk Edebiyatı',
        'Divan Edebiyatı',
        'Halk Edebiyatı',
        'Tanzimat Dönemi Edebiyatı',
        'Servet-i Fünun Edebiyatı',
        'Milli Edebiyat Dönemi',
        'Cumhuriyet Dönemi Türk Edebiyatı (1923-1940)',
        'Cumhuriyet Dönemi Türk Edebiyatı (1940-1960)',
        'Cumhuriyet Dönemi Türk Edebiyatı (1960 sonrası)',
        'Dünya Edebiyatı'
      ],
      
      'Tarih': [
        'Tarih ve Zaman',
        'İnsanlığın İlk Dönemleri',
        'Orta Çağda Dünya',
        'İlk ve Orta Çağlarda Türk Dünyası',
        'İslam Medeniyeti ve Türkler',
        'Türkiye Tarihi (11-13. Yüzyıl)',
        'Beylikten Devlete (1300-1453)',
        'Dünya Gücü Osmanlı (1453-1600)',
        'Yeni Çağda Avrupa',
        'Sultan ve Diplomasi',
        'Değişim Çağında Avrupa ve Osmanlı',
        'Uluslararası İlişkilerde Denge (1774-1914)',
        'XX. Yüzyıl Başlarında Osmanlı Devleti',
        'Millî Mücadele',
        'Türk İnkılabı',
        'Atatürkçülük ve Atatürk İlkeleri',
        'İkinci Dünya Savaşı Sonrası Dönem'
      ],
      
      'Coğrafya': [
        'Doğal Sistemler',
        'Beşeri Sistemler',
        'Mekânsal Sentez: Türkiye',
        'Küresel Ortam: Ülkeler ve Bölgeler',
        'Çevre ve Toplum',
        "Türkiye'nin Fiziki Coğrafyası",
        "Türkiye'nin Beşeri ve Ekonomik Coğrafyası",
        'Bölgesel Kalkınma ve Bölgelerarası İlişkiler',
        'Küresel Ortam ve Türkiye',
        'İklim Değişikliği ve İnsan',
        'Doğal Kaynaklar ve Sürdürülebilirlik',
        'Nüfus Politikaları',
        'Şehirleşme ve Planlama',
        'Uluslararası Ulaşım Hatları',
        'Bölgesel Kalkınma Projeleri'
      ],
      
      'Felsefe': [
        'Felsefenin Konusu ve Bilgiyle İlişkisi',
        'Felsefi Düşüncenin Gelişimi',
        'MÖ 6. Yüzyıl-MS 2. Yüzyıl Felsefesi',
        'MS 2. Yüzyıl-15. Yüzyıl Felsefesi',
        '15. Yüzyıl-17. Yüzyıl Felsefesi',
        '18. Yüzyıl-19. Yüzyıl Felsefesi',
        '20. Yüzyıl Felsefesi',
        'Bilgi Felsefesi',
        'Varlık Felsefesi',
        'Ahlak Felsefesi',
        'Sanat Felsefesi',
        'Din Felsefesi',
        'Siyaset Felsefesi',
        'Bilim Felsefesi',
        'Mantık',
        'Türk-İslam Düşüncesi'
      ],
    },
  };

  Map<String, Set<String>> _prioritizedTopics = {};
  String? _selectedBolum;
  late String _uid;
  bool _loadingBolum = true;
  bool _loadingTopics = true;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadSelectedBolum();
    _loadPrioritizedTopics();
  }

  Future<void> _loadSelectedBolum() async {
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .get();

    setState(() {
      _selectedBolum = doc.data()?['selectedBolum'];
      _loadingBolum = false;
    });
  }

  Future<void> _loadPrioritizedTopics() async {
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('yksGunlugum')
        .doc(widget.ay)
        .get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      setState(() {
        _prioritizedTopics = Map<String, Set<String>>.from(
          data.map(
            (key, value) => MapEntry(key, Set<String>.from(List<String>.from(value))),
          ),
        );
      });
    } else {
      setState(() {
        _prioritizedTopics = {};
      });
    }
    _loadingTopics = false;
  }

  Future<void> _savePrioritizedTopics() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('yksGunlugum')
        .doc(widget.ay)
        .set(
          _prioritizedTopics.map((key, value) => MapEntry(key, value.toList())),
          SetOptions(merge: true),
        );
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _isTYT
        ? _tytSubjects
        : (_selectedBolum != null && _aytSubjects.containsKey(_selectedBolum))
            ? _aytSubjects[_selectedBolum]!
            : {};

    if (_loadingBolum || _loadingTopics) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: Text('${widget.ay[0].toUpperCase()}${widget.ay.substring(1)} Ders Ekleme'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          elevation: 8,
          shadowColor: Colors.black54,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('${widget.ay[0].toUpperCase()}${widget.ay.substring(1)} Ders Ekleme'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 8,
        shadowColor: Colors.black54,
      ),
      body: Column(
        children: [
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTYT ? Colors.amber : Colors.white,
                  foregroundColor: _isTYT ? Colors.black : Colors.black,
                  side: BorderSide(color: Colors.amber, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  elevation: 5,
                ),
                onPressed: () {
                  setState(() {
                    _isTYT = true;
                  });
                },
                child: Text('TYT', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(width: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_isTYT ? Colors.redAccent : Colors.white,
                  foregroundColor: !_isTYT ? Colors.white : Colors.black,
                  side: BorderSide(color: Colors.redAccent, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  elevation: 5,
                ),
                onPressed: () {
                  setState(() {
                    _isTYT = false;
                  });
                },
                child: Text('AYT', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          SizedBox(height: 15),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: subjects.isNotEmpty
                  ? ListView(
                      children: subjects.entries.map((entry) {
                        final prioritized = _prioritizedTopics[entry.key] ?? <String>{};
                        final topics = List<String>.from(entry.value);
                        topics.sort((a, b) {
                          if (prioritized.contains(a) && !prioritized.contains(b)) return -1;
                          if (!prioritized.contains(a) && prioritized.contains(b)) return 1;
                          return 0;
                        });
                        return Card(
                          elevation: 5,
                          margin: EdgeInsets.symmetric(vertical: 8),
                          shadowColor: Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            title: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: topics.map((topic) {
                              final isPrioritized = prioritized.contains(topic);
                              return ListTile(
                                title: Text(
                                  topic,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    isPrioritized ? Icons.remove : Icons.add,
                                    color: isPrioritized ? Colors.red : Colors.green,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (isPrioritized) {
                                        prioritized.remove(topic);
                                        widget.onTopicRemoved('${entry.key}: $topic');
                                      } else {
                                        prioritized.add(topic);
                                        widget.onTopicAdded('${entry.key}: $topic');
                                      }
                                      _prioritizedTopics[entry.key] = prioritized;
                                    });
                                    _savePrioritizedTopics();
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    )
                  : Center(
                      child: Text(
                        'Lütfen bir bölüm seçiniz.',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}