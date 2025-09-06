import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yksgunluk/calisma_surem/calisma_surem.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/tyt_genel.dart';
import 'package:yksgunluk/ders_programi/program_tablo.dart';
import 'package:yksgunluk/cozdugun_soru/cozdugum_soru.sayisi.dart';
import 'package:yksgunluk/ogretmen/istatistik.dart';
import 'package:yksgunluk/ogretmen/ogretmen.dart';
import 'package:yksgunluk/teacher_mode.dart';

class OgrenciListesiSayfasi extends StatefulWidget {
  const OgrenciListesiSayfasi({Key? key}) : super(key: key);

  @override
  State<OgrenciListesiSayfasi> createState() => _OgrenciListesiSayfasiState();
}

class _OgrenciListesiSayfasiState extends State<OgrenciListesiSayfasi> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _ogrenciler = [];
  List<Map<String, dynamic>> _tumOgrenciler = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  
  // Açık/kapalı durumu takibi için
  Map<String, bool> _expandedMap = {};
  
  // Filtreleme ve sıralama seçenekleri
  String _selectedSort = 'Çalışma Süresine Göre';
  
  // Genel haftalık istatistikler
  int _totalWeeklyStudy = 0;
  int _bestStudentTime = 0;
  String _bestStudentName = "";
  
  // 🎨 RENK PALETİ - HER ÖĞRENCİ İÇİN CANLI RENKLER
  final List<Color> _studentColors = [
    Color(0xFF1976D2), // Mavi
    Color(0xFF388E3C), // Yeşil
    Color(0xFFFF5722), // Turuncu
    Color(0xFF7B1FA2), // Mor
    Color(0xFF00796B), // Teal
    Color(0xFFE91E63), // Pembe
    Color(0xFF689F38), // Lime
    Color(0xFF512DA8), // Deep purple
    Color(0xFF0288D1), // Light blue
    Color(0xFFF57C00), // Amber
    Color(0xFFD32F2F), // Kırmızı
    Color(0xFF455A64), // Blue grey
  ];
  
  @override
  void initState() {
    super.initState();
    _loadOgrenciler();
  }

  // Dakikayı saat ve dakika formatına çevirme fonksiyonu
  String formatMinutesToHourMinute(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}s ${remainingMinutes}dk';
  }

  Future<void> _loadOgrenciler() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Öğretmenin bağlı olduğu öğrencileri bul
      final QuerySnapshot studentRelations = await _firestore
          .collection('ogretmenOgrenci')
          .where('ogretmenId', isEqualTo: user.uid)
          .where('durum', isEqualTo: 'onaylandı')
          .get();
      
      List<Map<String, dynamic>> studentsList = [];
      int totalStudyTime = 0;
      int bestTime = 0;
      String bestStudent = "";
      
      // Her öğrenci için temel bilgileri ve çalışma verilerini al
      for (var doc in studentRelations.docs) {
        final String ogrenciId = doc['ogrenciId'];
        
        // Öğrenci bilgilerini al
        final DocumentSnapshot studentDoc = await _firestore
            .collection('users')
            .doc(ogrenciId)
            .get();
        
        if (!studentDoc.exists) continue;
        
        Map<String, dynamic> studentData = studentDoc.data() as Map<String, dynamic>;
        
        // Öğrencinin haftalık çalışma verilerini al
        int toplamSure = 0;
        int haftalikTestSure = 0;
        int haftalikKonuSure = 0;
        
        try {
          final testCozmeSurem = (studentData['testCozmeSurem'] as List<dynamic>?) ?? [];
          final konuCalismaSurem = (studentData['konuCalismaSurem'] as List<dynamic>?) ?? [];
          
          haftalikTestSure = testCozmeSurem.isNotEmpty
              ? testCozmeSurem
                  .map((e) => (e is num) ? e.toDouble() : double.tryParse(e.toString()) ?? 0.0)
                  .fold(0.0, (a, b) => a + b)
                  .toInt()
              : 0;
          
          haftalikKonuSure = konuCalismaSurem.isNotEmpty
              ? konuCalismaSurem
                  .map((e) => (e is num) ? e.toDouble() : double.tryParse(e.toString()) ?? 0.0)
                  .fold(0.0, (a, b) => a + b)
                  .toInt()
              : 0;
          
          toplamSure = haftalikTestSure + haftalikKonuSure;
          totalStudyTime += toplamSure;
          
          // En çok çalışan öğrenciyi bul
          if (toplamSure > bestTime) {
            bestTime = toplamSure;
            bestStudent = '${studentData['isim']} ${studentData['soyIsim']}';
          }
        } catch (e) {
          print('Öğrenci çalışma verileri alınırken hata: $e');
        }
        
        // Günlük çalışma süreleri
        List<double> gunlukSureler = List.filled(7, 0);
        try {
          final testCozmeSurem = (studentData['testCozmeSurem'] as List<dynamic>?) ?? [];
          final konuCalismaSurem = (studentData['konuCalismaSurem'] as List<dynamic>?) ?? [];
          
          for (int i = 0; i < 7; i++) {
            double testSure = i < testCozmeSurem.length
                ? (testCozmeSurem[i] is num)
                    ? testCozmeSurem[i].toDouble()
                    : double.tryParse(testCozmeSurem[i].toString()) ?? 0.0
                : 0.0;
            
            double konuSure = i < konuCalismaSurem.length
                ? (konuCalismaSurem[i] is num)
                    ? konuCalismaSurem[i].toDouble()
                    : double.tryParse(konuCalismaSurem[i].toString()) ?? 0.0
                : 0.0;
                
            gunlukSureler[i] = testSure + konuSure;
          }
        } catch (e) {
          print('Günlük çalışma verileri alınırken hata: $e');
        }
        
        // Öğrencinin son aktivite zamanını al
        DateTime? sonAktivite;
        int? cozilenSoru;
        try {
          final QuerySnapshot sonAktiviteSnapshot = await _firestore
              .collection('users')
              .doc(ogrenciId)
              .collection('calismaVerileri')
              .orderBy('tarih', descending: true)
              .limit(1)
              .get();
          
          if (sonAktiviteSnapshot.docs.isNotEmpty) {
            sonAktivite = (sonAktiviteSnapshot.docs.first['tarih'] as Timestamp).toDate();
            cozilenSoru = sonAktiviteSnapshot.docs.first['cozilenSoru'] as int?;
          }
        } catch (e) {
          print('Son aktivite alınırken hata: $e');
        }
        
        String ogrenciKey = ogrenciId;
        _expandedMap[ogrenciKey] = _expandedMap[ogrenciKey] ?? false;
        
        studentsList.add({
          'id': ogrenciId,
          'isim': studentData['isim'] ?? '',
          'soyIsim': studentData['soyIsim'] ?? '',
          'toplamSure': toplamSure,
          'testSure': haftalikTestSure,
          'konuSure': haftalikKonuSure,
          'sonAktivite': sonAktivite,
          'cozilenSoru': cozilenSoru ?? 0,
          'profilUrl': studentData['profilUrl'] ?? '',
          'gunlukSureler': gunlukSureler,
        });
      }
      
      if (!mounted) return;
      
      setState(() {
        _ogrenciler = studentsList;
        _tumOgrenciler = List.from(studentsList);
        _totalWeeklyStudy = totalStudyTime;
        _bestStudentTime = bestTime;
        _bestStudentName = bestStudent;
        _sortList(_selectedSort);
      });
      
    } catch (e) {
      print('Öğrenci listesi yüklenirken hata: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // Listeyi seçilen kritere göre sırala
  void _sortList(String sortCriteria) {
    switch (sortCriteria) {
      case 'Çalışma Süresine Göre':
        _ogrenciler.sort((a, b) => b['toplamSure'].compareTo(a['toplamSure']));
        break;
      case 'İsme Göre':
        _ogrenciler.sort((a, b) => '${a['isim']} ${a['soyIsim']}'.compareTo('${b['isim']} ${b['soyIsim']}'));
        break;
      case 'Son Aktiviteye Göre':
        _ogrenciler.sort((a, b) {
          DateTime? aDate = a['sonAktivite'] as DateTime?;
          DateTime? bDate = b['sonAktivite'] as DateTime?;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        break;
    }
  }
  
  // Filtreleme ve arama kriterlerine göre öğrencileri filtrele
  void _filterStudents() {
    setState(() {
      _ogrenciler = _tumOgrenciler.where((ogrenci) {
        bool matchesSearch = true;
        
        // Arama filtresi
        if (_searchQuery.isNotEmpty) {
          final fullName = '${ogrenci['isim']} ${ogrenci['soyIsim']}'.toLowerCase();
          matchesSearch = fullName.contains(_searchQuery.toLowerCase());
        }
        
        return matchesSearch;
      }).toList();
      
      // Filtreden sonra yeniden sırala
      _sortList(_selectedSort);
    });
  }

  // Öğrencinin durumunu değiştir (açık/kapalı)
  void _toggleExpanded(String studentId) {
    setState(() {
      _expandedMap[studentId] = !(_expandedMap[studentId] ?? false);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Öğrencilerim', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => OgretmenPaneli())
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Arama çubuğu
                _buildSearchBar(),
                
                // Özet bilgiler
                if (_ogrenciler.isNotEmpty)
                  _buildSummaryCard(isSmallScreen),
                
                // Öğrenci listesi
                Expanded(
                  child: _ogrenciler.isEmpty
                      ? _buildEmptyState()
                      : _buildOgrenciList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadOgrenciler,
        backgroundColor: Colors.blue.shade700,
        child: Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildSummaryCard(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Haftalık Özet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'Toplam Çalışma',
                formatMinutesToHourMinute(_totalWeeklyStudy),
                Colors.blue,
                Icons.timer,
                isSmallScreen,
              ),
              _buildSummaryItem(
                'Öğrenci Sayısı',
                '${_ogrenciler.length}',
                Colors.green,
                Icons.people,
                isSmallScreen,
              ),
              _buildSummaryItem(
                'En Çok Çalışan',
                _bestStudentName.isNotEmpty ? '${_bestStudentName.split(' ')[0]}' : '-',
                Colors.amber.shade700,
                Icons.emoji_events,
                isSmallScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, Color color, IconData icon, bool isSmallScreen) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
            SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: Colors.grey.shade700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Öğrenci Ara',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.blue.shade700),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _filterStudents();
        },
      ),
    );
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.blue.shade700, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Sıralama Seçenekleri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // Sıralama filtresi
              Text(
                'Sıralama:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down),
                    items: <String>[
                      'Çalışma Süresine Göre',
                      'İsme Göre',
                      'Son Aktiviteye Göre',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      Navigator.pop(context);
                      setState(() {
                        _selectedSort = newValue!;
                      });
                      _sortList(_selectedSort);
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedSort = 'Çalışma Süresine Göre';
                      });
                      _ogrenciler = List.from(_tumOgrenciler);
                      _sortList(_selectedSort);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                    child: Text('Sıfırla'),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Tamam'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline, 
            size: 80, 
            color: Colors.grey.shade400
          ),
          SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Aramanızla eşleşen öğrenci bulunamadı'
                : 'Henüz öğrenciniz bulunmuyor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'Farklı bir isim ile arayın'
                  : 'Öğrencileriniz size mentor isteği gönderdikten ve siz kabul ettikten sonra burada görünecektir.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOgrenciList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _ogrenciler.length,
      itemBuilder: (context, index) {
        final ogrenci = _ogrenciler[index];
        // 🎨 HER ÖĞRENCİYE CANLI RENK ATAMASINI YAP
        final Color cardColor = _studentColors[index % _studentColors.length];
        return _buildOgrenciExpandableCard(ogrenci, cardColor);
      },
    );
  }
  
  // 🎨 Yeni açılabilir/kapanabilir öğrenci kartı - CANLI RENKLİ VERSİYON
  Widget _buildOgrenciExpandableCard(Map<String, dynamic> ogrenci, Color cardColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final String studentId = ogrenci['id'];
    final bool isExpanded = _expandedMap[studentId] ?? false;
    
    // Son aktivite bilgisini formatla
    String sonAktiviteText = 'Henüz çalışma yok';
    if (ogrenci['sonAktivite'] != null) {
      final now = DateTime.now();
      final sonAktivite = ogrenci['sonAktivite'] as DateTime;
      final difference = now.difference(sonAktivite);
      
      if (difference.inMinutes < 60) {
        sonAktiviteText = '${difference.inMinutes} dakika önce';
      } else if (difference.inHours < 24) {
        sonAktiviteText = '${difference.inHours} saat önce';
      } else if (difference.inDays < 7) {
        sonAktiviteText = '${difference.inDays} gün önce';
      } else {
        sonAktiviteText = DateFormat('dd MMMM', 'tr_TR').format(sonAktivite);
      }
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor, // 🎨 CANLI RENK UYGULANIR
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Öğrenci bilgileri (her zaman görünür)
            InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => _toggleExpanded(studentId),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profil resmi veya baş harfler
                    ogrenci['profilUrl'] != null && ogrenci['profilUrl'].toString().isNotEmpty
                        ? CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(ogrenci['profilUrl']),
                          )
                        : CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            child: Text(
                              '${ogrenci['isim'][0]}${ogrenci['soyIsim'][0]}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white, // 🎨 BEYAZ YAZI
                              ),
                            ),
                          ),
                    SizedBox(width: 16),
                    // Öğrenci bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ogrenci['isim']} ${ogrenci['soyIsim']}',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // 🎨 BEYAZ YAZI
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.access_time, color: Colors.white70, size: isSmallScreen ? 14 : 16), // 🎨 BEYAZ İKON
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Son aktivite: $sonAktiviteText',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14, 
                                    color: Colors.white70, // 🎨 BEYAZ YAZI
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Genişlet/daralt ikonu
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white, // 🎨 BEYAZ İKON
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Açılabilir/kapanabilir bölüm
            AnimatedCrossFade(
              firstChild: SizedBox(height: 0),
              secondChild: _buildExpandedContent(ogrenci, isSmallScreen, cardColor),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
  
  // 🎨 Açıldığında görünecek içerik - CANLI RENKLİ VERSİYON
  Widget _buildExpandedContent(Map<String, dynamic> ogrenci, bool isSmallScreen, Color cardColor) {
    final String studentId = ogrenci['id'];
    final String studentName = '${ogrenci['isim']} ${ogrenci['soyIsim']}';
    
    return Column(
      children: [
        Divider(height: 0, thickness: 1, color: Colors.white.withOpacity(0.3)), // 🎨 BEYAZ DİVİDER
        
        // Çalışma istatistikleri
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1), // 🎨 HAFIF TRANSPARAN SİYAH ARKA PLAN
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(15),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Bu Haftanın Çalışma İstatistikleri',
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // 🎨 BEYAZ YAZI
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Toplam', 
                    formatMinutesToHourMinute(ogrenci['toplamSure']), 
                    Colors.white, // 🎨 BEYAZ YAZI
                    isSmallScreen
                  ),
                  _buildStatColumn(
                    'Test', 
                    formatMinutesToHourMinute(ogrenci['testSure']), 
                    Colors.white, // 🎨 BEYAZ YAZI
                    isSmallScreen
                  ),
                  _buildStatColumn(
                    'Konu', 
                    formatMinutesToHourMinute(ogrenci['konuSure']), 
                    Colors.white, // 🎨 BEYAZ YAZI
                    isSmallScreen
                  ),
                ],
              ),
              // Haftanın en çok çalışılan günü
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 16), // 🎨 BEYAZ İKON
                  SizedBox(width: 4),
                  Text(
                    'En çok ${_findMostStudiedDay(ogrenci['gunlukSureler'])}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70, // 🎨 BEYAZ YAZI
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Menü düğmeleri
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            children: [
              _buildMenuButton(
                title: 'Ders Programı',
                icon: Icons.calendar_today,
                onTap: () {
                  _navigateToDersProgrami(context, studentId, studentName);
                },
              ),
              SizedBox(height: 10),
              _buildMenuButton(
                title: 'Çözdüğü Sorular',
                icon: Icons.question_answer,
                onTap: () {
                  _navigateToQuestionDetails(context, studentId, studentName);
                },
              ),
              SizedBox(height: 10),
              _buildMenuButton(
                title: 'Çalışma Süresi',
                icon: Icons.bar_chart,
                onTap: () {
                  _navigateToStudentChart(
                    context,
                    studentId,
                    studentName,
                  );
                },
              ),
              SizedBox(height: 10),
              _buildMenuButton(
                title: 'Denemeler',
                icon: Icons.assignment,
                onTap: () {
                  _navigateToExamResults(context, studentId, studentName);
                },
              ),
              SizedBox(height: 10),
              _buildMenuButton(
                title: 'İstatistikler',
                icon: Icons.analytics,
                onTap: () {
                  _navigateToStudentStatistics(context, studentId, studentName);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 🎯 YENİ İSTATİSTİKLER SAYFASINA YÖNLENDİRME
  void _navigateToStudentStatistics(BuildContext context, String studentId, String studentName) {
      
    Navigator.push(
    context,
     MaterialPageRoute(builder: (context) => StudentStatisticsPage(studentId: studentId, studentName: studentName)),
   );
  }
  
  // 🎨 Menü butonu widget'ı - CANLI RENKLİ VERSİYON
  Widget _buildMenuButton({
    required String title, 
    required IconData icon, 
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2), // 🎨 TRANSPARAN BEYAZ ARKA PLAN
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)), // 🎨 BEYAZ BORDER
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white), // 🎨 BEYAZ İKON
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // 🎨 BEYAZ YAZI
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16), // 🎨 BEYAZ İKON
          ],
        ),
      ),
    );
  }
  
  // Deneme sonuçları sayfasına yönlendirme
  void _navigateToExamResults(BuildContext context, String studentId, String studentName) {
    final teacherMode = Provider.of<TeacherModeProvider>(context, listen: false);
    teacherMode.setTeacherMode(true, studentId: studentId, studentName: studentName);
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TYTDenemeSonuclarim()),
    );
  }
  
  // Çözdüğü sorular sayfasına yönlendirme
  void _navigateToQuestionDetails(BuildContext context, String studentId, String studentName) {
    final teacherMode = Provider.of<TeacherModeProvider>(context, listen: false);
    teacherMode.setTeacherMode(true, studentId: studentId, studentName: studentName);
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CozdugumSoruSayisiEkrani()),
    );
  }
  
  // Ders programı sayfasına yönlendirme
  void _navigateToDersProgrami(BuildContext context, String studentId, String studentName) {
    final teacherMode = Provider.of<TeacherModeProvider>(context, listen: false);
    teacherMode.setTeacherMode(true, studentId: studentId, studentName: studentName);
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DersProgrami()),
    );
  }
  
  String _findMostStudiedDay(List<dynamic> gunlukSureler) {
    if (gunlukSureler.isEmpty) return "çalışma yok";
    
    List<String> days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    int maxIndex = 0;
    double maxValue = 0;
    
    for (int i = 0; i < gunlukSureler.length; i++) {
      double value = gunlukSureler[i] is num 
          ? gunlukSureler[i].toDouble() 
          : double.tryParse(gunlukSureler[i].toString()) ?? 0.0;
          
      if (value > maxValue) {
        maxValue = value;
        maxIndex = i;
      }
    }
    
    if (maxValue == 0) return "çalışma yok";
    return '${days[maxIndex]} günü çalışmış';
  }
  
  // 🎨 İstatistik sütunu - BEYAZ YAZI VERSİYONU
  Widget _buildStatColumn(String title, String value, Color color, bool isSmallScreen) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            fontWeight: FontWeight.w500,
            color: color.withOpacity(0.8), // 🎨 BEYAZ YAZI
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: color, // 🎨 BEYAZ YAZI
          ),
        ),
      ],
    );
  }
  
  // Öğrenci çalışma grafiği sayfasına gitmek için kullanılan fonksiyon
  void _navigateToStudentChart(BuildContext context, String studentId, String studentName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalismaSurem(
          studentId: studentId,
          studentName: studentName,
        ),
      ),
    );
  }
}