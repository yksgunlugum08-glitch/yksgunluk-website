import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BilgiGuncellemeEkrani extends StatefulWidget {
  final String baslik;
  final String mevcutBilgi;
  final String bilgiKey;
  final Function(String bilgiKey, String deger) onGuncelle;
  final String? Function(String?)? validator;

  const BilgiGuncellemeEkrani({
    Key? key,
    required this.baslik,
    required this.mevcutBilgi,
    required this.bilgiKey,
    required this.onGuncelle,
    required this.validator,
  }) : super(key: key);

  @override
  _BilgiGuncellemeEkraniState createState() => _BilgiGuncellemeEkraniState();
}

class _BilgiGuncellemeEkraniState extends State<BilgiGuncellemeEkrani> {
  late TextEditingController _mevcutSifreController;
  late TextEditingController _yeniSifreController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  bool _mevcutSifreGorunur = false; // Mevcut şifre görünürlük durumu
  bool _yeniSifreGorunur = false; // Yeni şifre görünürlük durumu

  @override
  void initState() {
    super.initState();
    _mevcutSifreController = TextEditingController();
    _yeniSifreController = TextEditingController();
  }

  @override
  void dispose() {
    _mevcutSifreController.dispose();
    _yeniSifreController.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_formKey.currentState!.validate()) {
      final user = _auth.currentUser;
      final mevcutSifre = _mevcutSifreController.text;
      final yeniSifre = _yeniSifreController.text;

      try {
        // Mevcut şifreyi kontrol et
        final credential = EmailAuthProvider.credential(
          email: user!.email!,
          password: mevcutSifre,
        );
        await user.reauthenticateWithCredential(credential);

        // Yeni şifreyi güncelle
        await user.updatePassword(yeniSifre);

        // Veritabanını güncelle (isteğe bağlı)
        await _firestore.collection('users').doc(user.uid).update({
          widget.bilgiKey: yeniSifre, // Şifre burada saklanmamalı, sadece örnek
        });

        widget.onGuncelle(widget.bilgiKey, yeniSifre);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre başarıyla güncellendi!')),
        );
        Navigator.pop(context, yeniSifre);
      } catch (e) {
        // Mevcut şifre yanlışsa hata mesajı göster
        if (e is FirebaseAuthException && e.code == 'wrong-password') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mevcut şifre yanlış. Lütfen tekrar deneyin.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: ${e.toString()}')),
          );
        }
      }
    }
  }

  String? _yeniSifreValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Yeni şifre boş bırakılamaz.';
    }

    final regex =
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$');
    if (!regex.hasMatch(value)) {
      return 'Şifre en az bir küçük harf, bir büyük harf, bir rakam, bir özel karakter içermeli ve en az 8 karakter olmalıdır.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.baslik),
        backgroundColor: Colors.lightBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Mevcut Şifre Alanı
              TextFormField(
                controller: _mevcutSifreController,
                obscureText: !_mevcutSifreGorunur,
                decoration: InputDecoration(
                  labelText: 'Mevcut Şifre',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mevcutSifreGorunur ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _mevcutSifreGorunur = !_mevcutSifreGorunur;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mevcut şifre boş bırakılamaz.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Yeni Şifre Alanı
              TextFormField(
                controller: _yeniSifreController,
                obscureText: !_yeniSifreGorunur,
                decoration: InputDecoration(
                  labelText: 'Yeni Şifre',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _yeniSifreGorunur ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _yeniSifreGorunur = !_yeniSifreGorunur;
                      });
                    },
                  ),
                ),
                validator: _yeniSifreValidator,
              ),
              const SizedBox(height: 20),
              // Kaydet Butonu
              ElevatedButton(
                onPressed: _kaydet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                ),
                child: const Text(
                  'Kaydet',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}