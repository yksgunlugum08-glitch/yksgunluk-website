import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Provider ekledim
import 'package:yksgunluk/ogretmen/ogrencilerim.dart';
import 'package:yksgunluk/teacher_mode.dart'; // TeacherModeProvider için import ekledim

import 'package:yksgunluk/deneme_charts/tyt_deneme/mat_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/turkce_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/sosyal_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/fizik_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/biyoloji_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/tyt_genel.dart';

class KimyaChartPage extends StatefulWidget {
  @override
  _KimyaChartPageState createState() => _KimyaChartPageState();
}

class _KimyaChartPageState extends State<KimyaChartPage> {
  List<_ChartData> chartData = [];
  TooltipBehavior _tooltipBehavior = TooltipBehavior(enable: true);
  int _currentTabIndex = 5; // Kimya için doğru başlangıç değeri
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

  /// Firestore'dan kimya verilerini yükler
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
        if (data.containsKey('kimya')) {
          final kimya = data['kimya'];
          veri.add(_ChartData(
            data['date'] ?? "",
            (kimya['dogru'] ?? 0).toDouble(),
            (kimya['yanlis'] ?? 0).toDouble(),
            (kimya['bos'] ?? 0).toDouble(),
            (kimya['net'] ?? 0).toDouble(),
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
          case 3:
            targetPage = BiyolojiChartPage();
            break;
          case 4:
            targetPage = FizikChartPage();
            break;
          default:
            return; // Kimya için hiçbir şey yapma
        }

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => targetPage,
            transitionsBuilder: (_, animation, __, child) {
              final offsetAnimation = Tween<Offset>(
                begin: Offset(-1.0, 0.0),
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
        ? "${_studentName} - Kimya Net Grafiği"
        : "Kimya Net Grafiği";
        
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color.fromARGB(255, 255, 17, 156),
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
                          color: const Color.fromARGB(255, 255, 17, 156),
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
                                ? "Bu öğrencinin kimya deneme verisi bulunmuyor."
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
                                maximum: 7,
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
    final double buttonWidth = MediaQuery.of(context).size.width / 6;
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