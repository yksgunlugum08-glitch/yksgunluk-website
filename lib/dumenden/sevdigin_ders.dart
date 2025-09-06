import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yksgunluk/dumenden/hedef_siralama.dart';
import 'app_state.dart';

class SevilenDerslerSayfasi extends StatefulWidget {
  @override
  _SevilenDerslerSayfasiState createState() => _SevilenDerslerSayfasiState();
}

class _SevilenDerslerSayfasiState extends State<SevilenDerslerSayfasi> {
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDersler = prefs.getStringList('selectedDersler') ?? [];
    if (selectedDersler.isNotEmpty) {
      for (var ders in selectedDersler) {
        Provider.of<AppState>(context, listen: false).toggleDers(ders);
      }
    }
  }

  Future<void> _saveSelectedDersler() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedDersler = Provider.of<AppState>(context, listen: false).selectedDersler;
    await prefs.setStringList('selectedDersler', selectedDersler);
  }

  void _navigateToKaydetSayfasi(BuildContext context) {
    if (Provider.of<AppState>(context, listen: false).selectedDersler.isNotEmpty) {
      _saveSelectedDersler();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KaydetSayfasi(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lütfen en az bir ders seçin.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = Provider.of<AppState>(context);

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
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'En Sevdiğiniz 3 Dersi Seçiniz',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                DersSecimButonu(
                  ders: 'Matematik',
                  isSelected: appState.selectedDersler.contains('Matematik'),
                  onTap: () => appState.toggleDers('Matematik'),
                ),
                DersSecimButonu(
                  ders: 'Türkçe',
                  isSelected: appState.selectedDersler.contains('Türkçe'),
                  onTap: () => appState.toggleDers('Türkçe'),
                ),
                DersSecimButonu(
                  ders: 'Edebiyat',
                  isSelected: appState.selectedDersler.contains('Edebiyat'),
                  onTap: () => appState.toggleDers('Edebiyat'),
                ),
                DersSecimButonu(
                  ders: 'Fizik',
                  isSelected: appState.selectedDersler.contains('Fizik'),
                  onTap: () => appState.toggleDers('Fizik'),
                ),
                DersSecimButonu(
                  ders: 'Kimya',
                  isSelected: appState.selectedDersler.contains('Kimya'),
                  onTap: () => appState.toggleDers('Kimya'),
                ),
                DersSecimButonu(
                  ders: 'Biyoloji',
                  isSelected: appState.selectedDersler.contains('Biyoloji'),
                  onTap: () => appState.toggleDers('Biyoloji'),
                ),
                DersSecimButonu(
                  ders: 'Tarih',
                  isSelected: appState.selectedDersler.contains('Tarih'),
                  onTap: () => appState.toggleDers('Tarih'),
                ),
                DersSecimButonu(
                  ders: 'Coğrafya',
                  isSelected: appState.selectedDersler.contains('Coğrafya'),
                  onTap: () => appState.toggleDers('Coğrafya'),
                ),
                DersSecimButonu(
                  ders: 'Felsefe',
                  isSelected: appState.selectedDersler.contains('Felsefe'),
                  onTap: () => appState.toggleDers('Felsefe'),
                ),
                DersSecimButonu(
                  ders: 'Din',
                  isSelected: appState.selectedDersler.contains('Din'),
                  onTap: () => appState.toggleDers('Din'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: 'hero-back-button',
              onPressed: () => Navigator.pop(context),
              backgroundColor: Colors.lightBlue,
              child: Icon(Icons.arrow_back),
            ),
            FloatingActionButton(
              heroTag: 'hero-forward-button',
              onPressed: () => _navigateToKaydetSayfasi(context),
              backgroundColor: Colors.lightBlue,
              child: Icon(Icons.arrow_forward),
            ),
          ],
        ),
      ),
    );
  }
}

class DersSecimButonu extends StatelessWidget {
  final String ders;
  final bool isSelected;
  final VoidCallback onTap;

  DersSecimButonu({
    required this.ders,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(200, 60), // Boyut ayarlandı
          backgroundColor: isSelected ? Colors.lightBlue : Colors.indigoAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
        ),
        child: Text(
          ders,
          style: TextStyle(fontSize: 18, color: isSelected ? Colors.black : Colors.white),
        ),
      ),
    );
  }
}