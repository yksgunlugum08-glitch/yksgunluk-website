import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ChartsPage extends StatefulWidget {
  // Öğretmen modu için parametreler
  final String? studentId;
  final String? studentName;

  const ChartsPage({
    Key? key,
    this.studentId,
    this.studentName,
  }) : super(key: key);

  @override
  _ChartsPageState createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  Map<String, int> tytQuestions = {};
  Map<String, int> aytQuestions = {};
  double toplamTestCozme = 0.0;
  double toplamKonuCalisma = 0.0;

  List<String> aytDersler = [];
  int? hoveredIndexTyt;
  int? hoveredIndexAyt;
  int? hoveredIndexStudy;

  Timer? _timer;

  // Öğretmen modu kontrolü - basit ve net
  bool get _isTeacherMode {
    return widget.studentId != null && widget.studentName != null;
  }

  String? get _currentStudentId => widget.studentId;
  String? get _currentStudentName => widget.studentName;

  @override
  void initState() {
    super.initState();
    
    print("=== 📊 ChartsPage Başlatılıyor ===");
    print("📝 Widget studentId: ${widget.studentId}");
    print("📝 Widget studentName: ${widget.studentName}");
    print("📝 Öğretmen modu aktif mi: $_isTeacherMode");
    
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _loadStudyTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadSelectedBolum();
    await _loadTytQuestions();
    await _loadAytQuestions();
    await _loadStudyTime();
  }

  /// Firestore'dan TYT soru sayılarını yükler
  Future<void> _loadTytQuestions() async {
    print("🎯 TYT verileri yükleniyor...");
    
    String userId;
    if (_isTeacherMode && _currentStudentId != null) {
      userId = _currentStudentId!;
      print("✅ Öğretmen modu - Öğrenci TYT verisi yükleniyor: $userId");
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Kullanıcı oturum açmamış");
        return;
      }
      userId = user.uid;
      print("✅ Normal mod - Kullanıcı TYT verisi yükleniyor: $userId");
    }

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('solvedQuestionsTyt')
          .get();

      Map<String, int> data = {};
      for (var doc in snapshot.docs) {
        var decoded = doc.data() as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (key != 'date' && key != 'timestamp' && (value is int || value is num)) {
            data[key] = (data[key] ?? 0) + (value as num).toInt();
          }
        });
      }
      
      if (!mounted) return;
      setState(() {
        tytQuestions = data;
      });
      
      print("✅ TYT verileri yüklendi: ${data.keys.toList()}");
    } catch (e) {
      print("❌ TYT veri yükleme hatası: $e");
    }
  }

  /// Firestore'dan AYT soru sayılarını yükler
  Future<void> _loadAytQuestions() async {
    print("🎯 AYT verileri yükleniyor...");
    
    String userId;
    if (_isTeacherMode && _currentStudentId != null) {
      userId = _currentStudentId!;
      print("✅ Öğretmen modu - Öğrenci AYT verisi yükleniyor: $userId");
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Kullanıcı oturum açmamış");
        return;
      }
      userId = user.uid;
      print("✅ Normal mod - Kullanıcı AYT verisi yükleniyor: $userId");
    }

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('solvedQuestionsAyt')
          .get();

      Map<String, int> data = {};
      for (var doc in snapshot.docs) {
        var decoded = doc.data() as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (key != 'date' && key != 'timestamp' && (value is int || value is num)) {
            data[key] = (data[key] ?? 0) + (value as num).toInt();
          }
        });
      }
      
      if (!mounted) return;
      setState(() {
        aytQuestions = data;
      });
      
      print("✅ AYT verileri yüklendi: ${data.keys.toList()}");
    } catch (e) {
      print("❌ AYT veri yükleme hatası: $e");
    }
  }

  /// Firestore'dan haftalık toplam test ve konu çalışma sürelerini yükler
  Future<void> _loadStudyTime() async {
    print("🎯 Çalışma süreleri yükleniyor...");
    
    String userId;
    if (_isTeacherMode && _currentStudentId != null) {
      userId = _currentStudentId!;
      print("✅ Öğretmen modu - Öğrenci çalışma süresi yükleniyor: $userId");
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Kullanıcı oturum açmamış");
        if (!mounted) return;
        setState(() {
          toplamTestCozme = 0.0;
          toplamKonuCalisma = 0.0;
        });
        return;
      }
      userId = user.uid;
      print("✅ Normal mod - Kullanıcı çalışma süresi yükleniyor: $userId");
    }

    try {
      DocumentSnapshot curDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('currentWeekData')
          .doc('data')
          .get();

      if (curDoc.exists) {
        var data = curDoc.data() as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          toplamTestCozme = (data['test'] ?? 0).toDouble();
          toplamKonuCalisma = (data['konu'] ?? 0).toDouble();
        });
        print("✅ Çalışma süreleri yüklendi - Test: $toplamTestCozme, Konu: $toplamKonuCalisma");
      } else {
        if (!mounted) return;
        setState(() {
          toplamTestCozme = 0.0;
          toplamKonuCalisma = 0.0;
        });
        print("⚠️ Çalışma süresi verisi bulunamadı");
      }
    } catch (e) {
      print("❌ Çalışma süresi yükleme hatası: $e");
      if (!mounted) return;
      setState(() {
        toplamTestCozme = 0.0;
        toplamKonuCalisma = 0.0;
      });
    }
  }

  /// Firestore'dan kullanıcının bölümünü ve ona göre aytDersler listesini yükler
  Future<void> _loadSelectedBolum() async {
    print("🎯 Bölüm bilgisi yükleniyor...");
    
    String userId;
    if (_isTeacherMode && _currentStudentId != null) {
      userId = _currentStudentId!;
      print("✅ Öğretmen modu - Öğrenci bölümü yükleniyor: $userId");
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Kullanıcı oturum açmamış");
        if (!mounted) return;
        setState(() {
          aytDersler = [];
        });
        return;
      }
      userId = user.uid;
      print("✅ Normal mod - Kullanıcı bölümü yükleniyor: $userId");
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      String selectedBolum = '';
      if (userDoc.exists) {
        selectedBolum = (userDoc.data() as Map<String, dynamic>)['selectedBolum'] ?? 'Sayısal';
      } else {
        selectedBolum = 'Sayısal';
      }
      
      if (!mounted) return;
      setState(() {
        aytDersler = getDerslerByBolum(selectedBolum);
      });
      
      print("✅ Bölüm yüklendi: $selectedBolum, Dersler: $aytDersler");
    } catch (e) {
      print("❌ Bölüm yükleme hatası: $e");
      if (!mounted) return;
      setState(() {
        aytDersler = [];
      });
    }
  }

  List<String> getDerslerByBolum(String bolum) {
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
        return [];
    }
  }

  void _goBack() {
    print("🔙 Geri butonuna basıldı. Öğretmen modu: $_isTeacherMode");
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Öğretmen modu kontrolü ve başlık özelleştirme
    final String title = _isTeacherMode 
        ? "${_currentStudentName ?? 'Öğrenci'} - Çalışma Grafikleri" 
        : "Çalışma Grafikleri";

    print("🖼️ Build çağrıldı - Öğretmen modu: $_isTeacherMode, Başlık: $title");

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.lightBlue,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBack,
        ),
        // Öğretmen modu göstergesi AppBar'da
        actions: _isTeacherMode ? [
          Container(
            margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school, color: Colors.orange.shade700, size: 16),
                SizedBox(width: 4),
                Text(
                  "Öğretmen",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ] : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Öğretmen modu için ek bilgi kartı
              if (_isTeacherMode) ...[
                _buildTeacherModeInfoCard(),
                SizedBox(height: 20),
              ],
              _buildTytChartSection(),
              _buildAytChartSection(),
              _buildTotalStudyTimeChart(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherModeInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade300, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.orange.shade200,
            child: Text(
              _currentStudentName?.isNotEmpty == true
                  ? '${_currentStudentName!.split(' ')[0][0]}${_currentStudentName!.split(' ').length > 1 ? _currentStudentName!.split(' ')[1][0] : ''}'
                  : '??',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_currentStudentName ?? 'Öğrenci'} - Toplam İlerleme",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Genel performans ve çalışma istatistikleri",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.analytics,
            color: Colors.orange.shade700,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildTytChartSection() {
    // Toplam ve date/timestamp gibi gereksiz alanları filtrele
    Map<String, int> filteredData = Map.from(tytQuestions)
      ..removeWhere((key, value) => key == 'Toplam' || key == 'date' || key == 'timestamp');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.quiz, color: Colors.blue, size: 24),
            SizedBox(width: 8),
            Text(
              _isTeacherMode ? 'TYT Soru Sayıları (${_currentStudentName})' : 'TYT Soru Sayıları',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 20),
        filteredData.isEmpty 
          ? _buildEmptyDataCard("TYT") 
          : Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            if (!event.isInterestedForInteractions || 
                                pieTouchResponse == null || 
                                pieTouchResponse.touchedSection == null) {
                              return;
                            }
                            
                            final sectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            if (sectionIndex >= 0) {
                              setState(() {
                                hoveredIndexTyt = hoveredIndexTyt == sectionIndex ? null : sectionIndex;
                              });
                            }
                          },
                        ),
                        sections: _getSections(filteredData, hoveredIndexTyt),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ),
                _buildLegend(filteredData),
              ],
            ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAytChartSection() {
    // Toplam ve date/timestamp gibi gereksiz alanları filtrele
    Map<String, int> filteredData = Map.from(aytQuestions)
      ..removeWhere((key, value) => key == 'Toplam' || key == 'date' || key == 'timestamp');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.school, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text(
              _isTeacherMode ? 'AYT Soru Sayıları (${_currentStudentName})' : 'AYT Soru Sayıları',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 20),
        filteredData.isEmpty 
          ? _buildEmptyDataCard("AYT") 
          : Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            if (!event.isInterestedForInteractions || 
                                pieTouchResponse == null || 
                                pieTouchResponse.touchedSection == null) {
                              return;
                            }
                            
                            final sectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            if (sectionIndex >= 0) {
                              setState(() {
                                hoveredIndexAyt = hoveredIndexAyt == sectionIndex ? null : sectionIndex;
                              });
                            }
                          },
                        ),
                        sections: _getSections(filteredData, hoveredIndexAyt),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ),
                _buildLegend(filteredData),
              ],
            ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTotalStudyTimeChart() {
    final Map<String, double> haftalikToplamlar = {
      'Test Çözme Süresi': toplamTestCozme / 60.0, // saate çevir
      'Konu Çalışma Süresi': toplamKonuCalisma / 60.0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer, color: Colors.purple, size: 24),
            SizedBox(width: 8),
            Text(
              _isTeacherMode ? 'Toplam Çalışma Süresi (${_currentStudentName})' : 'Toplam Çalışma Süresi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 20),
        (toplamTestCozme == 0.0 && toplamKonuCalisma == 0.0) 
          ? _buildEmptyDataCard("Çalışma Süresi") 
          : Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            if (!event.isInterestedForInteractions || 
                                pieTouchResponse == null || 
                                pieTouchResponse.touchedSection == null) {
                              return;
                            }
                            
                            final sectionIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            if (sectionIndex >= 0) {
                              setState(() {
                                hoveredIndexStudy = hoveredIndexStudy == sectionIndex ? null : sectionIndex;
                              });
                            }
                          },
                        ),
                        sections: _getTotalStudyTimeSections(haftalikToplamlar),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                ),
                _buildTotalLegend(haftalikToplamlar),
              ],
            ),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmptyDataCard(String dataType) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 60,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            _isTeacherMode 
              ? "${_currentStudentName} için henüz $dataType verisi yok"
              : "Henüz $dataType verisi yok",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            _isTeacherMode 
              ? "Öğrenci $dataType çözdükçe/çalıştıkça burada görünecek"
              : "$dataType çözdükçe/çalıştıkça burada görünecek",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Map<String, dynamic> data) {
    // Veriyi miktarına göre sırala (büyükten küçüğe)
    var sortedEntries = data.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
      
    return Container(
      width: 120,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedEntries.map((entry) {
          final index = sortedEntries.indexOf(entry);
          final isHovered = index == hoveredIndexTyt || index == hoveredIndexAyt;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getColorBySubject(entry.key),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalLegend(Map<String, double> data) {
    var sortedEntries = data.entries.toList();
    
    return Container(
      width: 120,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedEntries.map((entry) {
          final index = sortedEntries.indexOf(entry);
          final isHovered = index == hoveredIndexStudy;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getColorByTotalKey(entry.key),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${entry.key}: ${entry.value.toStringAsFixed(1)} saat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<PieChartSectionData> _getSections(Map<String, int> data, int? hoveredIndex) {
    if (data.isEmpty) {
      return [];
    }
    
    // Verileri sırala (büyükten küçüğe)
    var sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    return List.generate(sortedEntries.length, (i) {
      final entry = sortedEntries[i];
      final isHovered = i == hoveredIndex;
      final double fontSize = isHovered ? 16 : 12;
      final double radius = isHovered ? 65 : 50; // Seçildiğinde hafifçe büyüt
      
      return PieChartSectionData(
        color: _getColorBySubject(entry.key),
        value: entry.value.toDouble(),
        radius: radius,
        title: entry.value > 0 ? '${entry.value}' : '',
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        // Badge kaldırıldı
      );
    });
  }

  List<PieChartSectionData> _getTotalStudyTimeSections(Map<String, double> data) {
    if (data.isEmpty || (data.values.every((v) => v == 0))) {
      return [];
    }
    
    var sortedEntries = data.entries.toList();
    
    return List.generate(sortedEntries.length, (i) {
      final entry = sortedEntries[i];
      final isHovered = i == hoveredIndexStudy;
      final double fontSize = isHovered ? 16 : 12;
      final double radius = isHovered ? 65 : 50;
      
      return PieChartSectionData(
        color: _getColorByTotalKey(entry.key),
        value: entry.value > 0 ? entry.value : 0.001, // Sıfır değerler için çok küçük değer
        radius: radius,
        title: entry.value > 0 ? '${entry.value.toStringAsFixed(1)}h' : '',
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Color _getColorBySubject(String subject) {
    switch (subject) {
      case 'Matematik':
        return Colors.green;
      case 'Türkçe':
        return Colors.blue;
      case 'Sosyal':
        return Colors.red;
      case 'Fen':
        return Colors.orange;
      case 'Fizik':
        return Colors.purple;
      case 'Kimya':
        return Colors.teal;
      case 'Biyoloji':
        return Colors.pink;
      case 'Edebiyat':
        return Colors.indigo;
      case 'Tarih':
        return Colors.brown;
      case 'Coğrafya':
        return Colors.cyan;
      case 'Felsefe':
        return Colors.lime;
      case 'Dilbilgisi':
        return Colors.deepPurple;
      case 'Okuma':
        return Colors.lightGreen;
      case 'Anlama':
        return Colors.deepOrange;
      case 'Yazma':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Color _getColorByTotalKey(String key) {
    switch (key) {
      case 'Test Çözme Süresi':
        return Colors.blueAccent;
      case 'Konu Çalışma Süresi':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}