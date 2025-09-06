import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:yksgunluk/dumenden/app_state.dart';
import 'package:yksgunluk/ders_programi/not.dart';
import 'package:intl/intl.dart';
import 'package:yksgunluk/teacher_mode.dart';

class DersProgrami extends StatefulWidget {
  // Öğretmen modu için parametreler eklendi
  final String? studentId; // Öğretmen modunda öğrencinin ID'si
  final String? studentName; // Öğretmen modunda öğrencinin adı

  DersProgrami({
    Key? key,
    this.studentId,
    this.studentName,
  }) : super(key: key);

  @override
  _DersProgramiState createState() => _DersProgramiState();
}

class _DersProgramiState extends State<DersProgrami> {
  final List<String> _tytSubjects = [
    "Matematik",
    "Fizik",
    "Kimya",
    "Biyoloji",
    "Edebiyat",
    "Tarih",
    "Coğrafya"
  ];

  // Bölüme göre AYT dersleri
  List<String> _getAytSubjects(String bolum) {
    switch (bolum) {
      case "Sayısal":
        return ["Matematik", "Fizik", "Kimya", "Biyoloji"];
      case "Eşit Ağırlık":
        return ["Edebiyat", "Tarih", "Coğrafya", "Matematik"];
      case "Sözel":
        return ["Edebiyat", "Felsefe", "Coğrafya", "Tarih"];
      default:
        return [];
    }
  }

  Map<String, Map<String, String>> _schedule = {};
  Map<int, TextEditingController> _hourControllers = {};
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _selectedWeek = 0;
  final ScrollController _scrollController = ScrollController();
  final double _dayColumnWidth = 150.0;
  
  // Verimlilik değeri
  double _productivityValue = 50.0;
  
  // Not defteri için kontrolcüler
  TextEditingController _usefulNotesController = TextEditingController();
  TextEditingController _nonUsefulNotesController = TextEditingController();

  // Öğretmen modu kontrolü için getter
  bool get _isTeacherMode => Provider.of<TeacherModeProvider>(context, listen: false).isTeacherMode;
  String? get _studentId => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentId;
  String? get _studentName => Provider.of<TeacherModeProvider>(context, listen: false).selectedStudentName;

  @override
  void initState() {
    super.initState();
    _initializeSchedule();
    _initializeHourControllers();
    _selectedWeek = _focusedDay.weekOfYear;
    _loadSchedule();
    _loadProductivityAndNotes();
  }

  @override
  void dispose() {
    _hourControllers.forEach((_, controller) => controller.dispose());
    _usefulNotesController.dispose();
    _nonUsefulNotesController.dispose();
    super.dispose();
  }

  void _initializeSchedule() {
    for (var day = 0; day < 7; day++) {
      _schedule[day.toString()] = {};
    }
  }

  void _initializeHourControllers() {
    for (var i = 0; i < 7; i++) {
      _hourControllers[i] = TextEditingController(text: "08:00-09:00");
    }
  }

  Future<void> _loadSchedule() async {
    // Öğretmen modunda seçilen öğrencinin ID'sini kullan, değilse kullanıcının kendi ID'sini
    String userId;
    if (_isTeacherMode) {
      userId = _studentId ?? '';
      if (userId.isEmpty) return;
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      userId = user.uid;
    }
    
    try {
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('schedules')
          .doc(_selectedWeek.toString())
          .get();
      final data = doc.data();
      setState(() {
        if (data != null) {
          // Schedule
          if (data['schedule'] != null) {
            final scheduleMap = Map<String, dynamic>.from(data['schedule']);
            for (var day = 0; day < 7; day++) {
              final dayMap = scheduleMap[day.toString()] ?? {};
              _schedule[day.toString()] = Map<String, String>.from(dayMap);
            }
          } else {
            _initializeSchedule();
          }
          // Hours
          if (data['hours'] != null) {
            final hoursMap = Map<String, dynamic>.from(data['hours']);
            for (var hour = 0; hour < 7; hour++) {
              _hourControllers[hour]?.text = hoursMap[hour.toString()] ?? "08:00-09:00";
            }
          } else {
            _initializeHourControllers();
          }
        } else {
          _initializeSchedule();
          _initializeHourControllers();
        }
      });
    } catch (e) {
      // Hata olursa varsayılanları kullan
      setState(() {
        _initializeSchedule();
        _initializeHourControllers();
      });
    }
  }

  Future<void> _loadProductivityAndNotes() async {
    // Öğretmen modunda seçilen öğrencinin ID'sini kullan, değilse kullanıcının kendi ID'sini
    String userId;
    if (_isTeacherMode) {
      userId = _studentId ?? '';
      if (userId.isEmpty) return;
    } else {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      userId = user.uid;
    }
    
    try {
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('scheduleNotes')
          .doc(_selectedWeek.toString())
          .get();
      
      final data = doc.data();
      if (data != null) {
        setState(() {
          _productivityValue = (data['productivity'] ?? 50.0).toDouble();
          _usefulNotesController.text = data['usefulNotes'] ?? '';
          _nonUsefulNotesController.text = data['nonUsefulNotes'] ?? '';
        });
      } else {
        setState(() {
          _productivityValue = 50.0;
          _usefulNotesController.text = '';
          _nonUsefulNotesController.text = '';
        });
      }
    } catch (e) {
      setState(() {
        _productivityValue = 50.0;
        _usefulNotesController.text = '';
        _nonUsefulNotesController.text = '';
      });
    }
  }

  Future<void> _saveSchedule() async {
    // Öğretmen modunda değişiklik yapılamaz
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Öğretmen modunda değişiklik yapamazsınız!'), backgroundColor: Colors.red)
      );
      return;
    }
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    Map<String, Map<String, String>> scheduleForFirebase = {};
    for (var day = 0; day < 7; day++) {
      scheduleForFirebase[day.toString()] = {};
      for (var hour = 0; hour < 7; hour++) {
        scheduleForFirebase[day.toString()]![hour.toString()] =
            _schedule[day.toString()]![hour.toString()] ?? "";
      }
    }
    Map<String, String> hoursForFirebase = {};
    for (var hour = 0; hour < 7; hour++) {
      hoursForFirebase[hour.toString()] = _hourControllers[hour]?.text ?? "08:00-09:00";
    }
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .doc(_selectedWeek.toString())
        .set({
      'schedule': scheduleForFirebase,
      'hours': hoursForFirebase,
    }, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ders programı ve saatler kaydedildi!')));
  }
  
  Future<void> _saveProductivity(double value) async {
    // Öğretmen modunda değişiklik yapılamaz
    if (_isTeacherMode) {
      return; // Sessizce başarısız olsun
    }
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scheduleNotes')
        .doc(_selectedWeek.toString())
        .set({
      'productivity': value,
    }, SetOptions(merge: true));
  }
  
  Future<void> _saveUsefulNotes() async {
    // Öğretmen modunda değişiklik yapılamaz
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Öğretmen modunda değişiklik yapamazsınız!'), backgroundColor: Colors.red)
      );
      return;
    }
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scheduleNotes')
        .doc(_selectedWeek.toString())
        .set({
      'usefulNotes': _usefulNotesController.text,
    }, SetOptions(merge: true));
    
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Faydalı notlar kaydedildi!')));
  }

  Future<void> _saveNonUsefulNotes() async {
    // Öğretmen modunda değişiklik yapılamaz
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Öğretmen modunda değişiklik yapamazsınız!'), backgroundColor: Colors.red)
      );
      return;
    }
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('scheduleNotes')
        .doc(_selectedWeek.toString())
        .set({
      'nonUsefulNotes': _nonUsefulNotesController.text,
    }, SetOptions(merge: true));
    
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Geliştirilebilir notlar kaydedildi!')));
  }

  void _scrollToDay(int dayIndex) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double tableWidth = _dayColumnWidth * 8;
    final double visibleTableWidth = screenWidth < tableWidth ? screenWidth : tableWidth;
    final double offset = dayIndex * _dayColumnWidth - (visibleTableWidth - _dayColumnWidth) / 2;

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // Saat stringini TimeOfDay'a çeviren yardımcı fonksiyon
  TimeOfDay? _parseTime(String input) {
    try {
      if (input.contains(":")) {
        List<String> parts = input.split(":");
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Yeni saat aralığı seçici modal
  Future<void> _showHourRangePicker(int hourIndex) async {
    // Öğretmen modunda düzenlemeyi engelle
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Öğretmen modunda değişiklik yapamazsınız!'), backgroundColor: Colors.red)
      );
      return;
    }
    
    // Mevcut değeri al ve parçala
    String currentValue = _hourControllers[hourIndex]!.text;
    List<String> parts = currentValue.split("-");
    
    // Varsayılan değerler
    TimeOfDay startTime = TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = TimeOfDay(hour: 9, minute: 0);
    
    // Mevcut değerler varsa ayrıştır
    if (parts.length == 2) {
      TimeOfDay? parsedStart = _parseTime(parts[0].trim());
      TimeOfDay? parsedEnd = _parseTime(parts[1].trim());
      
      if (parsedStart != null) startTime = parsedStart;
      if (parsedEnd != null) endTime = parsedEnd;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başlık
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Saat Aralığı Seçin",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(height: 30),
                  
                  // Başlangıç ve Bitiş Saati Seçicileri
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Başlangıç saati seçici
                      _buildTimeSelector(
                        title: "Başlangıç",
                        time: startTime,
                        onChanged: (TimeOfDay newTime) {
                          // Yeni zaman bitiş saatinden önce olmalı
                          if (newTime.hour < endTime.hour || 
                             (newTime.hour == endTime.hour && newTime.minute < endTime.minute)) {
                            setModalState(() {
                              startTime = newTime;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Başlangıç saati bitiş saatinden önce olmalıdır!'))
                            );
                          }
                        },
                        color: Colors.lightBlue,
                      ),
                      
                      Text("→", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
                      
                      // Bitiş saati seçici
                      _buildTimeSelector(
                        title: "Bitiş",
                        time: endTime,
                        onChanged: (TimeOfDay newTime) {
                          // Yeni zaman başlangıç saatinden sonra olmalı
                          if (newTime.hour > startTime.hour || 
                             (newTime.hour == startTime.hour && newTime.minute > startTime.minute)) {
                            setModalState(() {
                              endTime = newTime;
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Bitiş saati başlangıç saatinden sonra olmalıdır!'))
                            );
                          }
                        },
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 40),
                  
                  // Hazır Zaman Aralıkları Butonları
                  Text(
                    "Hızlı Seçim",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildQuickTimeButton(
                        "45 dk", 
                        () {
                          setModalState(() {
                            endTime = TimeOfDay(
                              hour: startTime.hour + (startTime.minute + 45) ~/ 60,
                              minute: (startTime.minute + 45) % 60,
                            );
                          });
                        }
                      ),
                      _buildQuickTimeButton(
                        "1 saat", 
                        () {
                          setModalState(() {
                            endTime = TimeOfDay(
                              hour: startTime.hour + 1,
                              minute: startTime.minute,
                            );
                          });
                        }
                      ),
                      _buildQuickTimeButton(
                        "1.5 saat", 
                        () {
                          setModalState(() {
                            endTime = TimeOfDay(
                              hour: startTime.hour + 1 + (startTime.minute + 30) ~/ 60,
                              minute: (startTime.minute + 30) % 60,
                            );
                          });
                        }
                      ),
                      _buildQuickTimeButton(
                        "2 saat", 
                        () {
                          setModalState(() {
                            endTime = TimeOfDay(
                              hour: startTime.hour + 2,
                              minute: startTime.minute,
                            );
                          });
                        }
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Kaydet ve İptal Butonları
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text("İptal", style: TextStyle(color: Colors.grey.shade700)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Saatleri formatlayıp controller'a atama
                            String formattedStart = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
                            String formattedEnd = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";
                            
                            setState(() {
                              _hourControllers[hourIndex]!.text = "$formattedStart-$formattedEnd";
                            });
                            
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text("Kaydet", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Hızlı zaman butonları için widget
  Widget _buildQuickTimeButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // Saat seçici widget
  Widget _buildTimeSelector({
    required String title, 
    required TimeOfDay time, 
    required ValueChanged<TimeOfDay> onChanged,
    required Color color
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              // Saat
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimeButton(
                    icon: Icons.arrow_drop_up,
                    onPressed: () {
                      onChanged(TimeOfDay(
                        hour: (time.hour + 1) % 24,
                        minute: time.minute,
                      ));
                    },
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              // Dakika
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimeButton(
                    icon: Icons.arrow_drop_down,
                    onPressed: () {
                      onChanged(TimeOfDay(
                        hour: (time.hour - 1 + 24) % 24,
                        minute: time.minute,
                      ));
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
              // Dakika Seçiciler
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMinuteButton(
                    "-15",
                    () {
                      int newMinute = time.minute - 15;
                      int newHour = time.hour;
                      if (newMinute < 0) {
                        newMinute = 60 + newMinute;
                        newHour = (newHour - 1 + 24) % 24;
                      }
                      onChanged(TimeOfDay(hour: newHour, minute: newMinute));
                    },
                    color,
                  ),
                  SizedBox(width: 4),
                  _buildMinuteButton(
                    "+15",
                    () {
                      int newMinute = time.minute + 15;
                      int newHour = time.hour;
                      if (newMinute >= 60) {
                        newMinute = newMinute - 60;
                        newHour = (newHour + 1) % 24;
                      }
                      onChanged(TimeOfDay(hour: newHour, minute: newMinute));
                    },
                    color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Saat arttırma/azaltma butonu
  Widget _buildTimeButton({required IconData icon, required VoidCallback onPressed}) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      padding: EdgeInsets.all(4),
      constraints: BoxConstraints(),
      iconSize: 32,
      color: Colors.grey.shade700,
    );
  }

  // Dakika arttırma/azaltma butonu
  Widget _buildMinuteButton(String label, VoidCallback onPressed, Color color) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildHourInput(int hourIndex) {
    // Öğretmen moduna göre görünüm değişikliği
    bool isEnabled = !_isTeacherMode;
    
    return GestureDetector(
      onTap: isEnabled ? () => _showHourRangePicker(hourIndex) : null,
      child: Container(
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.shade100, // Öğretmen modunda daha soluk
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: isEnabled ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ] : [],
        ),
        padding: EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 18, color: isEnabled ? Colors.blueAccent : Colors.grey),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                _hourControllers[hourIndex]?.text ?? "08:00-09:00",
                style: TextStyle(
                  color: isEnabled ? Colors.black : Colors.grey.shade700,
                  fontSize: 16.0
                ),
                textAlign: TextAlign.center,
              ),
            ),
            isEnabled ? Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey) : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  // Modern & şık seçim ekranı (modal bottom sheet)
  Future<void> _showSubjectPicker(BuildContext context, String day, String hour) async {
    // Öğretmen modunda düzenlemeyi engelle
    if (_isTeacherMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Öğretmen modunda değişiklik yapamazsınız!'), backgroundColor: Colors.red)
      );
      return;
    }
    
    final appState = Provider.of<AppState>(context, listen: false);
    final bolum = appState.selectedBolum; // "Sayısal", "Eşit Ağırlık", "Sözel"
    final aytSubjects = _getAytSubjects(bolum);

    int pageIndex = 0;
    String? selectedSubject = '';
    String? selectedType = '';
    String? raw = _schedule[day]?[hour];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        selectedSubject = decoded["subject"] ?? "";
        selectedType = decoded["type"] ?? "";
      } catch (_) {
        selectedSubject = raw;
        selectedType = "";
      }
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 250),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: 0, right: 0,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.only(top: 8, bottom: 24, left: 12, right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 6,
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Text(
                    "Ders Seç",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blueAccent),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 220,
                    child: PageView(
                      onPageChanged: (i) { setStateDialog(() { pageIndex = i; }); },
                      children: [
                        // TYT
                        _buildSubjectGrid(
                          title: "TYT",
                          subjects: _tytSubjects,
                          selectedSubject: selectedSubject,
                          selectedType: selectedType,
                          type: "TYT",
                          color: Color(0xFFBBDEFB), // açık mavi
                          accent: Color(0xFF1976D2), // canlı mavi
                          onTap: (subject) {
                            setState(() {
                              _schedule[day]![hour] = jsonEncode({"subject": subject, "type": "TYT"});
                            });
                            Navigator.pop(context);
                          },
                        ),
                        // AYT
                        _buildSubjectGrid(
                          title: "AYT (${bolum.isNotEmpty ? bolum : 'bölüm seçilmedi'})",
                          subjects: aytSubjects,
                          selectedSubject: selectedSubject,
                          selectedType: selectedType,
                          type: "AYT",
                          color: Color(0xFFE1BEE7), // açık mor
                          accent: Color(0xFF8E24AA), // canlı mor
                          onTap: (subject) {
                            setState(() {
                              _schedule[day]![hour] = jsonEncode({"subject": subject, "type": "AYT"});
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: pageIndex == 0 ? 28 : 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: pageIndex == 0 ? Color(0xFF1976D2) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        margin: EdgeInsets.symmetric(horizontal: 3),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: pageIndex == 1 ? 28 : 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: pageIndex == 1 ? Color(0xFF8E24AA) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        margin: EdgeInsets.symmetric(horizontal: 3),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text("Yana kaydır: TYT / AYT", style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          );
        });
      },
    );
    setState(() {});
  }
  
  // Faydalı notlar için tam ekran dialog
  Future<void> _showUsefulNotesDialog() async {
    // Öğretmen modunda salt okunur
    final bool isReadOnly = _isTeacherMode;
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text("Programın Faydalı Kısımları", style: TextStyle(color: Colors.green.shade700,
              fontSize: 20
              )),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: isReadOnly ? Colors.green.shade50.withOpacity(0.7) : Colors.green.shade50,
                    ),
                    child: TextField(
                      controller: _usefulNotesController,
                      readOnly: isReadOnly, // Öğretmen modunda salt okunur
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(16),
                        hintText: isReadOnly ? "Herhangi bir not bulunmuyor" : "Programın faydalı yönlerini yazın...",
                        border: InputBorder.none,
                      ),
                      maxLines: 10,
                      style: TextStyle(fontSize: 16, color: isReadOnly ? Colors.grey.shade700 : Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isReadOnly ? "Kapat" : "İptal", style: TextStyle(color: Colors.grey.shade700)),
            ),
            // Öğretmen modunda kaydet butonu gösterme
            if (!isReadOnly)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                ),
                onPressed: () {
                  _saveUsefulNotes();
                  Navigator.pop(context);
                },
                child: Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        );
      },
    );
  }
  
  // Faydalı olmayan notlar için tam ekran dialog
  Future<void> _showNonUsefulNotesDialog() async {
    // Öğretmen modunda salt okunur
    final bool isReadOnly = _isTeacherMode;
    
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 10),
              Text("Geliştirilebilir Kısımlar", style: TextStyle(color: Colors.red.shade700)),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: isReadOnly ? Colors.red.shade50.withOpacity(0.7) : Colors.red.shade50,
                    ),
                    child: TextField(
                      controller: _nonUsefulNotesController,
                      readOnly: isReadOnly, // Öğretmen modunda salt okunur
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.all(16),
                        hintText: isReadOnly ? "Herhangi bir not bulunmuyor" : "Programın geliştirilebilir yönlerini yazın...",
                        border: InputBorder.none,
                      ),
                      maxLines: 10,
                      style: TextStyle(fontSize: 16, color: isReadOnly ? Colors.grey.shade700 : Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isReadOnly ? "Kapat" : "İptal", style: TextStyle(color: Colors.grey.shade700)),
            ),
            // Öğretmen modunda kaydet butonu gösterme
            if (!isReadOnly)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                ),
                onPressed: () {
                  _saveNonUsefulNotes();
                  Navigator.pop(context);
                },
                child: Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSubjectGrid({
    required String title,
    required List<String> subjects,
    required String? selectedSubject,
    required String? selectedType,
    required String type,
    required Color color,
    required Color accent,
    required Function(String) onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: accent)),
        SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.7,
            physics: BouncingScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            children: subjects.map((subject) {
              final isSelected = selectedSubject == subject && selectedType == type;
              return GestureDetector(
                onTap: () => onTap(subject),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected ? accent : color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? accent : color,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: accent.withOpacity(0.22), blurRadius: 8, offset: Offset(0, 2))]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    subject,
                    style: TextStyle(
                      color: isSelected ? Colors.white : accent,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectPickerCell(String day, String hour) {
    // Öğretmen moduna göre görünüm değişikliği
    bool isEnabled = !_isTeacherMode;
    
    String? raw = _schedule[day]?[hour];
    String selectedSubject = "";
    String selectedType = "";
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        selectedSubject = decoded["subject"] ?? "";
        selectedType = decoded["type"] ?? "";
      } catch (_) {
        selectedSubject = raw;
        selectedType = "";
      }
    }

    final appState = Provider.of<AppState>(context, listen: false);
    final bolum = appState.selectedBolum;
    final aytSubjects = _getAytSubjects(bolum);

    final isTYT = selectedType == "TYT";
    final isAYT = selectedType == "AYT";

    // Belirgin renkler
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    FontWeight textWeight = FontWeight.w600;

    if (isTYT) {
      bgColor = Color(0xFF1976D2); // canlı mavi
      textColor = Colors.white;
      textWeight = FontWeight.bold;
    }
    if (isAYT) {
      bgColor = Color(0xFF8E24AA); // canlı mor
      textColor = Colors.white;
      textWeight = FontWeight.bold;
    }

    // Seçili değilse açık tonlar
    if (selectedSubject.isEmpty) {
      bgColor = Colors.grey.shade100;
      textColor = Colors.black54;
      textWeight = FontWeight.w600;
    }
    
    // Öğretmen modunda soluk göster
    if (!isEnabled && (isTYT || isAYT)) {
      bgColor = bgColor.withOpacity(0.7);
    }

    return GestureDetector(
      onTap: isEnabled ? () => _showSubjectPicker(context, day, hour) : null,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 2, horizontal: 0),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: (isTYT) ? Color(0xFF1976D2) : (isAYT ? Color(0xFF8E24AA) : Colors.grey.shade300),
            width: (isTYT || isAYT) && isEnabled ? 2.5 : 1,
          ),
          boxShadow: (isTYT || isAYT) && isEnabled
              ? [BoxShadow(color: bgColor.withOpacity(0.18), blurRadius: 7, offset: Offset(0, 2))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          selectedSubject.isNotEmpty ? selectedSubject : isEnabled ? "Seçiniz" : "-",
          style: TextStyle(
            color: textColor,
            fontWeight: textWeight,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String _getDayName(int index) {
    switch (index) {
      case 0:
        return "Pazartesi";
      case 1:
        return "Salı";
      case 2:
        return "Çarşamba";
      case 3:
        return "Perşembe";
      case 4:
        return "Cuma";
      case 5:
        return "Cumartesi";
      case 6:
        return "Pazar";
      default:
        return "";
    }
  }
  
  // Verimlilik çizelgesi için renk hesaplama
  Color _getProductivityColor(double value) {
    if (value <= 50) {
      // 1-50 arası kırmızıdan sarıya geçiş
      double ratio = value / 50;
      return Color.lerp(Colors.red, Colors.yellow, ratio)!;
    } else {
      // 51-100 arası sarıdan yeşile geçiş
      double ratio = (value - 50) / 50;
      return Color.lerp(Colors.yellow, Colors.green, ratio)!;
    }
  }
  
  Widget _buildProductivitySlider() {
    // Öğretmen moduna göre görünüm değişikliği
    final bool isReadOnly = _isTeacherMode;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Verimlilik Çizelgesi",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text("1", style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _getProductivityColor(_productivityValue),
                    inactiveTrackColor: Colors.grey.shade300,
                    thumbColor: _getProductivityColor(_productivityValue),
                    overlayColor: _getProductivityColor(_productivityValue).withOpacity(0.2),
                    trackHeight: 8.0,
                    thumbShape: RoundSliderThumbShape(
                      enabledThumbRadius: isReadOnly ? 6.0 : 10.0, // Öğretmen modunda küçük göster
                    ),
                  ),
                  child: Slider(
                    min: 1,
                    max: 100,
                    divisions: 99,
                    value: _productivityValue,
                    label: _productivityValue.round().toString(),
                    onChanged: isReadOnly ? null : (value) { // Öğretmen modunda değiştirilemiyor
                      setState(() {
                        _productivityValue = value;
                      });
                      _saveProductivity(value);
                    },
                  ),
                ),
              ),
              Text("100", style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Center(
          child: Text(
            "Verimlilik: ${_productivityValue.round()}/100",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getProductivityColor(_productivityValue),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildNotepadButtons() {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hafta ${_selectedWeek} Notları",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800
            ),
          ),
          SizedBox(height: 16),
          
          // Faydalı notlar butonu
          InkWell(
            onTap: _showUsefulNotesDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade300, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    "Faydalı Kısımlar",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16)
                ],
              ),
            ),
          ),
          
          SizedBox(height: 14),
          
          // Faydalı olmayan notlar butonu
          InkWell(
            onTap: _showNonUsefulNotesDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade300, Colors.red.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    "Geliştirilebilir Kısımlar",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: () {
              setState(() {
                _focusedDay = _focusedDay.subtract(Duration(days: 7));
                _selectedWeek = _focusedDay.weekOfYear;
              });
              _loadSchedule();
              _loadProductivityAndNotes();
            },
          ),
          Text(
            "Hafta ${_selectedWeek}",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios),
            onPressed: () {
              setState(() {
                _focusedDay = _focusedDay.add(Duration(days: 7));
                _selectedWeek = _focusedDay.weekOfYear;
              });
              _loadSchedule();
              _loadProductivityAndNotes();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Öğretmen modu kontrolü ve başlık özelleştirme
    final String title = _isTeacherMode 
        ? "${_studentName} - Ders Programı" 
        : "Ders Programı";
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.lightBlue,
        actions: [
          // Öğretmen modunda not defteri butonunu gizle
          if (!_isTeacherMode)
            IconButton(
              icon: Icon(Icons.note_add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NotePage()),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {
                CalendarFormat.week: 'Haftalık',
              },
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                  _selectedWeek = _focusedDay.weekOfYear;
                });
                _scrollToDay(focusedDay.weekday - 1);
                _loadSchedule();
                _loadProductivityAndNotes();
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                  _selectedWeek = _focusedDay.weekOfYear;
                });
                _loadSchedule();
                _loadProductivityAndNotes();
              },
            ),
            
            // Hafta seçici
            _buildWeekSelector(),
            
            // Ders programı tablosu
            Container(
              height: 400,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16.0,
                  headingRowColor: MaterialStateColor.resolveWith((states) => Colors.lightBlue.shade400),
                  columns: [
                    DataColumn(
                      label: Container(
                        padding: EdgeInsets.all(12.0),
                        child: Text("Saatler",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18.0)),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade400,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                    ...List.generate(7, (index) {
                      return DataColumn(
                        label: Container(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            _getDayName(index),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                          ),
                        ),
                      );
                    }),
                  ],
                  rows: List.generate(7, (hourIndex) {
                    return DataRow(cells: [
                      DataCell(_buildHourInput(hourIndex)),
                      ...List.generate(7, (dayIndex) {
                        return DataCell(
                          _buildSubjectPickerCell(dayIndex.toString(), hourIndex.toString()),
                        );
                      }),
                    ]);
                  }),
                ),
              ),
            ),
            
            Divider(thickness: 1.5),
            
            // Verimlilik çizelgesi ve not butonları
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verimlilik çizelgesi
                _buildProductivitySlider(),
                
                // Not butonları
                _buildNotepadButtons(),
              ],
            ),
            
            SizedBox(height: 20),
          ],
        ),
      ),
      // Öğretmen modunda kaydet butonunu gizle
      floatingActionButton: _isTeacherMode ? null : FloatingActionButton(
        onPressed: _saveSchedule,
        backgroundColor: Colors.lightBlue,
        child: Icon(Icons.save),
      ),
    );
  }
}

extension DateTimeExtensions on DateTime {
  int get weekOfYear {
    final firstDayOfYear = DateTime(this.year, 1, 1);
    final firstMondayOfYear =
        firstDayOfYear.add(Duration(days: (7 - firstDayOfYear.weekday) % 7));
    final daysSinceFirstMonday = this.difference(firstMondayOfYear).inDays;
    return (daysSinceFirstMonday / 7).ceil();
  }
}