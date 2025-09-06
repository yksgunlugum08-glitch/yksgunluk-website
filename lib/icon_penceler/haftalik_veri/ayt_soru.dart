import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:yksgunluk/icon_penceler/haftalik_veri/haftalik.dart';
import 'package:yksgunluk/icon_penceler/haftalik_veri/tyt_soru.dart';
import 'package:yksgunluk/ekranlar/home_page.dart';
import 'package:yksgunluk/teacher_mode.dart';

enum GrafikTab { calismaSurem, aytSoru, tytSoru }
enum GrafikTipi { soruSayisi, verimlilik }

class AYTGrafik extends StatefulWidget {
  // Öğretmen modu için parametreler
  final String? studentId;
  final String? studentName;

  const AYTGrafik({
    Key? key,
    this.studentId,
    this.studentName,
  }) : super(key: key);

  @override
  _AYTGrafikState createState() => _AYTGrafikState();
}

class _AYTGrafikState extends State<AYTGrafik> with SingleTickerProviderStateMixin {
  List<ChartSampleData> _chartData = [];
  List<VerimlilikData> _verimlilikData = [];
  List<String> _dersler = [];
  String _selectedBolum = '';
  bool _loading = true;
  int _touchedIndex = -1;
  int _selectedWeekIndex = -1;
  bool _isPanelLocked = false;
  GrafikTipi _aktifGrafikTipi = GrafikTipi.soruSayisi;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final ScrollController _scrollController = ScrollController();

  GrafikTab activeTab = GrafikTab.aytSoru;

  // Geliştirilmiş yüksek ayrım düzeyli renk paleti
  final List<Color> _colorList = [
    Color(0xFF8B00FF), // Mor
    Color(0xFFFF8C00), // Turuncu
    Color(0xFF000080), // Lacivert
    Color(0xFF8B0000), // Bordo
    Color(0xFF00CED1), // Turkuaz
    Color(0xFF32CD32), // Lime Yeşil
    Color(0xFFFF1493), // Koyu Pembe
    Color(0xFF4B0082), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    
    print("=== 🎯 AYT Grafik Başlatılıyor ===");
    print("📝 Widget studentId: ${widget.studentId}");
    print("📝 Widget studentName: ${widget.studentName}");
    print("📝 Öğretmen modu aktif mi: ${widget.studentId != null && widget.studentName != null}");
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    
    _verileriYukle();
  }

  // Öğretmen modu kontrolü - basit ve net
  bool get _isTeacherMode {
    return widget.studentId != null && widget.studentName != null;
  }

  String? get _currentStudentId => widget.studentId;
  String? get _currentStudentName => widget.studentName;
  
  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _loading = true;
    });

    print("=== 📊 Veri yükleme başlıyor ===");
    print("🎯 Öğretmen modu: $_isTeacherMode");
    print("📝 Student ID: $_currentStudentId");
    print("📝 Student Name: $_currentStudentName");

    String userId;
    if (_isTeacherMode && _currentStudentId != null) {
      userId = _currentStudentId!;
      print("✅ Öğretmen modu - Öğrenci verisi yükleniyor: $userId");
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Kullanıcı oturum açmamış");
        setState(() {
          _chartData = [];
          _verimlilikData = [];
          _loading = false;
        });
        return;
      }
      userId = user.uid;
      print("✅ Normal mod - Kullanıcı verisi yükleniyor: $userId");
    }

    try {
      // Kullanıcının bölüm bilgisini al
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      _selectedBolum = userDoc.get('selectedBolum') ?? '';
      print("📚 Kullanıcı bölümü: $_selectedBolum");
    } catch (e) {
      print("❌ Kullanıcı bölüm bilgisi alınamadı: $e");
      _selectedBolum = '';
    }
    
    // Bölüme göre dersleri belirle
    _dersler = _getDerslerByBolum(_selectedBolum);
    print("📖 Seçilen dersler: $_dersler");
    
    if (_dersler.isEmpty) {
      setState(() {
        _chartData = [];
        _verimlilikData = [];
        _loading = false;
      });
      print("❌ Dersler bulunamadı veya bölüm seçilmedi!");
      return;
    }

    try {
      print("📈 AYT verileri yükleniyor...");
      
      // 1. AYT Soru Verileri - Haftalık soru sayıları (Orijinal grafiğimiz)
      await _loadSoruVerileri(userId);
      
      // 2. Verimlilik Verileri - Haftalık verimlilik değerleri (Yeni grafiğimiz)
      await _loadVerimlilikVerileri(userId);
      
      setState(() {
        _loading = false;
      });
      
      if (_chartData.isNotEmpty || _verimlilikData.isNotEmpty) {
        _animationController.forward();
        print("✅ Veriler başarıyla yüklendi");
      } else {
        print("❌ Gösterilecek veri bulunamadı!");
      }
      
    } catch (e) {
      print("❌ Veri yükleme hatası: $e");
      setState(() {
        _chartData = [];
        _verimlilikData = [];
        _loading = false;
      });
    }
  }
  
  // Orijinal soru verilerini yükle (yığın grafiği için)
  Future<void> _loadSoruVerileri(String userId) async {
    try {
      // AYT verilerini getir
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('solvedQuestionsAyt')
          .orderBy('date', descending: false)
          .get();

      print("📊 Firestore'dan ${snapshot.docs.length} belge alındı");

      // Haftalık veriler için map
      Map<String, List<int>> haftalikVeri = {};
      Map<String, int> haftalikToplam = {};
      Map<String, List<DateTime>> tarihAraliklari = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (!data.containsKey('date')) {
          print("'date' alanı eksik olan belge atlandı: ${doc.id}");
          continue;
        }
        
        DateTime date;
        try {
          date = DateFormat('dd-MM-yyyy').parse(data['date']);
        } catch (e) {
          print("Tarih ayrıştırma hatası (${data['date']}): $e");
          continue;
        }

        // Haftanın başlangıç ve bitiş tarihlerini hesapla
        DateTime startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        String label = "${DateFormat('dd.MM').format(startOfWeek)} - ${DateFormat('dd.MM').format(endOfWeek)}";

        // Derslere göre verileri çıkar
        List<int> dersVeri = [];
        int toplam = 0;
        
        // Her dersin verisini kontrol et
        for (String ders in _dersler) {
          int val = 0;
          if (data.containsKey(ders)) {
            if (data[ders] is int) {
              val = data[ders] as int;
            } else {
              val = int.tryParse(data[ders]?.toString() ?? '0') ?? 0;
            }
          }
          dersVeri.add(val);
          toplam += val;
        }

        // Haftalık verileri birleştir
        if (haftalikVeri.containsKey(label)) {
          for (int i = 0; i < dersVeri.length; i++) {
            haftalikVeri[label]![i] += dersVeri[i];
          }
          haftalikToplam[label] = (haftalikToplam[label] ?? 0) + toplam;
        } else {
          haftalikVeri[label] = List<int>.from(dersVeri);
          haftalikToplam[label] = toplam;
          tarihAraliklari[label] = [startOfWeek, endOfWeek];
        }
      }

      // Tarih sırasına göre haftalık etiketleri sırala
      List<String> sortedLabels = haftalikVeri.keys.toList();
      sortedLabels.sort((a, b) {
        DateTime dateA = tarihAraliklari[a]![0];
        DateTime dateB = tarihAraliklari[b]![0];
        return dateA.compareTo(dateB);
      });
      
      // Son 8 hafta verisini göster (yeterli veri varsa)
      if (sortedLabels.length > 8) {
        sortedLabels = sortedLabels.sublist(sortedLabels.length - 8);
      }
      
      List<ChartSampleData> loadedData = [];
      for (String label in sortedLabels) {
        loadedData.add(
          ChartSampleData(
            x: label,
            values: haftalikVeri[label]!,
            toplam: haftalikToplam[label] ?? 0,
            startDate: tarihAraliklari[label]?[0],
            endDate: tarihAraliklari[label]?[1],
          ),
        );
      }

      setState(() {
        _chartData = loadedData;
      });
      
      print("✅ ${_chartData.length} haftalık soru verisi yüklendi");
    } catch (e) {
      print("❌ Soru verileri yüklenirken hata: $e");
      setState(() => _chartData = []);
    }
  }
  
  // Verimlilik verilerini yükle (çizgi grafiği için)
  Future<void> _loadVerimlilikVerileri(String userId) async {
    try {
      // 1. Haftalık çözülen soru sayıları
      Map<String, Map<String, int>> haftalikSoruVerileri = await _getHaftalikSoruVerileri(userId);
      
      // 2. Haftalık çalışma süreleri
      Map<String, Map<String, double>> haftalikCalismaSureleri = await _getHaftalikCalismaSureleri(userId);
      
      // 3. Verileri birleştir - Verimlilik hesapla (soru başına düşen süre)
      List<VerimlilikData> veriler = [];
      
      // Tüm hafta anahtarlarını birleştir (soru veya süre verisinden herhangi birinde olan tüm haftalar)
      Set<String> tumHaftalar = {...haftalikSoruVerileri.keys, ...haftalikCalismaSureleri.keys};
      
      // Haftaları tarih sırasına göre sırala
      List<String> siraliHaftalar = tumHaftalar.toList()..sort((a, b) {
        try {
          List<String> aParts = a.split(' - ');
          List<String> bParts = b.split(' - ');
          
          DateTime aDate = DateFormat('dd.MM').parse(aParts[0]);
          DateTime bDate = DateFormat('dd.MM').parse(bParts[0]);
          
          // Yıl bilgisi olmadığı için aynı yıl içinde karşılaştır
          if (aDate.month > bDate.month || (aDate.month == bDate.month && aDate.day > bDate.day)) {
            // a tarihi b tarihinden sonra (şubat vs ocak gibi)
            return 1;
          } else {
            return -1;
          }
        } catch (e) {
          return a.compareTo(b); // Hata durumunda string olarak karşılaştır
        }
      });
      
      // Son 8 haftayı al (yeterli veri varsa)
      if (siraliHaftalar.length > 8) {
        siraliHaftalar = siraliHaftalar.sublist(siraliHaftalar.length - 8);
      }
      
      for (String hafta in siraliHaftalar) {
        // Başlangıç ve bitiş tarihlerini parse et
        DateTime? startDate, endDate;
        try {
          List<String> parts = hafta.split(' - ');
          startDate = DateFormat('dd.MM').parse(parts[0]);
          endDate = DateFormat('dd.MM').parse(parts[1]);
          
          // Geçerli yıl ekle
          int currentYear = DateTime.now().year;
          startDate = DateTime(currentYear, startDate.month, startDate.day);
          endDate = DateTime(currentYear, endDate.month, endDate.day);
        } catch (e) {
          print("⚠️ Tarih ayrıştırma hatası: $e");
          // Tarih ayrıştırılamazsa null kalacak
        }
        
        Map<String, double> verimlilikDegerleri = {};
        Map<String, int> soruSayilari = haftalikSoruVerileri[hafta] ?? {};
        Map<String, double> calismaSureleri = haftalikCalismaSureleri[hafta] ?? {};
        int toplamSoru = 0;
        double toplamSure = 0;
        
        // Her ders için verimlilik hesapla
        for (String ders in _dersler) {
          int soruSayisi = soruSayilari[ders] ?? 0;
          double calismaSuresi = calismaSureleri[ders] ?? 0;
          
          toplamSoru += soruSayisi;
          toplamSure += calismaSuresi;
          
          // Verimlilik: Bir soru için harcanan ortalama süre (dakika/soru)
          double verimlilik = 0;
          if (soruSayisi > 0 && calismaSuresi > 0) {
            verimlilik = calismaSuresi / soruSayisi; // Dakika/soru
          }
          
          verimlilikDegerleri[ders] = verimlilik;
        }
        
        // Genel verimlilik
        double genelVerimlilik = 0;
        if (toplamSoru > 0 && toplamSure > 0) {
          genelVerimlilik = toplamSure / toplamSoru;
        }
        
        veriler.add(VerimlilikData(
          hafta: hafta,
          verimlilikDegerleri: verimlilikDegerleri,
          genelVerimlilik: genelVerimlilik,
          startDate: startDate,
          endDate: endDate,
          soruSayilari: soruSayilari,
          calismaSureleri: calismaSureleri,
        ));
      }
      
      setState(() {
        _verimlilikData = veriler;
      });
      
      print("✅ ${_verimlilikData.length} haftalık verimlilik verisi yüklendi");
      
    } catch (e) {
      print("❌ Verimlilik verileri yüklenirken hata: $e");
      setState(() => _verimlilikData = []);
    }
  }
  
  // Haftalık soru verilerini getir
  Future<Map<String, Map<String, int>>> _getHaftalikSoruVerileri(String userId) async {
    Map<String, Map<String, int>> haftalikVeri = {};
    
    try {
      // AYT verilerini getir
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('solvedQuestionsAyt')
          .orderBy('date', descending: false)
          .get();

      print("📊 Firestore'dan ${snapshot.docs.length} AYT belgesi alındı");
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (!data.containsKey('date')) {
          print("'date' alanı eksik olan belge atlandı: ${doc.id}");
          continue;
        }
        
        DateTime date;
        try {
          date = DateFormat('dd-MM-yyyy').parse(data['date']);
        } catch (e) {
          print("Tarih ayrıştırma hatası (${data['date']}): $e");
          continue;
        }

        // Haftanın başlangıç ve bitiş tarihlerini hesapla
        DateTime startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        String label = "${DateFormat('dd.MM').format(startOfWeek)} - ${DateFormat('dd.MM').format(endOfWeek)}";

        // O hafta için veri map'i oluştur veya güncelle
        if (!haftalikVeri.containsKey(label)) {
          haftalikVeri[label] = {};
          
          // Tüm dersleri 0 ile başlat
          for (String ders in _dersler) {
            haftalikVeri[label]![ders] = 0;
          }
        }
        
        // Derslere göre verileri ekle
        for (String ders in _dersler) {
          if (data.containsKey(ders)) {
            int soruSayisi = 0;
            if (data[ders] is int) {
              soruSayisi = data[ders] as int;
            } else {
              soruSayisi = int.tryParse(data[ders]?.toString() ?? '0') ?? 0;
            }
            
            // Mevcut değere ekle
            haftalikVeri[label]![ders] = (haftalikVeri[label]![ders] ?? 0) + soruSayisi;
          }
        }
      }
      
      return haftalikVeri;
    } catch (e) {
      print("❌ Soru verileri alınırken hata: $e");
      return {};
    }
  }
  
  // Haftalık çalışma sürelerini getir
  Future<Map<String, Map<String, double>>> _getHaftalikCalismaSureleri(String userId) async {
    Map<String, Map<String, double>> haftalikVeri = {};
    
    try {
      // Tüm ders bazlı çalışma sürelerini al
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('dersTestVerileri')
          .orderBy('tarih', descending: false)
          .get();

      print("📊 Firestore'dan ${snapshot.docs.length} çalışma süresi belgesi alındı");
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (!data.containsKey('tarih')) {
          print("'tarih' alanı eksik olan belge atlandı: ${doc.id}");
          continue;
        }
        
        // Tarih bilgisini al
        DateTime date;
        if (data['tarih'] is Timestamp) {
          date = (data['tarih'] as Timestamp).toDate();
        } else {
          print("Geçersiz tarih formatı: ${data['tarih']}");
          continue;
        }
        
        // Haftanın başlangıç ve bitiş tarihlerini hesapla
        DateTime startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        String label = "${DateFormat('dd.MM').format(startOfWeek)} - ${DateFormat('dd.MM').format(endOfWeek)}";

        // O hafta için veri map'i oluştur veya güncelle
        if (!haftalikVeri.containsKey(label)) {
          haftalikVeri[label] = {};
          
          // Tüm dersleri 0 ile başlat
          for (String ders in _dersler) {
            haftalikVeri[label]![ders] = 0;
          }
        }
        
        // Derslere göre süreleri ekle
        if (data.containsKey('dersler') && data['dersler'] is List) {
          List<dynamic> derslerList = data['dersler'];
          
          for (var dersData in derslerList) {
            if (dersData is Map<String, dynamic>) {
              String dersAd = dersData['ad'] ?? '';
              double dakika = (dersData['dakika'] ?? 0).toDouble();
              
              // Ders bizim izlediğimiz derslerden biri mi kontrol et
              if (_dersler.contains(dersAd)) {
                // Mevcut değere ekle
                haftalikVeri[label]![dersAd] = (haftalikVeri[label]![dersAd] ?? 0) + dakika;
              }
            }
          }
        }
      }
      
      return haftalikVeri;
    } catch (e) {
      print("❌ Çalışma süreleri alınırken hata: $e");
      return {};
    }
  }

  List<String> _getDerslerByBolum(String bolum) {
    switch (bolum) {
      case 'Sayısal':
        return ['Matematik', 'Fizik', 'Kimya', 'Biyoloji'];
      case 'Eşit Ağırlık':
        return ['Edebiyat', 'Matematik', 'Tarih', 'Coğrafya'];
      case 'Sözel':
        return ['Edebiyat', 'Tarih', 'Felsefe', 'Coğrafya'];
      case 'Dil':
        return ['Dilbilgisi', 'Okuma', 'Anlama', 'Yazma'];
      default:
        return ['Matematik', 'Fizik', 'Kimya', 'Biyoloji']; // Varsayılan olarak Sayısal
    }
  }

  void _goToTab(GrafikTab tab) {
    if (tab == activeTab) return;
    setState(() => activeTab = tab);
    if (tab == GrafikTab.calismaSurem) {
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 900),
          pageBuilder: (context, animation, secondaryAnimation) =>
              HaftalikGrafikSayfasi(
                studentId: _isTeacherMode ? _currentStudentId : null,
                studentName: _isTeacherMode ? _currentStudentName : null,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = const Offset(-1.0, 0.0);
            final end = Offset.zero;
            final curve = Curves.easeInOut;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    } else if (tab == GrafikTab.tytSoru) {
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 900),
          pageBuilder: (context, animation, secondaryAnimation) =>
              TYTHaftalik(
                studentId: _isTeacherMode ? _currentStudentId : null,
                studentName: _isTeacherMode ? _currentStudentName : null,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = const Offset(1.0, 0.0);
            final end = Offset.zero;
            final curve = Curves.easeInOut;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        ),
      );
    }
  }

  // Panel kilitleme/açma işlemi
  void _togglePanelLock(int index) {
    setState(() {
      if (_selectedWeekIndex == index && _isPanelLocked) {
        // Eğer aynı öğeye tıklanırsa ve panel kilitliyse, kilidi aç
        _isPanelLocked = false;
        _selectedWeekIndex = -1;
      } else {
        // Farklı öğeye tıklanırsa veya panel kilitli değilse, kilitle
        _isPanelLocked = true;
        _selectedWeekIndex = index;
        
        // Panel açıldığında otomatik olarak aşağı kaydır
        Future.delayed(Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
  }

  void _goBack() {
    print("🔙 Geri butonuna basıldı. Öğretmen modu: $_isTeacherMode");
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Öğretmen modu kontrolü ve başlık özelleştirme
    final String title = _isTeacherMode 
        ? "${_currentStudentName ?? 'Öğrenci'} - AYT İstatistikleri" 
        : "AYT Soru İstatistikleri";

    print("🖼️ Build çağrıldı - Öğretmen modu: $_isTeacherMode, Başlık: $title");

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.blueAccent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _goBack,
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Material(
          color: Colors.blueAccent,
          child: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _goBack,
                  splashRadius: 24,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _TabButon(
                          title: "Çalışma Sürem",
                          active: activeTab == GrafikTab.calismaSurem,
                          underlineColor: activeTab == GrafikTab.calismaSurem ? Colors.white : Colors.transparent,
                          onTap: () => _goToTab(GrafikTab.calismaSurem),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _TabButon(
                          title: "AYT Soru",
                          active: activeTab == GrafikTab.aytSoru,
                          underlineColor: activeTab == GrafikTab.aytSoru ? Colors.white : Colors.transparent,
                          onTap: () {}, // zaten buradasın
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _TabButon(
                          title: "TYT Soru",
                          active: activeTab == GrafikTab.tytSoru,
                          underlineColor: activeTab == GrafikTab.tytSoru ? Colors.white : Colors.transparent,
                          onTap: () => _goToTab(GrafikTab.tytSoru),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _chartData.isEmpty && _verimlilikData.isEmpty
        ? _buildEmptyDataView()
        : SingleChildScrollView(
            controller: _scrollController,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Ekran genişliğine göre uyarlanmış boyutlar
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;
                
                // Grafik için minimum yükseklik
                final chartHeight = screenHeight * 0.4; // Ekran yüksekliğinin %40'ı kadar
                
                return Column(
                  children: [
                    _buildHeader(),
                    _buildGrafikTypeSelector(),
                    
                    // Grafik alanı
                    _aktifGrafikTipi == GrafikTipi.soruSayisi
                      ? _chartData.isEmpty 
                          ? _buildNoDataMessageForChart()
                          : Container(
                              height: chartHeight,
                              padding: const EdgeInsets.all(16),
                              child: _buildStackedBarChart(),
                            )
                      : _verimlilikData.isEmpty
                          ? _buildNoDataMessageForVerimlilik()
                          : Container(
                              height: chartHeight,
                              padding: const EdgeInsets.all(16),
                              child: _buildVerimlilikGrafigi(),
                            ),
                    
                    // Detay paneli
                    if (_selectedWeekIndex != -1)
                      _aktifGrafikTipi == GrafikTipi.soruSayisi
                        ? _buildSoruDetailCard()
                        : _buildVerimlilikDetailCard(),
                      
                    SizedBox(height: 16),
                    _buildLegend(),
                    SizedBox(height: 20),
                  ],
                );
              }
            ),
          ),
    );
  }
  
  Widget _buildNoDataMessageForChart() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            "Haftalık soru verisi bulunamadı",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNoDataMessageForVerimlilik() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_outlined, size: 48, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            "Verimlilik verisi bulunamadı",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text(
            "Çalışma sürenizi ve çözdüğünüz soru sayısını girdikçe\nverimlilik analizi burada görünecek",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            _isTeacherMode ? "${_currentStudentName ?? 'Öğrenci'} için henüz AYT verisi yok!" : "Henüz AYT verisi yok!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _isTeacherMode ? "Öğrenci AYT soru çözdükçe burada istatistiklerini göreceksiniz" 
                           : "AYT soru çözdükçe burada istatistiklerinizi göreceksiniz",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _verileriYukle,
            icon: Icon(Icons.refresh),
            label: Text("Yenile"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isTeacherMode ? "${_currentStudentName ?? 'Öğrenci'}" : 'AYT Soru İstatistikleri',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Haftalık analiz',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey.shade600,
                    ),
                  ),
                  // Öğretmen modu göstergesi
                  if (_isTeacherMode) ...[
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        "Öğretmen Görünümü",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _verileriYukle,
                tooltip: 'Verileri Yenile',
                color: Colors.blueAccent,
              ),
            ],
          ),
          SizedBox(height: 10),
          if (_selectedBolum.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                "Bölüm: $_selectedBolum",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade700,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrafikTypeSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _grafikTypeButton(
            GrafikTipi.soruSayisi, 
            'Haftalık Soru Sayısı', 
            Icons.stacked_bar_chart
          ),
          SizedBox(width: 16),
          _grafikTypeButton(
            GrafikTipi.verimlilik, 
            'Verimlilik Analizi', 
            Icons.show_chart
          ),
        ],
      ),
    );
  }
  
  Widget _grafikTypeButton(GrafikTipi tip, String label, IconData icon) {
    bool isSelected = _aktifGrafikTipi == tip;
    
    return Expanded(
      child: ElevatedButton.icon(
        icon: Icon(icon, color: isSelected ? Colors.white : Colors.blueAccent),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blueAccent : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.blueAccent,
          side: BorderSide(color: Colors.blueAccent),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () {
          setState(() {
            _aktifGrafikTipi = tip;
            _selectedWeekIndex = -1; // Grafik tipi değiştiğinde seçimi sıfırla
            _isPanelLocked = false;
            _animationController.reset();
            _animationController.forward();
          });
        },
      ),
    );
  }
  
  Widget _buildStackedBarChart() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(
              enabled: true,
              handleBuiltInTouches: false, // Varsayılan davranışı devre dışı bırak
              touchCallback: (FlTouchEvent event, BarTouchResponse? touchResponse) {
                // Sadece tıklama eventlerini dinle
                if (event is FlTapUpEvent) {
                  if (touchResponse == null || touchResponse.spot == null) return;
                  
                  int touchedIndex = touchResponse.spot!.touchedBarGroupIndex;
                  _togglePanelLock(touchedIndex);
                }
              },
              touchTooltipData: BarTouchTooltipData(
                tooltipPadding: EdgeInsets.all(10),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  ChartSampleData data = _chartData[group.x.toInt()];
                  return BarTooltipItem(
                    'Toplam: ${data.toplam}\n',
                    TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    children: _dersler
                      .asMap()
                      .entries
                      .map((entry) => 
                        TextSpan(
                          text: '${entry.value}: ${data.values[entry.key]}\n',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        )
                      ).toList(),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() < 0 || value.toInt() >= _chartData.length) {
                      return const SizedBox.shrink();
                    }
                    
                    List<String> parts = _chartData[value.toInt()].x.split(' - ');
                    String displayText = parts[0]; // Sadece başlangıç tarihini göster
                    
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        displayText,
                        style: TextStyle(
                          color: Colors.blueGrey.shade700,
                          fontWeight: _selectedWeekIndex == value.toInt() ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 50,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
                dashArray: [5, 5],
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                left: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            groupsSpace: 16,
            barGroups: _getStackedBarGroups(_animation.value),
          ),
        );
      }
    );
  }
  
  Widget _buildVerimlilikGrafigi() {
    return Column(
      children: [
        // Grafik başlığı
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(
            "Haftalık Verimlilik Analizi",
            style: TextStyle(
              color: Colors.blueGrey.shade800,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Grafik açıklaması
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            "Bir soru için harcanan dakika (düşük değerler daha iyi)",
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        // Ana grafik
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 6, bottom: 10),
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipPadding: EdgeInsets.all(12),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final int dataIndex = barSpot.x.toInt();
                        final int lineIndex = touchedBarSpots.indexOf(barSpot);
                        
                        if (dataIndex < 0 || dataIndex >= _verimlilikData.length) {
                          return null;
                        }
                        
                        VerimlilikData data = _verimlilikData[dataIndex];
                        String dersAdi = lineIndex < _dersler.length ? _dersler[lineIndex] : "Ortalama";
                        double verimlilik;
                        
                        if (lineIndex < _dersler.length) {
                          verimlilik = data.verimlilikDegerleri[dersAdi] ?? 0;
                        } else {
                          verimlilik = data.genelVerimlilik;
                        }
                        
                        // Hafta bilgisini ekle
                        String hafta = data.hafta.split(' - ')[0]; // Sadece başlangıç tarihi
                        String formattedValue = _formatTime(verimlilik);
                        
                        return LineTooltipItem(
                          '$dersAdi\n',
                          TextStyle(
                            color: lineIndex < _dersler.length 
                                ? _colorList[lineIndex % _colorList.length]
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          children: [
                            TextSpan(
                              text: '$hafta haftası\n',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: '$formattedValue dk/soru',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (event is FlTapUpEvent) {
                      if (touchResponse == null || touchResponse.lineBarSpots == null || 
                          touchResponse.lineBarSpots!.isEmpty) return;
                      
                      int touchedIndex = touchResponse.lineBarSpots![0].x.toInt();
                      _togglePanelLock(touchedIndex);
                    }
                  },
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 0.8,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= _verimlilikData.length) {
                          return const SizedBox.shrink();
                        }
                        
                        List<String> parts = _verimlilikData[value.toInt()].hafta.split(' - ');
                        String displayText = parts[0]; // Sadece başlangıç tarihini göster
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            displayText,
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              fontWeight: _selectedWeekIndex == value.toInt() ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatTime(value),
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.blueGrey.shade300, width: 2),
                    left: BorderSide(color: Colors.blueGrey.shade300, width: 2),
                    right: BorderSide(color: Colors.transparent),
                    top: BorderSide(color: Colors.transparent),
                  ),
                ),
                minY: 0,
                maxY: _findMaxVerimlilik() + 5,
                lineBarsData: _getVerimlilikCizgileri(_animation.value),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // Maksimum verimlilik değerini bul (y ekseninin maksimum değeri için)
  double _findMaxVerimlilik() {
    double maxValue = 0;
    
    for (var data in _verimlilikData) {
      // Tüm derslerin verimlilik değerlerini kontrol et
      for (var value in data.verimlilikDegerleri.values) {
        if (value > maxValue && value.isFinite) {
          maxValue = value;
        }
      }
      
      // Genel verimliliği de kontrol et
      if (data.genelVerimlilik > maxValue && data.genelVerimlilik.isFinite) {
        maxValue = data.genelVerimlilik;
      }
    }
    
    // Eğer maksimum değer çok küçükse, minimum bir değer ayarla
    if (maxValue < 10) {
      maxValue = 10;
    }
    
    return maxValue;
  }
  
  // Görseli geliştirilmiş verimlilik çizgileri
  List<LineChartBarData> _getVerimlilikCizgileri(double animValue) {
    List<LineChartBarData> lines = [];
    
    // Her ders için bir çizgi ekleme
    for (int i = 0; i < _dersler.length; i++) {
      String ders = _dersler[i];
      
      // Sıfırdan büyük değerler var mı kontrol et
      bool hasNonZeroValue = false;
      for (var data in _verimlilikData) {
        if (data.verimlilikDegerleri.containsKey(ders) && 
            data.verimlilikDegerleri[ders]! > 0) {
          hasNonZeroValue = true;
          break;
        }
      }
      
      // Sadece en az bir sıfırdan büyük değeri olan dersler için çizgi ekle
      if (hasNonZeroValue) {
        lines.add(
          LineChartBarData(
            spots: List.generate(_verimlilikData.length, (index) {
              double value = _verimlilikData[index].verimlilikDegerleri[ders] ?? 0;
              return FlSpot(index.toDouble(), value * animValue);
            }),
            isCurved: true,
            curveSmoothness: 0.35, // Daha dalgalı çizgi için
            color: _colorList[i % _colorList.length],
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: _selectedWeekIndex == index ? 6 : 4,
                  color: Colors.white,
                  strokeWidth: 3,
                  strokeColor: _colorList[i % _colorList.length],
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: _colorList[i % _colorList.length].withOpacity(0.15),
            ),
          ),
        );
      }
    }
    
    // Genel verimlilik için bir çizgi ekleme
    lines.add(
      LineChartBarData(
        spots: List.generate(_verimlilikData.length, (index) {
          return FlSpot(index.toDouble(), _verimlilikData[index].genelVerimlilik * animValue);
        }),
        isCurved: true,
        curveSmoothness: 0.35,
        color: Colors.red,
        barWidth: 5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: _selectedWeekIndex == index ? 7 : 5,
              color: Colors.white,
              strokeWidth: 3,
              strokeColor: Colors.red,
            );
          },
        ),
        dashArray: [5, 5], // Kesikli çizgi
        belowBarData: BarAreaData(
          show: true,
          color: Colors.red.withOpacity(0.1),
        ),
      ),
    );
    
    return lines;
  }
  
  Widget _buildSoruDetailCard() {
    if (_selectedWeekIndex < 0 || _selectedWeekIndex >= _chartData.length) {
      return SizedBox.shrink();
    }
    
    ChartSampleData data = _chartData[_selectedWeekIndex];
    int totalQuestions = data.toplam;
    
    // Tarih bilgilerini formatlama
    String dateRange = "";
    if (data.startDate != null && data.endDate != null) {
      dateRange = "${DateFormat('d MMMM').format(data.startDate!)} - ${DateFormat('d MMMM yyyy').format(data.endDate!)}";
    } else {
      dateRange = data.x;
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seçilen Hafta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                                child: Text(
                  dateRange,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toplam Çözülen Soru:',
                style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade700),
              ),
              Text(
                '$totalQuestions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(data.values.length, (index) {
              if (index >= _dersler.length) return SizedBox.shrink();
              
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _colorList[index % _colorList.length].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _colorList[index % _colorList.length].withOpacity(0.3)),
                ),
                child: Text(
                  '${_dersler[index]}: ${data.values[index]}',
                  style: TextStyle(
                    color: _colorList[index % _colorList.length].withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVerimlilikDetailCard() {
    if (_selectedWeekIndex < 0 || _selectedWeekIndex >= _verimlilikData.length) {
      return SizedBox.shrink();
    }
    
    VerimlilikData data = _verimlilikData[_selectedWeekIndex];
    
    // Tarih bilgilerini formatlama
    String dateRange = "";
    if (data.startDate != null && data.endDate != null) {
      dateRange = "${DateFormat('d MMMM').format(data.startDate!)} - ${DateFormat('d MMMM yyyy').format(data.endDate!)}";
    } else {
      dateRange = data.hafta;
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seçilen Hafta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateRange,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 20),
          
          // Genel Verimlilik
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ortalama Verimlilik:',
                style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade700),
              ),
              Text(
                '${_formatTime(data.genelVerimlilik)} dk/soru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Düşük değerler daha iyi (bir soruyu daha az sürede çözmek daha verimlidir)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          SizedBox(height: 16),
          
          // Ders bazlı verimlilik, soru ve süre verileri
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _dersler.length,
            itemBuilder: (context, index) {
              String ders = _dersler[index];
              double verimlilik = data.verimlilikDegerleri[ders] ?? 0;
              int soruSayisi = data.soruSayilari[ders] ?? 0;
              double calismaSuresi = data.calismaSureleri[ders] ?? 0;
              
              // Eğer veri yoksa (0 ise) bu dersi gösterme
              if (soruSayisi == 0 && calismaSuresi == 0) {
                return SizedBox.shrink();
              }
              
              return Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _colorList[index % _colorList.length].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _colorList[index % _colorList.length].withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ders,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _colorList[index % _colorList.length].withOpacity(0.8),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Verimlilik:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        Text(
                          verimlilik > 0 ? '${_formatTime(verimlilik)} dk/soru' : 'Veri yok',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Çözülen Soru:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        Text(
                          '$soruSayisi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Çalışma Süresi:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                        Text(
                          '${_formatTime(calismaSuresi)} dk',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildLegend() {
    if (_dersler.isEmpty) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: List.generate(_dersler.length + 1, (index) {
          Color color = index < _dersler.length 
              ? _colorList[index % _colorList.length]
              : Colors.red;
          
          String text = index < _dersler.length 
              ? _dersler[index]
              : (_aktifGrafikTipi == GrafikTipi.soruSayisi ? 'Toplam' : 'Ortalama');
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey.shade700,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
  
  List<BarChartGroupData> _getStackedBarGroups(double animValue) {
    return List.generate(_chartData.length, (index) {
      List<int> values = _chartData[index].values;
      double cumulative = 0;
      
      List<BarChartRodStackItem> stackItems = [];
      for (int i = 0; i < values.length && i < _dersler.length; i++) {
        double value = values[i] * animValue;
        if (value > 0) { // Sadece değeri olan çubukları ekle
          double fromY = cumulative;
          cumulative += value;
          stackItems.add(
            BarChartRodStackItem(fromY, cumulative, _colorList[i % _colorList.length]),
          );
        }
      }
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: cumulative,
            rodStackItems: stackItems,
            width: 22,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
        showingTooltipIndicators: _selectedWeekIndex == index ? [0] : [],
      );
    });
  }
  
  // Dakikayı formatlı göster (XX.X şeklinde)
  String _formatTime(double minutes) {
    if (minutes <= 0 || !minutes.isFinite) return "0.0";
    return minutes.toStringAsFixed(1);
  }
}

// Verimlilik verilerini tutacak sınıf
class VerimlilikData {
  final String hafta;
  final Map<String, double> verimlilikDegerleri; // Ders adı -> verimlilik (dk/soru)
  final double genelVerimlilik; // Genel verimlilik (dk/soru)
  final DateTime? startDate;
  final DateTime? endDate;
  final Map<String, int> soruSayilari; // Ders adı -> soru sayısı
  final Map<String, double> calismaSureleri; // Ders adı -> çalışma süresi (dk)
  
  VerimlilikData({
    required this.hafta,
    required this.verimlilikDegerleri,
    required this.genelVerimlilik,
    this.startDate,
    this.endDate,
    required this.soruSayilari,
    required this.calismaSureleri,
  });
}

class ChartSampleData {
  ChartSampleData({
    required this.x,
    required this.values,
    required this.toplam,
    this.startDate,
    this.endDate,
  });

  final String x;
  final List<int> values;
  final int toplam;
  final DateTime? startDate;
  final DateTime? endDate;
}

// TAB BUTON
class _TabButon extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool active;
  final Color underlineColor;

  const _TabButon({
    Key? key,
    required this.title,
    required this.onTap,
    required this.active,
    required this.underlineColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: active ? FontWeight.bold : FontWeight.w600,
                        fontSize: 15,
                        letterSpacing: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ),
                SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  width: active
                      ? constraints.maxWidth * 0.92
                      : 0,
                  decoration: BoxDecoration(
                    color: underlineColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}