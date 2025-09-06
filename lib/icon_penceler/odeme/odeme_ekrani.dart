import 'dart:async';
import 'dart:convert'; // json için eklendi
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http; // HTTP istekleri için eklendi

// Abonelik ID'leri - bunları Google Play konsolunuzda ayarlamalısınız
const Set<String> _productIds = {
  'aylik_plan',  // Aylık plan
  '135790___135790...135790',   // Yıllık plan
};

// Firebase Function URL
const String VERIFY_PURCHASE_URL = 'https://verifypurchase-niwl4x4nca-uc.a.run.app';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({Key? key}) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isLoading = true;
  bool _isPending = false;
  String? _queryError;
  bool _showPremiumFeatures = false;
  
  // Connection initialization status
  bool _connectionInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Debug log
    debugPrint('SubscriptionScreen initState çağrıldı');
    
    // Stream'i dinlemeye başla
    final Stream<List<PurchaseDetails>> purchaseUpdated = 
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _processPurchaseUpdates(purchaseDetailsList);
      },
      onDone: () {
        debugPrint('Stream kapandı');
        _subscription.cancel();
      },
      onError: (error) {
        debugPrint('Stream hata verdi: $error');
      }
    );
    
    // Store bilgilerini yükle
    _initializeConnection();
  }
  
  // Satın alma stream'ini işle
  void _processPurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    debugPrint('Satın alma güncellemesi alındı: ${purchaseDetailsList.length} adet');
    
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('Satın alma durumu: Beklemede');
        setState(() {
          _isPending = true;
        });
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Satın alma durumu: Hata - ${purchaseDetails.error}');
          _handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased || 
                  purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('Satın alma durumu: ${purchaseDetails.status == PurchaseStatus.purchased ? "Satın alındı" : "Geri yüklendi"}');
          await _verifyAndDeliverProduct(purchaseDetails);
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          debugPrint('Satın alma tamamlanıyor...');
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        
        setState(() {
          _isPending = false;
        });
      }
    });
  }
  
  // Bağlantıyı başlat ve ürünleri yükle
  Future<void> _initializeConnection() async {
    debugPrint('Mağaza bağlantısı başlatılıyor...');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Mağazanın kullanılabilir olup olmadığını kontrol et
      final bool isAvailable = await _inAppPurchase.isAvailable();
      debugPrint('Mağaza kullanılabilir: $isAvailable');
      
      if (!isAvailable) {
        setState(() {
          _isAvailable = false;
          _isLoading = false;
          _products = [];
          _connectionInitialized = true;
        });
        return;
      }
      
      // Ürünleri sorgula
      debugPrint('Ürünler sorgulanıyor: $_productIds');
      final ProductDetailsResponse response = 
          await _inAppPurchase.queryProductDetails(_productIds);
      
      if (response.error != null) {
        debugPrint('Ürün sorgusu hatası: ${response.error}');
        setState(() {
          _queryError = response.error!.message;
          _isAvailable = isAvailable;
          _isLoading = false;
          _connectionInitialized = true;
        });
        return;
      }
      
      if (response.productDetails.isEmpty) {
        debugPrint('Hiç ürün bulunamadı!');
        setState(() {
          _queryError = 'Hiçbir abonelik planı bulunamadı.';
          _isAvailable = isAvailable;
          _isLoading = false;
          _connectionInitialized = true;
        });
        return;
      }
      
      debugPrint('${response.productDetails.length} adet ürün bulundu');
      // Her ürün için bilgi yazdır
      for (var product in response.productDetails) {
        debugPrint('Ürün: ${product.id} - ${product.title} - ${product.price}');
      }
      
      setState(() {
        _products = response.productDetails;
        _isAvailable = true;
        _isLoading = false;
        _connectionInitialized = true;
      });
      
      // Premium durumunu kontrol et
      _checkPremiumStatus();
      
    } catch (e) {
      debugPrint('Bağlantı kurulurken hata: $e');
      setState(() {
        _isAvailable = false;
        _isLoading = false;
        _queryError = 'Mağaza bağlantısı kurulamadı: $e';
        _connectionInitialized = true;
      });
    }
  }
  
  @override
  void dispose() {
    debugPrint('SubscriptionScreen dispose çağrıldı');
    _subscription.cancel();
    super.dispose();
  }

  // Premium durumunu kontrol etmek için
  Future<void> _checkPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showPremiumFeatures = prefs.getBool('isPremium') ?? false;
    });
    
    if (_showPremiumFeatures) {
      debugPrint('Kullanıcı premium üye');
      // Premium kullanıcı için bitiş tarihini kontrol et
      final expiryDateStr = prefs.getString('premiumExpiry');
      if (expiryDateStr != null) {
        final expiryDate = DateTime.parse(expiryDateStr);
        final now = DateTime.now();
        debugPrint('Premium bitiş tarihi: $expiryDate');
        
        if (expiryDate.isBefore(now)) {
          debugPrint('Premium üyelik süresi dolmuş!');
          await prefs.setBool('isPremium', false);
          setState(() {
            _showPremiumFeatures = false;
          });
        }
      }
    } else {
      debugPrint('Kullanıcı premium üye değil');
    }
  }

  // Satın alma hatasını işleme
  void _handleError(IAPError error) {
    debugPrint('Satın alma hatası: ${error.message} (${error.code})');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Satın alma işlemi sırasında bir hata oluştu: ${error.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Ürün satın alımını doğrula ve teslim et
  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    bool isValid = await _verifyPurchaseWithServer(purchaseDetails);
    
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma doğrulanamadı. Lütfen destek ile iletişime geçin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Satın alım başarılı, premium özellikleri etkinleştir
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', true);
    
    if (purchaseDetails.productID == 'yks_premium_monthly') {
      // Aylık abonelik - 30 gün ekle
      final expiryDate = DateTime.now().add(Duration(days: 30));
      await prefs.setString('premiumExpiry', expiryDate.toIso8601String());
      await prefs.setString('subscriptionType', 'monthly');
      debugPrint('Aylık abonelik aktif edildi. Bitiş tarihi: $expiryDate');
    } else if (purchaseDetails.productID == 'yks_premium_yearly') {
      // Yıllık abonelik - 365 gün ekle
      final expiryDate = DateTime.now().add(Duration(days: 365));
      await prefs.setString('premiumExpiry', expiryDate.toIso8601String());
      await prefs.setString('subscriptionType', 'yearly');
      debugPrint('Yıllık abonelik aktif edildi. Bitiş tarihi: $expiryDate');
    }
    
    // Satın alma kaydını Firestore'a ekle (isteğe bağlı)
    await _savePurchaseToFirestore(purchaseDetails);
    
    setState(() {
      _showPremiumFeatures = true;
    });
    
    // Başarılı mesajı göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Premium üyelik etkinleştirildi!'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  // Sunucuda satın almayı doğrula - Firebase Function kullanarak
  Future<bool> _verifyPurchaseWithServer(PurchaseDetails purchaseDetails) async {
    try {
      // Kullanıcı ID'sini al
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Kullanıcı oturum açmamış!');
        return false;
      }
      
      debugPrint('Firebase Cloud Function ile satın alma doğrulaması yapılıyor...');
      
      // Firebase Function'a istek gönder
      final response = await http.post(
        Uri.parse(VERIFY_PURCHASE_URL),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'productId': purchaseDetails.productID,
          'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
          'userId': user.uid,
        }),
      );
      
      debugPrint('Sunucu yanıtı: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Doğrulama yanıtı: $data');
        return data['isValid'] == true;
      } else {
        debugPrint('Sunucu hatası: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Sunucu doğrulama hatası: $e');
      // Hata durumunda, geliştirme aşamasında doğru kabul edebilirsiniz
      // ama canlı ortamda daha güvenli bir çözüm uygulamanız gerekir
      if (kDebugMode) {
        return true; // Geliştirme modunda true dön
      }
      return false;
    }
  }
  
  // Satın alma kayıtlarını Firestore'a kaydet
  Future<void> _savePurchaseToFirestore(PurchaseDetails purchaseDetails) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('purchases')
            .doc(purchaseDetails.purchaseID)
            .set({
          'productId': purchaseDetails.productID,
          'purchaseTime': DateTime.now(),
          'transactionDate': purchaseDetails.transactionDate,
          'status': purchaseDetails.status.toString(),
          'type': purchaseDetails.productID == 'yks_premium_monthly' ? 'monthly' : 'yearly',
        });
      }
    } catch (e) {
      // Kayıt başarısız olsa da kullanıcı deneyimini etkilemez
      debugPrint('Firestore kaydı hatası: $e');
    }
  }

  // Satın alma işlemini başlat
  Future<void> _buyProduct(ProductDetails product) async {
    debugPrint('Ürün satın alma başlatılıyor: ${product.id}');
    
    setState(() {
      _isPending = true;
    });
    
    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );
      
      // Abonelik ürünleri için
      if (product.id.contains('monthly') || product.id.contains('yearly')) {
        debugPrint('Abonelik satın alınıyor...');
        
        // Google Play Store'da otomatik yenilenen abonelikler için:
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Tek seferlik satın alma ürünü
        debugPrint('Tek seferlik ürün satın alınıyor...');
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
      
      debugPrint('Satın alma isteği başarıyla gönderildi');
    } catch (e) {
      debugPrint('Satın alma hatası: $e');
      setState(() {
        _isPending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Önceki satın alımları geri yükle
  Future<void> _restorePurchases() async {
    debugPrint('Önceki satın alımlar geri yükleniyor...');
    setState(() {
      _isPending = true;
    });
    
    try {
      await _inAppPurchase.restorePurchases();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alımlar geri yükleniyor...'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      debugPrint('Geri yükleme hatası: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alımlar geri yüklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isPending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Premium Üyelik'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingWidget()
          : _isAvailable
              ? _buildSubscriptionContent()
              : _buildErrorWidget(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.indigo),
          SizedBox(height: 20),
          Text('Abonelik bilgileri yükleniyor...', 
            style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          if (!_connectionInitialized) SizedBox(height: 10),
          if (!_connectionInitialized)
            Text(
              'Mağaza bağlantısı kuruluyor...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
        ],
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              _queryError ?? 'Store servisine bağlanılamadı',
              style: TextStyle(fontSize: 16, color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _initializeConnection(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo, Colors.indigo.shade700],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(20, 30, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 50,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'YKS Günlüğüm Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Tüm premium özellikleri kullanarak çalışmalarınızı bir üst seviyeye taşıyın!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Premium features
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Özellikleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 15),
                _buildFeatureItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: 'Kendi verilerin ile kendi çalışma stilini oluşturma',
                ),
                _buildFeatureItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: 'Özel çalışma programları',
                ),
                _buildFeatureItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: 'Detaylı istatistikler ve grafikler',
                ),
                _buildFeatureItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: 'Mentorunuz ile anlık veri paylaşımı ve geri bildirim alma ',
                ),
                _buildFeatureItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: 'Sosyal medya ile sınav deneyimini paylaşma',
                ),
                _buildFeatureItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: 'Reklamsız deneyim',
                ),
              ],
            ),
          ),
          
          // Subscription plans
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abonelik Planları',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 15),
                
                // Abonelik kartları
                if (_products.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Abonelik planları yüklenemedi.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  Column(
                    children: _products.map((product) => 
                      _buildSubscriptionCard(product)
                    ).toList(),
                  ),
              ],
            ),
          ),
          
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required Color color, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(ProductDetails product) {
    final isYearly = product.id.contains('yearly');
    final isBestValue = isYearly;
    
    String priceText = product.price;
    String period = isYearly ? 'yıl' : 'ay';
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: isYearly ? Colors.indigo.shade300 : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: isYearly 
              ? Colors.indigo.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ana içerik
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(15),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isYearly ? 'Yıllık Premium' : 'Aylık Premium',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 5),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                              children: [
                                TextSpan(text: priceText),
                                TextSpan(text: ' / $period'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isPending 
                        ? null
                        : () => _buyProduct(product),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isYearly 
                          ? Colors.indigo
                          : Colors.blue.shade700,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isPending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Satın Al',
                            style: TextStyle(color: Colors.white),
                          ),
                    ),
                  ],
                ),
              ),
              
              // Abonelik detayları
              if (isYearly) 
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(13),
                      bottomRight: Radius.circular(13),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Aylık plana göre %50 tasarruf',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          // "En İyi Değer" etiketi
          if (isBestValue)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(13),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: Text(
                  'En İyi Değer',
                  style: TextStyle(
                    color: Colors.brown[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Abonelik Hakkında'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium aboneliğiniz, seçtiğiniz süre sonunda otomatik olarak yenilenir. İstediğiniz zaman hesap ayarlarınızdan iptal edebilirsiniz.',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 15),
                        Text(
                          'Aboneliğinizi Google Play Store veya App Store hesap ayarlarınızdan yönetebilirsiniz.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Tamam'),
                    ),
                  ],
                ),
              );
            },
            child: Text(
              'Koşullar',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: _restorePurchases,
            child: Text(
              'Satın Alımları Geri Yükle',
              style: TextStyle(color: Colors.indigo),
            ),
          ),
        ],
      ),
    );
  }
}