import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:yksgunluk/dumenden/sevdigin_ders.dart';
import 'app_state.dart';

class BolumSecimiSayfasi extends StatefulWidget {
  @override
  _BolumSecimiSayfasiState createState() => _BolumSecimiSayfasiState();
}

class _BolumSecimiSayfasiState extends State<BolumSecimiSayfasi> {
  bool _isLoading = true;
  
  // Bölümlere göre AYT dersleri
  final Map<String, List<String>> bolumDersleri = {
    'Sayısal': ['Matematik', 'Fizik', 'Kimya', 'Biyoloji'],
    'Eşit Ağırlık': ['Matematik', 'Edebiyat', 'Tarih', 'Coğrafya'],
    'Sözel': ['Felsefe', 'Edebiyat', 'Tarih', 'Coğrafya', 'Din'],
  };
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        
        if (doc.exists) {
          Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
          
          if (data != null && data.containsKey('selectedBolum')) {
            String selectedBolum = data['selectedBolum'] as String? ?? '';
            if (selectedBolum.isNotEmpty) {
              Provider.of<AppState>(context, listen: false).setSelectedBolum(selectedBolum);
            }
          } else {
            print("Kullanıcı belgesi var ama 'selectedBolum' alanı yok.");
          }
        } else {
          print("Kullanıcı için belge henüz oluşturulmamış.");
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'createdAt': FieldValue.serverTimestamp(),
            'email': user.email,
          });
        }
      }
    } catch (e) {
      print("Kullanıcı bilgileri yüklenirken hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSelectedBolum(String bolum) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Bölümü kaydet
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'selectedBolum': bolum,
          'aytDersleri': bolumDersleri[bolum], // AYT derslerini de kaydet
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        Provider.of<AppState>(context, listen: false).setSelectedBolum(bolum);
        
        print("Bölüm başarıyla kaydedildi: $bolum");
        print("AYT Dersleri: ${bolumDersleri[bolum]}");
      }
    } catch (e) {
      print("Bölüm kaydedilirken hata: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bölüm kaydedilirken bir hata oluştu. Lütfen tekrar deneyin.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToSevilenDerslerSayfasi(BuildContext context) {
    if (Provider.of<AppState>(context, listen: false).selectedBolum.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SevilenDerslerSayfasi(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen bir bölüm seçin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Bölüm Seçimi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.lightBlue.shade700,
        elevation: 0,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.lightBlue, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(height: 40),
                Icon(Icons.school, size: 80, color: Colors.blue.shade700),
                SizedBox(height: 20),
                Text(
                  'Hangi Bölümde Okuyorsun?',
                  style: TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Bu seçim AYT derslerini belirleyecek',
                  style: TextStyle(
                    fontSize: 16, 
                    color: Colors.grey.shade700
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                
                // Sayısal Bölüm
                _buildBolumCard(
                  bolum: 'Sayısal',
                  aciklama: 'Matematik, Fizik, Kimya, Biyoloji',
                  icon: Icons.calculate,
                  color: Colors.green,
                  isSelected: appState.selectedBolum == 'Sayısal',
                  onTap: () => _saveSelectedBolum('Sayısal'),
                ),
                
                SizedBox(height: 20),
                
                // Eşit Ağırlık Bölüm
                _buildBolumCard(
                  bolum: 'Eşit Ağırlık',
                  aciklama: 'Matematik, Edebiyat, Tarih, Coğrafya',
                  icon: Icons.balance,
                  color: Colors.orange,
                  isSelected: appState.selectedBolum == 'Eşit Ağırlık',
                  onTap: () => _saveSelectedBolum('Eşit Ağırlık'),
                ),
                
                SizedBox(height: 20),
                
                // Sözel Bölüm
                _buildBolumCard(
                  bolum: 'Sözel',
                  aciklama: 'Felsefe, Edebiyat, Tarih, Coğrafya, Din',
                  icon: Icons.menu_book,
                  color: Colors.purple,
                  isSelected: appState.selectedBolum == 'Sözel',
                  onTap: () => _saveSelectedBolum('Sözel'),
                ),
                
                SizedBox(height: 40),
                
                if (appState.selectedBolum.isNotEmpty)
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _navigateToSevilenDerslerSayfasi(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 60),
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Devam Et',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.white
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildBolumCard({
    required String bolum,
    required String aciklama,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      child: Card(
        elevation: isSelected ? 8 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: isSelected ? color : Colors.transparent,
            width: 3,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bolum,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? color : Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        aciklama,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 20),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}