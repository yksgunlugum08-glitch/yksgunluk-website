import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:yksgunluk/deneme_charts/ayt_deneme/ders1_ayt.dart';
import 'package:yksgunluk/deneme_charts/ayt_deneme/sonuc_sayfasi.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/tyt_genel.dart';
import 'package:yksgunluk/ekranlar/home_page.dart';
import 'package:yksgunluk/ogretmen/ogrencilerim.dart';
import 'package:yksgunluk/teacher_mode.dart';

class AYTDenemeSonuclarim extends StatefulWidget {
  @override
  _AYTDenemeSonuclarimState createState() => _AYTDenemeSonuclarimState();
}

class _AYTDenemeSonuclarimState extends State<AYTDenemeSonuclarim> with SingleTickerProviderStateMixin {
  List<DenemeSonucu> _data = [];
  bool _isLoading = true;
  late TabController _tabController;
  bool _isTYTSelected = false;
  late TooltipBehavior _tooltipBehavior;
  
  // Öğretmen modu için getter'lar
  bool get _isTeacherMode => Provider.of<TeacherModeProvider>(context, listen: false).isTeacherMode;
  String? get _studentId => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentId;
  String? get _studentName => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _tooltipBehavior = TooltipBehavior(enable: true);
    _loadData();
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isTYTSelected = _tabController.index == 0;
        });
        
        if (_isTYTSelected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TYTDenemeSonuclarim()),
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
    
    String userId;
    
    if (_isTeacherMode) {
      userId = _studentId ?? '';
      if (userId.isEmpty) {
        setState(() {
          _data = [];
          _isLoading = false;
        });
        return;
      }
    } else {
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
          .collection('aytDenemeSonuclari')
          .orderBy('timestamp', descending: true)
          .get();

      List<DenemeSonucu> results = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Net hesaplaması burada doğru yapılıyor
        double calculatedScore = 0.0;
        
        // Eğer dokümanda 'score' alanı varsa onu kullan
        if (data['score'] != null) {
          calculatedScore = (data['score'] is double) 
              ? data['score'] 
              : (data['score'] as num).toDouble();
        } else {
          // Yoksa dogru/yanlis verilerinden hesapla
          final Map<String, dynamic> dogru = Map<String, dynamic>.from(data['dogru'] ?? {});
          final Map<String, dynamic> yanlis = Map<String, dynamic>.from(data['yanlis'] ?? {});
          
          for (final ders in dogru.keys) {
            final d = (dogru[ders] is int) ? dogru[ders] as int : int.tryParse(dogru[ders].toString()) ?? 0;
            final y = (yanlis[ders] is int) ? yanlis[ders] as int : int.tryParse(yanlis[ders].toString()) ?? 0;
            calculatedScore += d - y / 4.0;
          }
        }
        
        // Sadece geçerli sonuçları listeye ekle (sıfır olanları da dahil et ama negatif olanları filtrele)
        if (calculatedScore >= 0) {
          results.add(DenemeSonucu(
            date: data['date'] ?? '',
            score: calculatedScore,
          ));
        }
      }
      
      setState(() {
        _data = results;
        _isLoading = false;
      });
      
      print("Yüklenen veri sayısı: ${_data.length}"); // Debug için
      _data.forEach((item) => print("Tarih: ${item.date}, Net: ${item.score}")); // Debug için
      
    } catch (e) {
      print("Veri yükleme hatası: $e");
      setState(() {
        _data = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData(DenemeSonucu yeni, Map<String, dynamic> rawJson) async {
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
    
    try {
      // Veritabanına kaydetmeden önce net hesaplamasını doğrula
      double verifiedScore = _calculateNetFromJson(rawJson);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('aytDenemeSonuclari')
          .add({
        'date': yeni.date,
        'score': verifiedScore, // Doğrulanmış skoru kaydet
        'dogru': rawJson['dogru'] ?? {},
        'yanlis': rawJson['yanlis'] ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Verileri yeniden yükle
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deneme sonucu kaydedildi (Net: ${verifiedScore.toStringAsFixed(1)})'),
          backgroundColor: Colors.purple.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print("Kaydetme hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sonuç kaydedilirken bir hata oluştu'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Net hesaplama fonksiyonunu ayrı bir metod haline getir
  double _calculateNetFromJson(Map<String, dynamic> item) {
    final Map<String, dynamic> dogru = Map<String, dynamic>.from(item['dogru'] ?? {});
    final Map<String, dynamic> yanlis = Map<String, dynamic>.from(item['yanlis'] ?? {});
    
    double net = 0.0;
    for (final ders in dogru.keys) {
      final d = (dogru[ders] is int) ? dogru[ders] as int : int.tryParse(dogru[ders].toString()) ?? 0;
      final y = (yanlis[ders] is int) ? yanlis[ders] as int : int.tryParse(yanlis[ders].toString()) ?? 0;
      net += d - y / 4.0;
    }
    
    return net;
  }

  void _navigateAndAddResult(BuildContext context) async {
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
      MaterialPageRoute(builder: (context) => AYTAddResultPage()),
    );
    
    if (result != null && result is Map<String, dynamic>) {
      // Net hesaplamasını doğrula
      double calculatedNet = _calculateNetFromJson(result);
      
      DenemeSonucu yeni = DenemeSonucu(
        date: result['date'] ?? '',
        score: calculatedNet,
      );
      
      print("Yeni eklenen deneme: Tarih: ${yeni.date}, Net: ${yeni.score}"); // Debug için
      
      await _saveData(yeni, result);
    }
  }

  DenemeSonucu _fromAytJson(Map<String, dynamic> item) {
    final String date = item['date'] ?? '';
    double net = _calculateNetFromJson(item);
    return DenemeSonucu(date: date, score: net);
  }

  @override
  Widget build(BuildContext context) {
    final String title = _isTeacherMode 
        ? "${_studentName} - AYT Deneme Sonuçları"
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
                  builder: (context) => AytDersGrafikleriPage(),
                ),
              );
            },
          ),
        ],
        title: Text(
          title, 
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade600,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
            if (_isTeacherMode) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OgrenciListesiSayfasi(),
                ),
              );
            } else {
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
              color: Colors.purple.shade500,
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
                        color: Colors.blue.shade200,
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
                        color: Colors.white,
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
            ? Center(key: ValueKey('loading'), child: CircularProgressIndicator(color: Colors.purple))
            : _data.isEmpty
                ? _buildEmptyState()
                : _buildChart(),
      ),
      floatingActionButton: _isTeacherMode ? null : FloatingActionButton(
        onPressed: () => _navigateAndAddResult(context),
        backgroundColor: Colors.purple.shade600,
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
            color: Colors.purple.shade300,
          ),
          SizedBox(height: 16),
          Text(
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
            _isTeacherMode
                ? "Bu öğrenci için AYT deneme sonucu bulunmuyor."
                : "İlk deneme sonucunuzu ekleyin",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          if (!_isTeacherMode) ... [
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("Sonuç Ekle"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
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
      key: ValueKey(_data.length),
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
                      color: Colors.purple.shade700,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "AYT Deneme Sonuçları (${_data.length} deneme)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
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
                        text: 'AYT Net Sonuçları',
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
                        maximum: 100,
                        interval: 10,
                      ),
                      tooltipBehavior: _tooltipBehavior,
                      series: <CartesianSeries>[
                        BarSeries<DenemeSonucu, String>(
                          dataSource: _data.reversed.toList(),
                          xValueMapper: (DenemeSonucu deneme, _) => deneme.date,
                          yValueMapper: (DenemeSonucu deneme, _) => deneme.score,
                          name: 'AYT Net',
                          color: Colors.purple.shade500,
                          borderRadius: BorderRadius.circular(4),
                          animationDuration: 700,
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelAlignment: ChartDataLabelAlignment.middle,
                            labelPosition: ChartDataLabelPosition.inside,
                            useSeriesColor: true,
                            builder: (dynamic data, dynamic point, dynamic series, int pointIndex, int seriesIndex) {
                              final net = (data as DenemeSonucu).score;
                              return Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  net.toStringAsFixed(net % 1 == 0 ? 0 : 1),
                                  style: TextStyle(
                                    color: Colors.purple.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            },
                          ),
                          width: 0.8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
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
    if (_data.isEmpty) {
      return SizedBox();
    }
    
    // Sadece gerçek verileri kullanarak istatistik hesapla
    List<double> validScores = _data
        .where((item) => item.score >= 0) // Sadece geçerli skorları al
        .map((item) => item.score)
        .toList();
    
    if (validScores.isEmpty) {
      return SizedBox();
    }
    
    double sum = validScores.fold(0.0, (a, b) => a + b);
    double average = sum / validScores.length;
    double highest = validScores.reduce((a, b) => a > b ? a : b);
    double lowest = validScores.reduce((a, b) => a < b ? a : b);
    
    print("İstatistik hesaplama - Geçerli veri sayısı: ${validScores.length}"); // Debug için
    print("Toplam: $sum, Ortalama: $average, En yüksek: $highest, En düşük: $lowest"); // Debug için
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard("Ortalama", average.toStringAsFixed(1), Icons.calculate_outlined, Colors.purple.shade600),
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

class DenemeSonucu {
  final String date;
  final double score;

  DenemeSonucu({
    required this.date,
    required this.score,
  });

  Map<String, dynamic> toAytJson() => {
        'date': date,
        'score': score,
      };
}