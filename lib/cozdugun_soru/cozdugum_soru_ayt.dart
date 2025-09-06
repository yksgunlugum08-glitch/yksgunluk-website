import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Provider import
import 'package:yksgunluk/cozdugun_soru/cozdugum_soru.sayisi.dart';
import 'package:yksgunluk/teacher_mode.dart'; // YENİ: Teacher mode provider import

class CozdugumSoruSayisiAytEkrani extends StatefulWidget {
  @override
  _CozdugumSoruSayisiAytEkraniState createState() => _CozdugumSoruSayisiAytEkraniState();
}

class _CozdugumSoruSayisiAytEkraniState extends State<CozdugumSoruSayisiAytEkrani> {
  List<Map<String, dynamic>> _solvedQuestions = [];
  List<String> _dersler = [];
  String _selectedBolum = '';
  bool _isLoading = true;

  // Sabit mor tema rengi
  final Color _defaultThemeColor = Colors.purple.shade600;

  // Bölüm renkleri
  final Map<String, Color> _bolumColors = {
    'Sayısal': Colors.purple.shade600, // Hepsini mor yaptım
    'Eşit Ağırlık': Colors.purple.shade600,
    'Sözel': Colors.purple.shade600,
    'Dil': Colors.purple.shade600,
  };

  // Aktif renk temasını al (şimdi hepsi mor)
  Color get _activeColor => _defaultThemeColor;
  Color get _activeColorLight => _activeColor.withOpacity(0.2);
  Color get _activeColorMedium => _activeColor.withOpacity(0.5);
  
  // YENİ: Öğretmen modu kontrolü
  bool get _isTeacherMode => Provider.of<TeacherModeProvider>(context, listen: false).isTeacherMode;
  String? get _studentId => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentId;
  String? get _studentName => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentName;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // YENİ: Kullanıcı ID'sini belirleme (öğretmen modu veya normal mod)
      final String userId = _isTeacherMode 
          ? (_studentId ?? '')  // Öğretmen modunda seçilen öğrencinin ID'si
          : (FirebaseAuth.instance.currentUser?.uid ?? '');  // Normal modda kendi ID'si
      
      if (userId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Kullanıcının bölüm tercihini Firestore'dan oku
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final bolum = (userDoc.data() ?? {})['selectedBolum'] ?? '';
      
      // Bölüm boşsa varsayılan olarak "Sayısal" kullan
      final selectedBolum = bolum.isNotEmpty ? bolum : 'Sayısal';
      final dersler = _getDerslerByBolum(selectedBolum);
      
      setState(() {
        _selectedBolum = selectedBolum;
        _dersler = dersler;
      });
      
      await _loadSolvedQuestions();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Veri yükleme hatası: $e");
      // Hata durumunda varsayılan değerler kullan
      setState(() {
        _selectedBolum = 'Sayısal';
        _dersler = _getDerslerByBolum('Sayısal');
        _isLoading = false;
      });
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
        return ['Matematik', 'Fizik', 'Kimya', 'Biyoloji']; // Varsayılan olarak Sayısal dersleri
    }
  }

  Future<void> _loadSolvedQuestions() async {
    try {
      // YENİ: Kullanıcı ID'sini belirleme (öğretmen modu veya normal mod)
      final String userId = _isTeacherMode 
          ? (_studentId ?? '')
          : (FirebaseAuth.instance.currentUser?.uid ?? '');
          
      if (userId.isEmpty) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('solvedQuestionsAyt')
          .orderBy('date', descending: true)
          .get();

      // SADECE mevcut bölümün derslerini içeren kayıtları filtrele
      List<Map<String, dynamic>> filteredData = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        
        // Herhangi bir bölüm dersi var mı kontrol et
        bool hasAnyClassData = false;
        for (String ders in _dersler) {
          if (data.containsKey(ders) && ((data[ders] ?? 0) > 0)) {
            hasAnyClassData = true;
            break;
          }
        }
        
        // Bu belge bizim bölümümüzle ilgili veri içermiyorsa atla
        if (!hasAnyClassData) continue;
        
        // Sadece tarih ve seçili bölümün derslerini içeren yeni bir nesne oluştur
        Map<String, dynamic> filteredItem = {
          'date': data['date'] ?? '',
        };

        // Sadece mevcut bölümdeki dersler için veri alın
        int toplam = 0;
        for (String ders in _dersler) {
          int value = (data[ders] is int) ? data[ders] : int.tryParse(data[ders]?.toString() ?? '0') ?? 0;
          filteredItem[ders] = value;
          toplam += value;
        }
        
        filteredItem['Toplam'] = toplam;
        filteredData.add(filteredItem);
      }

      setState(() {
        _solvedQuestions = filteredData;
      });
    } catch (e) {
      print("Soru verisi yükleme hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veriler yüklenirken bir sorun oluştu'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  Future<void> _saveSolvedQuestion(Map<String, dynamic> solvedQuestion) async {
    // YENİ: Öğretmen modunda kayıt engelleme
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğretmen modunda değişiklik yapamazsınız!'),
          backgroundColor: Colors.red,
        )
      );
      return;
    }
    
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Tarihe göre aynı gün varsa güncelle, yoksa ekle
      String today = solvedQuestion['date'];
      var existingDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('solvedQuestionsAyt')
          .where('date', isEqualTo: today)
          .limit(1)
          .get();
          
      if (existingDoc.docs.isNotEmpty) {
        // Varolan belgeyi al
        DocumentSnapshot existingDocument = existingDoc.docs.first;
        Map<String, dynamic> existingData = existingDocument.data() as Map<String, dynamic>;
        
        // Mevcut veriden sadece kaydedilmesi gereken alanları al
        Map<String, dynamic> updatedData = {
          'date': today,
          'Toplam': solvedQuestion['Toplam'],
        };
        
        // Sadece mevcut bölümün derslerini güncelle
        for (String ders in _dersler) {
          updatedData[ders] = solvedQuestion[ders];
        }
        
        // Diğer bölümlerin verilerini koru (bunlar UI'da gösterilmeyecek)
        for (var key in existingData.keys) {
          if (!updatedData.containsKey(key) && key != 'date' && key != 'Toplam') {
            updatedData[key] = existingData[key];
          }
        }
        
        // Güncelle
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('solvedQuestionsAyt')
            .doc(existingDocument.id)
            .update(updatedData);
      } else {
        // Ekle
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('solvedQuestionsAyt')
            .add(solvedQuestion);
      }
      await _loadSolvedQuestions();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Soru sayıları kaydedildi'),
          backgroundColor: _activeColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )
      );
    } catch (e) {
      print("Soru kaydetme hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veriler kaydedilirken bir sorun oluştu'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  // TYT sayfasına geçiş yapma fonksiyonu
  void _goToTytPage() {
    print("TYT sayfasına geçmeye çalışıyorum"); // Debug için
    
    // TYT sayfasını direkt açıyoruz
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CozdugumSoruSayisiEkrani(),
      ),
    );
  }

  Future<void> _addSolvedQuestion() async {
    // YENİ: Öğretmen modunda ekleme engelleme
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğretmen modunda değişiklik yapamazsınız!'),
          backgroundColor: Colors.red,
        )
      );
      return;
    }
    
    if (_dersler.isEmpty) {
      // Bölüm seçilmediyse kullanıcıya uyarı göster
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Flexible(child: Text("Bölüm Seçiniz")),
            ],
          ),
          content: Text("Lütfen önce profilinizden bir bölüm seçiniz."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: _activeColorLight,
                foregroundColor: _activeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("Tamam"),
            ),
          ],
        ),
      );
      return;
    }

    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return QuestionInputDialog(
          dersler: _dersler, 
          bolum: _selectedBolum,
          themeColor: _activeColor,
        );
      },
    );

    if (result != null) {
      String today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      result['date'] = today;
      
      // Toplam hesapla
      int toplam = 0;
      _dersler.forEach((ders) {
        toplam += (result[ders] as int? ?? 0);
      });
      result['Toplam'] = toplam;
      
      await _saveSolvedQuestion(result);
    }
  }

  List<DataColumn2> _getColumns() {
    return [
      DataColumn2(
        label: Text(
          'Tarih',
          style: TextStyle(fontWeight: FontWeight.bold),
        ), 
        size: ColumnSize.M
      ),
      ..._dersler.map((ders) => 
        DataColumn2(
          label: Text(
            ders,
            style: TextStyle(fontWeight: FontWeight.bold),
          ), 
          size: ColumnSize.S
        )
      ).toList(),
      DataColumn2(
        label: Text(
          'Toplam',
          style: TextStyle(fontWeight: FontWeight.bold),
        ), 
        size: ColumnSize.S
      ),
    ];
  }

  List<DataRow> _getRows() {
    return List<DataRow>.generate(
      _solvedQuestions.length,
      (index) {
        final solvedQuestion = _solvedQuestions[index];
        
        // Toplam değeri al veya hesapla
        int toplam = solvedQuestion['Toplam'] ?? _dersler.fold<int>(
          0,
          (sum, ders) => sum + (solvedQuestion[ders] as int? ?? 0),
        );
        
        return DataRow(
          color: index % 2 == 0 
              ? MaterialStateProperty.all(_activeColorLight)
              : null,
          cells: [
            DataCell(Text(solvedQuestion['date'] ?? '')),
            ..._dersler.map(
              (ders) => DataCell(_buildNumberCell(solvedQuestion[ders] ?? 0)),
            ).toList(),
            DataCell(_buildTotalCell(toplam)),
          ],
        );
      },
    );
  }

  Widget _buildNumberCell(int value) {
    return Text(
      value.toString(),
      style: TextStyle(fontWeight: FontWeight.w500),
    );
  }

  Widget _buildTotalCell(int total) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _activeColorLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        total.toString(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _activeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // YENİ: Öğretmen modu kontrolü için provider erişimi
    final teacherMode = Provider.of<TeacherModeProvider>(context, listen: false);
    
    // YENİ: Başlık için öğrenci adı düzenlemesi
    final String title = _isTeacherMode 
        ? "${_studentName} - Çözdüğü Soru Sayısı" 
        : "Çözdüğüm Soru Sayısı";
        
    return Scaffold(
      appBar: AppBar(
        // YENİ: Dinamik başlık
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _activeColor,
        elevation: 0,
        // Sıfırlama butonu kaldırıldı
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: _activeColor.withOpacity(0.85),
            ),
            child: Row(
              children: [
                // TYT tab (tıklanabilir)
                Expanded(
                  child: InkWell(
                    onTap: _goToTytPage,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          "TYT",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // AYT seçili tab
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Center(
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
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _activeColor))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bölüm gösterge paneli
                Container(
                  color: _activeColorLight,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.school, color: _activeColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Seçili Bölüm: $_selectedBolum",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _activeColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // YENİ: Öğretmen modunda bu uyarıyı gizle
                      if (!_isTeacherMode)
                        _dersler.isEmpty 
                            ? TextButton.icon(
                                icon: Icon(Icons.warning_amber_rounded),
                                label: Text("Bölüm Seçiniz"),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.orange.shade100,
                                  foregroundColor: Colors.orange.shade900,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Profil ayarlarından bölüm seçiniz'),
                                      behavior: SnackBarBehavior.floating,
                                    )
                                  );
                                },
                              )
                            : Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _activeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: _activeColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  "${_dersler.length} ders",
                                  style: TextStyle(
                                    color: _activeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                    ],
                  ),
                ),
                Divider(height: 1),
                
                // Ana içerik
                Expanded(
                  child: _solvedQuestions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined, 
                              size: 80,
                              color: _activeColor.withOpacity(0.5),
                            ),
                            SizedBox(height: 16),
                            Text(
                              // YENİ: Öğretmen moduna göre metin
                              _isTeacherMode 
                                  ? "$_selectedBolum bölümü için AYT sorusu çözülmemiş!"
                                  : "Henüz $_selectedBolum bölümü için AYT sorusu çözmediniz!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                // YENİ: Öğretmen moduna göre metin
                                _isTeacherMode
                                    ? "Bu bölümde henüz çözülmüş soru kaydı yok."
                                    : "Bu bölümde ${_dersler.join(', ')} dersleri için çözülen soruları kaydedebilirsiniz.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            // YENİ: Öğretmen modunda soru ekle butonu gizlenir
                            if (!_isTeacherMode)
                              ElevatedButton.icon(
                                icon: Icon(Icons.add),
                                label: Text("Soru Ekle"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _activeColor,
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  )
                                ),
                                onPressed: _addSolvedQuestion,
                              )
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.assignment_outlined,
                                        color: _activeColor,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          // YENİ: Öğretmen moduna göre metin
                                          _isTeacherMode
                                            ? "AYT $_selectedBolum Dersleri Çözülen Sorular"
                                            : "AYT $_selectedBolum Dersleri Çözülen Sorular",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _activeColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(),
                                Expanded(
                                  child: DataTable2(
                                    columnSpacing: 12,
                                    horizontalMargin: 12,
                                    minWidth: 600,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    headingRowHeight: 50,
                                    headingRowColor: MaterialStateProperty.all(
                                      _activeColorLight
                                    ),
                                    headingTextStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _activeColor,
                                    ),
                                    dataRowHeight: 54,
                                    dividerThickness: 1,
                                    showBottomBorder: true,
                                    border: TableBorder(
                                      horizontalInside: BorderSide(
                                        color: Colors.grey.shade300, 
                                        width: 1
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    columns: _getColumns(),
                                    rows: _getRows(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                ),
              ],
            ),
      // YENİ: Öğretmen modunda buton gizlenir
      floatingActionButton: _isTeacherMode ? null : FloatingActionButton(
        onPressed: _addSolvedQuestion,
        child: Icon(Icons.add),
        backgroundColor: _activeColor,
        elevation: 4,
      ),
    );
  }
}

class QuestionInputDialog extends StatefulWidget {
  final List<String> dersler;
  final String bolum;
  final Color themeColor;

  QuestionInputDialog({
    required this.dersler, 
    required this.bolum,
    required this.themeColor,
  });

  @override
  _QuestionInputDialogState createState() => _QuestionInputDialogState();
}

class _QuestionInputDialogState extends State<QuestionInputDialog> {
  final Map<String, TextEditingController> _controllers = {};
  int _total = 0;

  @override
  void initState() {
    super.initState();
    // Her ders için controller oluştur
    widget.dersler.forEach((ders) {
      _controllers[ders] = TextEditingController();
      _controllers[ders]!.addListener(_updateTotal);
    });
  }

  void _updateTotal() {
    int total = 0;
    widget.dersler.forEach((ders) {
      total += int.tryParse(_controllers[ders]!.text) ?? 0;
    });
    setState(() {
      _total = total;
    });
  }

  @override
  void dispose() {
    // Controller'ları temizle
    _controllers.forEach((_, controller) {
      controller.removeListener(_updateTotal);
      controller.dispose();
    });
    super.dispose();
  }
  
  Map<IconData, String> _getDersIconMap() {
    return {
      Icons.calculate_outlined: 'Matematik',
      Icons.science_outlined: 'Kimya',
      Icons.bolt_outlined: 'Fizik',
      Icons.biotech_outlined: 'Biyoloji',
      Icons.menu_book_outlined: 'Edebiyat',
      Icons.history_edu_outlined: 'Tarih',
      Icons.public_outlined: 'Coğrafya',
      Icons.psychology_outlined: 'Felsefe',
      Icons.brightness_high_outlined: 'Din',
      Icons.translate_outlined: 'Dilbilgisi',
      Icons.remove_red_eye_outlined: 'Okuma',
      Icons.record_voice_over_outlined: 'Anlama',
      Icons.edit_outlined: 'Yazma',
    };
  }

  IconData _getIconForDers(String ders) {
    final iconMap = _getDersIconMap();
    for (var entry in iconMap.entries) {
      if (ders.toLowerCase().contains(entry.value.toLowerCase())) {
        return entry.key;
      }
    }
    return Icons.book_outlined; // Varsayılan ikon
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      title: Row(
        children: [
          Icon(
            Icons.edit_note_rounded,
            color: widget.themeColor,
            size: 28,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AYT Çözdüğünüz Soru Sayısı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.themeColor,
                  ),
                ),
                Text(
                  'Bölüm: ${widget.bolum}',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.themeColor.withOpacity(0.7),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toplam gösterge
            if (_total > 0)
              Container(
                margin: EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.themeColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Toplam Soru:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.themeColor,
                      ),
                    ),
                    Text(
                      "$_total",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: widget.themeColor,
                      ),
                    ),
                  ],
                ),
              ),
              
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.dersler.map((ders) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: TextField(
                        controller: _controllers[ders],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: ders,
                          hintText: '0',
                          prefixIcon: Icon(
                            _getIconForDers(ders),
                            color: widget.themeColor,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              width: 2,
                              color: widget.themeColor,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          child: Text('İptal'),
        ),
        TextButton(
          onPressed: () {
            Map<String, dynamic> result = {};
            widget.dersler.forEach((ders) {
              result[ders] = int.tryParse(_controllers[ders]?.text ?? '') ?? 0;
            });
            Navigator.of(context).pop(result);
          },
          style: TextButton.styleFrom(
            backgroundColor: widget.themeColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
          child: Text('Kaydet'),
        ),
      ],
    );
  }
}