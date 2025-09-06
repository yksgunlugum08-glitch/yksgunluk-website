import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Provider ekledim
import 'package:yksgunluk/ogretmen/ogrencilerim.dart';
import 'package:yksgunluk/teacher_mode.dart'; // TeacherModeProvider için import
import 'package:yksgunluk/deneme_charts/tyt_deneme/mat_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/turkce_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/sosyal_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/kimya_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/fizik_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/tyt_genel.dart';

class BiyolojiChartPage extends StatefulWidget {
  @override
  _BiyolojiChartPageState createState() => _BiyolojiChartPageState();
}

class _BiyolojiChartPageState extends State<BiyolojiChartPage> {
  List<_ChartData> chartData = [];
  TooltipBehavior _tooltipBehavior = TooltipBehavior(enable: true);
  int _currentTabIndex = 3; // Biyoloji için doğru başlangıç değeri
  bool _loading = true;

  // Öğretmen modu için getter'lar
  bool get _isTeacherMode => Provider.of<TeacherModeProvider>(context, listen: false).isTeacherMode;
  String? get _studentId => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentId;
  String? get _studentName => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentName;

  @override
  void initState() {
    super.initState();
    _loadChartDataFromFirebase();
  }

  /// Firestore'dan biyoloji verilerini yükler
  Future<void> _loadChartDataFromFirebase() async {
    setState(() {
      _loading = true;
    });
    
    // Öğretmen/öğrenci moduna göre ID seçimi
    String userId;
    
    if (_isTeacherMode) {
      // Öğretmen modunda seçilen öğrencinin ID'sini kullan
      userId = _studentId ?? '';
      if (userId.isEmpty) {
        setState(() {
          chartData = [];
          _loading = false;
        });
        return;
      }
    } else {
      // Normal modda kendi ID'sini kullan
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          chartData = [];
          _loading = false;
        });
        return;
      }
      userId = user.uid;
    }
    
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('tytDenemeSonuclari')
          .orderBy('timestamp', descending: false)
          .get();

      List<_ChartData> veri = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('biyoloji')) {
          final biyoloji = data['biyoloji'];
          veri.add(_ChartData(
            data['date'] ?? "",
            (biyoloji['dogru'] ?? 0).toDouble(),
            (biyoloji['yanlis'] ?? 0).toDouble(),
            (biyoloji['bos'] ?? 0).toDouble(),
            (biyoloji['net'] ?? 0).toDouble(),
          ));
        }
      }
      setState(() {
        chartData = veri;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        chartData = [];
        _loading = false;
      });
    }
  }

  void _onTabTapped(int index) {
    if (index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = index;
      });

      Future.delayed(Duration(milliseconds: 100), () {
        Widget targetPage;

        switch (index) {
          case 0:
            targetPage = MatematikChartPage();
            break;
          case 1:
            targetPage = TurkceChartPage();
            break;
          case 2:
            targetPage = SosyalChartPage();
            break;
          case 4:
            targetPage = FizikChartPage();
            break;
          case 5:
            targetPage = KimyaChartPage();
            break;
          default:
            return; // Biyoloji için hiçbir şey yapma
        }

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => targetPage,
            transitionsBuilder: (_, animation, __, child) {
              final offsetAnimation = Tween<Offset>(
                begin: (index == 4 || index == 5) ? Offset(1.0, 0.0) : Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(animation);

              return SlideTransition(position: offsetAnimation, child: child);
            },
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Başlığı öğretmen moduna göre ayarla
    final String title = _isTeacherMode 
        ? "${_studentName} - Biyoloji Net Grafiği"
        : "Biyoloji Net Grafiği";
        
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.lightGreen,
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
            } else {
              // Normal modda TYT deneme sonuçları sayfasına git
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TYTDenemeSonuclarim(),
                ),
              );
            }
          },
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab Buttons with Dynamic Underline Animation
                SizedBox(
                  height: 60,
                  child: Stack(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTabButton('Matematik', 0),
                          _buildTabButton('Türkçe', 1),
                          _buildTabButton('Sosyal', 2),
                          _buildTabButton('Biyoloji', 3),
                          _buildTabButton('Fizik', 4),
                          _buildTabButton('Kimya', 5),
                        ],
                      ),
                      AnimatedPositioned(
                        duration: Duration(milliseconds: 300),
                        left: _getTabIndicatorPosition(context, _currentTabIndex),
                        bottom: 0,
                        child: Container(
                          height: 3,
                          width: _getTabButtonWidth(context, _currentTabIndex),
                          color: Colors.lightGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: chartData.isEmpty
                      ? Center(
                          child: Text(
                            _isTeacherMode
                                ? "Bu öğrencinin biyoloji deneme verisi bulunmuyor."
                                : "Henüz veri yok veya kayıtlar okunamıyor."
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
                                maximum: 6,
                                interval: 1,
                              ),
                              tooltipBehavior: _tooltipBehavior,
                              legend: Legend(isVisible: true),
                              series: [
                                LineSeries<_ChartData, String>(
                                  name: 'Doğru',
                                  color: Colors.green,
                                  dataSource: chartData,
                                  xValueMapper: (_ChartData data, _) => data.date,
                                  yValueMapper: (_ChartData data, _) => data.dogru,
                                  markerSettings: const MarkerSettings(isVisible: true),
                                ),
                                LineSeries<_ChartData, String>(
                                  name: 'Yanlış',
                                  color: Colors.red,
                                  dataSource: chartData,
                                  xValueMapper: (_ChartData data, _) => data.date,
                                  yValueMapper: (_ChartData data, _) => data.yanlis,
                                  markerSettings: const MarkerSettings(isVisible: true),
                                ),
                                LineSeries<_ChartData, String>(
                                  name: 'Boş',
                                  color: Colors.yellow,
                                  dataSource: chartData,
                                  xValueMapper: (_ChartData data, _) => data.date,
                                  yValueMapper: (_ChartData data, _) => data.bos,
                                  markerSettings: const MarkerSettings(isVisible: true),
                                ),
                                LineSeries<_ChartData, String>(
                                  name: 'Net',
                                  color: Colors.blue,
                                  dataSource: chartData,
                                  xValueMapper: (_ChartData data, _) => data.date,
                                  yValueMapper: (_ChartData data, _) => data.net,
                                  markerSettings: const MarkerSettings(isVisible: true),
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

  Widget _buildTabButton(String label, int index) {
    final bool isActive = _currentTabIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  double _getTabButtonWidth(BuildContext context, int index) {
    const Map<int, String> tabLabels = {
      0: "Matematik",
      1: "Türkçe",
      2: "Sosyal",
      3: "Biyoloji",
      4: "Fizik",
      5: "Kimya",
    };
    final String label = tabLabels[index] ?? "";
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: TextStyle(fontSize: 16.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  double _getTabIndicatorPosition(BuildContext context, int index) {
    final double buttonWidth = MediaQuery.of(context).size.width / 5.55;
    final double labelWidth = _getTabButtonWidth(context, index);
    return (buttonWidth * index) + (buttonWidth - labelWidth) / 2;
  }
}

class _ChartData {
  final String date;
  final double dogru;
  final double yanlis;
  final double bos;
  final double net;

  _ChartData(this.date, this.dogru, this.yanlis, this.bos, this.net);

  Map<String, dynamic> toJson() => {
        'date': date,
        'dogru': dogru,
        'yanlis': yanlis,
        'bos': bos,
        'net': net,
      };
}