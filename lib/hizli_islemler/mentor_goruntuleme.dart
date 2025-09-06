import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class MentorViewScreen extends StatefulWidget {
  const MentorViewScreen({Key? key}) : super(key: key);

  @override
  State<MentorViewScreen> createState() => _MentorViewScreenState();
}

class _MentorViewScreenState extends State<MentorViewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _mentorData;
  List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadCurrentUser();
  }

  Future<void> _initializeNotifications() async {
    // Bildirim izinlerini iste
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // FCM token'ını al ve kaydet
      String? token = await _firebaseMessaging.getToken();
      if (token != null && _currentUserId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .update({'fcmToken': token});
      }

      // Foreground mesajları dinle
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    if (message.notification != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.notification!.title ?? 'Yeni Mesaj',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(message.notification!.body ?? ''),
            ],
          ),
          backgroundColor: Colors.deepPurple,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Görüntüle',
            textColor: Colors.white,
            onPressed: () {
              _loadMessages(); // Mesajları yenile
            },
          ),
        ),
      );
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      await _loadMentorData();
      await _loadMessages();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadMentorData() async {
    if (_currentUserId == null) return;

    try {
      // ogretmenOgrenci collection'ından aktif bağlantıyı bul
      final connectionSnapshot = await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .where('ogrenciId', isEqualTo: _currentUserId)
          .where('durum', isEqualTo: 'onaylandı')
          .limit(1)
          .get();

      if (connectionSnapshot.docs.isEmpty) {
        return; // Mentor bağlantısı yok
      }

      // Bağlantı bulundu, mentor bilgilerini al
      await _processMentorConnection(connectionSnapshot.docs.first);

    } catch (e) {
      // Sessiz hata yakalama
    }
  }

  Future<void> _processMentorConnection(DocumentSnapshot connectionDoc) async {
    try {
      final connection = connectionDoc.data() as Map<String, dynamic>;
      String mentorId = connection['ogretmenId'];

      // Mentor bilgilerini al
      final mentorSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(mentorId)
          .get();

      if (mentorSnapshot.exists) {
        final mentorData = mentorSnapshot.data()!;
        
        setState(() {
          _mentorData = {
            'connectionId': connectionDoc.id,
            'mentorId': mentorId,
            'connectionDate': connection['baglantitarihi'] ?? connection['istekTarihi'],
            'lastActivity': connection['sonaktivite'] ?? mentorData['lastSeen'],
            'name': '${mentorData['isim'] ?? ''} ${mentorData['soyIsim'] ?? ''}',
            'email': mentorData['email'] ?? '',
            ...mentorData,
          };
        });
      }
    } catch (e) {
      // Sessiz hata yakalama
    }
  }

  Future<void> _loadMessages() async {
    if (_currentUserId == null) return;

    try {
      // mentorMesajlari collection'ından mesajları al
      QuerySnapshot messagesSnapshot;
      
      try {
        // Önce sıralı sorgu dene
        messagesSnapshot = await FirebaseFirestore.instance
            .collection('mentorMesajlari')
            .where('ogrenciId', isEqualTo: _currentUserId)
            .orderBy('sabitlendi', descending: true)
            .orderBy('tarih', descending: true)
            .get();
      } catch (e) {
        // Sıralama başarısızsa basit sorgu
        messagesSnapshot = await FirebaseFirestore.instance
            .collection('mentorMesajlari')
            .where('ogrenciId', isEqualTo: _currentUserId)
            .get();
      }

      if (messagesSnapshot.docs.isNotEmpty) {
        await _processMessages(messagesSnapshot);
      }

    } catch (e) {
      // Sessiz hata yakalama
    }
  }

  Future<void> _processMessages(QuerySnapshot snapshot) async {
    final messages = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'sabitlendi': data['sabitlendi'] ?? false,
        ...data,
      };
    }).toList();

    // Manuel sıralama: Önce sabitlenmiş, sonra tarihe göre
    messages.sort((a, b) {
      // Önce sabitleme durumuna göre sırala
      if (a['sabitlendi'] == true && b['sabitlendi'] != true) return -1;
      if (b['sabitlendi'] == true && a['sabitlendi'] != true) return 1;
      
      // Sonra tarihe göre sırala
      final aDate = a['tarih'] as Timestamp?;
      final bDate = b['tarih'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    setState(() {
      _messages = messages;
    });
  }

  // Mesajı okundu olarak işaretle
  Future<void> _markMessageAsRead(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('mentorMesajlari')
          .doc(messageId)
          .update({'okundu': true});

      // Local state'i güncelle
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['id'] == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex]['okundu'] = true;
        }
      });
    } catch (e) {
      print("Mesaj okundu işaretleme hatası: $e");
    }
  }

  // Mesajı sabitle/sabitlemeyi kaldır
  Future<void> _togglePinMessage(String messageId, bool currentPinStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('mentorMesajlari')
          .doc(messageId)
          .update({'sabitlendi': !currentPinStatus});

      // Mesajları yeniden yükle
      await _loadMessages();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentPinStatus ? 'Mesaj sabitleme kaldırıldı' : 'Mesaj sabitlendi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İşlem başarısız oldu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mesajı sil
  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await _showDeleteConfirmDialog();
    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('mentorMesajlari')
          .doc(messageId)
          .delete();

      // Local state'den mesajı kaldır
      setState(() {
        _messages.removeWhere((msg) => msg['id'] == messageId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj silindi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mesaj silinirken hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _showDeleteConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 10),
            Text('Mesajı Sil'),
          ],
        ),
        content: Text(
          'Bu mesajı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Sil'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Mesaj seçeneklerini göster
  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Mesaj Seçenekleri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 20),
            
            // Sabitle/Sabitlemeyi Kaldır
            ListTile(
              leading: Icon(
                message['sabitlendi'] == true ? Icons.push_pin : Icons.push_pin_outlined,
                color: message['sabitlendi'] == true ? Colors.orange : Colors.blue,
              ),
              title: Text(message['sabitlendi'] == true ? 'Sabitlemeyi Kaldır' : 'Sabitle'),
              subtitle: Text(message['sabitlendi'] == true ? 'Mesajı listenin üstünden kaldır' : 'Mesajı listenin üstünde tut'),
              onTap: () {
                Navigator.pop(context);
                _togglePinMessage(message['id'], message['sabitlendi'] == true);
              },
            ),
            
            Divider(),
            
            // Sil
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Sil', style: TextStyle(color: Colors.red)),
              subtitle: Text('Mesajı kalıcı olarak sil'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message['id']);
              },
            ),
            
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Mesaj detayını göster
  void _showMessageDetail(Map<String, dynamic> message) {
    // Eğer okunmamışsa okundu olarak işaretle
    if (message['okundu'] == false) {
      _markMessageAsRead(message['id']);
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.message,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Mentor Mesajı',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            if (message['sabitlendi'] == true) ...[
                              SizedBox(width: 8),
                              Icon(Icons.push_pin, color: Colors.orange, size: 16),
                            ],
                          ],
                        ),
                        Text(
                          _formatDate(message['tarih']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      Navigator.pop(context);
                      if (value == 'pin') {
                        _togglePinMessage(message['id'], message['sabitlendi'] == true);
                      } else if (value == 'delete') {
                        _deleteMessage(message['id']);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(
                              message['sabitlendi'] == true ? Icons.push_pin : Icons.push_pin_outlined,
                              color: message['sabitlendi'] == true ? Colors.orange : Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(message['sabitlendi'] == true ? 'Sabitlemeyi Kaldır' : 'Sabitle'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Sil', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // Başlık
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                ),
                child: Text(
                  message['baslik'] ?? 'Başlıksız Mesaj',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
              SizedBox(height: 16),
              
              // Mesaj içeriği
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      message['mesaj'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              
              // Footer
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade500),
                  SizedBox(width: 4),
                  Text(
                    _mentorData?['name'] ?? 'Mentor',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                        SizedBox(width: 4),
                        Text(
                          'Okundu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
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

  Future<void> _disconnectMentor() async {
    if (_mentorData == null || _currentUserId == null) return;

    final confirmed = await _showDisconnectDialog();
    if (!confirmed) return;

    try {
      // ogretmenOgrenci collection'ında durumu güncelle
      await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .doc(_mentorData!['connectionId'])
          .update({
        'durum': 'sonlandirildi',
        'sonlandiran': 'ogrenci',
        'sonlandirmaTarihi': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mentor bağlantısı başarıyla sonlandırıldı'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı sonlandırma işlemi başarısız oldu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showDisconnectDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Mentor Bağlantısını Sonlandır'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mentor bağlantınızı sonlandırmak istediğinizden emin misiniz?',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Dikkat:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '• Mentor istatistiklerinize erişim kaybedecek\n• Mesaj geçmişi korunacak\n• Yeniden bağlantı kurmanız gerekecek',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Sonlandır'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _navigateToMentorConnection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MentorConnectionScreen()),
    );
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

  String _getActivityStatus() {
    if (_mentorData == null || _mentorData!['lastActivity'] == null) {
      return 'Bilinmiyor';
    }

    final lastActivity = (_mentorData!['lastActivity'] as Timestamp).toDate();
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inMinutes < 5) {
      return 'Çevrimiçi';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} dk önce aktif';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} sa önce aktif';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce aktif';
    } else {
      return 'Uzun süredir aktif değil';
    }
  }

  String _getLastActivityText() {
    if (_mentorData == null || _mentorData!['lastActivity'] == null) {
      return 'Bilinmiyor';
    }

    final lastActivity = (_mentorData!['lastActivity'] as Timestamp).toDate();
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inMinutes < 5) {
      return 'Şimdi aktif';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} sa önce';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} gün önce';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months ay önce';
    }
  }

  int _getThisMonthMessages() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    
    return _messages.where((msg) {
      final messageDate = (msg['tarih'] as Timestamp?)?.toDate();
      return messageDate != null && messageDate.isAfter(thisMonth);
    }).length;
  }

  Color _getActivityColor() {
    if (_mentorData == null || _mentorData!['lastActivity'] == null) {
      return Colors.grey;
    }

    final lastActivity = (_mentorData!['lastActivity'] as Timestamp).toDate();
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inMinutes < 5) {
      return Colors.green;
    } else if (difference.inHours < 24) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Mentorluk'),
          backgroundColor: Colors.deepPurple,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_mentorData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Mentorluk'),
          backgroundColor: Colors.deepPurple,
        ),
        body: _buildNoMentorView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Mentorluk'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadMentorData();
              await _loadMessages();
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadMentorData();
          await _loadMessages();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildMentorInfoCard(),
                  _buildStatsSection(),
                ],
              ),
            ),
            _buildMessagesSliver(),
            SliverToBoxAdapter(
              child: SizedBox(height: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMentorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 100,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 24),
            Text(
              'Henüz Mentor Bağlantınız Yok',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Text(
              'Bir öğretmenin size mentor olması için bağlantı kurmanız gerekiyor.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToMentorConnection,
              icon: Icon(Icons.add),
              label: Text('Mentor Bul'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.arrow_back),
              label: Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentorInfoCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.purple.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: Text(
                  _mentorData!['name']?.isNotEmpty == true
                      ? '${_mentorData!['name'].split(' ')[0][0]}${_mentorData!['name'].split(' ').length > 1 ? _mentorData!['name'].split(' ')[1][0] : ''}'
                      : 'M',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mentorData!['name'] ?? 'Mentor',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _mentorData!['email'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _getActivityColor(),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          _getActivityStatus(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Divider(color: Colors.white30),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    'Son Aktivite',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _getLastActivityText(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white30,
              ),
              Column(
                children: [
                  Text(
                    'Bu Ay Mesaj',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_getThisMonthMessages()}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _disconnectMentor,
              icon: Icon(Icons.link_off, size: 18),
              label: Text('Mentor Bağlantısını Sonlandır'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildStatsSection() {
    final unreadCount = _messages.where((msg) => msg['okundu'] == false).length;
    final pinnedCount = _messages.where((msg) => msg['sabitlendi'] == true).length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Okunmamış Mesaj',
              '$unreadCount',
              Icons.mark_email_unread,
              Colors.orange,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Sabitlenmiş',
              '$pinnedCount',
              Icons.push_pin,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesSliver() {
    if (_messages.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: EdgeInsets.all(16),
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
                'Henüz Mesaj Yok',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Mentorunuzdan henüz mesaj almadınız',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              'Mentor Mesajları (${_messages.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _messages.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _buildMessageCard(message);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final isUnread = message['okundu'] == false;
    final isPinned = message['sabitlendi'] == true;
    
    return InkWell(
      onTap: () => _showMessageDetail(message),
      onLongPress: () => _showMessageOptions(message),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
            color: isPinned
                ? Colors.orange.shade300
                : isUnread 
                    ? Colors.blue.shade300 
                    : Colors.grey.shade200,
            width: isPinned || isUnread ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPinned)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin, size: 12, color: Colors.orange.shade700),
                        SizedBox(width: 4),
                        Text(
                          'SABİTLİ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isPinned && isUnread) SizedBox(width: 8),
                if (isUnread)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'YENİ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
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
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showMessageOptions(message),
                  child: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              message['baslik'] ?? 'Başlıksız Mesaj',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isPinned 
                    ? Colors.orange.shade800
                    : isUnread 
                        ? Colors.blue.shade800 
                        : Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message['mesaj'] ?? '',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                SizedBox(width: 4),
                Text(
                  _mentorData?['name'] ?? 'Mentor',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'Detay için tıklayın',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Mentor bağlantı kurma sayfası aynı kalacak...
class MentorConnectionScreen extends StatefulWidget {
  const MentorConnectionScreen({Key? key}) : super(key: key);

  @override
  State<MentorConnectionScreen> createState() => _MentorConnectionScreenState();
}

class _MentorConnectionScreenState extends State<MentorConnectionScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _sendMentorRequest() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Lütfen öğretmen email adresini girin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Öğretmen email ile kullanıcıyı bul
      final teacherQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .where('userType', isEqualTo: 'ogretmen')
          .limit(1)
          .get();

      if (teacherQuery.docs.isEmpty) {
        _showError('Bu email ile kayıtlı öğretmen bulunamadı');
        return;
      }

      final teacherDoc = teacherQuery.docs.first;
      final teacherId = teacherDoc.id;

      // Zaten bağlantı var mı kontrol et
      final existingConnection = await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .where('ogrenciId', isEqualTo: _currentUserId)
          .where('ogretmenId', isEqualTo: teacherId)
          .where('durum', whereIn: ['beklemede', 'onaylandı'])
          .get();

      if (existingConnection.docs.isNotEmpty) {
        final durum = existingConnection.docs.first.data()['durum'];
        if (durum == 'onaylandı') {
          _showError('Bu öğretmenle zaten aktif bağlantınız var');
        } else {
          _showError('Bu öğretmene zaten istek gönderdiniz, cevap bekleniyor');
        }
        return;
      }

      // Öğrenci bilgilerini al
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      final studentData = studentDoc.data()!;

      // Mentor isteği oluştur
      await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .add({
        'ogrenciId': _currentUserId,
        'ogretmenId': teacherId,
        'ogrenciAdi': '${studentData['isim']} ${studentData['soyIsim']}',
        'ogretmenAdi': '${teacherDoc.data()!['isim']} ${teacherDoc.data()!['soyIsim']}',
        'durum': 'beklemede',
        'istekTarihi': FieldValue.serverTimestamp(),
        'baglantitarihi': null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mentor isteği başarıyla gönderildi!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      _showError('Bir hata oluştu, lütfen tekrar deneyin');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mentor Bağlantısı'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        'Mentor Bağlantısı Nasıl Çalışır?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Öğretmeninizin email adresini girin\n'
                    '• Mentor isteği gönderilecek\n'
                    '• Öğretmen onayladıktan sonra istatistiklerinizi görebilecek\n'
                    '• Size motivasyon ve tavsiye mesajları gönderebilecek',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Öğretmen Email Adresi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'ornek@okul.edu.tr',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepPurple),
                ),
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendMentorRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Mentor İsteği Gönder',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}