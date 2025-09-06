import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({Key? key}) : super(key: key);

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final TextEditingController _textController = TextEditingController();
  JournalEntry? _currentEntry;
  
  int _currentPage = 0;
  String _selectedFont = 'Roboto';
  double _fontSize = 18;
  bool _isEditMode = true;
  
  final JournalService _journalService = JournalService();
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  // Düzeltilmiş font adları - Google Fonts'un tanıdığı doğru format
  final List<String> _availableFonts = [
    'Roboto',
    'Open Sans',      // Düzeltildi
    'Lato',
    'Montserrat', 
    'Raleway',
    'Merriweather',
    'Playfair Display', // Düzeltildi
    'Poppins',
    'Noto Sans',      // Düzeltildi
    'Nunito Sans',    // Düzeltildi
    'Quicksand',
    'Ubuntu',
    'Source Sans Pro', // Düzeltildi
    'PT Serif',       // Düzeltildi
    'Dancing Script'  // Düzeltildi
  ];

  @override
  void initState() {
    super.initState();
    
    // Türkçe tarih formatları için lokal verileri başlat
    initializeDateFormatting('tr_TR', null).then((_) => _loadEntries());
  }
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // Eski format font adlarını yeni formata dönüştür
  String _normalizeFontName(String fontName) {
    switch (fontName) {
      case 'OpenSans': return 'Open Sans';
      case 'PlayfairDisplay': return 'Playfair Display';
      case 'NotoSans': return 'Noto Sans';
      case 'NunitoSans': return 'Nunito Sans';
      case 'SourceSansPro': return 'Source Sans Pro';
      case 'PTSerif': return 'PT Serif';
      case 'DancingScript': return 'Dancing Script';
      default: return fontName;
    }
  }

  // Günlük kayıtlarını yükle
  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      _entries = await _journalService.getEntries();
      
      if (_entries.isEmpty) {
        _createNewEntry();
      } else {
        _loadEntry(_entries.last);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Günlük kayıtları yüklenirken hata: $e')),
      );
      _createNewEntry();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Yeni günlük girişi oluştur
  void _createNewEntry() {
    final now = DateTime.now();
    _currentEntry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: now,
      content: '',
      fontFamily: _selectedFont,
      fontSize: _fontSize,
    );
    _textController.text = '';
    _isEditMode = true;
  }

  // Günlük girişini yükle
  Future<void> _loadEntry(JournalEntry entry) async {
    _currentEntry = entry;
    _selectedFont = _normalizeFontName(entry.fontFamily);
    _fontSize = entry.fontSize;
    _textController.text = entry.content;
    setState(() => _isEditMode = true);
  }

  // Günlük girişini kaydet
  Future<void> _saveCurrentEntry() async {
    if (_currentEntry != null) {
      try {
        _currentEntry = _currentEntry!.copyWith(
          content: _textController.text,
          fontFamily: _selectedFont,
          fontSize: _fontSize,
        );
        
        await _journalService.saveEntry(_currentEntry!);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Günlük kaydedildi')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydetme hatası: $e')),
        );
      }
    }
  }

  // Font değiştir
  void _onChangeFontFamily(String font) {
    setState(() => _selectedFont = font);
  }

  // Font boyutu değiştir
  void _onChangeFontSize(double size) {
    setState(() => _fontSize = size);
  }
  
  // Belirli bir günlük girişine git
  void _navigateToEntry(int index) {
    if (index >= 0 && index < _entries.length) {
      setState(() => _currentPage = index);
      _loadEntry(_entries[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.brown)),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.brown.shade800),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Günlüğüm',
          style: TextStyle(
            color: Colors.brown.shade800,
            fontFamily: 'Satisfy',
            fontSize: 28,
          ),
        ),
        centerTitle: true,
        actions: [
          // Düzenleme/Önizleme modu
          IconButton(
            icon: Icon(
              _isEditMode ? Icons.visibility : Icons.edit,
              color: Colors.brown.shade800,
            ),
            tooltip: _isEditMode ? 'Önizleme' : 'Düzenle',
            onPressed: () {
              setState(() => _isEditMode = !_isEditMode);
            },
          ),
          // Yeni sayfa
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.brown.shade800, size: 26),
            tooltip: 'Yeni Sayfa',
            onPressed: () {
              _createNewEntry();
              setState(() {});
            },
          ),
          // Kaydet
          IconButton(
            icon: Icon(Icons.save_outlined, color: Colors.brown.shade800, size: 26),
            tooltip: 'Kaydet',
            onPressed: _saveCurrentEntry,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/arkaplan.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Sayfa seçme bölümü
              if (_entries.length > 1)
                Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final dateFormat = DateFormat('d MMM', 'tr_TR');
                      final isSelected = _currentPage == index;
                      
                      return GestureDetector(
                        onTap: () => _navigateToEntry(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.brown.shade300
                                : Colors.brown.shade100.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.brown.shade700
                                  : Colors.brown.shade200,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              dateFormat.format(entry.date),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.brown.shade700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              
              // Ana günlük içeriği
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCF8E8), // Hafif krem rengi kağıt
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: LinePainter(),
                      child: _buildEntryPage(_currentEntry!),
                    ),
                  ),
                ),
              ),
              
              // Font ve font boyutu seçme araç çubuğu
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -1),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Font seçici
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => _buildFontSelector(),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.grey.shade800,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedFont,
                                style: TextStyle(fontFamily: _selectedFont),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_drop_down, size: 18),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Font boyutu seçici
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (_fontSize > 12) {
                                  _onChangeFontSize(_fontSize - 2);
                                }
                              },
                              icon: const Icon(Icons.remove, size: 20),
                              color: Colors.grey.shade800,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${_fontSize.round()}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if (_fontSize < 36) {
                                  _onChangeFontSize(_fontSize + 2);
                                }
                              },
                              icon: const Icon(Icons.add, size: 20),
                              color: Colors.grey.shade800,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Günlük sayfasını oluştur
  Widget _buildEntryPage(JournalEntry entry) {
    final dateFormat = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');
    final formattedDate = dateFormat.format(entry.date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarih başlığı
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.brown.shade300,
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.only(bottom: 8),
            margin: const EdgeInsets.only(bottom: 16),
            child: Text(
              formattedDate,
              style: GoogleFonts.getFont(
                'Lora',
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade800,
                ),
              ),
            ),
          ),
          
          // İçerik - Düzenleme veya Önizleme moduna göre
          Expanded(
            child: _isEditMode
                ? TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    style: GoogleFonts.getFont(
                      _selectedFont,
                      textStyle: TextStyle(
                        fontSize: _fontSize,
                        color: Colors.brown.shade900,
                        height: 1.5,
                      ),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Bugün neler yaşadın?...',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: Colors.black38,
                      ),
                    ),
                  )
                : Markdown(
                    data: _textController.text,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.getFont(
                        _selectedFont,
                        textStyle: TextStyle(
                          fontSize: _fontSize,
                          color: Colors.brown.shade900,
                          height: 1.5,
                        ),
                      ),
                      h1: GoogleFonts.getFont(
                        _selectedFont,
                        textStyle: TextStyle(
                          fontSize: _fontSize + 8,
                          color: Colors.brown.shade900,
                          height: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      h2: GoogleFonts.getFont(
                        _selectedFont,
                        textStyle: TextStyle(
                          fontSize: _fontSize + 6,
                          color: Colors.brown.shade900,
                          height: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      h3: GoogleFonts.getFont(
                        _selectedFont,
                        textStyle: TextStyle(
                          fontSize: _fontSize + 4,
                          color: Colors.brown.shade900,
                          height: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      blockquote: GoogleFonts.getFont(
                        _selectedFont,
                        textStyle: TextStyle(
                          fontSize: _fontSize,
                          color: Colors.brown.shade700,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    selectable: true,
                    shrinkWrap: true,
                  ),
          ),
        ],
      ),
    );
  }
  
  // Font seçici pencere
  Widget _buildFontSelector() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Başlık çubuğu
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: const Center(
              child: Text(
                'Yazı Tipi Seçin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Font listesi
          Expanded(
            child: ListView.builder(
              itemCount: _availableFonts.length,
              itemBuilder: (context, index) {
                final font = _availableFonts[index];
                final isSelected = font == _selectedFont;
                
                return ListTile(
                  title: Text(
                    'AaBbCcÇçĞğİiŞş 123',
                    style: GoogleFonts.getFont(
                      font,
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  subtitle: Text(
                    font,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: Colors.blue.shade400)
                      : null,
                  tileColor: isSelected ? Colors.blue.shade50 : null,
                  onTap: () {
                    _onChangeFontFamily(font);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          
          // Kapat butonu
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kapat'),
            ),
          ),
        ],
      ),
    );
  }
}

// Günlük Girişi Model Sınıfı
class JournalEntry {
  final String id;
  final DateTime date;
  final String content;
  final String fontFamily;
  final double fontSize;

  JournalEntry({
    required this.id,
    required this.date,
    required this.content,
    required this.fontFamily,
    required this.fontSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'content': content,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      date: DateTime.parse(json['date']),
      content: json['content'],
      fontFamily: json['fontFamily'],
      fontSize: (json['fontSize'] as num).toDouble(),
    );
  }

  JournalEntry copyWith({
    String? id,
    DateTime? date,
    String? content,
    String? fontFamily,
    double? fontSize,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      content: content ?? this.content,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

// Günlük Servis Sınıfı
class JournalService {
  static const String _entriesKey = 'journal_entries';

  Future<List<JournalEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList(_entriesKey) ?? [];
    
    return entriesJson
        .map((jsonStr) => JournalEntry.fromJson(json.decode(jsonStr)))
        .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> saveEntry(JournalEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    List<JournalEntry> entries = await getEntries();
    
    // Mevcut girişi güncelle veya yenisini ekle
    final existingIndex = entries.indexWhere((e) => e.id == entry.id);
    if (existingIndex >= 0) {
      entries[existingIndex] = entry;
    } else {
      entries.add(entry);
    }
    
    // Tüm girişleri JSON olarak kaydet
    final entriesJson = entries
        .map((entry) => json.encode(entry.toJson()))
        .toList();
    
    await prefs.setStringList(_entriesKey, entriesJson);
  }

  Future<void> deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<JournalEntry> entries = await getEntries();
    
    entries.removeWhere((entry) => entry.id == id);
    
    final entriesJson = entries
        .map((entry) => json.encode(entry.toJson()))
        .toList();
    
    await prefs.setStringList(_entriesKey, entriesJson);
  }
}

// Çizgili Defter Kağıdı için Custom Painter
class LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade100.withOpacity(0.5)
      ..strokeWidth = 1;

    // Yatay çizgiler çiz (defter çizgileri)
    double lineSpacing = 28.0;
    for (double y = 60; y < size.height - 20; y += lineSpacing) {
      canvas.drawLine(
        Offset(40, y),
        Offset(size.width - 40, y),
        paint,
      );
    }

    // Dikey çizgi (sol kenar)
    final marginPaint = Paint()
      ..color = Colors.red.shade100.withOpacity(0.7)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(40, 40),
      Offset(40, size.height - 40),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}