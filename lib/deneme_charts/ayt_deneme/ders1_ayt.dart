import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:yksgunluk/dumenden/app_state.dart';
import 'package:yksgunluk/ogretmen/ogrencilerim.dart';
import 'package:yksgunluk/teacher_mode.dart';

class AytDersGrafikleriPage extends StatefulWidget {
  const AytDersGrafikleriPage({Key? key}) : super(key: key);

  @override
  State<AytDersGrafikleriPage> createState() => _AytDersGrafikleriPageState();
}

class _AytDersGrafikleriPageState extends State<AytDersGrafikleriPage> {
  final Map<String, Map<String, int>> derslerVeMaxlar = {
    'Sayısal': {
      'Matematik': 40,
      'Fizik': 14,
      'Kimya': 13,
      'Biyoloji': 13,
    },
    'Eşit Ağırlık': {
      'Edebiyat': 24,
      'Matematik': 40,
      'Tarih': 10,
      'Coğrafya': 6,
    },
    'Sözel': {
      'Tarih Sos 1': 10,
      'Tarih Sos 2': 11,
      'Edebiyat': 24,
      'Coğrafya Sos 1': 6,
      'Coğrafya Sos 2': 11,
      'Felsefe': 12,
      'Din': 6,
    },
  };

  // Her ders için renkler (appBar ve underline için)
  static const Map<String, Color> dersRenkleri = {
    'Matematik': Color(0xff2196F3),
    'Fizik': Color(0xffE91E63),
    'Kimya': Color(0xff4CAF50),
    'Biyoloji': Color(0xffFFC107),
    'Edebiyat': Color(0xff9C27B0),
    'Tarih': Color(0xffFF5722),
    'Coğrafya': Color(0xff009688),
    'Tarih Sos 1': Color(0xffFF9800),
    'Tarih Sos 2': Color(0xffFF6F00),
    'Coğrafya Sos 1': Color(0xff607D8B),
    'Coğrafya Sos 2': Color(0xff795548),
    'Felsefe': Color(0xff607D8B),
    'Din': Color(0xff00BCD4),
  };

  List<Map<String, dynamic>> aytVeriListesi = [];
  int _selectedTabIndex = 0;
  bool _loading = true;
  String? _studentBolum; // Başlangıçta null olarak ayarla
  
  // Öğretmen modu için getter'lar
  bool get _isTeacherMode => Provider.of<TeacherModeProvider>(context, listen: false).isTeacherMode;
  String? get _studentId => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentId;
  String? get _studentName => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  // Tüm veri yükleme işlemlerini buradan yönetiyoruz
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    
    // Öğretmen modundaysa önce öğrencinin bölümünü yükle
    if (_isTeacherMode) {
      await _loadStudentBolum();
    } else {
      // Öğrenci kendi bölümünü AppState'den al
      final appState = Provider.of<AppState>(context, listen: false);
      _studentBolum = appState.selectedBolum;
    }
    
    // Sonra AYT verilerini yükle
    await _loadAytVeriFirestore();
    
    setState(() {
      _loading = false;
    });
  }
  
  // Öğrencinin bölüm bilgisini yükle - iyileştirilmiş
  Future<void> _loadStudentBolum() async {
    if (!_isTeacherMode || _studentId == null || _studentId!.isEmpty) return;
    
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_studentId)
          .get();
      
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>?;
        
        // Debug için tüm kullanıcı verisini yazdır
        print("Öğrenci verileri: $userData");
        
        // Farklı alan isimlerini deneyelim
        String? bolum;
        
        // Olası alan isimleri listesi
        List<String> possibleFields = [
          'bolum',
          'bölüm',
          'selectedBolum',
          'secilibolum',
          'branch',
          'department',
          'alan'
        ];
        
        // Tüm olası alanları kontrol et
        for (var field in possibleFields) {
          if (userData!.containsKey(field)) {
            bolum = userData?[field];
            print("Bölüm bilgisi '$field' alanından alındı: $bolum");
            break;
          }
        }
        
        // Eğer bölüm bulunamazsa manuel olarak kontrol et
        if (bolum == null) {
          userData?.forEach((key, value) {
            if (value is String) {
              if (value == 'Sayısal' || value == 'Eşit Ağırlık' || value == 'Sözel') {
                bolum = value;
                print("Bölüm bilgisi '$key' alanından alındı: $bolum");
              }
            }
          });
        }
        
        // Bulunan bölümü kaydet
        if (bolum != null && bolum!.isNotEmpty) {
          setState(() {
            _studentBolum = bolum;
          });
          return;
        }
        
        // Hiçbir yerden bölüm bilgisi bulunamazsa, AYT denemeleri kontrol et
        // Belki bu denemelerdeki derslerden bölümü tahmin edebiliriz
        if (_studentBolum == null) {
          QuerySnapshot aytDenemeleri = await FirebaseFirestore.instance
              .collection('users')
              .doc(_studentId)
              .collection('aytDenemeSonuclari')
              .limit(5)
              .get();
          
          if (aytDenemeleri.docs.isNotEmpty) {
            Set<String> dersler = {};
            
            for (var doc in aytDenemeleri.docs) {
              var data = doc.data() as Map<String, dynamic>;
              if (data.containsKey('dogru')) {
                var dogru = data['dogru'] as Map<String, dynamic>?;
                if (dogru != null) {
                  dogru.keys.forEach((ders) => dersler.add(ders));
                }
              }
            }
            
            print("Bulunan dersler: $dersler");
            
            // Derslere göre bölüm tahmini
            if (dersler.contains('Fizik') && dersler.contains('Kimya') && dersler.contains('Biyoloji')) {
              setState(() { _studentBolum = 'Sayısal'; });
              print("Derslerden tahmin edilen bölüm: Sayısal");
            } else if (dersler.contains('Edebiyat') && dersler.contains('Tarih') && 
                      dersler.contains('Coğrafya') && dersler.contains('Matematik')) {
              setState(() { _studentBolum = 'Eşit Ağırlık'; });
              print("Derslerden tahmin edilen bölüm: Eşit Ağırlık");
            } else if (dersler.contains('Tarih Sos 1') || dersler.contains('Tarih Sos 2') || 
                      dersler.contains('Felsefe') || dersler.contains('Din')) {
              setState(() { _studentBolum = 'Sözel'; });
              print("Derslerden tahmin edilen bölüm: Sözel");
            }
          }
        }
      }
      
      // Yine bulunamazsa varsayılan "Eşit Ağırlık" kullan
      if (_studentBolum == null) {
        print("Bölüm bilgisi bulunamadı, varsayılan olarak 'Eşit Ağırlık' kullanılıyor");
        setState(() {
          _studentBolum = 'Eşit Ağırlık';  // Varsayılan "Eşit Ağırlık" olsun
        });
      }
    } catch (e) {
      print("Öğrenci bölümü yüklenirken hata: $e");
      setState(() {
        _studentBolum = 'Eşit Ağırlık';  // Hata durumunda varsayılan
      });
    }
  }

  Future<void> _loadAytVeriFirestore() async {
    // Öğretmen/öğrenci moduna göre ID seçimi
    String userId;
    
    if (_isTeacherMode) {
      // Öğretmen modunda seçilen öğrencinin ID'sini kullan
      userId = _studentId ?? '';
      if (userId.isEmpty) {
        setState(() {
          aytVeriListesi = [];
        });
        return;
      }
    } else {
      // Normal modda kendi ID'sini kullan
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          aytVeriListesi = [];
        });
        return;
      }
      userId = user.uid;
    }
    
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('aytDenemeSonuclari')
          .orderBy('timestamp', descending: false)
          .get();

      List<Map<String, dynamic>> veriList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'date': data['date'] ?? '',
          'dogru': data['dogru'] ?? {},
          'yanlis': data['yanlis'] ?? {},
        };
      }).toList();
      setState(() {
        aytVeriListesi = veriList;
      });
    } catch (e) {
      print("AYT verileri yüklenirken hata: $e");
      setState(() {
        aytVeriListesi = [];
      });
    }
  }

  double _getDersValue(Map? map, String ders) {
    if (map == null) return 0.0;
    if (!map.containsKey(ders)) return 0.0;
    var val = map[ders];
    if (val == null) return 0.0;
    if (val is int) return val.toDouble();
    if (val is double) return val;
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // Bölüm bilgisini belirle
    String bolum;
    
    if (_isTeacherMode) {
      // Öğretmen modunda öğrencinin bölümünü kullan
      bolum = _studentBolum ?? 'Eşit Ağırlık';
    } else {
      // Normal modda AppState'den bölüm bilgisini al
      final appState = Provider.of<AppState>(context, listen: true);
      bolum = appState.selectedBolum ?? 'Eşit Ağırlık';
    }
    
    // Seçilen bölüme göre dersleri al
    final derslerMap = derslerVeMaxlar[bolum]!;
    final dersList = derslerMap.keys.toList();

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isTeacherMode 
            ? "${_studentName} - AYT Ders Grafikleri" 
            : "AYT Ders Grafikleri")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Seçili dersi belirle (tab index'ine göre)
    if (_selectedTabIndex >= dersList.length) {
      _selectedTabIndex = 0; // Eğer seçili tab index dışındaysa sıfırla
    }
    
    String seciliDers = dersList[_selectedTabIndex];
    int maxY = derslerMap[seciliDers] ?? 40;
    final Color selectedColor =
        dersRenkleri[seciliDers] ?? Colors.lightBlue; // Default

    // Tab ve underline genişliği eşit olacak şekilde:
    final double screenWidth = MediaQuery.of(context).size.width;
    final int tabCount = dersList.length;
    final double tabWidth = screenWidth / tabCount;

    // Kayıtların ders bazında doğru/yanlış/boş/net hesabı
    List<_ChartData> chartData = aytVeriListesi.map((veri) {
      double dogru = _getDersValue(veri['dogru'], seciliDers);
      double yanlis = _getDersValue(veri['yanlis'], seciliDers);
      int maxSoru = derslerMap[seciliDers] ?? 0;
      double bos = maxSoru - (dogru + yanlis);
      if (bos < 0) bos = 0.0;
      double net = dogru - (yanlis / 4);
      return _ChartData(
        date: (veri['date'] ?? '').toString(),
        dogru: dogru,
        yanlis: yanlis,
        bos: bos,
        net: net,
      );
    }).where((d) => d.dogru > 0 || d.yanlis > 0 || d.bos > 0 || d.net != 0).toList();

    // Başlığı öğretmen moduna göre ayarla
    final String title = _isTeacherMode 
        ? "${_studentName} - AYT $seciliDers Net Grafiği"
        : "AYT $seciliDers Net Grafiği";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: selectedColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
            // Öğretmen moduna göre farklı sayfalara yönlendir
            if (_isTeacherMode) {
              // Öğretmen modunda öğrenci listesi sayfasına git
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OgrenciListesiSayfasi(),
                ),
              );
            }
            // Normal modda geri dönüş yeterli
          },
        ),
      ),
      body: Column(
        children: [
          // Bölüm bilgisi göster (öğretmen modunda)
          if (_isTeacherMode)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  "Öğrenci Bölümü: $bolum",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
            
          // Eşit aralıklı tab bar ve underline
          SizedBox(
            height: 58,
            child: Stack(
              children: [
                Row(
                  children: List.generate(tabCount, (i) {
                    bool isActive = i == _selectedTabIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTabIndex = i;
                        });
                      },
                      child: Container(
                        width: tabWidth,
                        alignment: Alignment.center,
                        child: Text(
                          dersList[i],
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.grey[700],
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                  left: _selectedTabIndex * tabWidth,
                  bottom: 5,
                  child: Container(
                    width: tabWidth,
                    height: 3,
                    color: selectedColor,
                  ),
                ),
              ],
            ),
          ),
          // GRAFİK
          Expanded(
            child: chartData.isEmpty
                ? Center(
                    child: Text(
                      _isTeacherMode
                          ? "Bu öğrencinin AYT $seciliDers deneme verisi bulunmuyor."
                          : "Henüz veri yok veya kayıtlar okunamıyor.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: 600,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(
                          title: AxisTitle(text: 'Tarih'),
                          labelRotation: 45,
                        ),
                        primaryYAxis: NumericAxis(
                          minimum: 0,
                          maximum: maxY.toDouble(),
                          interval: 5,
                        ),
                        tooltipBehavior: TooltipBehavior(enable: true),
                        legend: Legend(isVisible: true),
                        series: [
                          LineSeries<_ChartData, String>(
                            name: 'Doğru',
                            color: Colors.green,
                            dataSource: chartData,
                            xValueMapper: (_ChartData data, _) => data.date,
                            yValueMapper: (_ChartData data, _) => data.dogru,
                            markerSettings: MarkerSettings(isVisible: true),
                          ),
                          LineSeries<_ChartData, String>(
                            name: 'Yanlış',
                            color: Colors.red,
                            dataSource: chartData,
                            xValueMapper: (_ChartData data, _) => data.date,
                            yValueMapper: (_ChartData data, _) => data.yanlis,
                            markerSettings: MarkerSettings(isVisible: true),
                          ),
                          LineSeries<_ChartData, String>(
                            name: 'Boş',
                            color: Colors.yellow,
                            dataSource: chartData,
                            xValueMapper: (_ChartData data, _) => data.date,
                            yValueMapper: (_ChartData data, _) => data.bos,
                            markerSettings: MarkerSettings(isVisible: true),
                          ),
                          LineSeries<_ChartData, String>(
                            name: 'Net',
                            color: selectedColor,
                            dataSource: chartData,
                            xValueMapper: (_ChartData data, _) => data.date,
                            yValueMapper: (_ChartData data, _) => data.net,
                            markerSettings: MarkerSettings(isVisible: true),
                            dashArray: [6, 3],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChartData {
  final String date;
  final double dogru;
  final double yanlis;
  final double bos;
  final double net;
  _ChartData({
    required this.date,
    required this.dogru,
    required this.yanlis,
    required this.bos,
    required this.net,
  });
}