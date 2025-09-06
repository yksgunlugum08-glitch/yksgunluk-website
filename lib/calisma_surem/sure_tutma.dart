import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class OdaklanmisCalismaModu extends StatefulWidget {
  @override
  _OdaklanmisCalismaModu createState() => _OdaklanmisCalismaModu();
}

class _OdaklanmisCalismaModu extends State<OdaklanmisCalismaModu> {
  bool _isRunning = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  int _backPressCount = 0;
  Timer? _backPressTimer;
  bool _isDndEnabled = false;
  bool _isNotificationInitialized = false;
  bool _isDndPermissionGranted = false;
  
  // Platform Channel - Android tarafındaki native kodu çağırmak için
  static const platform = MethodChannel('com.yksgunluk/dnd');
  
  // Varsayılan süreler (dakika cinsinden)
  final List<int> _defaultTimes = [25, 45, 60, 90, 120];
  int _selectedMinutes = 25; // Varsayılan süre: 25 dakika (Pomodoro)

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    if (Platform.isAndroid) {
      _checkDndPermissions();
    }
  }

  @override
  void dispose() {
    if (_isRunning) {
      _timer?.cancel();
    }
    _disableDndMode();
    WakelockPlus.disable();
    super.dispose();
  }

  // DND izinlerini kontrol et
  Future<void> _checkDndPermissions() async {
    if (Platform.isAndroid) {
      try {
        final bool hasPermission = await platform.invokeMethod('checkDndPermission');
        setState(() {
          _isDndPermissionGranted = hasPermission;
        });
      } catch (e) {
        print('DND izni kontrol edilirken hata: $e');
        // Hata durumunda izin yokmuş gibi davran
        setState(() {
          _isDndPermissionGranted = false;
        });
      }
    }
  }

  // DND izni iste
  Future<void> _requestDndPermission() async {
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('openDndSettings');
        
        // Kullanıcı ayarlar ekranından döndüğünde izin durumunu tekrar kontrol et
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İzinleri verdikten sonra uygulamaya geri dönün'),
            duration: Duration(seconds: 3),
          )
        );
        
        // Kısa bir gecikme sonrası izinleri tekrar kontrol et
        Future.delayed(Duration(seconds: 2), () {
          _checkDndPermissions();
        });
      } catch (e) {
        print('DND izni istenirken hata: $e');
      }
    }
  }

  // Bildirimleri başlat ve izinleri kontrol et
  Future<void> _initializeNotifications() async {
    try {
      if (!_isNotificationInitialized) {
        _isNotificationInitialized = await AwesomeNotifications().initialize(
          null,
          [
            NotificationChannel(
              channelKey: 'focus_mode_channel',
              channelName: 'Odak Modu Bildirimleri',
              channelDescription: 'Odak modu için bildirimleri gösterir',
              defaultColor: Colors.blue,
              importance: NotificationImportance.High,
              ledColor: Colors.blue,
              channelShowBadge: true,
              playSound: true,
              enableVibration: true,
            )
          ],
        ) ?? false;
        
        if (_isNotificationInitialized) {
          bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
          if (!isAllowed) {
            Future.delayed(Duration(seconds: 1), () {
              _requestNotificationPermission();
            });
          }
        }
      }
    } catch (e) {
      print('Bildirimler başlatılırken hata: $e');
      _isNotificationInitialized = false;
    }
  }

  // Bildirim izni iste
  void _requestNotificationPermission() {
    try {
      AwesomeNotifications().requestPermissionToSendNotifications().then((isAllowed) {
        if (!isAllowed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bildirim izni olmadan çalışma süresi bitimini bildiremeyeceğiz'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      });
    } catch (e) {
      print('Bildirim izni istenirken hata: $e');
    }
  }

  // Rahatsız etme modunu etkinleştir - PLATFORM KONTROLÜ EKLENEN KISIM
  Future<void> _enableDndMode() async {
    try {
      // Her iki platformda da ekranı açık tut
      await WakelockPlus.enable();
      
      // Platform bazlı DND kontrolü
      if (Platform.isAndroid) {
        if (_isDndPermissionGranted) {
          try {
            await platform.invokeMethod('setDndOn');
            _isDndEnabled = true;
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Rahatsız etmeyin modu aktif'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              )
            );
          } catch (e) {
            print('DND modu etkinleştirilirken hata: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bildirimler engellenmeyebilir'),
                backgroundColor: Colors.orange,
              )
            );
          }
        } else {
          // İzin yoksa bildirim göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Odaklanma için bildirim engelleme izni gerekiyor'),
              action: SnackBarAction(
                label: 'İZİN VER',
                onPressed: _requestDndPermission,
              ),
              duration: Duration(seconds: 5),
            )
          );
        }
      } 
      else if (Platform.isIOS) {
        // iOS için sadece tavsiye göster, DND API erişimi yok
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lütfen daha iyi odaklanmak için telefonunuzu sessiz moda alın'),
            action: SnackBarAction(
              label: 'BİLGİ',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Rahatsız Etmeyin Modu'),
                    content: Text('Kontrol Merkezi\'ni açın (ekranın sağ üst köşesinden aşağı kaydırın) ve Rahatsız Etmeyin simgesine dokunun.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('TAMAM'),
                      )
                    ],
                  ),
                );
              },
            ),
            duration: Duration(seconds: 5),
          )
        );
        
        // iOS'ta gerçek DND modu açılmasa bile çalışma takibi için true yapıyoruz
        _isDndEnabled = true;
      }
    } catch (e) {
      print('Rahatsız etme modu etkinleştirilirken hata: $e');
    }
  }
  
  // Rahatsız etme modunu kapat
  Future<void> _disableDndMode() async {
    try {
      if (Platform.isAndroid && _isDndEnabled && _isDndPermissionGranted) {
        try {
          await platform.invokeMethod('setDndOff');
        } catch (e) {
          print('DND modu kapatılırken hata: $e');
        }
      }
      
      _isDndEnabled = false;
      await WakelockPlus.disable();
    } catch (e) {
      print('Rahatsız etme modu kapatılırken hata: $e');
    }
  }

  // Odaklanma süresi bitince bildirim göster
  Future<void> _showFocusCompletedNotification() async {
    try {
      if (_isNotificationInitialized) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 1,
            channelKey: 'focus_mode_channel',
            title: 'Odaklanma süresi tamamlandı!',
            body: '$_selectedMinutes dakikalık odaklanma süreniz başarıyla tamamlandı.',
            notificationLayout: NotificationLayout.Default,
          ),
        );
      }
    } catch (e) {
      print('Bildirim gösterilirken hata: $e');
    }
  }

  void _startTimer() async {
    _remainingSeconds = _selectedMinutes * 60;
    await _enableDndMode();
    
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _timerComplete();
        }
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Odaklanma modu başladı! $_selectedMinutes dakika boyunca odaklanabilirsin.'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.green,
      )
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    
    _disableDndMode();
    
    // Not: Çalışma süresi artık kaydedilmiyor
  }

  void _timerComplete() {
    _disableDndMode();
    
    HapticFeedback.vibrate();
    HapticFeedback.heavyImpact();
    
    // Bildirimi göster
    _showFocusCompletedNotification();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tebrikler! $_selectedMinutes dakikalık çalışma sürenizi tamamladınız!'),
        backgroundColor: Colors.green,
      )
    );
    
    // Not: Çalışma süresi artık kaydedilmiyor
  }

  String _formatTime() {
    int hours = _remainingSeconds ~/ 3600;
    int minutes = (_remainingSeconds % 3600) ~/ 60;
    int seconds = _remainingSeconds % 60;
    
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // Premium kısıtlaması tamamen kaldırıldı - doğrudan içeriği göster
    return _buildContent();
  }

  Widget _buildContent() {
    // Ekran boyutlarını al
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    
    return WillPopScope(
      onWillPop: () async {
        if (_isRunning) {
          // Çalışma modundayken çıkmayı zorlaştır
          _backPressCount++;
          
          if (_backPressTimer == null || !_backPressTimer!.isActive) {
            _backPressTimer = Timer(Duration(seconds: 2), () {
              _backPressCount = 0;
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Çalışma modundan çıkmak için tekrar basın'),
                duration: Duration(seconds: 2),
              ),
            );
            
            return false;
          }
          
          if (_backPressCount >= 2) {
            _backPressCount = 0;
            _backPressTimer!.cancel();
            
            // Çalışma devam ederken çıkış yapmak istediğinde onaylama diyaloğu göster
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Colors.grey[850],
                title: Text(
                  'Çalışmayı Sonlandır',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'Çalışmanız yarıda kesilecek. Devam etmek istiyor musunuz?',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('İptal', style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () {
                      _stopTimer();
                      Navigator.of(context).pop(true);
                    },
                    child: Text('Çıkış Yap'),
                  ),
                ],
              ),
            );
          }
          
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _isRunning
            // Çalışma modu aktifken farklı bir düzen kullan
            ? Column(
                children: [
                  // Üst kısım - Başlık
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 20 : 30,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.timer,
                          size: isSmallScreen ? 40 : 50,
                          color: Colors.white,
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 15),
                        Text(
                          "Odaklanma Modu Aktif",
                          style: TextStyle(
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_isDndEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_off, size: 16, color: Colors.red),
                                SizedBox(width: 5),
                                Text(
                                  "Rahatsız Etmeyin Modu Aktif",
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500
                                  ),
                                )
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // ORTA KISIM - Geri sayım zamanlayıcısı (genişletilmiş ve ortalanmış)
                  Expanded(
                    child: Center(
                      child: _buildCountdownTimer(screenSize),
                    ),
                  ),
                  
                  // ALT KISIM - Durdurma butonu
                  Container(
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 20 : 30,
                      horizontal: 20,
                    ),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.stop_circle_outlined),
                      label: Text(
                        "Çalışmayı Bitir",
                        style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 24 : 32,
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _stopTimer,
                    ),
                  ),
                ],
              )
            // Çalışma modu aktif değilken mevcut düzeni kullan
            : SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenSize.height - MediaQuery.of(context).padding.vertical,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: isSmallScreen ? 20 : 40),
                        
                        // Başlık Alanı - Ekran boyutuna göre boyutlandırıldı
                        Container(
                          padding: EdgeInsets.only(bottom: isSmallScreen ? 20 : 40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: isSmallScreen ? 40 : 50,
                                color: Colors.white,
                              ),
                              SizedBox(height: isSmallScreen ? 10 : 20),
                              Text(
                                "Odaklanma Modu",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Android'de DND izni yoksa ve çalışma modu başlamadıysa izin butonu göster
                        if (Platform.isAndroid && !_isDndPermissionGranted && !_isRunning)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.notifications_off, size: 16, color: Colors.amber),
                              label: Text(
                                'Bildirim Engelleme İzni Ver',
                                style: TextStyle(color: Colors.amber),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.amber),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onPressed: _requestDndPermission,
                            ),
                          ),
                        
                        // Geri sayım veya süre seçimi
                        _buildTimeSelector(screenSize, isSmallScreen),
                        
                        // Alt alan - Butonlar
                        Container(
                          padding: EdgeInsets.only(top: isSmallScreen ? 30 : 50),
                          child: Column(
                            children: [
                              ElevatedButton.icon(
                                icon: Icon(Icons.play_circle_outline),
                                label: Text(
                                  "Çalışmaya Başla",
                                  style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 24 : 32,
                                    vertical: isSmallScreen ? 12 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: _startTimer,
                              ),
                              SizedBox(height: 20),
                              TextButton.icon(
                                icon: Icon(Icons.arrow_back),
                                label: Text("Geri Dön"),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                          
                        // Çalışma modu ipuçları - Küçük ekranlarda daha az padding
                        if (!_isRunning)
                          Padding(
                            padding: EdgeInsets.only(
                              top: isSmallScreen ? 20 : 40,
                              left: 15,
                              right: 15,
                              bottom: isSmallScreen ? 20 : 0
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "Odaklanma modunda rahatsız etmeyin özelliği aktif olur, "
                                  "bildirimlerin ve aramaların sizi rahatsız etmesini engeller. "
                                  "Sürenizi seçin ve kesintisiz çalışmaya başlayın.",
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: isSmallScreen ? 11 : 12,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (Platform.isAndroid && !_isDndPermissionGranted)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: Text(
                                      "Not: Bildirim engelleme için izin vermeniz gerekiyor.",
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontSize: isSmallScreen ? 11 : 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
  
  // Boyutları ekrana göre ayarlanmış geri sayım
  Widget _buildCountdownTimer(Size screenSize) {
    // Ekran boyutuna göre boyutları ayarla
    final double circleSize = screenSize.width * 0.6;
    final double circleSize2 = circleSize > 220 ? 220 : circleSize;
    
    // Kalan süre yüzdesi
    double progressValue = _remainingSeconds / (_selectedMinutes * 60);
    
    // Zaman formatını hazırla
    final timeStr = _formatTime();
    
    // Ekran genişliğine göre yazı boyutu hesapla
    final double fontSize = circleSize2 * 0.15;
    
    return SizedBox(
      width: circleSize2,
      height: circleSize2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dairesel ilerleme göstergesi
          SizedBox(
            width: circleSize2,
            height: circleSize2,
            child: CircularProgressIndicator(
              value: progressValue,
              strokeWidth: 10,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          
          // İç kısımda sayaç - Metin sığdırmak için ayarlanmış
          Container(
            width: circleSize2 * 0.75,
            height: circleSize2 * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[900],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zamanlayıcı metni - Düzeltilmiş hali
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: circleSize2 * 0.65,
                      ),
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "kalan süre",
                    style: TextStyle(
                      fontSize: circleSize2 * 0.07,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Boyutları ekrana göre ayarlanmış süre seçici
  Widget _buildTimeSelector(Size screenSize, bool isSmallScreen) {
    // Ekran boyutuna göre boyutları ayarla
    final double circleSize = isSmallScreen ? 
                              screenSize.width * 0.4 : 
                              screenSize.width * 0.45;
    final double circleSize2 = circleSize > 180 ? 180 : circleSize;
    
    return Column(
      children: [
        Text(
          "Çalışma Süresi Seçin",
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        SizedBox(height: isSmallScreen ? 15 : 20),
        Container(
          height: circleSize2,
          width: circleSize2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[900],
            border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$_selectedMinutes",
                style: TextStyle(
                  fontSize: circleSize2 * 0.25,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                "dakika",
                style: TextStyle(
                  fontSize: circleSize2 * 0.09,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isSmallScreen ? 15 : 30),
        
        // Süre seçenekleri - daha kompakt
        Wrap(
          spacing: isSmallScreen ? 6 : 10,
          runSpacing: isSmallScreen ? 6 : 10,
          alignment: WrapAlignment.center,
          children: _defaultTimes.map((minutes) {
            return ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedMinutes = minutes;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedMinutes == minutes 
                    ? Colors.blue 
                    : Colors.grey[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 15 : 20, 
                  vertical: isSmallScreen ? 8 : 10
                ),
              ),
              child: Text("$minutes dk", style: TextStyle(fontSize: isSmallScreen ? 12 : 14)),
            );
          }).toList(),
        ),
        SizedBox(height: isSmallScreen ? 10 : 15),
        
        // Özel süre girmek için
        TextButton.icon(
          onPressed: () {
            _showCustomTimeDialog();
          },
          icon: Icon(Icons.add_circle_outline, size: isSmallScreen ? 14 : 16),
          label: Text("Özel Süre", style: TextStyle(fontSize: isSmallScreen ? 12 : 14)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white60,
          ),
        ),
      ],
    );
  }
  
  // Özel süre girme diyaloğu
  void _showCustomTimeDialog() {
    TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("Özel Süre Belirle", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Dakika",
            hintText: "1-180 arası bir değer girin",
            labelStyle: TextStyle(color: Colors.white70),
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("İptal", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              int? minutes = int.tryParse(_controller.text);
              if (minutes != null && minutes > 0 && minutes <= 180) {
                setState(() {
                  _selectedMinutes = minutes;
                });
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Lütfen 1-180 arası bir değer girin"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: Text("Tamam"),
          ),
        ],
      ),
    );
  }
}