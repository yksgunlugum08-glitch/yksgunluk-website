import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yksgunluk/ekranlar/home_page.dart';
// import 'package:provider/provider.dart';
// import 'package:yksgunluk/ekranlar/home_page.dart';
// import 'app_state.dart';

class KaydetSayfasi extends StatefulWidget {
  @override
  _KaydetSayfasiState createState() => _KaydetSayfasiState();
}

class _KaydetSayfasiState extends State<KaydetSayfasi> {
  final TextEditingController _hedefSiralamaController = TextEditingController();
  final TextEditingController _bolumSorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Artık AppState kullanılmıyor, Firebase'den okuma ekleyebilirsin istersen.
  }

  void _saveAndGoToMainPage(BuildContext context) async {
    String hedefSiralama = _hedefSiralamaController.text;
    String bolumSor = _bolumSorController.text;

    if (_validateInputs(hedefSiralama, bolumSor)) {
      try {
        // Kullanıcı giriş yaptıysa, UID ile veriyi kaydet
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'hedefSiralama': hedefSiralama,
            'bolumSor': bolumSor,
            'kayitTarihi': FieldValue.serverTimestamp(), // isteğe bağlı
          }, SetOptions(merge: true));
        }
        // Kayıt başarılıysa ana ekrana yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AnaEkran(),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veri kaydedilirken hata oluştu: $e'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen geçerli değerler girin.'),
        ),
      );
    }
  }

  bool _validateInputs(String hedefSiralama, String bolumSor) {
    final siralamaValid = hedefSiralama.isNotEmpty && int.tryParse(hedefSiralama) != null;
    final bolumSorValid = bolumSor.length >= 3;
    return siralamaValid && bolumSorValid;
  }

  void _goBack(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlue, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hedeflerinizi Belirleyin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _hedefSiralamaController,
                decoration: InputDecoration(
                  labelText: 'Hedef Sıralama',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _bolumSorController,
                decoration: InputDecoration(
                  labelText: 'Hedef Bölüm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => _goBack(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(100, 50),
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    child: Text(
                      'İptal',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _saveAndGoToMainPage(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(100, 50),
                      backgroundColor: Colors.lightBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    child: Text(
                      'Kaydet',
                      style: TextStyle(color: Colors.white),
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
}