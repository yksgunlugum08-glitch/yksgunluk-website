import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yksgunluk/icon_penceler/haftalik_veri/ayt_soru.dart';
import 'package:yksgunluk/icon_penceler/haftalik_veri/tyt_soru.dart';
import 'package:yksgunluk/ekranlar/home_page.dart';

class HaftalikGrafikSayfasi extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const HaftalikGrafikSayfasi({Key? key, this.studentId, this.studentName}) : super(key: key);

  @override
  State<HaftalikGrafikSayfasi> createState() => _HaftalikGrafikSayfasiState();
}

class _HaftalikGrafikSayfasiState extends State<HaftalikGrafikSayfasi> {
  List<WeekEntry> _gecmisHaftalar = [];
  WeekEntry? _currentHafta;
  bool _loading = true;
  late TooltipBehavior _tooltipBehavior;
  late ScrollController _scrollController;

  bool get _isTeacherMode => widget.studentId != null && widget.studentName != null;
  String? get _currentStudentId => widget.studentId;
  String? get _currentStudentName => widget.studentName;

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _scrollController = ScrollController();
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _loading = true;
    });

    String userId;
    if (_isTeacherMode && _currentStudentId != null) {
      userId = _currentStudentId!;
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _gecmisHaftalar = [];
          _currentHafta = null;
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
          .collection('weeksData')
          .orderBy('start', descending: false)
          .get();

      List<WeekEntry> gecmisListe = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        gecmisListe.add(
          WeekEntry(
            DateTime.fromMillisecondsSinceEpoch(data['start']),
            DateTime.fromMillisecondsSinceEpoch(data['end']),
            (data['test'] ?? 0) is int ? data['test'] ?? 0 : (data['test'] as num?)?.toInt() ?? 0,
            (data['konu'] ?? 0) is int ? data['konu'] ?? 0 : (data['konu'] as num?)?.toInt() ?? 0,
          ),
        );
      }

      DocumentSnapshot curWeekDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('currentWeekData')
          .doc('data')
          .get();

      WeekEntry? curHafta;
      if (curWeekDoc.exists && curWeekDoc.data() != null) {
        final curData = curWeekDoc.data() as Map<String, dynamic>;
        DateTime start = DateTime.fromMillisecondsSinceEpoch(curData['start']);
        DateTime end = DateTime.fromMillisecondsSinceEpoch(curData['end']);
        int test = (curData['test'] ?? 0) is int ? curData['test'] ?? 0 : (curData['test'] as num?)?.toInt() ?? 0;
        int konu = (curData['konu'] ?? 0) is int ? curData['konu'] ?? 0 : (curData['konu'] as num?)?.toInt() ?? 0;
        curHafta = WeekEntry(start, end, test, konu);
      }

      setState(() {
        _gecmisHaftalar = gecmisListe;
        _currentHafta = curHafta;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _gecmisHaftalar = [];
        _currentHafta = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    List<WeekEntry> tumHaftalar = List.from(_gecmisHaftalar);
    if (_currentHafta != null) tumHaftalar.add(_currentHafta!);

    final String title = _isTeacherMode 
        ? "${_currentStudentName ?? 'Öğrenci'} - Haftalık Çalışma"
        : "Haftalık Çalışma";

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
                          active: true,
                          underlineColor: Colors.white,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _TabButon(
                          title: "AYT Soru",
                          active: false,
                          underlineColor: Colors.transparent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AYTGrafik(
                                  studentId: _isTeacherMode ? _currentStudentId : null,
                                  studentName: _isTeacherMode ? _currentStudentName : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _TabButon(
                          title: "TYT Soru",
                          active: false,
                          underlineColor: Colors.transparent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TYTHaftalik(
                                  studentId: _isTeacherMode ? _currentStudentId : null,
                                  studentName: _isTeacherMode ? _currentStudentName : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isTeacherMode)
                  Container(
                    margin: EdgeInsets.only(right: 12),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
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
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isTeacherMode)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
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
                            "${_currentStudentName ?? 'Öğrenci'} - Haftalık Çalışma",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Son haftaların çalışma süresi ve test grafiği",
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
              ),
            ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: (tumHaftalar.length * 150).toDouble().clamp(600, double.infinity),
                  child: SfCartesianChart(
                    legend: Legend(isVisible: true, position: LegendPosition.bottom),
                    tooltipBehavior: _tooltipBehavior,
                    primaryXAxis: CategoryAxis(),
                    primaryYAxis: NumericAxis(minimum: 0, maximum: 112, interval: 16),
                    enableSideBySideSeriesPlacement: false,
                    series: <CartesianSeries<WeekEntry, String>>[
                      ColumnSeries<WeekEntry, String>(
                        dataSource: tumHaftalar.isEmpty
                            ? [WeekEntry(DateTime.now(), DateTime.now(), 0, 0)]
                            : tumHaftalar,
                        xValueMapper: (data, _) => data.label,
                        yValueMapper: (data, _) => data.toplamSure,
                        name: 'Toplam',
                        width: 0.9,
                        color: Colors.orange.shade300,
                      ),
                      ColumnSeries<WeekEntry, String>(
                        dataSource: tumHaftalar.isEmpty
                            ? [WeekEntry(DateTime.now(), DateTime.now(), 0, 0)]
                            : tumHaftalar,
                        xValueMapper: (data, _) => data.label,
                        yValueMapper: (data, _) => data.konuSure,
                        name: 'Konu Çalışma',
                        width: 0.6,
                        color: Colors.green,
                      ),
                      ColumnSeries<WeekEntry, String>(
                        dataSource: tumHaftalar.isEmpty
                            ? [WeekEntry(DateTime.now(), DateTime.now(), 0, 0)]
                            : tumHaftalar,
                        xValueMapper: (data, _) => data.label,
                        yValueMapper: (data, _) => data.testSure,
                        name: 'Test Çözme',
                        width: 0.3,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    double fontSize = title == "Çalışma Sürem" ? 15 : 17;
    FontWeight fontWeight = active ? FontWeight.bold : FontWeight.w600;

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
                        fontWeight: fontWeight,
                        fontSize: fontSize,
                        letterSpacing: 1.1,
                        height: 1.3,
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

class WeekEntry {
  final DateTime startDate;
  final DateTime endDate;
  final int testSureDakika;
  final int konuSureDakika;

  WeekEntry(this.startDate, this.endDate, this.testSureDakika, this.konuSureDakika);

  String get label {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(startDate.day)}.${twoDigits(startDate.month)} - ${twoDigits(endDate.day)}.${twoDigits(endDate.month)}";
  }

  double get toplamSure => (testSureDakika + konuSureDakika) / 60.0;
  double get testSure => testSureDakika / 60.0;
  double get konuSure => konuSureDakika / 60.0;
}