import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yksgunluk/dumenden/app_state.dart' as app;
import 'package:yksgunluk/ekranlar/home_page.dart';
import 'package:yksgunluk/icon_penceler/ozellestirme_ekrani.dart';
import 'package:yksgunluk/ogretmen/ogretmen.dart';
import 'package:yksgunluk/giris/auth_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yksgunluk/teacher_mode.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';

// FCM arka plan mesaj işleyici
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Arka planda bildirim alındı: ${message.messageId}");
}

// Bildirim kanalı tanımı
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Yüksek Öncelikli Bildirimler',
  description: 'Mentor istekleri ve önemli bildirimler için kanal',
  importance: Importance.high,
  playSound: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
  FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 AdMob'u başlat
  await MobileAds.instance.initialize();
  print('🔥 AdMob başlatıldı');
  
  // 🔥 Premium durumunu yükle
  await PremiumManager.loadPremiumStatus();
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: []
  );
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
  try {
    await ThemeManager.loadColors();
    print('🎨 Ana tema yüklendi: Primary: ${ThemeManager.primaryColor}, Secondary: ${ThemeManager.secondaryColor}');
  } catch (e) {
    print('❌ Tema yüklenirken hata: $e');
  }
  
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  await _initializeNotifications();
  
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final userType = prefs.getString('userType') ?? 'Öğrenci';

  // 🔥 Premium değilse reklamı yükle
  if (!PremiumManager.isPremium) {
    AdMobHelper.loadInterstitialAd();
    print('🆓 Free kullanıcı - reklamlar aktif');
  } else {
    print('👑 Premium kullanıcı - reklamlar devre dışı');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => app.AppState(isLoggedIn: isLoggedIn, userType: userType),
        ),
        ChangeNotifierProvider(
          create: (context) => TeacherModeProvider(),
        ),
        ChangeNotifierProvider(
          create: (context) => PremiumManager(),
        ),
      ],
      child: MyApp(),
    ),
  );
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid = 
      AndroidInitializationSettings('app_icon');
  
  final DarwinInitializationSettings initializationSettingsDarwin = 
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
  
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      print('Bildirime tıklandı: ${response.payload}');
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _getFCMToken();
    _setupForegroundMessaging();
    _setupOnMessageOpenedApp();
  }
  
  Future<void> _getFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');
  }
  
  void _setupForegroundMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      
      print('Ön planda bildirim alındı: ${notification?.title}');
      
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
              icon: 'app_icon',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data['type'] ?? '',
        );
      }
    });
  }
  
  void _setupOnMessageOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Bildirime tıklandı!');
      print('Mesaj verisi: ${message.data}');
      
      final appState = Provider.of<app.AppState>(context, listen: false);
      if (appState.isLoggedIn && message.data['type'] == 'mentor_istegi') {
        // Yönlendirme işlemleri
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    _ensureFullScreen();
    
    final appState = Provider.of<app.AppState>(context);
    
    return MaterialApp(
      title: 'YKS Günlüğüm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        dialogBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        brightness: Brightness.light,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
          titleLarge: TextStyle(color: Colors.black87),
          titleMedium: TextStyle(color: Colors.black87),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: child!,
        );
      },
      home: _buildHomeScreen(appState),
    );
  }

  Widget _buildHomeScreen(app.AppState appState) {
    if (!appState.isLoggedIn) {
      return AuthScreen();
    }
    
    if (appState.userType == 'Öğretmen') {
      return OgretmenPaneli();
    } else {
      return AnaEkran();
    }
  }
  
  void _ensureFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: []
    );
  }
}

class FullScreenHelper {
  static void enableFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: []
    );
  }
  
  static void disableFullScreen() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]
    );
  }
}

class FCMHelper {
  static Future<void> saveUserFCMToken(String userId) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': token,
        });
        print('FCM Token kaydedildi: $token');
      }
    } catch (e) {
      print('FCM token kaydedilirken hata: $e');
    }
  }
  
  static Future<void> subscribeToTopic(String topic) async {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  }
  
  static Future<void> unsubscribeFromTopic(String topic) async {
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  }
  
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'app_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}

// 👑 PREMIUM YÖNETİM SİSTEMİ
class PremiumManager extends ChangeNotifier {
  static bool _isPremium = false;
  static DateTime? _premiumExpiryDate;
  static String? _purchaseId;
  
  // Getter'lar
  static bool get isPremium => _isPremium;
  static DateTime? get premiumExpiryDate => _premiumExpiryDate;
  static String? get purchaseId => _purchaseId;
  
  // Premium durumunu SharedPreferences'dan yükle
  static Future<void> loadPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool('isPremium') ?? false;
      
      final expiryString = prefs.getString('premiumExpiryDate');
      if (expiryString != null) {
        _premiumExpiryDate = DateTime.parse(expiryString);
        
        // Süre dolmuş mu kontrol et
        if (_premiumExpiryDate!.isBefore(DateTime.now())) {
          print('⚠️ Premium süresi dolmuş, durumu güncelleniyor...');
          await setPremiumStatus(false);
        }
      }
      
      _purchaseId = prefs.getString('purchaseId');
      
      print('👑 Premium durum yüklendi: $_isPremium');
      if (_premiumExpiryDate != null) {
        print('📅 Premium bitiş tarihi: $_premiumExpiryDate');
      }
    } catch (e) {
      print('❌ Premium durum yüklenirken hata: $e');
      _isPremium = false;
    }
  }
  
  // Premium durumunu ayarla
  static Future<void> setPremiumStatus(bool premium, {DateTime? expiryDate, String? purchaseId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isPremium = premium;
      _premiumExpiryDate = expiryDate;
      _purchaseId = purchaseId;
      
      await prefs.setBool('isPremium', premium);
      
      if (expiryDate != null) {
        await prefs.setString('premiumExpiryDate', expiryDate.toIso8601String());
      } else {
        await prefs.remove('premiumExpiryDate');
      }
      
      if (purchaseId != null) {
        await prefs.setString('purchaseId', purchaseId);
      } else {
        await prefs.remove('purchaseId');
      }
      
      print('👑 Premium durum güncellendi: $premium');
      
      // Reklam durumunu güncelle
      if (premium) {
        AdMobHelper.disableAds();
        print('🚫 Reklamlar devre dışı bırakıldı');
      } else {
        AdMobHelper.enableAds();
        print('📺 Reklamlar etkinleştirildi');
      }
      
    } catch (e) {
      print('❌ Premium durum kaydedilirken hata: $e');
    }
  }
  
  // Premium süresini kontrol et
  static bool isPremiumValid() {
    if (!_isPremium) return false;
    
    if (_premiumExpiryDate == null) return true; // Sınırsız premium
    
    return _premiumExpiryDate!.isAfter(DateTime.now());
  }
  
  // Kalan premium süresini al
  static Duration? getRemainingPremiumTime() {
    if (!_isPremium || _premiumExpiryDate == null) return null;
    
    final now = DateTime.now();
    if (_premiumExpiryDate!.isBefore(now)) return Duration.zero;
    
    return _premiumExpiryDate!.difference(now);
  }
  
  // Premium bilgilerini temizle
  static Future<void> clearPremiumStatus() async {
    await setPremiumStatus(false);
  }
}

// 🔥 PREMIUM DESTEKLİ AdMob Helper
class AdMobHelper {
  static const String _interstitialAdId = 'ca-app-pub-1776033348127199/7211314486';
  
  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdReady = false;
  static int _actionCount = 0;
  static DateTime? _lastAdShown;
  static bool _adsEnabled = true; // Reklamlar aktif mi?
  
  static const int MIN_MINUTES_BETWEEN_ADS = 1;
  static const int MIN_ACTIONS_BEFORE_AD = 8;
  
  // Reklamları devre dışı bırak (Premium için)
  static void disableAds() {
    _adsEnabled = false;
    _disposeCurrentAd();
    print('🚫 Reklamlar devre dışı bırakıldı');
  }
  
  // Reklamları etkinleştir
  static void enableAds() {
    _adsEnabled = true;
    loadInterstitialAd();
    print('📺 Reklamlar etkinleştirildi');
  }
  
  // Mevcut reklamı temizle
  static void _disposeCurrentAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }
  
  static Future<void> loadInterstitialAd() async {
    // Premium kontrolü
    if (!_adsEnabled || PremiumManager.isPremium) {
      print('👑 Premium kullanıcı - reklam yüklenmedi');
      return;
    }
    
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            print('🎯 Interstitial reklam yüklendi');
            _interstitialAd = ad;
            _isInterstitialAdReady = true;
            
            _interstitialAd!.setImmersiveMode(true);
            _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (InterstitialAd ad) {
                print('🔥 Interstitial reklam gösterildi');
              },
              onAdDismissedFullScreenContent: (InterstitialAd ad) {
                print('✅ Interstitial reklam kapatıldı');
                ad.dispose();
                _isInterstitialAdReady = false;
                _lastAdShown = DateTime.now();
                
                // Premium kontrolü ile yeni reklam yükle
                Future.delayed(Duration(seconds: 15), () {
                  if (!PremiumManager.isPremium) {
                    loadInterstitialAd();
                  }
                });
              },
              onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
                print('❌ Interstitial reklam gösterilemedi: $error');
                ad.dispose();
                _isInterstitialAdReady = false;
                loadInterstitialAd();
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('❌ Interstitial reklam yüklenemedi: $error');
            _interstitialAd = null;
            _isInterstitialAdReady = false;
            
            Future.delayed(Duration(seconds: 30), () {
              if (!PremiumManager.isPremium) {
                loadInterstitialAd();
              }
            });
          },
        ),
      );
    } catch (e) {
      print('❌ AdMob yükleme hatası: $e');
    }
  }
  
  // 👑 PREMIUM KONTROLLÜ reklam gösterme
  static void tryShowAd() {
    // Premium kontrolü - EN ÖNEMLİ!
    if (!_adsEnabled || PremiumManager.isPremium) {
      print('👑 Premium kullanıcı - reklam gösterilmedi');
      return;
    }
    
    _actionCount++;
    
    final now = DateTime.now();
    final timeSinceLastAd = _lastAdShown == null ? 
        Duration(minutes: 10) : now.difference(_lastAdShown!);
    
    final canShowAd = _actionCount >= MIN_ACTIONS_BEFORE_AD && 
        timeSinceLastAd.inMinutes >= MIN_MINUTES_BETWEEN_ADS && 
        _isInterstitialAdReady && 
        _interstitialAd != null;
    
    if (canShowAd) {
      _interstitialAd!.show();
      _actionCount = 0;
      print('🚀 REKLAM gösterildi! Sonraki reklam: ${now.add(Duration(minutes: MIN_MINUTES_BETWEEN_ADS))}');
    } else {
      print('⚠️ Reklam gösterme koşulları sağlanmadı');
      print('   🎯 Aksiyon sayısı: $_actionCount/$MIN_ACTIONS_BEFORE_AD');
      print('   ⏰ Son reklamdan geçen süre: ${timeSinceLastAd.inMinutes}/$MIN_MINUTES_BETWEEN_ADS dakika');
      print('   📱 Reklam hazır: $_isInterstitialAdReady');
      
      if (!_isInterstitialAdReady && !PremiumManager.isPremium) {
        loadInterstitialAd();
      }
    }
  }
  
  static void showInterstitialAd() {
    if (!_adsEnabled || PremiumManager.isPremium) {
      print('👑 Premium kullanıcı - manuel reklam gösterilmedi');
      return;
    }
    
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _isInterstitialAdReady = false;
    } else {
      print('⚠️ Interstitial reklam henüz hazır değil');
      loadInterstitialAd();
    }
  }
  
  static bool isAdReady() {
    if (!_adsEnabled || PremiumManager.isPremium) return false;
    return _isInterstitialAdReady && _interstitialAd != null;
  }
  
  static Map<String, dynamic> getAdStats() {
    return {
      'isPremium': PremiumManager.isPremium,
      'adsEnabled': _adsEnabled,
      'actionCount': _actionCount,
      'requiredActions': MIN_ACTIONS_BEFORE_AD,
      'isAdReady': _isInterstitialAdReady,
      'lastAdShown': _lastAdShown?.toString() ?? 'Hiç gösterilmedi',
      'nextAdAvailable': _lastAdShown != null ? 
          _lastAdShown!.add(Duration(minutes: MIN_MINUTES_BETWEEN_ADS)).toString() : 'Şimdi',
      'waitTime': '${MIN_MINUTES_BETWEEN_ADS} dakika',
    };
  }
}

// 🎯 PREMIUM KONTROLLÜ reklam gösterme helper'ları
class AdStrategy {
  static void onPageTransition() {
    print('📄 Sayfa geçişi - reklam kontrol ediliyor...');
    AdMobHelper.tryShowAd();
  }
  
  static void onFeatureUsed() {
    print('⚙️ Özellik kullanıldı - reklam kontrol ediliyor...');
    AdMobHelper.tryShowAd();
  }
  
  static void onAchievement() {
    print('🏆 Başarı kazanıldı - reklam kontrol ediliyor...');
    AdMobHelper.tryShowAd();
  }
  
  static void onMenuOpen() {
    print('📋 Menü açıldı - reklam kontrol ediliyor...');
    AdMobHelper.tryShowAd();
  }
  
  static void onDailyComplete() {
    print('✅ Günlük tamamlandı - reklam kontrol ediliyor...');
    AdMobHelper.tryShowAd();
  }
  
  static void onStudyStart() {
    print('📚 Çalışma başladı - reklam kontrol ediliyor...');
    AdMobHelper.tryShowAd();
  }
  
  static void onStudyEnd() {
    print('⏰ Çalışma bitti - reklam kontrol ediliyor...');
    AdMobHelper.tryShowAd();
  }
}