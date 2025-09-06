import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // YENİ: Provider import
import 'package:yksgunluk/cozdugun_soru/cozdugum_soru_ayt.dart';
import 'package:yksgunluk/teacher_mode.dart';

class CozdugumSoruSayisiEkrani extends StatefulWidget {
  @override
  _CozdugumSoruSayisiEkraniState createState() => _CozdugumSoruSayisiEkraniState();
}

class _CozdugumSoruSayisiEkraniState extends State<CozdugumSoruSayisiEkrani> {
  List<Map<String, dynamic>> _solvedQuestions = [];
  bool _isLoading = true;

  // TYT renk teması
  final Color _primaryColor = Colors.blue.shade600;
  final Color _lightColor = Colors.blue.shade100;
  final Color _darkColor = Colors.blue.shade900;
  
  // YENİ: Öğretmen modu kontrolü için getter metodları
  bool get _isTeacherMode => Provider.of<TeacherModeProvider>(context, listen: false).isTeacherMode;
  String? get _studentId => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentId;
  String? get _studentName => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentName;

  @override
  void initState() {
    super.initState();
    _loadSolvedQuestions();
  }

  Future<void> _loadSolvedQuestions() async {
    setState(() {
      _isLoading = true;
    });
    
    // YENİ: Öğretmen moduna göre kullanıcı ID'si belirle
    String userId;
    if (_isTeacherMode) {
      userId = _studentId ?? '';
      if (userId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      userId = user.uid;
    }
    
    // Sadece TYT verilerini yükle
    final collection = 'solvedQuestionsTyt';
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collection)
          .orderBy('date', descending: true)
          .get();

      setState(() {
        _solvedQuestions = snapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading questions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSolvedQuestion(Map<String, dynamic> solvedQuestion) async {
    // YENİ: Öğretmen modunda değişiklik yapılmasını engelle
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğretmen modunda değişiklik yapamazsınız!'),
          backgroundColor: Colors.red,
        )
      );
      return;
    }
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final collection = 'solvedQuestionsTyt';
    String today = solvedQuestion['date'];
    
    try {
      var existingDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(collection)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();
          
      if (existingDoc.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(collection)
            .doc(existingDoc.docs.first.id)
            .set(solvedQuestion);
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection(collection)
            .add(solvedQuestion);
      }
      await _loadSolvedQuestions();
      
      // Başarılı bildirim göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Soru sayıları kaydedildi'),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )
      );
    } catch (e) {
      print('Error saving question: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Soru sayısı kaydedilirken hata oluştu.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  Future<void> _addSolvedQuestion() async {
    // YENİ: Öğretmen modunda değişiklik yapılmasını engelle
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Öğretmen modunda değişiklik yapamazsınız!'),
          backgroundColor: Colors.red,
        )
      );
      return;
    }
    
    Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        // Sadece TYT için veri girişi dialogunu göster
        return TYTQuestionInputDialog(themeColor: _primaryColor);
      },
    );

    if (result != null) {
      String today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      result['date'] = today;
      
      // Toplam soru sayısını hesapla
      int toplam = 0;
      result.forEach((key, value) {
        if (key != 'date' && key != 'Toplam' && value is int) {
          toplam += value;
        }
      });
      result['Toplam'] = toplam;
      
      await _saveSolvedQuestion(result);
    }
  }

  // AYT sayfasına geçiş yapma fonksiyonu
  void _goToAytPage() {
    print("AYT sayfasına geçmeye çalışıyorum"); // Debug için
    
    // Aşağıdaki yöntemi deneyerek doğrudan sınıfı kullan
    final aytScreen = CozdugumSoruSayisiAytEkrani();
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => aytScreen,
        transitionDuration: Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  List<DataColumn2> _getColumns() {
    // TYT sütunları
    return [
      DataColumn2(
        label: Text(
          'Tarih',
          style: TextStyle(fontWeight: FontWeight.bold),
        ), 
        size: ColumnSize.M
      ),
      DataColumn2(
        label: Text(
          'Matematik',
          style: TextStyle(fontWeight: FontWeight.bold),
        ), 
        size: ColumnSize.S
      ),
      DataColumn2(
        label: Text(
          'Türkçe',
          style: TextStyle(fontWeight: FontWeight.bold),
        ), 
        size: ColumnSize.S
      ),
      DataColumn2(
        label: Text(
          'Sosyal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ), 
        size: ColumnSize.S
      ),
      DataColumn2(
        label: Text(
          'Fen',
          style: TextStyle(fontWeight: FontWeight.bold),
        ), 
        size: ColumnSize.S
      ),
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
        return DataRow(
          color: index % 2 == 0 
              ? MaterialStateProperty.all(_lightColor.withOpacity(0.3))
              : null,
          cells: [
            DataCell(Text(solvedQuestion['date'] ?? '')),
            DataCell(_buildNumberCell(solvedQuestion['Matematik'] ?? 0)),
            DataCell(_buildNumberCell(solvedQuestion['Türkçe'] ?? 0)),
            DataCell(_buildNumberCell(solvedQuestion['Sosyal'] ?? 0)),
            DataCell(_buildNumberCell(solvedQuestion['Fen'] ?? 0)),
            DataCell(_buildTotalCell(solvedQuestion['Toplam'] ?? 0)),
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
        color: _lightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        total.toString(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _darkColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // YENİ: Öğretmen modu için başlık özelleştirme
    final String title = _isTeacherMode 
        ? "${_studentName} - Çözdüğü Soru Sayısı" 
        : "Çözdüğüm Soru Sayısı";
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title, // YENİ: Dinamik başlık
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        // Tab yerine AYT sayfasına geçiş butonu
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.85),
            ),
            child: Row(
              children: [
                // TYT seçili tab
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
                        "TYT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                // AYT tab (tıklanabilir)
                Expanded(
                  child: InkWell(
                    onTap: _goToAytPage,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          "AYT",
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
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : _solvedQuestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book_outlined, 
                        size: 80,
                        color: _primaryColor.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        // YENİ: Öğretmen moduna göre metin
                        _isTeacherMode
                          ? "Henüz TYT sorusu çözülmemiş!"
                          : "Henüz TYT sorusu çözmediniz!",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8),
                      // YENİ: Öğretmen moduna göre bilgilendirme metni
                      Text(
                        _isTeacherMode
                          ? "Bu öğrenci henüz TYT sorusu çözmemiş veya kaydetmemiş."
                          : "Çözdüğünüz soruları kaydetmek için 'Soru Ekle' butonunu kullanabilirsiniz.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 24),
                      // YENİ: Öğretmen modunda soru ekle butonu gösterme
                      if (!_isTeacherMode)
                        ElevatedButton.icon(
                          icon: Icon(Icons.add),
                          label: Text("Soru Ekle"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
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
                                  color: _primaryColor,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  // YENİ: Öğretmen moduna göre başlık
                                  _isTeacherMode
                                    ? "$_studentName - TYT Çözülen Sorular"
                                    : "TYT Çözülen Sorular",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryColor,
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
                              headingRowColor: MaterialStateProperty.all(_lightColor),
                              headingTextStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _darkColor,
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
      // YENİ: Öğretmen modunda kaydetme butonu gösterme
      floatingActionButton: _isTeacherMode ? null : FloatingActionButton(
        onPressed: _addSolvedQuestion,
        child: Icon(Icons.add),
        backgroundColor: _primaryColor,
        elevation: 4,
      ),
    );
  }
}

// Sadece TYT dersleri için dialog
class TYTQuestionInputDialog extends StatefulWidget {
  final Color themeColor;
  
  TYTQuestionInputDialog({required this.themeColor});

  @override
  _TYTQuestionInputDialogState createState() => _TYTQuestionInputDialogState();
}

class _TYTQuestionInputDialogState extends State<TYTQuestionInputDialog> {
  final TextEditingController _matematikController = TextEditingController();
  final TextEditingController _turkceController = TextEditingController();
  final TextEditingController _sosyalController = TextEditingController();
  final TextEditingController _fenController = TextEditingController();
  
  int _total = 0;
  
  @override
  void initState() {
    super.initState();
    // Controllers değişikliklerini dinle ve toplam hesapla
    _matematikController.addListener(_updateTotal);
    _turkceController.addListener(_updateTotal);
    _sosyalController.addListener(_updateTotal);
    _fenController.addListener(_updateTotal);
  }
  
  @override
  void dispose() {
    _matematikController.dispose();
    _turkceController.dispose();
    _sosyalController.dispose();
    _fenController.dispose();
    super.dispose();
  }
  
  void _updateTotal() {
    setState(() {
      _total = (int.tryParse(_matematikController.text) ?? 0) +
              (int.tryParse(_turkceController.text) ?? 0) +
              (int.tryParse(_sosyalController.text) ?? 0) +
              (int.tryParse(_fenController.text) ?? 0);
    });
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
            child: Text(
              'TYT Çözdüğünüz Soru Sayısı',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.themeColor,
              ),
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
                  children: [
                    _buildInputField(_matematikController, 'Matematik', Icons.calculate_outlined),
                    SizedBox(height: 12),
                    _buildInputField(_turkceController, 'Türkçe', Icons.menu_book_outlined),
                    SizedBox(height: 12),
                    _buildInputField(_sosyalController, 'Sosyal Bilimler', Icons.public_outlined),
                    SizedBox(height: 12),
                    _buildInputField(_fenController, 'Fen Bilimleri', Icons.science_outlined),
                  ],
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
            Map<String, dynamic> result = {
              'Matematik': int.tryParse(_matematikController.text) ?? 0,
              'Türkçe': int.tryParse(_turkceController.text) ?? 0,
              'Sosyal': int.tryParse(_sosyalController.text) ?? 0,
              'Fen': int.tryParse(_fenController.text) ?? 0,
            };
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

  Widget _buildInputField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        prefixIcon: Icon(
          icon,
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
    );
  }
}