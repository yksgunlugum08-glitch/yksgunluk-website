import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yksgunluk/giris/auth_screen.dart';
import 'package:yksgunluk/icon_penceler/bilgilerimi_guncelle.dart';
import 'dart:async';

class Bilgilerim extends StatefulWidget {
  const Bilgilerim({Key? key}) : super(key: key);

  @override
  _BilgilerimState createState() => _BilgilerimState();
}

class _BilgilerimState extends State<Bilgilerim> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _sifreController = TextEditingController();
  
  bool _isSilmeIslemiBasladi = false;
  int _sayac = 3;
  Timer? _timer;

  late Future<DocumentSnapshot<Map<String, dynamic>>> _userDoc;

  @override
  void initState() {
    super.initState();
    _userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid).get();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _guncelleBilgi(String key, String deger) async {
    try {
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({key: deger});
      setState(() {
        _userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid).get();
      });
    } catch (e) {
      print('Hata: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncelleme sırasında bir hata oluştu: ${e.toString()}')),
      );
    }
  }
  
  // Şifre doğrulama işlemi
  Future<bool> _sifreDogrula(String sifre) async {
    try {
      // Kullanıcının email'ini al
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return false;
      }
      
      // Email ve şifre ile yeniden kimlik doğrulama yap
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: sifre,
      );
      
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('Şifre doğrulama hatası: ${e.toString()}');
      return false;
    }
  }
  
  // Hesabı silme işlemi - AuthScreen'e yönlendirme güncellendi
  Future<void> _hesabiSil() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Firestore'dan kullanıcı verilerini sil
        await _firestore.collection('users').doc(user.uid).delete();
        
        // Authentication'dan hesabı sil
        await user.delete();
        
        // Başarılı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hesabınız başarıyla silindi.')),
        );
        
        // Çıkış yapıp AuthScreen'e yönlendir
        await _auth.signOut();
        
        // Named route yerine doğrudan AuthScreen'e yönlendir
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => AuthScreen()),
          (route) => false, // tüm önceki rotaları kaldır
        );
      }
    } catch (e) {
      print('Hesap silme hatası: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hesap silme işlemi başarısız: ${e.toString()}')),
      );
    }
  }
  
  // Şifre onay dialogunu göster
  Future<void> _sifreOnayDialogGoster() async {
    _sifreController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Şifreyi Doğrulayın'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hesabınızı silmek için şifrenizi giriniz.'),
              SizedBox(height: 16),
              TextField(
                controller: _sifreController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (await _sifreDogrula(_sifreController.text)) {
                  Navigator.of(context).pop();
                  _geriSayimBaslat();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Şifre yanlış!')),
                  );
                }
              },
              child: Text('Devam'),
            ),
          ],
        );
      },
    );
  }
  
  // Geri sayım işlemi - Güncellenmiş versiyonu
  void _geriSayimBaslat() {
    setState(() {
      _isSilmeIslemiBasladi = true;
      _sayac = 3;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Timer'ı burada başlatıyoruz
            _timer = Timer.periodic(Duration(seconds: 1), (timer) {
              setDialogState(() {
                if (_sayac > 1) {
                  _sayac--;
                } else if (_sayac == 1) {
                  _sayac--;
                  timer.cancel();
                  // Geri sayım bitince dialog'u kapat ve son onay dialogunu göster
                  Future.delayed(Duration(milliseconds: 500), () {
                    Navigator.of(context).pop();
                    _sonOnayDialogGoster();
                  });
                }
              });
            });
            
            return AlertDialog(
              title: Text('Hesabınız Silinecek'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hesap silme işlemi başlatıldı.', 
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        "$_sayac",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _timer?.cancel();
                    Navigator.of(context).pop();
                    setState(() {
                      _isSilmeIslemiBasladi = false;
                    });
                  },
                  child: Text('İptal'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  // Son onay dialogunu göster
  void _sonOnayDialogGoster() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Emin misiniz?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Bu işlem geri alınamaz!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text('Hesabınız ve tüm verileriniz kalıcı olarak silinecek.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isSilmeIslemiBasladi = false;
                });
              },
              child: Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _hesabiSil();
              },
              child: Text('Hesabımı Sil'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilgilerim'),
        centerTitle: true,
        backgroundColor: Colors.lightBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _userDoc,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return const Center(child: Text('Veriler yüklenirken bir hata oluştu.'));
            } else if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Kullanıcı verileri bulunamadı.'));
            } else {
              var userData = snapshot.data!.data();
              return Column(
                children: [
                  _buildBilgiTile('İsim', userData?['isim'], 'isim'),
                  const Divider(),
                  _buildBilgiTile('Soy İsim', userData?['soyIsim'], 'soyIsim'),
                  const Divider(),
                  _buildBilgiTile('E-posta', userData?['email'], 'email'),
                  const Divider(),
                  _buildBilgiTile('Şifre', userData?['sifre'], 'sifre'),
                  const Divider(),
                  const SizedBox(height: 32),
                  // Hesabı Sil Butonu
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _sifreOnayDialogGoster,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_forever),
                        SizedBox(width: 8),
                        Text('Hesabımı Sil', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildBilgiTile(String baslik, String? mevcutBilgi, String key) {
    return ListTile(
      leading: Icon(_getIconForKey(key)),
      title: Text(baslik),
      subtitle: Text(mevcutBilgi ?? ''),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () async {
          final yeniBilgi = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BilgiGuncellemeEkrani(
                baslik: '$baslik Güncelleme',
                mevcutBilgi: mevcutBilgi ?? '',
                bilgiKey: key,
                onGuncelle: _guncelleBilgi,
                validator: _getValidatorForKey(key),
              ),
            ),
          );
          if (yeniBilgi != null) {
            _guncelleBilgi(key, yeniBilgi);
          }
        },
      ),
    );
  }

  IconData _getIconForKey(String key) {
    switch (key) {
      case 'isim':
        return Icons.person;
      case 'soyIsim':
        return Icons.person_outline;
      case 'email':
        return Icons.email;
      case 'sifre':
        return Icons.lock;
      default:
        return Icons.info;
    }
  }

  String? Function(String?)? _getValidatorForKey(String key) {
    switch (key) {
      case 'isim':
      case 'soyIsim':
        return (value) {
          if (value == null || value.isEmpty) {
            return 'Lütfen bir değer girin.';
          } else if (value.length < 2) {
            return 'Değer en az 2 karakter olmalıdır.';
          }
          return null;
        };
      case 'email':
        return (value) {
          if (value == null || value.isEmpty) {
            return 'Lütfen bir e-posta adresi girin.';
          } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
              .hasMatch(value)) {
            return 'Lütfen geçerli bir e-posta adresi girin.';
          }
          return null;
        };
      case 'sifre':
        return (value) {
          if (value == null || value.isEmpty) {
            return 'Lütfen bir şifre girin.';
          } else if (value.length < 8 ||
              !RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_])[A-Za-z\d@$!%*?&_]{8,}$')
                  .hasMatch(value)) {
            return 'Şifre en az 8 karakter, büyük harf, küçük harf, sayı ve özel karakter içermelidir.';
          }
          return null;
        };
      default:
        return null;
    }
  }
}