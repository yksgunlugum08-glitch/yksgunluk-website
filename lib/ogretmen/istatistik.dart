import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:yksgunluk/icon_penceler/haftalik_veri/ayt_soru.dart';
import 'package:yksgunluk/icon_penceler/toplam_ilermem.dart';

class StudentStatisticsPage extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentStatisticsPage({
    Key? key,
    required this.studentId,
    required this.studentName,
  }) : super(key: key);

  @override
  State<StudentStatisticsPage> createState() => _StudentStatisticsPageState();
}

class _StudentStatisticsPageState extends State<StudentStatisticsPage> {
  bool _isLoading = true;
  Map<String, dynamic> _studentData = {};
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _sentMessages = [];
  String _teacherId = '';

  @override
  void initState() {
    super.initState();
    _loadTeacherId();
    _loadStudentData();
    _loadSentMessages();
  }

  Future<void> _loadTeacherId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _teacherId = user.uid;
    }
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    
    try {
      // Öğrenci temel verilerini al
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .get();

      if (studentDoc.exists) {
        _studentData = studentDoc.data()!;
      }

      // Son 4 haftanın verilerini al
      final now = DateTime.now();
      List<Map<String, dynamic>> weeklyStats = [];

      for (int i = 0; i < 4; i++) {
        final weekStart = now.subtract(Duration(days: (i * 7) + now.weekday - 1));
        final weekEnd = weekStart.add(Duration(days: 6));

        final weekData = await _getWeeklyData(weekStart, weekEnd);
        weeklyStats.add({
          'week': 'Hafta ${i + 1}',
          'startDate': weekStart,
          'endDate': weekEnd,
          ...weekData,
        });
      }

      setState(() {
        _weeklyData = weeklyStats;
        _isLoading = false;
      });

    } catch (e) {
      print('Veri yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSentMessages() async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('mentorMesajlari')
          .where('ogretmenId', isEqualTo: _teacherId)
          .where('ogrenciId', isEqualTo: widget.studentId)
          .orderBy('tarih', descending: true)
          .limit(10)
          .get();

      setState(() {
        _sentMessages = messagesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      print('Mesajlar yüklenirken hata: $e');
    }
  }

  Future<Map<String, dynamic>> _getWeeklyData(DateTime start, DateTime end) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.studentId)
          .collection('calismaVerileri')
          .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('tarih', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      int totalStudyTime = 0;
      int totalQuestions = 0;
      int studyDays = 0;

      Set<String> uniqueDays = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalStudyTime += (data['calismaSuresi'] ?? 0) as int;
        totalQuestions += (data['cozilenSoru'] ?? 0) as int;
        
        final date = (data['tarih'] as Timestamp).toDate();
        final dayKey = DateFormat('yyyy-MM-dd').format(date);
        uniqueDays.add(dayKey);
      }

      studyDays = uniqueDays.length;

      return {
        'totalStudyTime': totalStudyTime,
        'totalQuestions': totalQuestions,
        'studyDays': studyDays,
        'avgDailyTime': studyDays > 0 ? (totalStudyTime / studyDays).round() : 0,
      };
    } catch (e) {
      print('Haftalık veri alma hatası: $e');
      return {
        'totalStudyTime': 0,
        'totalQuestions': 0,
        'studyDays': 0,
        'avgDailyTime': 0,
      };
    }
  }

  String formatMinutesToHourMinute(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}s ${remainingMinutes}dk';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Bilinmiyor';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Bilinmiyor';
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Bugün ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Dün ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName} - İstatistikler'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadStudentData();
              _loadSentMessages();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Öğrenci Bilgi Kartı
                  _buildStudentInfoCard(),
                  SizedBox(height: 20),

                  // İstatistik Butonları
                  _buildStatisticsButtons(),
                  SizedBox(height: 30),

                  // Tavsiye Mesajı Gönder Bölümü
                  _buildAdviceMessageSection(),
                  SizedBox(height: 30),

                  // Gönderilen Mesajlar Bölümü
                  _buildSentMessagesSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.purple.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(
              widget.studentName.isNotEmpty
                  ? '${widget.studentName.split(' ')[0][0]}${widget.studentName.split(' ').length > 1 ? widget.studentName.split(' ')[1][0] : ''}'
                  : '??',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            widget.studentName,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'İstatistik ve İlerleme Takibi',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsButtons() {
    return Column(
      children: [
        // Toplam İlerleme Butonu
        _buildStatButton(
          title: 'Toplam İlerleme',
          subtitle: 'Genel performans analizi',
          icon: Icons.trending_up,
          color: Colors.blue,
          onTap: () => _navigateToTotalProgress(),
        ),
        SizedBox(height: 16),
        
        // Haftalık İlerleme Butonu
        _buildStatButton(
          title: 'Haftalık İlerleme',
          subtitle: 'Son 4 haftanın detayları',
          icon: Icons.calendar_view_week,
          color: Colors.green,
          onTap: () => _navigateToWeeklyProgress(),
        ),
      ],
    );
  }

  Widget _buildStatButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAdviceMessageSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 28),
              SizedBox(width: 12),
              Text(
                'Tavsiye Mesajı Gönder',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '${widget.studentName} adlı öğrencinize motivasyon ve tavsiye mesajı gönderin.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAdviceMessageDialog(),
              icon: Icon(Icons.send),
              label: Text('Mesaj Gönder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentMessagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: Colors.blue.shade700, size: 24),
            SizedBox(width: 8),
            Text(
              'Gönderilen Mesajlar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Spacer(),
            Text(
              '(${_sentMessages.length})',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        
        if (_sentMessages.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16),
                Text(
                  'Henüz Mesaj Gönderilmedi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Bu öğrenciye henüz hiç mesaj göndermediniz',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _sentMessages.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final message = _sentMessages[index];
              return _buildMessageCard(message);
            },
          ),
      ],
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: message['okundu'] == false 
              ? Colors.blue.shade300 
              : Colors.grey.shade200,
          width: message['okundu'] == false ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: message['okundu'] == false 
                      ? Colors.blue.shade100 
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message['okundu'] == false ? 'GÖNDERİLDİ' : 'OKUNDU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: message['okundu'] == false 
                        ? Colors.blue.shade700 
                        : Colors.green.shade700,
                  ),
                ),
              ),
              Spacer(),
              Text(
                _formatDate(message['tarih']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            message['baslik'] ?? 'Başlıksız Mesaj',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            message['mesaj'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if ((message['mesaj'] ?? '').length > 100) ...[
            SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showFullMessage(message),
              child: Text(
                'Tamamını oku →',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullMessage(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.message, color: Colors.blue.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gönderilen Mesaj',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                message['baslik'] ?? 'Başlıksız Mesaj',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message['mesaj'] ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                  SizedBox(width: 4),
                  Text(
                    _formatDate(message['tarih']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: message['okundu'] == false 
                          ? Colors.blue.shade100 
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message['okundu'] == false ? 'Gönderildi' : 'Okundu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: message['okundu'] == false 
                            ? Colors.blue.shade700 
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTotalProgress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChartsPage(
          studentId: widget.studentId,
          studentName: widget.studentName,
        ),
      ),
    );
  }

  void _navigateToWeeklyProgress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AYTGrafik(
          studentId: widget.studentId,
          studentName: widget.studentName,
        ),
      ),
    );
  }

  void _showAdviceMessageDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(24),
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.send, color: Colors.orange.shade700, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tavsiye Mesajı Gönder',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                
                // Başlık Alanı
                Text(
                  'Mesaj Başlığı',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'Örn: Motivasyon Mesajı, Çalışma Tavsiyesi...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.orange.shade600),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 20),
                
                // Mesaj Alanı
                Text(
                  'Mesaj İçeriği',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  constraints: BoxConstraints(
                    minHeight: 150,
                  ),
                  child: TextField(
                    controller: messageController,
                    maxLines: 8,
                    minLines: 6,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: 'Öğrencinize göndermek istediğiniz tavsiye mesajını buraya yazın.\n\nÖrnek:\n- Çalışma rutininizi düzenleyin\n- Zayıf olduğunuz konulara odaklanın\n- Düzenli deneme sınavları çözün\n- Motivasyonunuzu yüksek tutun...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.orange.shade600),
                      ),
                      contentPadding: EdgeInsets.all(16),
                      alignLabelWithHint: true,
                    ),
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
                SizedBox(height: 24),
                
                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('İptal'),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _sendAdviceMessage(titleController.text, messageController.text),
                      icon: Icon(Icons.send, size: 18),
                      label: Text('Gönder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Future<void> _sendAdviceMessage(String title, String message) async {
    if (title.trim().isEmpty || message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen başlık ve mesaj alanlarını doldurun'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Mentor mesajını Firestore'a kaydet
      await FirebaseFirestore.instance.collection('mentorMesajlari').add({
        'ogretmenId': _teacherId,
        'ogrenciId': widget.studentId,
        'ogrenciAdi': widget.studentName,
        'baslik': title.trim(),
        'mesaj': message.trim(),
        'tarih': FieldValue.serverTimestamp(),
        'okundu': false,
      });

      Navigator.pop(context); // Dialog'u kapat

      // Gönderilen mesajları yeniden yükle
      await _loadSentMessages();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tavsiye mesajınız ${widget.studentName} adlı öğrencinize gönderildi!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      print('Mesaj gönderme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj gönderilirken bir hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}