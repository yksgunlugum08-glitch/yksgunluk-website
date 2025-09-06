import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yksgunluk/dumenden/app_state.dart';
import 'package:yksgunluk/dumenden/bolum_secimii.dart';
import 'package:yksgunluk/ogretmen/ogretmen.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _isObscure = true; // Şifre görünürlüğü için
  String _userType = 'Öğrenci'; // Varsayılan kullanıcı tipi

  Future<void> _registerUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        User? user = userCredential.user;

        if (user != null) {
          // Firestore'a kullanıcı verilerini ekle
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'isim': nameController.text.trim(),
            'soyIsim': surnameController.text.trim(),
            'email': emailController.text.trim(),
            'kullaniciTipi': _userType,
            'olusturmaTarihi': FieldValue.serverTimestamp(),
            // Şifreyi Firestore'a kaydetmiyoruz
          }).catchError((error) {
            setState(() {
              _errorMessage = 'Veritabanı hatası: $error';
            });
            return;
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userType', _userType);

          Provider.of<AppState>(context, listen: false).setLoggedIn(true);
          Provider.of<AppState>(context, listen: false).setUserType(_userType);

          if (!mounted) return;
          
          // Kullanıcı tipine göre farklı sayfalara yönlendirme
          if (_userType == 'Öğretmen') {
            // Öğretmen ise doğrudan öğretmen ana sayfasına yönlendir
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => OgretmenPaneli()),
            );
          } else {
            // Öğrenci ise bölüm seçimi sayfasına yönlendir
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BolumSecimiSayfasi()),
            );
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Kayıt işlemi sırasında bir hata oluştu: ${e.toString()}';
        });

        await Future.delayed(Duration(seconds: 3));
        setState(() {
          _errorMessage = null;
        });
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 36,
                    horizontal: 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Kayıt Ol',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 24),
                        if (_errorMessage != null)
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red),
                          ),
                        SizedBox(height: 16),
                        // Kullanıcı tipi seçimi
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, color: Colors.blue),
                              SizedBox(width: 10),
                              Text('Kullanıcı Tipi:', style: TextStyle(fontSize: 16)),
                              Spacer(),
                              DropdownButton<String>(
                                value: _userType,
                                underline: Container(height: 0),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _userType = newValue!;
                                  });
                                },
                                items: <String>['Öğrenci', 'Öğretmen']
                                    .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: TextStyle(
                                        color: value == 'Öğretmen' ? Colors.red : Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Ad',
                            prefixIcon: Icon(Icons.person, color: Colors.blue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen adınızı girin.';
                            } else if (value.length < 2) {
                              return 'Ad en az 2 karakter olmalıdır.';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: surnameController,
                          decoration: InputDecoration(
                            labelText: 'Soyad',
                            prefixIcon: Icon(Icons.person, color: Colors.blue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen soyadınızı girin.';
                            } else if (value.length < 2) {
                              return 'Soyad en az 2 karakter olmalıdır.';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'E-posta',
                            prefixIcon: Icon(Icons.email, color: Colors.blue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen bir e-posta adresi girin.';
                            } else if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Lütfen geçerli bir e-posta adresi girin.';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          obscureText: _isObscure,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            prefixIcon: Icon(Icons.lock, color: Colors.blue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isObscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isObscure = !_isObscure;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen bir şifre girin.';
                            } else if (value.length < 8 ||
                                !RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_])[A-Za-z\d@$!%*?&_]{8,}$')
                                    .hasMatch(value)) {
                              return 'Şifre en az 8 karakter, büyük harf, küçük harf, sayı ve özel karakter içermelidir.';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _registerUser,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            backgroundColor: _userType == 'Öğretmen' ? Colors.red : Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _userType == 'Öğretmen' ? 'Öğretmen Olarak Kayıt Ol' : 'Öğrenci Olarak Kayıt Ol',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: _navigateToLogin,
                          child: Text('Zaten hesabınız var mı? Giriş Yap'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}