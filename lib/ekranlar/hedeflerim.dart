import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yksgunluk/hedeflerim/Haziran.dart';
import 'package:yksgunluk/hedeflerim/Temmuz.dart';
import 'package:yksgunluk/hedeflerim/agustos.dart';
import 'package:yksgunluk/hedeflerim/aral%C4%B1k.dart';
import 'package:yksgunluk/hedeflerim/ekim.dart';
import 'package:yksgunluk/hedeflerim/eylul.dart';
import 'package:yksgunluk/hedeflerim/kasim.dart';
import 'package:yksgunluk/hedeflerim/mart.dart';
import 'package:yksgunluk/hedeflerim/mayis.dart';
import 'package:yksgunluk/hedeflerim/nisan.dart';
import 'package:yksgunluk/hedeflerim/ocak.dart';
import 'package:yksgunluk/hedeflerim/subat.dart';

class HedeflerimPage extends StatefulWidget {
  @override
  _HedeflerimPageState createState() => _HedeflerimPageState();
}

class _HedeflerimPageState extends State<HedeflerimPage> {
  // Animasyonlu yükleme ekranı ve timer kaldırıldı

  List<Map<String, dynamic>> _buildButtonData() {
    return [
      {"text": "Ocak", "page": OcakWeeklyPlanPage()},
      {"text": "Şubat", "page": SubatWeeklyPlanPage()},
      {"text": "Mart", "page": MartWeeklyPlanPage()},
      {"text": "Nisan", "page": NisanWeeklyPlanPage()},
      {"text": "Mayıs", "page": MayisWeeklyPlanPage()},
      {"text": "Haziran", "page": HaziranWeeklyPlanPage()},
      {"text": "Temmuz", "page": TemmuzWeeklyPlanPage()},
      {"text": "Ağustos", "page": AgustosWeeklyPlanPage()},
      {"text": "Eylül", "page": EylulWeeklyPlanPage()},
      {"text": "Ekim", "page": EkimWeeklyPlanPage()},
      {"text": "Kasım", "page": KasimWeeklyPlanPage()},
      {"text": "Aralık", "page": AralikWeeklyPlanPage()},
    ];
  }

  List<Widget> _buildButtonList(BuildContext context) {
    final buttonData = _buildButtonData();
    return buttonData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return Container(
        width: MediaQuery.of(context).size.width / 3.5,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: _getGradientColor(index / (buttonData.length - 1)),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => data["page"]),
            );
          },
          child: Text(
            data["text"],
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }).toList();
  }

  Color _getGradientColor(double position) {
    return Color.lerp(const Color.fromARGB(255, 255, 230, 0), const Color.fromARGB(255, 255, 0, 179), position)!;
  }

  // Firebase'den hedef verilerini okuyan fonksiyon
  Future<Map<String, dynamic>> _fetchUserTargets() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturumu açık değil');
    }
    DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    return {
      "hedefSiralama": data?['hedefSiralama'] ?? '',
      "bolumSor": data?['bolumSor'] ?? ''
    };
  }

  @override
  Widget build(BuildContext context) {
    // Doğrudan FutureBuilder kullanarak içeriği göster, animasyonlu ekran kaldırıldı
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchUserTargets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Veri okunurken hata oluştu: ${snapshot.error}')),
          );
        }
        final String targetRank = snapshot.data?['hedefSiralama'] ?? '';
        final String targetDepartment = snapshot.data?['bolumSor'] ?? '';

        return Scaffold(
          appBar: AppBar(
            title: Text('Hedeflerim'),
            backgroundColor: Colors.blueAccent,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: InfoCard(
                        title: 'Hedef Sıralama',
                        value: targetRank,
                        colors: [Colors.blueAccent, Colors.purpleAccent],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: InfoCard(
                        title: 'Hedef Bölüm',
                        value: targetDepartment,
                        colors: [Colors.orangeAccent, Colors.pinkAccent],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16.0,
                    runSpacing: 16.0,
                    children: _buildButtonList(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final List<Color> colors;
  final double height;

  const InfoCard({
    required this.title,
    required this.value,
    required this.colors,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          AutoSizeText(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            minFontSize: 10,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}