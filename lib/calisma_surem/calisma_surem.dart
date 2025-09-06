import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:yksgunluk/ekranlar/home_page.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;



// Ders bazlı test çözme sürelerini tutacak model sınıfı - kategori eklendi
class TestDersi {
  final String id;
  final String ad;
  final String kategori; // 'TYT' veya 'AYT'
  double dakika;

  TestDersi({
    required this.id,
    required this.ad,
    required this.kategori,
    this.dakika = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ad': ad,
      'kategori': kategori,
      'dakika': dakika,
    };
  }

  factory TestDersi.fromMap(Map<String, dynamic> map) {
    return TestDersi(
      id: map['id'] ?? '',
      ad: map['ad'] ?? '',
      kategori: map['kategori'] ?? 'TYT',
      dakika: (map['dakika'] ?? 0).toDouble(),
    );
  }
}

// Kullanıcı bölümüne göre AYT derslerini döndüren fonksiyon
Future<List<TestDersi>> getAYTDersleri() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return [];

  try {
    final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

    if (doc.exists) {
      String bolum = doc['selectedBolum'] ?? 'Sayısal';
      
      switch(bolum) {
        case 'Sayısal':
          return [
            TestDersi(id: 'matematik_ayt', ad: 'Matematik', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'fizik', ad: 'Fizik', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'kimya', ad: 'Kimya', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'biyoloji', ad: 'Biyoloji', kategori: 'AYT', dakika: 0),
          ];
        case 'Eşit Ağırlık':
          return [
            TestDersi(id: 'matematik_ayt', ad: 'Matematik', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'edebiyat', ad: 'Edebiyat', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'tarih', ad: 'Tarih', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'cografya', ad: 'Coğrafya', kategori: 'AYT', dakika: 0),
          ];
        case 'Sözel':
          return [
            TestDersi(id: 'edebiyat', ad: 'Edebiyat', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'felsefe', ad: 'Felsefe', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'tarih', ad: 'Tarih', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'cografya', ad: 'Coğrafya', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'din', ad: 'Din', kategori: 'AYT', dakika: 0),
          ];
        default:
          return [
            TestDersi(id: 'matematik_ayt', ad: 'Matematik', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'fizik', ad: 'Fizik', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'kimya', ad: 'Kimya', kategori: 'AYT', dakika: 0),
            TestDersi(id: 'biyoloji', ad: 'Biyoloji', kategori: 'AYT', dakika: 0),
          ];
      }
    }
    
    // Varsayılan olarak sayısal dersleri döndür
    return [
      TestDersi(id: 'matematik_ayt', ad: 'Matematik', kategori: 'AYT', dakika: 0),
      TestDersi(id: 'fizik', ad: 'Fizik', kategori: 'AYT', dakika: 0),
      TestDersi(id: 'kimya', ad: 'Kimya', kategori: 'AYT', dakika: 0),
      TestDersi(id: 'biyoloji', ad: 'Biyoloji', kategori: 'AYT', dakika: 0),
    ];
  } catch (e) {
    print('AYT dersleri alınırken hata: $e');
    return [];
  }
}

// TYT dersleri (herkes için sabit)
List<TestDersi> getTYTDersleri() {
  return [
    TestDersi(id: 'turkce', ad: 'Türkçe', kategori: 'TYT', dakika: 0),
    TestDersi(id: 'matematik_tyt', ad: 'Matematik', kategori: 'TYT', dakika: 0),
    TestDersi(id: 'sosyal', ad: 'Sosyal', kategori: 'TYT', dakika: 0),
    TestDersi(id: 'fen', ad: 'Fen', kategori: 'TYT', dakika: 0),
  ];
}

// Varsayılan ders listesini döndüren fonksiyon (TYT ve AYT dahil)
Future<List<TestDersi>> varsayilanDersListesi() async {
  List<TestDersi> dersler = getTYTDersleri();
  List<TestDersi> aytDersleri = await getAYTDersleri();
  dersler.addAll(aytDersleri);
  return dersler;
}

// Belirli bir gün için ders bazlı test sürelerini kaydet
Future<void> dersBazliTestSuresiKaydet(String userId, int dayIndex, List<TestDersi> dersler) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  DateTime now = DateTime.now();
  DateTime monday = now.subtract(Duration(days: now.weekday - 1));
  DateTime targetDate = monday.add(Duration(days: dayIndex));
  
  // Ders bazlı verileri kaydet
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('dersTestVerileri')
      .doc(DateFormat('yyyy-MM-dd').format(targetDate))
      .set({
    'tarih': Timestamp.fromDate(targetDate),
    'gunIndex': dayIndex,
    'dersler': dersler.map((d) => d.toMap()).toList(),
    'toplamTestSuresi': dersler.fold(0.0, (sum, ders) => sum + ders.dakika),
    'guncellenmeTarihi': Timestamp.now(),
  }, SetOptions(merge: true));
}

// Belirli bir gün için ders bazlı test sürelerini getir
Future<List<TestDersi>> dersBazliTestSuresiGetir(String userId, int dayIndex) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return await varsayilanDersListesi();

  DateTime now = DateTime.now();
  DateTime monday = now.subtract(Duration(days: now.weekday - 1));
  DateTime targetDate = monday.add(Duration(days: dayIndex));
  
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('dersTestVerileri')
        .doc(DateFormat('yyyy-MM-dd').format(targetDate))
        .get();
    
    if (doc.exists && doc.data()!.containsKey('dersler')) {
      List<dynamic> dersVerileri = doc.data()!['dersler'];
      return dersVerileri.map((veri) => TestDersi.fromMap(veri)).toList();
    }
    
    return await varsayilanDersListesi();
  } catch (e) {
    print('Ders verileri alınırken hata: $e');
    return await varsayilanDersListesi();
  }
}

Future<void> checkAndResetWeekAndCharts() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final data = (await userDoc.get()).data() ?? {};

  DateTime now = DateTime.now();
  DateTime currentMonday = now.subtract(Duration(days: now.weekday - 1));
  DateTime lastResetDate = data['lastCalismaResetDate'] != null
      ? DateTime.tryParse(data['lastCalismaResetDate']) ?? DateTime(2000)
      : DateTime(2000);

  if (now.weekday == DateTime.monday) {
    final thisMonday = DateTime(now.year, now.month, now.day);

    if (lastResetDate.isBefore(thisMonday)) {
      List testList = data['testCozmeSurem'] ?? [];
      List konuList = data['konuCalismaSurem'] ?? [];
      int currentTestSure = testList.isNotEmpty
          ? testList
              .map((e) => (e is num ? e : double.tryParse(e.toString()) ?? 0.0))
              .fold(0.0, (a, b) => a + b)
              .toInt()
          : 0;
      int currentKonuSure = konuList.isNotEmpty
          ? konuList
              .map((e) => (e is num ? e : double.tryParse(e.toString()) ?? 0.0))
              .fold(0.0, (a, b) => a + b)
              .toInt()
          : 0;

      DateTime weekStart = lastResetDate.isAfter(DateTime(2001))
          ? lastResetDate
          : thisMonday.subtract(const Duration(days: 7));

      await userDoc.collection('weeksData').add({
        'start': weekStart.millisecondsSinceEpoch,
        'end': weekStart.add(const Duration(days: 6)).millisecondsSinceEpoch,
        'test': currentTestSure,
        'konu': currentKonuSure,
      });

      // Haftalık verileri sıfırla
      await userDoc.set({
        'testCozmeSurem': List.filled(7, 0.0),
        'konuCalismaSurem': List.filled(7, 0.0),
        'currentWeekStart': thisMonday.millisecondsSinceEpoch,
        'lastCalismaResetDate': thisMonday.toIso8601String(),
      }, SetOptions(merge: true));

      // Öğretmen görünümü için geçen haftanın özet verilerini calismaVerileri koleksiyonuna ekle
      await userDoc.collection('calismaVerileri').add({
        'tarih': Timestamp.now(),
        'calismaSuresi': currentTestSure + currentKonuSure,
        'cozilenSoru': 0,
        'testSuresi': currentTestSure,
        'konuSuresi': currentKonuSure,
        'notlar': 'Haftalık otomatik sıfırlama sonrası özet veri',
        'haftaBaslangic': weekStart.millisecondsSinceEpoch,
        'haftaBitis': weekStart.add(const Duration(days: 6)).millisecondsSinceEpoch,
      });
    }
  }
}

Future<void> updateCurrentWeekData(List<double> testCozmeSurem,
    List<double> konuCalismaSurem, String? userId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Güncellenecek kullanıcı ID'si (öğretmen görüntülüyorsa öğrenci ID'si, öğrenci kendi verilerini görüntülüyorsa kendi ID'si)
  final String targetUserId = userId ?? user.uid;

  DateTime now = DateTime.now();
  DateTime monday = now.subtract(Duration(days: now.weekday - 1));
  await FirebaseFirestore.instance
      .collection('users')
      .doc(targetUserId)
      .collection('currentWeekData')
      .doc('data')
      .set({
    'start': monday.millisecondsSinceEpoch,
    'end': monday.add(const Duration(days: 6)).millisecondsSinceEpoch,
    'test': testCozmeSurem.fold<double>(0.0, (a, b) => a + b).round(),
    'konu': konuCalismaSurem.fold<double>(0.0, (a, b) => a + b).round(),
  }, SetOptions(merge: true));
}

Future<void> saveDailyData(String userId, int dayIndex, double testTime, double konuTime) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  DateTime now = DateTime.now();
  DateTime monday = now.subtract(Duration(days: now.weekday - 1));
  DateTime targetDate = monday.add(Duration(days: dayIndex));
  
  // Günlük veriyi ayrı bir koleksiyona kaydet
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('dailyStudyData')
      .doc(DateFormat('yyyy-MM-dd').format(targetDate))
      .set({
    'tarih': Timestamp.fromDate(targetDate),
    'testSuresi': testTime,
    'konuSuresi': konuTime,
    'toplamSure': testTime + konuTime,
    'gunIndex': dayIndex, // 0: Pazartesi, 6: Pazar
    'haftalikTarih': DateFormat('dd.MM.yyyy').format(targetDate),
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  }, SetOptions(merge: true));
}

class CalismaSurem extends StatefulWidget {
  final String? studentId; // Öğretmenin görüntülediği öğrencinin ID'si
  final String? studentName; // Öğrencinin adı
  final bool? isTeacher = false; // Varsayılan değeri false

  const CalismaSurem({
    Key? key,
    this.studentId,
    this.studentName,
  }) : super(key: key);

  @override
  State<CalismaSurem> createState() => _CalismaSuremState();
}

class _CalismaSuremState extends State<CalismaSurem> {
  bool _isLoading = true;
  bool _isTeacher = false;
  List<Map<String, dynamic>> _students = [];
  String? _selectedStudentId;
  String? _selectedStudentName;
  bool? isTeacher; // Yeni eklenen parametre

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    // Öğrenci ID'si dışarıdan verilmişse (öğretmen tarafından tıklandıysa)
    if (widget.studentId != null && widget.studentName != null) {
      setState(() {
        _isTeacher = true;
        _selectedStudentId = widget.studentId;
        _selectedStudentName = widget.studentName;
      });
    } else {
      // Kullanıcı tipini kontrol et
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('userType') ?? '';

      if (userType == 'teacher') {
        setState(() => _isTeacher = true);
        await _loadStudents();
      }
    }

    // Öğretmen ise öğrenci seçili olmadan sayfa yükleme işlemini tamamla
    if (_isTeacher && _selectedStudentId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Veri sıfırlama ve sayfa yükleme
    await checkAndResetWeekAndCharts();
    setState(() => _isLoading = false);
  }

  // Mentorluğu olan öğrencileri yükle
  Future<void> _loadStudents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Öğretmenin bağlı olduğu öğrencileri bul
      final QuerySnapshot studentRelations = await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .where('ogretmenId', isEqualTo: user.uid)
          .where('durum', isEqualTo: 'onaylandı')
          .get();

      List<Map<String, dynamic>> studentsList = [];

      // Her öğrenci için temel bilgileri al
      for (var doc in studentRelations.docs) {
        final String ogrenciId = doc['ogrenciId'];

        // Öğrenci bilgilerini al
        final DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(ogrenciId)
            .get();

        if (studentDoc.exists) {
          Map<String, dynamic> studentData =
              studentDoc.data() as Map<String, dynamic>;

          studentsList.add({
            'id': ogrenciId,
            'isim': studentData['isim'] ?? '',
            'soyIsim': studentData['soyIsim'] ?? '',
            'sinif': studentData['sinif'] ?? '',
          });
        }
      }

      if (!mounted) return;

      // İsme göre alfabetik sırala
      studentsList.sort((a, b) => '${a['isim']} ${a['soyIsim']}'
          .compareTo('${b['isim']} ${b['soyIsim']}'));

      setState(() => _students = studentsList);
    } catch (e) {
      print('Öğrenci listesi yüklenirken hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium kısıtlaması tamamen kaldırıldı - doğrudan içeriği göster
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.studentId != null && widget.studentName != null
              ? '${widget.studentName} - Çalışma Süreleri'
              : 'Çalışma Sürem',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Eğer studentId parametresi verilmişse, bu öğretmen görünümü demektir
            if (widget.studentId != null) {
              Navigator.pop(context);
            } 
            // Öğrenci kendi sayfasında
            else {
              Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => AnaEkran())
              );
            }
          },
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          if (widget.studentId == null) // Sadece öğrenci kendi sayfasındayken görünsün
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () async {
                setState(() => _isLoading = true);
                await checkAndResetWeekAndCharts();
                setState(() => _isLoading = false);
              },
            ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _isTeacher && _selectedStudentId == null
              ? _buildStudentSelectionScreen()
              : StudyTimeChart(
                  studentId: _selectedStudentId, isTeacher: _isTeacher),
    );
  }

  // Öğretmenler için öğrenci seçme ekranı
  Widget _buildStudentSelectionScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade100.withOpacity(0.5), Colors.white],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 2)
                    ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school,
                            color: Colors.blue.shade700, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Öğrenci Seçin',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Çalışma sürelerini görmek istediğiniz öğrenciyi seçin',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _students.isEmpty
                  ? _buildEmptyStudentView()
                  : _buildStudentList(),
            ),
          ],
        ),
      ),
    );
  }

  // Öğrenci olmadığında gösterilecek mesaj
  Widget _buildEmptyStudentView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 80, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            'Mentoru olduğunuz öğrenci bulunamadı',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Öğrencileriniz size mentor isteği gönderdikten ve siz kabul ettikten sonra burada görünecektir.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStudents,
            icon: Icon(Icons.refresh),
            label: Text('Yenile', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // Öğrenci listesi
  Widget _buildStudentList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CalismaSurem(
                            studentId: student['id'],
                            studentName:
                                '${student['isim']} ${student['soyIsim']}',
                          )));
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    radius: 30,
                    child: Text(
                      '${student['isim'][0]}${student['soyIsim'][0]}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${student['isim']} ${student['soyIsim']}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800),
                        ),
                        SizedBox(height: 4),
                        Text(
                          student['sinif'] != null &&
                                  student['sinif'].toString().isNotEmpty
                              ? '${student['sinif']}. Sınıf'
                              : 'Sınıf bilgisi yok',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.blue.shade700),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                  _isTeacher ? 'Öğretmen Bilgilendirme' : 'Nasıl Kullanılır?',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _isTeacher
              ? [
                  _buildInfoItem(Icons.visibility,
                      'Öğrencilerin haftalık çalışma verilerini görüntüleyebilirsiniz'),
                  _buildInfoItem(Icons.history,
                      'Veriler her Pazartesi günü otomatik olarak sıfırlanır'),
                  _buildInfoItem(Icons.bar_chart,
                      'Üç farklı renkteki çizgi öğrencinin çalışma türlerini gösterir'),
                  _buildInfoItem(Icons.assessment,
                      'Haftalık ortalama ve en çok çalışılan günleri analiz edebilirsiniz'),
                ]
              : [
                  _buildInfoItem(Icons.touch_app,
                      'Gün isimlerine tıklayarak veri girebilirsiniz'),
                  _buildInfoItem(Icons.schedule,
                      'Saatleri "saat:dakika" formatında girin (örn: 02:30)'),
                  _buildInfoItem(
                      Icons.bar_chart, 'Üç çizgi çalışma türlerinizi gösterir'),
                  _buildInfoItem(Icons.refresh,
                      'Her Pazartesi günü veriler otomatik sıfırlanır'),
                  _buildInfoItem(Icons.school,
                      'Test çözme sürelerinizi TYT ve AYT dersleri için ayrı ayrı girebilirsiniz'),
                ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              textStyle: TextStyle(fontSize: 16),
            ),
            child: Text('Anladım'),
          )
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.blue.shade700),
          SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}

// Ders bazlı test süre girişi için widget - Yeniden düzenlenmiş yan yana tasarım

class DersSecimWidget extends StatefulWidget {
  final int gunIndex;
  final Function(double) toplamSureDegisti;
  
  const DersSecimWidget({
    Key? key, 
    required this.gunIndex,
    required this.toplamSureDegisti,
  }) : super(key: key);

  @override
  _DersSecimWidgetState createState() => _DersSecimWidgetState();
}

class _DersSecimWidgetState extends State<DersSecimWidget> {
  List<TestDersi> _dersler = [];
  bool _yukleniyor = true;
  double _toplamSure = 0.0;
  bool _tytSelected = true; // TYT seçili mi (false ise AYT seçili)
  
  @override
  void initState() {
    super.initState();
    _dersleriYukle();
  }
  
  Future<void> _dersleriYukle() async {
    setState(() => _yukleniyor = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _dersler = [];
        _yukleniyor = false;
      });
      return;
    }
    
    try {
      _dersler = await dersBazliTestSuresiGetir(user.uid, widget.gunIndex);
      _toplamSureHesapla();
      
      if (!mounted) return;
      setState(() => _yukleniyor = false);
    } catch (e) {
      print('Dersler yüklenirken hata: $e');
      if (!mounted) return;
      setState(() {
        _dersler = [];
        _yukleniyor = false;
      });
    }
  }
  
  void _toplamSureHesapla() {
    _toplamSure = _dersler.fold(0.0, (sum, ders) => sum + ders.dakika);
    widget.toplamSureDegisti(_toplamSure);
  }
  
  Future<void> _dersleriKaydet() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await dersBazliTestSuresiKaydet(user.uid, widget.gunIndex, _dersler);
      _toplamSureHesapla();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ders test süreleri kaydedildi', style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        )
      );
    } catch (e) {
      print('Ders verileri kaydedilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ders verileri kaydedilirken hata oluştu', style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        )
      );
    }
  }
  
  void _dersSuresiDuzenleDialogGoster(TestDersi ders) {
    final TextEditingController controller = TextEditingController(
      text: _dakikayiSaatDakikaFormatinaDonustur(ders.dakika)
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('${ders.ad} Test Süresi'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Süre (saat:dakika)',
            hintText: '01:30',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.datetime,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_gecerliZamanFormatiMi(controller.text)) {
                setState(() {
                  ders.dakika = _zamanFormatiniDakikayaDonustur(controller.text).toDouble();
                  _toplamSureHesapla();
                });
                _dersleriKaydet();
                Navigator.pop(context);
              } else {
                _gecersizGirisUyarisiGoster();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: Text('Kaydet'),
          ),
        ],
      ),
    );
  }
  
  String _dakikayiSaatDakikaFormatinaDonustur(double dakika) {
    final hours = (dakika ~/ 60).toString().padLeft(2, '0');
    final mins = (dakika % 60).toInt().toString().padLeft(2, '0');
    return '$hours:$mins';
  }
  
  bool _gecerliZamanFormatiMi(String value) {
    if (value.isEmpty) return true;
    final parts = value.split(':');
    if (parts.length == 1) {
      final hours = int.tryParse(parts[0]);
      return hours != null && hours >= 0 && hours <= 24;
    } else if (parts.length == 2) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      return hours != null &&
          minutes != null &&
          hours >= 0 &&
          hours <= 24 &&
          minutes >= 0 &&
          minutes < 60;
    }
    return false;
  }
  
  int _zamanFormatiniDakikayaDonustur(String time) {
    if (time.isEmpty) return 0;
    final parts = time.split(':');
    if (parts.length == 1) {
      return (int.tryParse(parts[0]) ?? 0) * 60;
    } else if (parts.length == 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      return hours * 60 + minutes;
    }
    return 0;
  }
  
  void _gecersizGirisUyarisiGoster() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Geçersiz Giriş'),
        content: Text('Lütfen geçerli bir saat formatı girin (ör: 01:30)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return Center(child: CircularProgressIndicator());
    }

    // TYT ve AYT derslerini ayır
    List<TestDersi> tytDersler = _dersler.where((d) => d.kategori == 'TYT').toList();
    List<TestDersi> aytDersler = _dersler.where((d) => d.kategori == 'AYT').toList();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve toplam süre
          Row(
            children: [
              Icon(Icons.school, color: Colors.blue.shade700, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Test Süreleri - Ders Bazlı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Toplam: ${_dakikayiSaatDakikaFormatinaDonustur(_toplamSure)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // TYT ve AYT başlıkları yan yana
          Row(
            children: [
              // TYT Başlık - Sola yaslı
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tytSelected = true),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _tytSelected 
                          ? Colors.blue.shade700 
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school, 
                          color: _tytSelected ? Colors.white : Colors.grey.shade700, 
                          size: 18
                        ),
                        SizedBox(width: 8),
                        Text(
                          'TYT',
                          style: TextStyle(
                            color: _tytSelected ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // AYT Başlık - Sağa yaslı
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tytSelected = false),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_tytSelected 
                          ? Colors.blue.shade700 
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment, 
                          color: !_tytSelected ? Colors.white : Colors.grey.shade700,
                          size: 18
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AYT',
                          style: TextStyle(
                            color: !_tytSelected ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // İçerik bölümü - Aktif sekmeye göre TYT veya AYT içeriği göster
         AnimatedSwitcher(
  duration: Duration(milliseconds: 300),
  child: _tytSelected
      ? _buildDerslerListesi(tytDersler, false) // TYT dersleri - sola yaslı
      : _buildDerslerListesi(aytDersler, true),  // AYT dersleri - sağa yaslı
),
          
          SizedBox(height: 8),
          Center(
            child: Text(
              'Ders kartlarına tıklayarak süre girebilirsiniz',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
   // Ders listesini oluştur - hizalama parametresi ile
Widget _buildDerslerListesi(List<TestDersi> dersler, bool isSagaYasli) {
  if (dersler.isEmpty) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Text(
        _tytSelected ? 'TYT dersleri bulunamadı' : 'AYT dersleri bulunamadı',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 16,
        ),
      ),
    );
  }
  
  return Container(
    key: ValueKey<String>(_tytSelected ? 'tyt' : 'ayt'), // AnimatedSwitcher için key
    constraints: BoxConstraints(
      minHeight: 100,
      maxHeight: 300,
    ),
    width: double.infinity,
    child: SingleChildScrollView(
      child: Align(
        // Sağa veya sola hizalama için
        alignment: isSagaYasli ? Alignment.centerRight : Alignment.centerLeft,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: dersler.map((ders) => _buildDersCard(ders)).toList(),
        ),
      ),
    ),
  );
}
  
  // Ders kartını oluştur
  Widget _buildDersCard(TestDersi ders) {
    final Color cardColor = ders.dakika > 0 
                        ? Colors.green.shade50 
                        : Colors.grey.shade100;
    final Color borderColor = ders.dakika > 0 
                        ? Colors.green.shade300 
                        : Colors.grey.shade300;
    final Color textColor = ders.dakika > 0 
                        ? Colors.green.shade700 
                        : Colors.grey.shade700;
    
    return Container(
      width: 110, // Sabit genişlik
      child: Card(
        elevation: 0,
        color: cardColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: () => _dersSuresiDuzenleDialogGoster(ders),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  ders.ad,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Text(
                  _dakikayiSaatDakikaFormatinaDonustur(ders.dakika),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: ders.dakika > 0 ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class StudyTimeChart extends StatefulWidget {
  final String?
      studentId; // Gösterilecek öğrencinin ID'si (öğretmen görüntülüyorsa)
  final bool isTeacher; // Öğretmen modu

  StudyTimeChart({this.studentId, this.isTeacher = false});

  @override
  _StudyTimeChartState createState() => _StudyTimeChartState();
}

class _StudyTimeChartState extends State<StudyTimeChart>
    with SingleTickerProviderStateMixin {
  List<double> testCozmeSurem = List.filled(7, 0.0);
  List<double> konuCalismaSurem = List.filled(7, 0.0);
  bool _isLoading = true;
  int _selectedDayIndex = -1;
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  // Günlerin gerçek tarihleri (arka planda kalacak)
  List<DateTime> weekDates = [];
  List<String> formattedDates = [];
  
  // Aktif seçilen gün için ders seçim paneli
  int _activeDayForSubjects = -1;
  
  final days = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar'
  ];
  final shortDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  String _studentName = "";

  // Öğretmen görünümü için ilave veri
  List<Map<String, dynamic>> _calismaVerileri = [];
  bool _useCalismaVerileri = false;

  // Süreleri saat ve dakika formatında gösterecek yardımcı fonksiyon
  String formatMinutesToHourMinute(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}s ${remainingMinutes}dk';
  }

  // Haftanın tarihlerini hesapla (arka planda kullanmak için)
  void _calculateWeekDates() {
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    
    weekDates.clear();
    formattedDates.clear();
    
    for (int i = 0; i < 7; i++) {
      DateTime dayDate = monday.add(Duration(days: i));
      weekDates.add(dayDate);
      formattedDates.add(DateFormat('dd.MM.yyyy').format(dayDate));
    }
  }

  @override
  void initState() {
    super.initState();
    _calculateWeekDates(); // Haftanın tarihlerini hesapla
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Verilerin yükleneceği kullanıcı ID'sini belirle
    final String userId =
        widget.studentId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Eğer öğretmen modundaysa öğrenci bilgilerini yükle
      if (widget.isTeacher && widget.studentId != null) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.studentId)
            .get();

        if (studentDoc.exists) {
          _studentName = '${studentDoc['isim']} ${studentDoc['soyIsim']}';

          // Öğretmen görünümü için calismaVerileri alt koleksiyonunu kontrol et
          QuerySnapshot calismaVerileriSnapshot =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.studentId)
                  .collection('calismaVerileri')
                  .orderBy('tarih', descending: true)
                  .limit(14) // Son 2 hafta
                  .get();

          if (calismaVerileriSnapshot.docs.isNotEmpty) {
            _calismaVerileri = calismaVerileriSnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();

            _useCalismaVerileri = true;

            // Son 7 günün verilerini al
            DateTime now = DateTime.now();
            DateTime oneWeekAgo = now.subtract(Duration(days: 7));

            // Her gün için verileri sıfırla
            for (int i = 0; i < 7; i++) {
              testCozmeSurem[i] = 0;
              konuCalismaSurem[i] = 0;
            }

            // Günlük çalışma verilerini doldur
            for (var data in _calismaVerileri) {
              if (data['tarih'] == null) continue;

              DateTime tarih = data['tarih'].toDate();
              if (tarih.isAfter(oneWeekAgo)) {
                int dayOfWeek = tarih.weekday - 1; // 0: Pazartesi, 6: Pazar
                if (dayOfWeek >= 0 && dayOfWeek < 7) {
                  testCozmeSurem[dayOfWeek] +=
                      (data['testSuresi'] as num?)?.toDouble() ?? 0.0;
                  konuCalismaSurem[dayOfWeek] +=
                      (data['konuSuresi'] as num?)?.toDouble() ?? 0.0;
                }
              }
            }
          }
        }
      }

      // Eğer calismaVerileri yoksa veya öğrenci kendi verilerini görüntülüyorsa
      if (!_useCalismaVerileri) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        final data = doc.data() ?? {};

        final testData =
            (data['testCozmeSurem'] as List<dynamic>? ?? List.filled(7, 0.0))
                .map((e) => (e is num)
                    ? e.toDouble()
                    : double.tryParse(e.toString()) ?? 0.0)
                .toList();

        final konuData =
            (data['konuCalismaSurem'] as List<dynamic>? ?? List.filled(7, 0.0))
                .map((e) => (e is num)
                    ? e.toDouble()
                    : double.tryParse(e.toString()) ?? 0.0)
                .toList();

        if (!mounted) return;
        setState(() {
          testCozmeSurem = testData;
          konuCalismaSurem = konuData;
        });
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      await updateCurrentWeekData(
          testCozmeSurem, konuCalismaSurem, widget.studentId);
      _animationController.forward();
    } catch (e) {
      print('Veri yükleme hatası: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (widget.isTeacher) return; // Öğretmenler değişiklik yapamaz

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Ana belgeyi güncelle
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'testCozmeSurem': testCozmeSurem,
        'konuCalismaSurem': konuCalismaSurem,
      }, SetOptions(merge: true));

      // Her gün için günlük veri kaydet
      for (int i = 0; i < 7; i++) {
        if (testCozmeSurem[i] > 0 || konuCalismaSurem[i] > 0) {
          await saveDailyData(user.uid, i, testCozmeSurem[i], konuCalismaSurem[i]);
        }
      }

      // Bugünün güncellemesi için günü ve indeksi bul
      final DateTime now = DateTime.now();
      final int todayIndex = now.weekday - 1; // 0: Pazartesi, 6: Pazar

      // Bugün için çalışma süreleri
      final double testToday = testCozmeSurem[todayIndex];
      final double konuToday = konuCalismaSurem[todayIndex];

      // Bugün için çalışma varsa, öğretmen görünümü için calismaVerileri koleksiyonunu da güncelle
      if (testToday > 0 || konuToday > 0) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('calismaVerileri')
            .add({
          'tarih': Timestamp.now(),
          'calismaSuresi': (testToday + konuToday).round(),
          'cozilenSoru': 0, // Bu değer ayrıca girilmeli
          'testSuresi': testToday.round(),
          'konuSuresi': konuToday.round(),
          'puan': 0, // İsteğe bağlı puan
          'notlar': 'Çalışma sürem sayfasından girildi',
          'gercekTarih': formattedDates[todayIndex], // Arka planda tarih bilgisi
        });
      }

      await updateCurrentWeekData(testCozmeSurem, konuCalismaSurem, null);
    } catch (e) {
      print('Veri kaydetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Veriler kaydedilirken bir hata oluştu',
                style: TextStyle(fontSize: 16)),
            backgroundColor: Colors.red));
      }
    }
  }

  // Gün seçildiğinde ders seçim panelini göster veya gizle
  void _handleDaySelection(int dayIndex) {
    setState(() {
      if (_activeDayForSubjects == dayIndex) {
        _activeDayForSubjects = -1; // Aynı güne tekrar tıklanırsa kapat
      } else {
        _activeDayForSubjects = dayIndex; // Yeni gün seç
      }
    });
  }

  // Ders seçiminden toplam test süresi güncellendiğinde
  void _handleTotalTestTimeChanged(double newTotalTime) {
    if (_activeDayForSubjects >= 0 && _activeDayForSubjects < 7) {
      setState(() {
        testCozmeSurem[_activeDayForSubjects] = newTotalTime;
      });
      _saveData();
    }
  }

  void _showEditDialog(String day, int index) async {
    // Öğretmen modunda düzenleme yapılamaz
    if (widget.isTeacher) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Öğretmen olarak öğrenci verilerini düzenleyemezsiniz',
            style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ));
      return;
    }

    final TextEditingController testCozmeController = TextEditingController(
        text: _formatMinutesToTime(testCozmeSurem[index]));
    final TextEditingController konuCalismaController = TextEditingController(
        text: _formatMinutesToTime(konuCalismaSurem[index]));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints:
              BoxConstraints(maxWidth: 400), // Maksimum genişlik sınırı
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue.shade700, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "$day Verilerini Düzenle",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                _buildTimeInputField(
                  controller: testCozmeController,
                  label: 'Test Çözme Sürem',
                  icon: Icons.timer,
                  color: Colors.green.shade600,
                ),
                SizedBox(height: 20),
                _buildTimeInputField(
                  controller: konuCalismaController,
                  label: 'Konu Çalışma Sürem',
                  icon: Icons.book,
                  color: Colors.blue.shade600,
                ),
                SizedBox(height: 16),
                Text(
                  'Format: saat:dakika (örn: 02:30)',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('İptal', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(                        onPressed: () async {
                          if (_isValidTime(testCozmeController.text) &&
                              _isValidTime(konuCalismaController.text)) {
                            double newTest =
                                _parseTimeToMinutes(testCozmeController.text)
                                    .toDouble();
                            double newKonu =
                                _parseTimeToMinutes(konuCalismaController.text)
                                    .toDouble();

                            setState(() {
                              testCozmeSurem[index] = newTest;
                              konuCalismaSurem[index] = newKonu;
                            });

                            // Ders seçim ekranını göster
                            _handleDaySelection(index);

                            await _saveData();
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('$day verileri güncellendi. Ders bazlı test sürelerini girebilirsiniz',
                                  style: TextStyle(fontSize: 16)),
                              backgroundColor: Colors.blue.shade700,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.all(16),
                            ));
                          } else if (testCozmeController.text.isEmpty ||
                              konuCalismaController.text.isEmpty) {
                            Navigator.pop(context);
                          } else {
                            _showInvalidInputAlert();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Kaydet', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                labelStyle:
                    TextStyle(fontSize: 16, color: Colors.grey.shade800),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: TextInputType.datetime,
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidTime(String value) {
    if (value.isEmpty) return true;
    final parts = value.split(':');
    if (parts.length == 1) {
      final hours = int.tryParse(parts[0]);
      return hours != null && hours >= 0 && hours <= 24;
    } else if (parts.length == 2) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      return hours != null &&
          minutes != null &&
          hours >= 0 &&
          hours <= 24 &&
          minutes >= 0 &&
          minutes < 60;
    }
    return false;
  }

  void _showInvalidInputAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Flexible(
                child: Text("Geçersiz Giriş", style: TextStyle(fontSize: 18))),
          ],
        ),
        content: Text(
          "Lütfen sadece saat ve dakika cinsinden ve saat değeri maksimum 24, dakika değeri maksimum 59 olacak şekilde değer giriniz (örneğin 02:30).",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Tamam', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  int _parseTimeToMinutes(String time) {
    if (time.isEmpty) return 0;
    final parts = time.split(':');
    if (parts.length == 1) {
      return (int.tryParse(parts[0]) ?? 0) * 60;
    } else if (parts.length == 2) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      return hours * 60 + minutes;
    }
    return 0;
  }

  String _formatMinutesToTime(double minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }

  // En çok çalışılan günü bulan fonksiyon
  String _findMostStudiedDay() {
    List<double> totalDailyStudy = List.generate(
      7,
      (i) => testCozmeSurem[i] + konuCalismaSurem[i],
    );

    int maxIndex = 0;
    double maxValue = totalDailyStudy[0];

    for (int i = 1; i < totalDailyStudy.length; i++) {
      if (totalDailyStudy[i] > maxValue) {
        maxIndex = i;
        maxValue = totalDailyStudy[i];
      }
    }

    return days[maxIndex] + ' (' + formatMinutesToHourMinute(maxValue.toInt()) + ')';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator());

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateFormat('d MMMM yyyy').format(monday);
    final weekEndDate =
        DateFormat('d MMMM yyyy').format(monday.add(Duration(days: 6)));

    final double totalTestTime = testCozmeSurem.reduce((a, b) => a + b);
    final double totalKonuTime = konuCalismaSurem.reduce((a, b) => a + b);
    final double totalStudyTime = totalTestTime + totalKonuTime;

    final int totalHours = (totalStudyTime / 60).floor();
    final int totalMinutes = (totalStudyTime % 60).floor();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade100.withOpacity(0.5), Colors.white],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isTeacher) _buildTeacherStudentInfoCard(isSmallScreen),
              _buildSummaryCard(weekStartDate, weekEndDate, totalHours,
                  totalMinutes, totalTestTime, totalKonuTime, isSmallScreen),
              _buildChartCard(isSmallScreen),
              
              // Ders bazlı test süre paneli
              if (_activeDayForSubjects >= 0 && !widget.isTeacher)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.green.shade700),
                          SizedBox(width: 12),
                          Text(
                            '${days[_activeDayForSubjects]} - Ders Bazlı Test Süreleri',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      DersSecimWidget(
                        gunIndex: _activeDayForSubjects,
                        toplamSureDegisti: _handleTotalTestTimeChanged,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => _activeDayForSubjects = -1);
                          },
                          icon: Icon(Icons.close),
                          label: Text('Kapat'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              _buildInfoCards(totalStudyTime, isSmallScreen),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Öğretmen modu için öğrenci bilgi kartı
  Widget _buildTeacherStudentInfoCard(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 20, 16, 8),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, color: Colors.blue.shade700, size: 30),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Öğrenci Bilgileri",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _studentName.isEmpty ? "Öğrenci" : _studentName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Özet kart
  Widget _buildSummaryCard(
      String weekStartDate,
      String weekEndDate,
      int totalHours,
      int totalMinutes,
      double totalTestTime,
      double totalKonuTime,
      bool isSmallScreen) {
    // Fonksiyon içinde totalStudyTime hesaplanmalı
    final double totalStudyTime = totalTestTime + totalKonuTime;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 20, 16, 16),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.isTeacher
                        ? "Bu Haftanın Çalışma Verileri"
                        : "Bu Haftanın Çalışma Verileri",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text("$weekStartDate - $weekEndDate",
              style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey.shade700)),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                  "Toplam",
                  "${totalStudyTime ~/ 60}s ${(totalStudyTime % 60).toInt()}dk",
                  Colors.amber.shade700,
                  Icons.access_time,
                  isSmallScreen),
              _buildStatCard(
                  "Test",
                  "${totalTestTime ~/ 60}s ${(totalTestTime % 60).toInt()}dk",
                  Colors.green.shade600,
                  Icons.timer,
                  isSmallScreen),
              _buildStatCard(
                  "Konu",
                  "${totalKonuTime ~/ 60}s ${(totalKonuTime % 60).toInt()}dk",
                  Colors.blue.shade600,
                  Icons.book,
                  isSmallScreen),
            ],
          ),
        ],
      ),
    );
  }

  // Grafik kartı
  Widget _buildChartCard(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Haftalık Çalışma Grafiği",
                          style: TextStyle(
                              fontSize: isSmallScreen ? 18 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800),
                        ),
                      ),
                      SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.isTeacher
                              ? "Öğrencinin günlük çalışma saatleri"
                              : "Gün isimlerine tıklayarak veri ekleyebilirsiniz",
                          style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                _buildLegendButton(),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return SizedBox(
                height: isSmallScreen ? 300 : 350,
                child: LineChart(_buildChartData(isSmallScreen)),
              );
            },
          ),
        ],
      ),
    );
  }

  // Bilgi kartları
  Widget _buildInfoCards(double totalStudyTime, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildDayDetailCard(
                      "En Çok Çalışılan Gün",
                      _findMostStudiedDay(),
                      Icons.emoji_events,
                      Colors.amber.shade700,
                      isSmallScreen)),
              SizedBox(width: 16),
              Expanded(
                  child: _buildDayDetailCard(
                      "Günlük Ortalama",
                      "${(totalStudyTime / 7).toInt() ~/ 60}s ${((totalStudyTime / 7).toInt() % 60)}dk",
                      Icons.trending_up,
                      Colors.teal.shade600,
                      isSmallScreen)),
            ],
          ),
          SizedBox(height: 16),
          widget.isTeacher
              ? _buildTeacherTipCard(isSmallScreen)
              : _buildTipCard(isSmallScreen),
        ],
      ),
    );
  }

  // Öğretmenler için ipucu kartı
  Widget _buildTeacherTipCard(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
                color: Colors.blue.shade100, shape: BoxShape.circle),
            child: Icon(Icons.lightbulb,
                color: Colors.blue.shade700, size: isSmallScreen ? 24 : 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Öğretmen İpucu",
                  style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700),
                ),
                SizedBox(height: 6),
                Text(
                  "Öğrencinin çalışma alışkanlıklarını analiz ederek geri bildirim verebilirsiniz. Haftanın günleri bazında veriler arka planda tarihlerle kaydedilmektedir.",
                  style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 15,
                      color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tekrarlanan kart dekorasyonu
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: Offset(0, 3))
      ],
    );
  }

  // İstatistik kartları
  Widget _buildStatCard(String title, String value, Color color, IconData icon,
      bool isSmallScreen) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 4 : 8,
            vertical: isSmallScreen ? 10 : 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isSmallScreen ? 24 : 28),
            SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
            SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title,
                  style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: color.withOpacity(0.8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetailCard(String title, String value, IconData icon,
      Color color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: isSmallScreen ? 24 : 28),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 15,
                          color: Colors.grey.shade700)),
                ),
                SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: isSmallScreen ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(bool isSmallScreen) {
    final List<String> tips = [
      "Düzenli çalışma programı oluşturun",
      "Her gün en az 30 dakika test çözün",
      "Düzenli çalışma programı oluşturun",
      "Her gün en az 30 dakika test çözün",
      "Çalışma molalarını ihmal etmeyin",
      "Her hafta önceki haftadan daha fazla çalışmayı hedefleyin",
      "Verimli çalışma teknikleri deneyin"
    ];
    final tip = tips[DateTime.now().day % tips.length];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
                color: Colors.blue.shade100, shape: BoxShape.circle),
            child: Icon(Icons.lightbulb,
                color: Colors.blue.shade700, size: isSmallScreen ? 24 : 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Günün İpucu",
                  style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700),
                ),
                SizedBox(height: 6),
                Text(
                  tip,
                  style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 15,
                      color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Açıklama düğmesini oluştur
  Widget _buildLegendButton() {
    return ElevatedButton.icon(
      onPressed: () => _showLegendDialog(),
      icon: Icon(Icons.info_outline, color: Colors.white, size: 20),
      label: Text("Açıklama", style: TextStyle(fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade700,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Açıklama diyaloğunu göster
  void _showLegendDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
          padding: EdgeInsets.all(24),
          constraints:
              BoxConstraints(maxWidth: 400), // Maksimum genişlik sınırı
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Çizgilerin Anlamları",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 24),
              _buildLegendItem(
                  Colors.green.shade600, "Test Çözme Sürem", 24, 16),
              SizedBox(height: 16),
              _buildLegendItem(
                  Colors.blue.shade600, "Konu Çalışma Sürem", 24, 16),
              SizedBox(height: 16),
              _buildLegendItem(
                  Colors.amber.shade600, "Toplam Çalışma Sürem", 24, 16),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Tamam", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(
      Color color, String text, double size, double fontSize) {
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(6)),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(text,
              style:
                  TextStyle(fontSize: fontSize, color: Colors.grey.shade800)),
        ),
      ],
    );
  }

  // Grafik verilerini oluştur
  LineChartData _buildChartData(bool isSmallScreen) {
    List<double> toplamCalismaSurem = List.generate(
      7,
      (i) => testCozmeSurem[i] + konuCalismaSurem[i],
    );

    return LineChartData(
      backgroundColor: Colors.transparent,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 6 * 60,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.2),
          strokeWidth: 1,
          dashArray: [5, 5],
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: Colors.grey.withOpacity(0.2),
          strokeWidth: 1,
          dashArray: [5, 5],
        ),
      ),
      titlesData: _buildTitles(isSmallScreen),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
          left: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
      ),
      minY: 0,
      maxY: 24 * 60,
      lineBarsData: [
        _buildLineChartBarData(
            toplamCalismaSurem, Colors.amber.shade600, isSmallScreen),
        _buildLineChartBarData(
            konuCalismaSurem, Colors.blue.shade600, isSmallScreen),
        _buildLineChartBarData(
            testCozmeSurem, Colors.green.shade600, isSmallScreen),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final minutes = spot.y;
              final hours = (minutes ~/ 60).toString().padLeft(2, '0');
              final mins = (minutes % 60).toString().padLeft(2, '0');
              String title = spot.barIndex == 0
                  ? 'Toplam'
                  : spot.barIndex == 1
                      ? 'Konu'
                      : 'Test';
              return LineTooltipItem(
                '$title: $hours:$mins',
                TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              );
            }).toList();
          },
        ),
        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
          if (response == null || response.lineBarSpots == null) {
            setState(() => _selectedDayIndex = -1);
            return;
          }

          if (event is FlTapUpEvent && !widget.isTeacher) {
            final spotIndex = response.lineBarSpots!.first.spotIndex;
            setState(() => _selectedDayIndex = spotIndex);
            _showEditDialog(days[spotIndex], spotIndex);
          } else if (event is FlPanEndEvent) {
            setState(() => _selectedDayIndex = -1);
          }
        },
      ),
    );
  }

  // Grafik eksenleri için başlıkları oluştur - Tarih görünümü kaldırıldı
  FlTitlesData _buildTitles(bool isSmallScreen) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dayWidth = (screenWidth - 100) / 7;

    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: isSmallScreen ? 45 : 50,
          interval: 6 * 60,
          getTitlesWidget: (value, _) {
            final hours = (value / 60).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('$hours s',
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.bold)),
              ),
            );
          },
        ),
      ),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40, // Tarih görünümü kaldırıldığı için rezerve alan azaltıldı
          interval: 1,
          getTitlesWidget: (value, _) {
            final index = value.toInt();
            if (index < 0 || index >= shortDays.length)
              return const SizedBox.shrink();

            return GestureDetector(
              onTap: widget.isTeacher
                  ? null
                  : () {
                      _showEditDialog(days[index], index);
                      if (!widget.isTeacher) {
                        _handleDaySelection(index);
                      }
                    },
              child: Container(
                width: dayWidth,
                height: 40,
                padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                margin: EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: _selectedDayIndex == index || _activeDayForSubjects == index
                      ? Colors.blue.shade700.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedDayIndex == index || _activeDayForSubjects == index
                        ? Colors.blue.shade700
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    shortDays[index],
                    style: TextStyle(
                      color: _selectedDayIndex == index || _activeDayForSubjects == index
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                      fontSize: isSmallScreen ? 13 : 15,
                      fontWeight: _selectedDayIndex == index || _activeDayForSubjects == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // Grafik çizgilerini oluştur
  LineChartBarData _buildLineChartBarData(
      List<double> data, Color color, bool isSmallScreen) {
    return LineChartBarData(
      spots: List.generate(7, (index) {
        double totalMinutes = data[index];
        if (totalMinutes > 24 * 60) totalMinutes = 24 * 60;
        return FlSpot(index.toDouble(), totalMinutes * _animation.value);
      }),
      isCurved: true,
      color: color,
      barWidth: isSmallScreen ? 4 : 5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final isSelected = index == _selectedDayIndex || index == _activeDayForSubjects;
          return FlDotCirclePainter(
            radius:
                isSelected ? (isSmallScreen ? 6 : 7) : (isSmallScreen ? 5 : 6),
            color: isSelected ? Colors.white : color,
            strokeWidth: isSmallScreen ? 2.0 : 2.5,
            strokeColor: color,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.3), color.withOpacity(0.05)],
        ),
      ),
    );
  }
}
                