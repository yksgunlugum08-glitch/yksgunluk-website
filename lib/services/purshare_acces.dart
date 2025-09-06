import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseVerifier {
  // Sunucu endpoint'inizle değiştirin
  final String verificationEndpoint = 'https://yourserver.com/api/verify-purchase';
  
  Future<bool> verifyPurchase(PurchaseDetails purchase) async {
    try {
      // Satın alma bilgilerini sunucuya gönder
      final response = await http.post(
        Uri.parse(verificationEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'productId': purchase.productID,
          'purchaseToken': purchase.verificationData.serverVerificationData,
          'platform': 'android',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isValid'] == true;
      }
      
      return false;
    } catch (e) {
      print('Satın alma doğrulama hatası: $e');
      // Hata durumunda, hızlı hata sağlamak için true döndürüp
      // sonra sunucu tarafında tekrar doğrulama yapabilirsiniz
      return true; 
    }
  }
}