import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:yksgunluk/calisma_surem/sure_tutma.dart';
import 'package:yksgunluk/cozdugun_soru/cozdugum_soru.sayisi.dart';
import 'package:yksgunluk/deneme_charts/tyt_deneme/tyt_genel.dart';
import 'dart:io';
import 'dart:math';
import 'package:yksgunluk/ekranlar/hedeflerim.dart';
import 'package:yksgunluk/giris/auth_screen.dart';
import 'package:yksgunluk/hizli_islemler/gunluk.dart';
import 'package:yksgunluk/hizli_islemler/hobi/hobi.dart';
import 'package:yksgunluk/hizli_islemler/mentor_goruntuleme.dart';
import 'package:yksgunluk/icon_penceler/haftalik_veri/ayt_soru.dart';
import 'package:yksgunluk/icon_penceler/odeme/odeme_ekrani.dart';
import 'package:yksgunluk/icon_penceler/ozellestirme_ekrani.dart';
import 'package:yksgunluk/calisma_surem/calisma_surem.dart';
import 'package:yksgunluk/ders_programi/program_tablo.dart';
import 'package:yksgunluk/icon_penceler/bilgilerim.dart';
import 'package:yksgunluk/icon_penceler/toplam_ilermem.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Flutter Local Notifications Plugin için global değişken
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Bildirim kanalı (Android için)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Yüksek Öncelikli Bildirimler',
  description: 'Mentor istekleri ve önemli bildirimler için kanal',
  importance: Importance.high,
);

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran>
    with TickerProviderStateMixin {
  File? _profileImage;
  late TabController _tabController;
  int _selectedIndex = 0;
  final List<String> _motivasyonMesajlari = [
    "Bugün bir adım daha ileri! 💪",
    "Emeklerinin karşılığını alacaksın! ✨",
    "Hedefine her gün biraz daha yaklaşıyorsun! 🎯",
    "Zorluklar seni daha da güçlendirecek! 🌟",
    "Kendine inan, başaracaksın! 🚀",
  ];
  String _gunlukMotivasyonMesaji = "";
  // YKS tarihini 21 Haziran 2026 olarak güncelledim
  DateTime _sinavaKalanGun = DateTime(2026, 6, 21);
  bool _isOverlayVisible = false;
  bool _isLoading = true;
  
  // Kullanıcı bilgileri
  String _userName = "Kullanıcı";
  String _userUid = "";
  
  // Bildirim değişkenleri
  int _bildirimSayisi = 0;
  List<Map<String, dynamic>> _bildirimler = [];
  bool _hasMentor = false;
  bool _isNotificationsPanelVisible = false;

  // Kullanıcı istatistikleri değişkenleri
  int _tamamlananHedefSayisi = 0;
  int _cozulenSoruSayisi = 0;
  int _tamamlananCalismaSaati = 0;
  int _denemePuani = 0;

  // Animasyon kontrolcüsü
  late AnimationController _notificationPanelController;
  late Animation<double> _notificationPanelAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Overlay için global key
  OverlayState? _overlay;
  OverlayEntry? _loadingOverlayEntry;
  
  void _checkFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM TOKEN: $token");
    
    // Token'ı kaydet
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcmToken': token});
      print("FCM token güncellendi!");
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeApp(); // 🎯 YENİ INITIALIZE FONKSIYONU
    _loadProfileImage();
    
    // Bildirim paneli animasyonu için controller
    _notificationPanelController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _notificationPanelAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _notificationPanelController,
        curve: Curves.easeOut,
      ),
    );
    
    // Bildirim izinlerini iste
    _requestNotificationPermissions();
    
    // Bildirim kanalını oluştur (Android için)
    _setupNotificationChannel();
    
    // Flutter Local Notifications Plugin'i başlat
    _initializeLocalNotifications();
    
    // FCM token'ı kaydet
    _saveFCMToken();
    
    // FCM bildirimlerini dinle
    _setupFCMListeners();

    // Status bar'ı şeffaf yapmak için
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  // 🎯 YENİ INITIALIZE FONKSIYONU
  Future<void> _initializeApp() async {
    try {
      // ÖNCE TEMA YÜKLE
      await ThemeManager.loadColors();
      print('🎨 Tema yüklendi: Primary: ${ThemeManager.primaryColor}');
      
      // SONRA DİĞER İŞLEMLER
      _checkFCMToken();
      _loadUserInfo();
      _gunlukMotivasyonMesaji = _motivasyonMesajlari[Random().nextInt(_motivasyonMesajlari.length)];
      
      // UI güncelle
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ App initialize hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 🎯 RENK YENİLEME FONKSİYONU
  Future<void> _refreshColors() async {
    await ThemeManager.loadColors();
    if (mounted) {
      setState(() {});
    }
  }

  // Bildirim izinlerini isteme
  Future<void> _requestNotificationPermissions() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    print('Kullanıcı izin durumu: ${settings.authorizationStatus}');
  }
  
  // Bildirim kanalını oluşturma (Android için)
  Future<void> _setupNotificationChannel() async {
    // Android için kanal oluştur
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    // iOS için izinleri ayarla
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
  
  // Flutter Local Notifications Plugin'i başlatma
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Bildirime tıklandı: ${response.payload}');
        
        if (response.payload == 'mentor_istegi') {
          _loadBildirimler();
          _toggleNotificationsPanel();
        }
      },
    );
  }

  // FCM token'ı kaydetme metodu
  Future<void> _saveFCMToken() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
            'fcmToken': token,
          });
          print('Öğrenci FCM Token kaydedildi: $token');
        }
      }
    } catch (e) {
      print('FCM token kaydedilirken hata: $e');
    }
  }

  // 🎯 DÜZELTİLMİŞ FCM dinleyicilerini kurma metodu
  void _setupFCMListeners() {
    // Uygulama açıkken bildirim alma
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 FCM Mesajı alındı: ${message.notification?.title}");
      print("📱 Mesaj tipi: ${message.data['type']}");
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      
      // 🎯 SADECE YEREL BİLDİRİM GÖSTER - Firestore güncelleme YOK
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data['type'],
        );
      }
      
      // 🎯 MENTOR İSTEĞİ İSE SADECE BİLDİRİMLERİ YENİLE - Sayıyı manuel artırma
      if (message.data['type'] == 'mentor_istegi') {
        _loadBildirimler(); // Bu zaten sayıyı doğru şekilde hesaplayacak
        // setState(() { _bildirimSayisi++; }); // ❌ KALDIRILDI!
      }
    });
    
    // Bildirime tıklama durumunu dinle
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("🔔 Bildirime tıklandı: ${message.notification?.title}");
      
      // Mentor isteği bildirimi ise, bildirimleri göster
      if (message.data['type'] == 'mentor_istegi') {
        _loadBildirimler();
        _toggleNotificationsPanel();
      }
    });
    
    // İlk açılışta bildirim kontrolü
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print("🔔 Uygulama bildirimle açıldı: ${message.notification?.title}");
        
        // Mentor isteği bildirimi ise, bildirimleri göster
        if (message.data['type'] == 'mentor_istegi') {
          _loadBildirimler();
          // Sayfa yüklendikten sonra bildirimleri göster
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _toggleNotificationsPanel();
          });
        }
      }
    });
  }
  
  // Kullanıcı bilgilerini ve mentor durumunu yükle
  Future<void> _loadUserInfo() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _userUid = currentUser.uid;
        
        // Kullanıcı bilgilerini al
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _userName = userData['isim'] ?? "Kullanıcı";
            });
          }
        }
        
        // Mentor durumunu kontrol et
        await _checkMentorStatus();
        
        // Bildirimleri yükle
        await _loadBildirimler();
      }
    } catch (e) {
      print('Kullanıcı bilgileri yüklenirken hata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Mentor durumunu kontrol et
  Future<void> _checkMentorStatus() async {
    try {
      // Öğrenciyle ilişkili onaylanmış bir mentor var mı?
      QuerySnapshot mentorSnapshot = await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .where('ogrenciId', isEqualTo: _userUid)
          .where('durum', isEqualTo: 'onaylandı')
          .limit(1)
          .get();
      
      if (mounted) {
        setState(() {
          _hasMentor = mentorSnapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Mentor durumu kontrol edilirken hata: $e');
    }
  }

  // 🎯 DÜZELTİLMİŞ Bildirimleri yükle
  Future<void> _loadBildirimler() async {
    try {
      if (!mounted) return;
      
      print("🔍 Bildirimler yükleniyor - Öğrenci UID: $_userUid");
      
      // 🎯 SADECE FIRESTORE BİLDİRİMLERİNİ AL (normal bildirimler)
      QuerySnapshot bildirimSnapshot = await FirebaseFirestore.instance
          .collection('bildirimler')
          .where('aliciId', isEqualTo: _userUid)
          .where('okundu', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();
      
      print("📊 Firestore bildirim sayısı: ${bildirimSnapshot.docs.length}");
      
      // 🎯 SADECE MENTOR İSTEKLERİNİ AL (ogretmenOgrenci koleksiyonundan)
      QuerySnapshot istekSnapshot = await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .where('ogrenciId', isEqualTo: _userUid)
          .where('durum', isEqualTo: 'beklemede')
          .get();
      
      print("📊 Bekleyen mentor istek sayısı: ${istekSnapshot.docs.length}");
      
      List<Map<String, dynamic>> bildirimler = [];
      
      // Normal bildirimleri işle
      for (var doc in bildirimSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // 🎯 MENTOR İSTEĞİ TİPİNDEKİLERİ ATLA (çünkü aşağıda ayrıca alıyoruz)
        if (data['tip'] == 'mentor_istegi') continue;
        
        bildirimler.add({
          'id': doc.id,
          'tip': data['tip'] ?? '',
          'mesaj': data['mesaj'] ?? '',
          'gonderenId': data['gonderenId'] ?? '',
          'gonderenAdi': data['gonderenAdi'] ?? '',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
          'okundu': false,
          'baglantiId': data['baglantiId'] ?? '',
        });
      }
      
      // Öğretmen isteklerini bildirimlere ekle (AYRI OLARAK)
      for (var doc in istekSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String ogretmenId = data['ogretmenId'];
        
        // Öğretmen bilgilerini al
        DocumentSnapshot ogretmenDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(ogretmenId)
            .get();
        
        if (ogretmenDoc.exists) {
          Map<String, dynamic> ogretmenData = ogretmenDoc.data() as Map<String, dynamic>;
          String ogretmenAdi = '${ogretmenData['isim']} ${ogretmenData['soyIsim']}';
          
          bildirimler.add({
            'id': doc.id,
            'tip': 'mentor_istegi',
            'mesaj': '$ogretmenAdi size mentor olmak istiyor',
            'gonderenId': ogretmenId,
            'gonderenAdi': ogretmenAdi,
            'timestamp': data['timestamp'] ?? Timestamp.now(),
            'okundu': false,
            'baglantiId': doc.id,
          });
        }
      }
      
      // Bildirimleri tarih sırasına göre sırala
      bildirimler.sort((a, b) {
        Timestamp aTimestamp = a['timestamp'] as Timestamp;
        Timestamp bTimestamp = b['timestamp'] as Timestamp;
        return bTimestamp.compareTo(aTimestamp);
      });
      
      if (mounted) {
        setState(() {
          _bildirimler = bildirimler;
          _bildirimSayisi = bildirimler.length;
          _isLoading = false;
        });
        
        print("✅ Toplam bildirim sayısı: $_bildirimSayisi");
      }
    } catch (e) {
      print('❌ Bildirimler yüklenirken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Bildirim panelini aç/kapat
  void _toggleNotificationsPanel() {
    setState(() {
      _isNotificationsPanelVisible = !_isNotificationsPanelVisible;
      
      if (_isNotificationsPanelVisible) {
        _notificationPanelController.forward();
      } else {
        _notificationPanelController.reverse();
      }
    });
  }

  // Bildirim okundu olarak işaretle
  Future<void> _markNotificationAsRead(String bildirimId, String tip) async {
    try {
      if (tip != 'mentor_istegi') {
        // Normal bildirim ise bildirimler koleksiyonunda güncelle
        await FirebaseFirestore.instance
            .collection('bildirimler')
            .doc(bildirimId)
            .update({'okundu': true});
      }
      
      // Bildirimleri yeniden yükle
      await _loadBildirimler();
    } catch (e) {
      print('Bildirim okundu olarak işaretlenirken hata: $e');
    }
  }

  // Mentor isteğini kabul et
  Future<void> _acceptMentorRequest(String baglantiId, String mentorId, String mentorAdi) async {
    try {
      // Mevcut durumu kontrol et
      if (_hasMentor) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zaten bir mentorunuz var. Yeni bir mentor eklemek için önce mevcut mentorla bağlantınızı kaldırın.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // İsteği onayla
      await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .doc(baglantiId)
          .update({'durum': 'onaylandı'});
      
      // Mentora bildirim gönder
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'aliciId': mentorId,
        'gonderenId': _userUid,
        'gonderenAdi': _userName,
        'mesaj': '$_userName mentor isteğinizi kabul etti',
        'tip': 'mentor_kabul',
        'okundu': false,
        'timestamp': FieldValue.serverTimestamp(),
        'baglantiId': baglantiId,
      });
      
      // Mentor durumunu güncelle
      setState(() {
        _hasMentor = true;
      });
      
      // Bildirimleri yeniden yükle ve paneli kapat
      await _loadBildirimler();
      _toggleNotificationsPanel();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$mentorAdi artık mentorunuz!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Mentor isteği kabul edilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İstek kabul edilirken bir hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mentor isteğini reddet
  Future<void> _rejectMentorRequest(String baglantiId, String mentorId, String mentorAdi) async {
    try {
      // İsteği sil
      await FirebaseFirestore.instance
          .collection('ogretmenOgrenci')
          .doc(baglantiId)
          .delete();
      
      // Mentora bildirim gönder
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'aliciId': mentorId,
        'gonderenId': _userUid,
        'gonderenAdi': _userName,
        'mesaj': '$_userName mentor isteğinizi reddetti',
        'tip': 'mentor_red',
        'okundu': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Bildirimleri yeniden yükle ve paneli kapat
      await _loadBildirimler();
      _toggleNotificationsPanel();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$mentorAdi\'nın mentor isteği reddedildi'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Mentor isteği reddedilirken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İstek reddedilirken bir hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Timestamp formatını düzenle
  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();
    Duration difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Az önce';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationPanelController.dispose();
    // Eğer yükleniyor ise kaldır
    _hideLoadingOverlay();
    super.dispose();
  }

  // YENİ: Yükleme overlay'ini göster
  void _showLoadingOverlay(String message) {
    _hideLoadingOverlay(); // Önce varsa kaldır
    
    _overlay = Overlay.of(context);
    _loadingOverlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black45,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: ThemeManager.primaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    _overlay?.insert(_loadingOverlayEntry!);
  }

  // YENİ: Yükleme overlay'ini kaldır
  void _hideLoadingOverlay() {
    _loadingOverlayEntry?.remove();
    _loadingOverlayEntry = null;
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      try {
        // Cihazda fotoğrafın yolunu kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profileImagePath', file.path);

        setState(() {
          _profileImage = file;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profil fotoğrafı güncellendi!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        print('Fotoğraf kaydedilirken hata oluştu: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Fotoğraf kaydedilirken hata oluştu!"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profileImagePath');

    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
  }

  // E-posta gönderme fonksiyonu
  Future<void> _sendEmail(String emailAddress) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      queryParameters: {
        'subject': 'YKS Günlüğüm Hakkında Yardım Talebi',
      }
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('E-posta uygulaması açılamadı'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("E-posta açılırken hata: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Mentor isteği diyaloğu
  void _showMentorRequestDialog(Map<String, dynamic> bildirim) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mentor İsteği'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: ThemeManager.primaryColor.withOpacity(0.1),
              child: Icon(
                Icons.person,
                size: 40,
                color: ThemeManager.primaryColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              bildirim['gonderenAdi'],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Size mentor olmak istiyor',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            if (_hasMentor)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Zaten bir mentorunuz var. Yeni bir mentor eklemek için önce mevcut mentorla bağlantınızı kaldırın.',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectMentorRequest(
                bildirim['baglantiId'],
                bildirim['gonderenId'],
                bildirim['gonderenAdi'],
              );
            },
            child: Text('Reddet', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: _hasMentor ? null : () {
              Navigator.pop(context);
              _acceptMentorRequest(
                bildirim['baglantiId'],
                bildirim['gonderenId'],
                bildirim['gonderenAdi'],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeManager.primaryColor,
              disabledBackgroundColor: Colors.grey,
            ),
            child: Text('Kabul Et'),
          ),
        ],
      ),
    );
  }

  // Bildirim panelini oluştur (Animasyonlu panel için)
  Widget _buildNotificationsPanel() {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 56, // AppBar height
        left: 10,
        right: 10,
      ),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 5),
        elevation: 8.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: ThemeManager.primaryColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve Kapatma butonu
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Bildirimler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_bildirimler.length} bildirim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: _toggleNotificationsPanel,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              
              Divider(height: 1, color: Colors.white.withOpacity(0.2)),
              
              // Bildirim listesi
              _bildirimler.isEmpty
                  ? Container(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 48,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Bildiriminiz bulunmuyor',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _bildirimler.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.white.withOpacity(0.2)),
                        itemBuilder: (context, index) {
                          final bildirim = _bildirimler[index];
                          final isMentorRequest = bildirim['tip'] == 'mentor_istegi';
                          
                          return Dismissible(
                            key: Key(bildirim['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: EdgeInsets.only(right: 20.0),
                              color: Colors.red,
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (direction) async {
                              // Bildirim sil veya okundu olarak işaretle
                              await _markNotificationAsRead(
                                bildirim['id'],
                                bildirim['tip'],
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: Icon(
                                  isMentorRequest ? Icons.person_add : Icons.notifications,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                bildirim['mesaj'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                _formatTimestamp(bildirim['timestamp']),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: isMentorRequest
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.check_circle, color: Colors.green),
                                          onPressed: _hasMentor ? null : () {
                                            _acceptMentorRequest(
                                              bildirim['baglantiId'],
                                              bildirim['gonderenId'],
                                              bildirim['gonderenAdi'],
                                            );
                                          },
                                          tooltip: 'Kabul Et',
                                          color: _hasMentor ? Colors.grey : Colors.white,
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.cancel, color: Colors.white),
                                          onPressed: () {
                                            _rejectMentorRequest(
                                              bildirim['baglantiId'],
                                              bildirim['gonderenId'],
                                              bildirim['gonderenAdi'],
                                            );
                                          },
                                          tooltip: 'Reddet',
                                        ),
                                      ],
                                    )
                                  : IconButton(
                                      icon: Icon(Icons.check_circle_outline, color: Colors.white),
                                      onPressed: () {
                                        _markNotificationAsRead(
                                          bildirim['id'],
                                          bildirim['tip'],
                                        );
                                      },
                                      tooltip: 'Okundu İşaretle',
                                    ),
                              onTap: () {
                                if (isMentorRequest) {
                                  _showMentorRequestDialog(bildirim);
                                } else {
                                  // Normal bildirimi okundu olarak işaretle
                                  _markNotificationAsRead(bildirim['id'], bildirim['tip']);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sinavaKalanGun = _sinavaKalanGun.difference(DateTime.now()).inDays;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'YKS Günlüğüm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: // Bildirim çanı ikonu (sol tarafta)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: Colors.white,
                ),
                onPressed: _toggleNotificationsPanel,
              ),
              if (_bildirimSayisi > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _bildirimSayisi > 9 ? '9+' : _bildirimSayisi.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        actions: [
          // Profil fotoğrafı
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
              child: _buildProfileImage(),
            ),
          ),
        ],
      ),
      endDrawer: _buildProfileDrawer(),
      body: _isLoading
          ? _buildLoadingScreen()
          : Stack(
              children: [
                // Gradient Arka Plan
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeManager.primaryColor.withOpacity(0.95), // 🎯 TEMA RENGİ
                        ThemeManager.secondaryColor.withOpacity(0.85), // 🎯 TEMA RENGİ
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),

                // Arka plan dalgaları
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 0.2,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white10, Colors.white24],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),

                // Ana İçerik
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Motivasyon Mesajı ve Sınav Geri Sayım
                        _buildMotivationCard(sinavaKalanGun),

                        // Ana Modüller
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 20, top: 20, bottom: 10),
                          child: Text(
                            "Modüller",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // Modül Kartları
                        _buildModernModuleCards(),

                        SizedBox(height: 80), // Bottom Navigation için ekstra alan
                      ],
                    ),
                  ),
                ),

                // Hızlı Aksiyon Menüsü
                _isOverlayVisible
                    ? _buildQuickActionOverlay()
                    : SizedBox.shrink(),
                
                // Animasyonlu Bildirim Paneli
                if (_isNotificationsPanelVisible)
                  AnimatedBuilder(
                    animation: _notificationPanelAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, MediaQuery.of(context).size.height * _notificationPanelAnimation.value * 0.3),
                        child: child!,
                      );
                    },
                    child: _buildNotificationsPanel(),
                  ),
              ],
            ),
      floatingActionButton: _buildAnimatedFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildLoadingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeManager.primaryColor.withOpacity(0.95), // 🎯 TEMA RENGİ
            ThemeManager.secondaryColor.withOpacity(0.85), // 🎯 TEMA RENGİ
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              "Hazırlanıyor...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Düzenlenmiş Drawer Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeManager.primaryColor, // 🎯 TEMA RENGİ
                  ThemeManager.secondaryColor // 🎯 TEMA RENGİ
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: _buildProfileImage(radius: 40),
                ),
                SizedBox(height: 8),
                Text(
                  "Merhaba, $_userName",  // Kullanıcı adını kullan
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  "Premium Kullanıcı",
                  style: TextStyle(
                    color: Colors.yellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          _buildDrawerItem(
            icon: Icons.info_outline,
            title: 'Kullanıcı Bilgilerim',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Bilgilerim()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.show_chart,
            title: 'Toplam İlerlemem',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChartsPage()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.bookmark_outline,
            title: 'Premium\'a Yükselt',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SubscriptionScreen()),
              );
            },
            isHighlighted: true,
          ),
          _buildDrawerItem(
            icon: Icons.color_lens_outlined,
            title: 'Özelleştirme',
            onTap: () async {
              Navigator.pop(context);
              final result = await Navigator.push( // 🎯 RESULT BEKLE
                context,
                MaterialPageRoute(builder: (context) => OzellistirmeEkrani()),
              );
              
              // 🎯 RENK DEĞİŞTİĞİNDE YENİLE
              if (result == true) {
                await _refreshColors();
              }
            },
          ),
          _buildDrawerItem(
            icon: Icons.timeline,
            title: 'Haftalık İlerleme',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AYTGrafik()),
              );
            },
          ),
          Divider(),
          _buildDrawerItem(
            icon: Icons.help_outline,
            title: 'Yardım ve Destek',
            onTap: () {
              Navigator.pop(context);
              _showHelpDialog(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.exit_to_app,
            title: 'Çıkış Yap',
            onTap: () {
              Navigator.pop(context);
              _showLogoutDialog(context);
            },
            textColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isHighlighted = false,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: isHighlighted
              ? Colors.orange
              : (textColor ?? ThemeManager.primaryColor), // 🎯 TEMA RENGİ
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? Colors.black87,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isHighlighted
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("YENİ",
                    style: TextStyle(color: Colors.orange, fontSize: 12)),
              )
            : null,
        onTap: onTap,
        tileColor: isHighlighted ? Colors.orange.withOpacity(0.1) : null,
      ),
    );
  }

  Widget _buildMotivationCard(int sinavaKalanGun) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline,
                      color: Colors.white,
                      size: 30
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _gunlukMotivasyonMesaji,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              color: Colors.white.withOpacity(0.2),
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "YKS'ye kalan:",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$sinavaKalanGun gün",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernModuleCards() {
    final List<Map<String, dynamic>> modules = [
      {
        "title": "Çözdüğüm Soru Sayısı",
        "icon": Icons.edit_note_rounded,
        "description": "Soru çözüm istatistiklerinizi görün",
        "page": CozdugumSoruSayisiEkrani(),
        "color1": Colors.green,
        "color2": Colors.lightGreen,
      },
      {
        "title": "Deneme Sonuçlarım",
        "icon": Icons.bar_chart_rounded,
        "description": "Deneme sınavı sonuçlarınızı takip edin",
        "page": TYTDenemeSonuclarim(),
        "color1": Colors.orange,
        "color2": Colors.amber,
      },
      {
        "title": "Çalışma Sürem",
        "icon": Icons.timer_rounded,
        "description": "Çalışma sürelerinizi kaydedip analiz edin",
        "page": CalismaSurem(),
        "color1": Colors.red,
        "color2": Colors.redAccent,
      },
    ];

    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => module["page"]),
            );
          },
          child: _buildModuleCard(
            title: module["title"],
            icon: module["icon"],
            description: module["description"],
            color1: module["color1"],
            color2: module["color2"],
          ),
        );
      },
    );
  }

  Widget _buildModuleCard({
    required String title,
    required IconData icon,
    required String description,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color1.withOpacity(0.7),
            color2.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedFAB() {
    return FloatingActionButton(
      elevation: 8,
      backgroundColor: ThemeManager.primaryColor, // 🎯 TEMA RENGİ
      onPressed: _toggleOverlay,
      child: AnimatedRotation(
        duration: Duration(milliseconds: 300),
        turns: _isOverlayVisible ? 0.125 : 0,
        child: Icon(_isOverlayVisible ? Icons.close : Icons.add,
            color: Colors.white),
      ),
    );
  }

  Widget _buildQuickActionOverlay() {
    return GestureDetector(
      onTap: _toggleOverlay,
      behavior: HitTestBehavior.translucent,
      child: Container(
                color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            margin: EdgeInsets.only(bottom: 100),
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Hızlı İşlemler",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ThemeManager.primaryColor, // 🎯 TEMA RENGİ
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuickActionButton(
                      icon: Icons.add_task,
                      label: "Hobilerim",
                      color: Colors.blue,
                      onTap: () {
                        _toggleOverlay();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => HobbyBalanceScreen()));
                      },
                    ),
                    SizedBox(width: 20),
                    _buildQuickActionButton(
                      icon: Icons.timer,
                      label: "Çalışmayı Başlat",
                      color: Colors.green,
                      onTap: () {
                        _toggleOverlay();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => OdaklanmisCalismaModu()));
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuickActionButton(
                      icon: Icons.book,
                      label: "Günlük",
                      color: Colors.orange,
                      onTap: () {
                        _toggleOverlay();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => JournalPage()));
                      },
                    ),
                    SizedBox(width: 20),
                    _buildQuickActionButton(
                      icon: Icons.person,
                      label: "Mentor",
                      color: Colors.purple,
                      onTap: () {
                        _toggleOverlay();
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MentorViewScreen()));
                      },
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

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 110,
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            // Seçilen sekmeye göre yönlendirme
            switch (index) {
              case 0:
                // Ana Sayfa sekmesi tıklandığında - zaten anasayfadayız
                break;
              case 1:
                // Hedeflerim sekmesi tıklandığında Hedeflerim sayfasına yönlendir
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HedeflerimPage()),
                );
                break;
              case 2:
                // Program sekmesi tıklandığında Ders Programı sayfasına yönlendir
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DersProgrami()),
                );
                break;
              case 3:
                // İstatistik sekmesi tıklandığında AYT Grafik sayfasına yönlendir
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AYTGrafik()),
                );
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: ThemeManager.primaryColor, // 🎯 TEMA RENGİ
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle:
              TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle:
              TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flag_outlined),
              activeIcon: Icon(Icons.flag),
              label: 'Hedeflerim',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Program',
              tooltip: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'İstatistik',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage({double radius = 20}) {
    if (_profileImage != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: FileImage(_profileImage!),
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: Icon(
          Icons.add_a_photo,
          color: Colors.grey,
          size: radius * 0.6,
        ),
      );
    }
  }

  // GÜNCELLENMİŞ ÇIKIŞ DİYALOĞU
  void _showLogoutDialog(BuildContext context) {
    // Burada context yerine global context kullanıyoruz
    final BuildContext safeContext = context;
    
    showDialog(
      context: safeContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.red),
              SizedBox(width: 10),
              Text('Çıkış Yap'),
            ],
          ),
          content: Text('YKS Günlüğüm uygulamasından çıkış yapmak istiyor musunuz?'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Güvenli çıkış işlemini çağır
                AuthService.logout(safeContext);
              },
              child: Text('Çıkış Yap'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.help_outline, color: ThemeManager.primaryColor), // 🎯 TEMA RENGİ
              SizedBox(width: 10),
              Text('Yardım ve Destek'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpItem(
                icon: Icons.email_outlined,
                title: "E-posta ile iletişim",
                subtitle: "yksgunlugum08@gmail.com",
              ),
              
              SizedBox(height: 16),
              _buildHelpItem(
                icon: Icons.book_outlined,
                title: "Kullanım Kılavuzu",
                subtitle: "Detaylı bilgiler",
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeManager.primaryColor, // 🎯 TEMA RENGİ
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () {
        if (icon == Icons.email_outlined) {
          _sendEmail(subtitle);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeManager.primaryColor.withOpacity(0.1), // 🎯 TEMA RENGİ
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: ThemeManager.primaryColor, size: 22), // 🎯 TEMA RENGİ
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: icon == Icons.email_outlined ? ThemeManager.primaryColor : Colors.grey, // 🎯 TEMA RENGİ
                      decoration: icon == Icons.email_outlined ? TextDecoration.underline : TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// Güvenli çıkış işlemi için ayrı servis sınıfı
class AuthService {
  static OverlayEntry? _loadingOverlay;
  
  // Güvenli çıkış yöntemi
  static Future<void> logout(BuildContext context) async {
    // Yükleniyor Overlay'i Göster
    _showLoadingOverlay(context, "Çıkış yapılıyor...");
    
    try {
      // 1. SharedPreferences temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userType');
      print("SharedPreferences temizlendi");
      
      // 2. Firebase Auth çıkış
      await FirebaseAuth.instance.signOut();
      print("Firebase Auth çıkış yapıldı");
      
      // 3. Firebase Messaging token sil (hata olsa bile devam et)
      try {
        await FirebaseMessaging.instance.deleteToken();
        print("Firebase Messaging token silindi");
      } catch (e) {
        print("Firebase Messaging token silinirken hata: $e");
      }
      
      // Yükleniyor Overlay'i Kaldır
      _hideLoadingOverlay();
      
      // Context kontrolü
      if (!context.mounted) return;
      
      // Ana sayfaya yönlendirme - burada context kullanılıyor ama önceki işlemler bitmiş durumda
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => AuthScreen()),
        (route) => false,
      );
      
    } catch (e) {
      print("Çıkış yapılırken hata: $e");
      
      // Yükleniyor Overlay'i Kaldır
      _hideLoadingOverlay();
      
      // Context kontrolü
      if (!context.mounted) return;
      
      // Hata mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Çıkış yapılırken bir hata oluştu. Lütfen tekrar deneyin."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Yükleniyor Overlay'ini Göster
  static void _showLoadingOverlay(BuildContext context, String message) {
    _hideLoadingOverlay(); // Önce varsa temizle
    
    final overlay = Overlay.of(context);
    _loadingOverlay = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(_loadingOverlay!);
  }
  
  // Yükleniyor Overlay'ini Kaldır
  static void _hideLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }
}