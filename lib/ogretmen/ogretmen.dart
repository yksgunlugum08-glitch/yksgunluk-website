import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yksgunluk/giris/auth_screen.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yksgunluk/icon_penceler/ozellestirme_ekrani.dart';

import 'package:yksgunluk/ogretmen/ogrencilerim.dart';

class OgretmenPaneli extends StatefulWidget {
  @override
  _OgretmenPaneliState createState() => _OgretmenPaneliState();
}

class _OgretmenPaneliState extends State<OgretmenPaneli> {
  // Firebase bağlantıları
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Öğretmen verileri
  String _ogretmenAdi = '';
  String _ogretmenEmail = '';
  String _ogretmenUid = '';
  int _ogrenciSayisi = 0;
  
  // PROFIL FOTOĞRAFI İÇİN (DÜZELTİLDİ)
  File? _profilFoto;
  final ImagePicker _picker = ImagePicker();
  
  // Öğrenci arama ve filtreleme
  bool _isLoading = false;
  List<Map<String, dynamic>> _bulunanOgrenciler = [];
  List<Map<String, dynamic>> _baglantiliOgrenciler = [];
  
  // Arama tipi
  bool _aramaYapiliyor = false;
  
  // TextEditingController'lar
  final TextEditingController _aramaController = TextEditingController();
  
  // Çıkış yapma kontrolü için
  bool _isSigningOut = false;
  
  // Gerçek zamanlı güncellemeler için Stream aboneliği
  StreamSubscription? _ogrenciStreamSubscription;
  
  @override
  void initState() {
    super.initState();
    _ogretmenVerileriniYukle();
    _profilFotoYukle(); // FOTO YÜKLE
    _baglantiliOgrencileriDinle();
    _saveFCMToken();
  }
  
  @override
  void dispose() {
    _aramaController.dispose();
    _ogrenciStreamSubscription?.cancel();
    super.dispose();
  }

  // FOTO YÜKLE (DÜZELTİLDİ)
  _profilFotoYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('profil_foto');
      if (path != null && File(path).existsSync()) {
        setState(() => _profilFoto = File(path));
      }
    } catch (e) {
      print('Profil fotoğrafı yüklenirken hata: $e');
    }
  }

  // FOTO SEÇ (AYNI)
  _fotoSec() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Profil Fotoğrafı'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final foto = await _picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 300,  // BOYUT KONTROL
                maxHeight: 300, // BOYUT KONTROL
                imageQuality: 85,
              );
              if (foto != null) _fotoKaydet(File(foto.path));
            },
            child: Text('Kamera'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final foto = await _picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 300,  // BOYUT KONTROL
                maxHeight: 300, // BOYUT KONTROL
                imageQuality: 85,
              );
              if (foto != null) _fotoKaydet(File(foto.path));
            },
            child: Text('Galeri'),
          ),
          if (_profilFoto != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _fotoSil();
              },
              child: Text('Sil', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  // FOTO KAYDET (DÜZELTİLDİ - PATH PROVIDER KULLANDIK)
  _fotoKaydet(File foto) async {
    try {
      // Doğru path'i al
      final appDir = await getApplicationDocumentsDirectory();
      final userId = _auth.currentUser?.uid ?? 'user';
      final fileName = 'profil_$userId.jpg';
      final newPath = '${appDir.path}/$fileName';
      
      // Dosyayı kopyala
      final savedFile = await foto.copy(newPath);
      
      // SharedPreferences'a kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profil_foto', newPath);
      
      // State güncelle
      setState(() => _profilFoto = savedFile);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil fotoğrafı kaydedildi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Foto kayıt hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf kaydedilemedi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // FOTO SİL (DÜZELTİLDİ)
  _fotoSil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_profilFoto != null && await _profilFoto!.exists()) {
        await _profilFoto!.delete();
      }
      await prefs.remove('profil_foto');
      setState(() => _profilFoto = null);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil fotoğrafı silindi'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Foto silme hatası: $e');
    }
  }

  // FCM token'ı kaydeden metod
  Future<void> _saveFCMToken() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .update({
            'fcmToken': token,
          });
          print('Öğretmen FCM Token kaydedildi: $token');
        }
      }
    } catch (e) {
      print('FCM token kaydedilirken hata: $e');
    }
  }
  
  // Öğretmen bilgilerini yükle
  Future<void> _ogretmenVerileriniYukle() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        _ogretmenUid = user.uid;
        
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists && mounted) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _ogretmenAdi = '${userData['isim']} ${userData['soyIsim']}';
            _ogretmenEmail = userData['email'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Öğretmen verileri yüklenirken hata: $e');
    }
  }
  
  // Bağlantılı öğrencileri gerçek zamanlı olarak dinle
  void _baglantiliOgrencileriDinle() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      User? user = _auth.currentUser;
      if (user == null) return;
      
      _ogretmenUid = user.uid;
      
      _ogrenciStreamSubscription = _firestore
          .collection('ogretmenOgrenci')
          .where('ogretmenId', isEqualTo: _ogretmenUid)
          .snapshots()
          .listen((snapshot) async {
            if (!mounted) return;
            
            List<Map<String, dynamic>> ogrenciler = [];
            
            for (var doc in snapshot.docs) {
              Map<String, dynamic> data = doc.data();
              String ogrenciId = data['ogrenciId'];
              String durum = data['durum'];
              
              DocumentSnapshot ogrenciDoc = await _firestore
                  .collection('users')
                  .doc(ogrenciId)
                  .get();
              
              if (ogrenciDoc.exists) {
                Map<String, dynamic> ogrenciData = ogrenciDoc.data() as Map<String, dynamic>;
                
                ogrenciler.add({
                  'id': ogrenciId,
                  'ad': '${ogrenciData['isim']} ${ogrenciData['soyIsim']}',
                  'email': ogrenciData['email'],
                  'durum': durum,
                  'baglanti_id': doc.id,
                  'timestamp': data['timestamp'] ?? Timestamp.now(),
                });
              }
            }
            
            if (mounted) {
              setState(() {
                _baglantiliOgrenciler = ogrenciler;
                _ogrenciSayisi = ogrenciler.where((o) => o['durum'] == 'onaylandı').length;
                _isLoading = false;
              });
            }
          }, onError: (error) {
            print('Öğrencileri dinlerken hata: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          });
      
    } catch (e) {
      print('Dinleyici başlatılırken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Manuel yenileme için eski metodu tutalım
  Future<void> _baglantiliOgrencileriGetir() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('ogretmenOgrenci')
          .where('ogretmenId', isEqualTo: _ogretmenUid)
          .get();
      
      List<Map<String, dynamic>> ogrenciler = [];
      
      for (var doc in snapshot.docs) {
        if (!mounted) return;
        
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String ogrenciId = data['ogrenciId'];
        String durum = data['durum'];
        
        DocumentSnapshot ogrenciDoc = await _firestore
            .collection('users')
            .doc(ogrenciId)
            .get();
        
        if (ogrenciDoc.exists) {
          Map<String, dynamic> ogrenciData = ogrenciDoc.data() as Map<String, dynamic>;
          
          ogrenciler.add({
            'id': ogrenciId,
            'ad': '${ogrenciData['isim']} ${ogrenciData['soyIsim']}',
            'email': ogrenciData['email'],
            'durum': durum,
            'baglanti_id': doc.id,
            'timestamp': data['timestamp'] ?? Timestamp.now(),
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _baglantiliOgrenciler = ogrenciler;
          _ogrenciSayisi = ogrenciler.where((o) => o['durum'] == 'onaylandı').length;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Öğrenci ara - TAM EŞLEŞTİRME için güncellendi
  Future<void> _ogrenciAra(String arama) async {
    if (!mounted || arama.isEmpty) {
      if (arama.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lütfen bir arama metni girin')),
        );
      }
      return;
    }
    
    setState(() {
      _isLoading = true;
      _aramaYapiliyor = true;
      _bulunanOgrenciler = [];
    });
    
    try {
      QuerySnapshot kullanicilarSnapshot = await _firestore
          .collection('users')
          .get();
      
      if (!mounted) return;
      
      List<Map<String, dynamic>> bulunanlar = [];
      
      for (var doc in kullanicilarSnapshot.docs) {
        if (!mounted) return;
        
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String ogrenciId = doc.id;
        
        String isim = data['isim'] ?? '';
        String soyIsim = data['soyIsim'] ?? '';
        String email = data['email'] ?? '';
        String kullaniciTipi = data['kullaniciTipi'] ?? '';
        
        String tamAd = '$isim $soyIsim';
        
        // TAM EŞLEŞTİRME: büyük/küçük harf duyarsız
        bool isimTamUyusuyor = tamAd.toLowerCase() == arama.toLowerCase();
        bool emailTamUyusuyor = email.toLowerCase() == arama.toLowerCase();
        
        if (kullaniciTipi == 'Öğrenci' && (isimTamUyusuyor || emailTamUyusuyor)) {
          bool zatenBagli = _baglantiliOgrenciler.any((element) => element['id'] == ogrenciId);
          
          if (!zatenBagli) {
            bulunanlar.add({
              'id': ogrenciId,
              'ad': tamAd,
              'email': email,
            });
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _bulunanOgrenciler = bulunanlar;
          _isLoading = false;
        });
        
        if (_bulunanOgrenciler.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Arama sonucunda öğrenci bulunamadı'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // 🎯 DÜZELTİLMİŞ - Öğrenciye istek gönder (tek kayıt sistemi)
  Future<void> _istekGonder(String ogrenciId, String ogrenciAdi) async {
    if (!mounted) return;
    
    try {
      final timestamp = FieldValue.serverTimestamp();
      
      // 🎯 SADECE ogretmenOgrenci koleksiyonuna ekle
      DocumentReference docRef = await _firestore.collection('ogretmenOgrenci').add({
        'ogretmenId': _ogretmenUid,
        'ogrenciId': ogrenciId,
        'durum': 'beklemede',
        'timestamp': timestamp,
      });
      
      print('✅ Mentor isteği kaydedildi: ${docRef.id}');
      
      // 🎯 FCM push notification için Cloud Function tetikle (opsiyonel)
      DocumentSnapshot ogrenciDoc = await _firestore.collection('users').doc(ogrenciId).get();
      if (ogrenciDoc.exists) {
        Map<String, dynamic> ogrenciData = ogrenciDoc.data() as Map<String, dynamic>;
        String? fcmToken = ogrenciData['fcmToken'];
        
        if (fcmToken != null) {
          print('🔔 FCM Push notification gönderilecek: $fcmToken');
          // Cloud Function burada devreye girecek
        }
      }
      
      if (!mounted) return;
      
      setState(() {
        _aramaYapiliyor = false;
        _aramaController.clear();
        _bulunanOgrenciler = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ogrenciAdi adlı öğrenciye mentor isteği gönderildi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
    } catch (e) {
      print('❌ İstek gönderilirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İstek gönderilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // 🎯 DÜZELTİLMİŞ - İsteği iptal et (tek kayıt sistemi)
  Future<void> _istegiIptalEt(String baglantiId, String ogrenciAdi) async {
    if (!mounted) return;
    
    try {
      // 🎯 SADECE ogretmenOgrenci kaydını sil
      await _firestore.collection('ogretmenOgrenci').doc(baglantiId).delete();
      
      print('✅ Mentor isteği iptal edildi: $baglantiId');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ogrenciAdi adlı öğrenciye gönderilen istek iptal edildi'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ İstek iptal edilirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İstek iptal edilirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Öğrenci bağlantısını sil
  Future<void> _ogrenciBaglantisiniSil(String baglantiId, String ogrenciAdi) async {
    if (!mounted) return;
    
    try {
      await _firestore.collection('ogretmenOgrenci').doc(baglantiId).delete();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ogrenciAdi adlı öğrenciyle bağlantınız silindi'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı silinirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Çıkış yap - düzeltilmiş versiyon
  void _cikisYap() {
    if (_isSigningOut) return;
    
    setState(() {
      _isSigningOut = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Çıkış Yapılıyor'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Lütfen bekleyin...'),
          ],
        ),
      ),
    );
    
    Future.delayed(Duration(milliseconds: 300), () {
      _logoutAndNavigate();
    });
  }
  
  // Çıkış yapma işlemi - düzeltilmiş versiyon
  Future<void> _logoutAndNavigate() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      await FirebaseAuth.instance.signOut();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userType');
      
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Çıkış yapılırken hata: $e');
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yaparken bir sorun oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
        
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy');
    final now = DateTime.now();
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final statusBarHeight = mediaQuery.padding.top;
    final appBarHeight = kToolbarHeight;
    final availableHeight = screenHeight - statusBarHeight;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        height: screenHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ThemeManager.primaryColor, ThemeManager.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.white))
            : RefreshIndicator(
                onRefresh: _baglantiliOgrencileriGetir,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: availableHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: statusBarHeight + appBarHeight + 16,
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tarih ve karşılama mesajı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Merhaba, $_ogretmenAdi',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    dateFormat.format(now),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Çevrimiçi',
                                  style: TextStyle(color: Colors.white),
                                ),
                              )
                            ],
                          ),
                          
                          SizedBox(height: 24),
                          
                          // Genel bilgiler kartı
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.people, color: Colors.white, size: 32),
                                ),
                                SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_baglantiliOgrenciler.where((o) => o['durum'] == 'beklemede').length}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Onay Bekleyen',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 24),
                          
                          // Öğrenci Ara başlığı
                          Text(
                            'Öğrenci Ara',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Arama kutusu
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _aramaController,
                                  decoration: InputDecoration(
                                    hintText: 'Tam İsim veya Tam E-posta ile Ara...',
                                    prefixIcon: Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading || _isSigningOut ? null : () {
                                  _ogrenciAra(_aramaController.text.trim());
                                },
                                child: Text('Ara', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeManager.tertiaryColor,
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          if (_aramaYapiliyor) ...[
                            SizedBox(height: 16),
                            // Arama sonuçları
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Arama Sonuçları',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close, color: Colors.white),
                                        onPressed: () {
                                          setState(() {
                                            _aramaYapiliyor = false;
                                            _aramaController.clear();
                                            _bulunanOgrenciler = [];
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  Divider(color: Colors.white30),
                                  _bulunanOgrenciler.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            children: [
                                              Icon(Icons.search_off, size: 48, color: Colors.white70),
                                              SizedBox(height: 8),
                                              Text(
                                                'Öğrenci bulunamadı',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Farklı bir isim veya e-posta ile arayın',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Column(
                                          children: _bulunanOgrenciler.map((ogrenci) {
                                            return Container(
                                              margin: EdgeInsets.only(bottom: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ListTile(
                                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                leading: CircleAvatar(
                                                  backgroundColor: ThemeManager.primaryColor.withOpacity(0.2),
                                                  child: Text(
                                                    ogrenci['ad'].toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join(''),
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: ThemeManager.primaryColor,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  ogrenci['ad'],
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                subtitle: Text(ogrenci['email']),
                                                trailing: ElevatedButton(
                                                  onPressed: _isSigningOut ? null : () {
                                                    _istekGonder(ogrenci['id'], ogrenci['ad']);
                                                  },
                                                  child: Text('İstek Gönder', style: TextStyle(color: Colors.white)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ],
                              ),
                            ),
                          ],
                          
                          SizedBox(height: 24),
                          
                          // Onay Bekleyenler Başlığı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Onay Bekleyenler',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${_baglantiliOgrenciler.where((o) => o['durum'] == 'beklemede').length} öğrenci',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 16),
                          
                          // SADECE BEKLEMEDE OLAN ÖĞRENCİLER LİSTESİ
                          _baglantiliOgrenciler.where((o) => o['durum'] == 'beklemede').isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Column(
                                    children: [
                                      Icon(Icons.people_outline, size: 64, color: Colors.white70),
                                      SizedBox(height: 16),
                                      Text(
                                        'Henüz onay bekleyen öğrenciniz yok',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Öğrencilere bağlanmak için yukarıdaki arama kutusunu kullanın',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: _baglantiliOgrenciler.where((o) => o['durum'] == 'beklemede').map((ogrenci) {
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.all(12),
                                        leading: CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Colors.orange.withOpacity(0.2),
                                          child: Icon(Icons.hourglass_empty, color: Colors.orange),
                                        ),
                                        title: Row(
                                          children: [
                                            Text(
                                              ogrenci['ad'],
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                'Beklemede',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(height: 4),
                                            Text(ogrenci['email'], style: TextStyle(fontSize: 14)),
                                            SizedBox(height: 4),
                                            Text(
                                              'İstek gönderildi',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(Icons.cancel_outlined, color: Colors.red),
                                          onPressed: _isSigningOut ? null : () {
                                            _istegiIptalEt(ogrenci['baglanti_id'], ogrenci['ad']);
                                          },
                                          tooltip: 'İsteği İptal Et',
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                          
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
      appBar: AppBar(
        title: Text('YKS Günlüğüm', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _isSigningOut ? null : _cikisYap,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: ThemeManager.primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BOYUT KONTROLLÜ PROFIL AVATAR (DÜZELTİLDİ)
                  GestureDetector(
                    onTap: _fotoSec,
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: ClipOval( // YUVARLAK KESİM İÇİN
                        child: _profilFoto != null
                            ? Image.file(
                                _profilFoto!,
                                width: 72,   // SABİT BOYUT
                                height: 72,  // SABİT BOYUT
                                fit: BoxFit.cover, // KESİP SİĞDIR
                              )
                            : Text(
                                _ogretmenAdi.isNotEmpty 
                                    ? _ogretmenAdi.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join('')
                                    : 'O',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: ThemeManager.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _ogretmenAdi.isNotEmpty ? _ogretmenAdi : 'Öğretmen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    _ogretmenEmail,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text('Ana Sayfa'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.dashboard),
              title: Text('Öğrencilerim'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OgrenciListesiSayfasi())
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Özelleştirme'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push( // 🎯 RESULT BEKLE
                  context,
                  MaterialPageRoute(builder: (context) => OzellistirmeEkrani())
                );
                
                // 🎯 RENK DEĞİŞTİĞİNDE SAYFAYI YENİLE
                if (result == true) {
                  setState(() {
                    // ThemeManager.loadTheme() otomatik çağrılacak
                    // Bu setState sayfayı yeniden build eder
                  });
                }
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.exit_to_app),
              title: Text('Çıkış Yap'),
              onTap: _isSigningOut ? null : _cikisYap,
            ),
          ],
        ),
      ),
    );
  }
}