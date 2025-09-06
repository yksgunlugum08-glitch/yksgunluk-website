import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // Provider ekledim
import 'package:yksgunluk/deneme_charts/ayt_deneme/ayt_genel.dart' hide DenemeSonucu;
import 'package:yksgunluk/deneme_charts/denemesonucu.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/mat_chart.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/result_page.dart';
import 'package:yksgunluk/ekranlar/home_page.dart';
import 'package:yksgunluk/ogretmen/ogrencilerim.dart';
import 'package:yksgunluk/teacher_mode.dart';

class TYTDenemeSonuclarim extends StatefulWidget {
  @override
  _TYTDenemeSonuclarimState createState() => _TYTDenemeSonuclarimState();
}

class _TYTDenemeSonuclarimState extends State<TYTDenemeSonuclarim> with SingleTickerProviderStateMixin {
  List<DenemeSonucu> _data = [];
  bool _isLoading = true;
  late TooltipBehavior _tooltipBehavior;
  late TabController _tabController;
  bool _isTYTSelected = true; // TYT seçili olarak başla
  
  // Öğretmen modu için getter'lar
  bool get _isTeacherMode => Provider.of<TeacherModeProvider>(context, listen: false).isTeacherMode;
  String? get _studentId => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentId;
  String? get _studentName => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentName;

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    
    // Tab değişikliklerini dinle
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isTYTSelected = _tabController.index == 0;
        });
        
        // AYT seçilirse AYT sayfasına yönlendir
        if (!_isTYTSelected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AYTDenemeSonuclarim()),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Öğretmen/öğrenci moduna göre ID seçimi
    String userId;
    
    if (_isTeacherMode) {
      // Öğretmen modunda seçilen öğrencinin ID'sini kullan
      userId = _studentId ?? '';
      if (userId.isEmpty) {
        setState(() {
          _data = [];
          _isLoading = false;
        });
        return;
      }
    } else {
      // Normal modda kendi ID'sini kullan
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _data = [];
          _isLoading = false;
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

      List<DenemeSonucu> results = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DenemeSonucu(
          date: data['date'] ?? '',
          score: (data['score'] ?? 0).toDouble(),
        );
      }).toList();
      setState(() {
        _data = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _data = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData(DenemeSonucu yeni) async {
    // Öğretmen modunda değişiklik yapılamaz
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğretmen modunda değişiklik yapamazsınız!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Eski sonucu aynı tarihle varsa sil (güncelleme mantığı)
    QuerySnapshot existing = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tytDenemeSonuclari')
        .where('date', isEqualTo: yeni.date)
        .get();
    for (var doc in existing.docs) {
      await doc.reference.delete();
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tytDenemeSonuclari')
        .add({
      'date': yeni.date,
      'score': yeni.score,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // _loadData yerine aşağıdaki satırla doğrudan veri ekleyip animasyonu tetikle
    setState(() {
      _data.add(yeni);
    });
    
    // Kullanıcıya bildirim göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deneme sonucu kaydedildi'),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _navigateAndAddResult(BuildContext context) async {
    // Öğretmen modunda değişiklik yapılamaz
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğretmen modunda değişiklik yapamazsınız!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddResultPage()),
    );

    if (result != null && result is DenemeSonucu) {
      await _saveData(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Başlığı öğretmen moduna göre ayarla
    final String title = _isTeacherMode 
        ? "${_studentName} - TYT Deneme Sonuçları"
        : "Deneme Sonuçlarım";
        
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MatematikChartPage(),
                ),
              );
            },
          ),
        ],
        title: Text(
          title, 
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
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
              // Normal modda ana sayfaya git
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AnaEkran(),
                ),
              );
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade500,
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
              ),
              tabs: [
                Tab(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isTYTSelected ? Colors.blue.shade600 : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "TYT",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Tab(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isTYTSelected ? Colors.purple.shade600 : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "AYT",
                      style: TextStyle(
                        color: Colors.purple.shade200,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        child: _isLoading
            ? Center(key: ValueKey('loading'), child: CircularProgressIndicator(color: Colors.blue))
            : _data.isEmpty
                ? _buildEmptyState()
                : _buildChart(),
      ),
      // Öğretmen modunda FloatingActionButton gizlenir
      floatingActionButton: _isTeacherMode ? null : FloatingActionButton(
        onPressed: () => _navigateAndAddResult(context),
        backgroundColor: Colors.blue.shade600,
        child: Icon(Icons.add),
        tooltip: 'Deneme Sonucu Ekle',
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined, 
            size: 80,
            color: Colors.blue.shade300,
          ),
          SizedBox(height: 16),
          Text(
            // Öğretmen moduna göre metni özelleştir
            _isTeacherMode
                ? "Öğrenci henüz deneme sonucu eklememiş!"
                : "Henüz deneme sonucu eklenmemiş!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            // Öğretmen moduna göre metni özelleştir
            _isTeacherMode
                ? "Bu öğrenci için deneme sonucu bulunmuyor."
                : "İlk deneme sonucunuzu ekleyin",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          // "Sonuç Ekle" butonunu öğretmen modunda gösterme
          if (!_isTeacherMode) ... [
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("Sonuç Ekle"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                )
              ),
              onPressed: () => _navigateAndAddResult(context),
            )
          ],
        ],
      ),
    );
  }
  
  Widget _buildChart() {
    return Padding(
      key: ValueKey(_data.length), // animasyon için
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      color: Colors.blue.shade700,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _isTeacherMode
                          ? "TYT Deneme Sonuçları"
                          : "TYT Deneme Sonuçları",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    height: _data.length > 8
                        ? MediaQuery.of(context).size.height * (_data.length / 8)
                        : MediaQuery.of(context).size.height - 200,
                    child: SfCartesianChart(
                      title: ChartTitle(
                        text: 'TYT Net Sonuçları',
                        textStyle: TextStyle(fontWeight: FontWeight.bold)
                      ),
                      legend: Legend(
                        isVisible: true,
                        position: LegendPosition.bottom
                      ),
                      primaryXAxis: CategoryAxis(
                        title: AxisTitle(text: 'Tarih'),
                        labelRotation: _data.length > 5 ? 45 : 0,
                      ),
                      primaryYAxis: NumericAxis(
                        edgeLabelPlacement: EdgeLabelPlacement.shift,
                        title: AxisTitle(text: 'Net'),
                        minimum: 0,
                        maximum: 120,
                        interval: 10,
                      ),
                      tooltipBehavior: _tooltipBehavior,
                      series: <CartesianSeries>[
                        BarSeries<DenemeSonucu, String>(
                          dataSource: _data,
                          xValueMapper: (DenemeSonucu deneme, _) => deneme.date,
                          yValueMapper: (DenemeSonucu deneme, _) => deneme.score,
                          name: 'TYT Net',
                          color: Colors.blue.shade500,
                          borderRadius: BorderRadius.circular(4),
                          animationDuration: 700,
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelAlignment: ChartDataLabelAlignment.middle,
                            labelPosition: ChartDataLabelPosition.inside,
                            useSeriesColor: true,
                            builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                              final net = (data as DenemeSonucu).score;
                              if (net != 0) {
                                return Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    net.toStringAsFixed(net % 1 == 0 ? 0 : 2),
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                          width: 0.8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Ek istatistik bilgileri
              if (_data.isNotEmpty) ...[
                Divider(),
                _buildStatisticsRow(),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatisticsRow() {
    // Ortalama, en yüksek ve en düşük puanları hesaplama
    double average = 0;
    double highest = _data.isNotEmpty ? _data.first.score : 0;
    double lowest = _data.isNotEmpty ? _data.first.score : 0;
    
    for (var item in _data) {
      average += item.score;
      if (item.score > highest) highest = item.score;
      if (item.score < lowest) lowest = item.score;
    }
    
    if (_data.isNotEmpty) average = average / _data.length;
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard("Ortalama", average.toStringAsFixed(1), Icons.calculate_outlined, Colors.blue.shade600),
          _buildStatCard("En Yüksek", highest.toStringAsFixed(1), Icons.arrow_upward, Colors.green.shade600),
          _buildStatCard("En Düşük", lowest.toStringAsFixed(1), Icons.arrow_downward, Colors.orange.shade600),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}