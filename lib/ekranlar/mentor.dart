import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class ComingSoonScreen extends StatefulWidget {
  final String feature;
  final String description;
  
  const ComingSoonScreen({
    Key? key, 
    required this.feature,
    this.description = "Bu özellik üzerinde çalışıyoruz. Çok yakında sizlerle olacak.",
  }) : super(key: key);

  @override
  _ComingSoonScreenState createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  String _loadingText = "Yakında Eklenecek";
  int _dotCount = 0;
  late Timer _timer;
  
  @override
  void initState() {
    super.initState();
    
    // Basit bir pulsing (nefes alma) animasyonu için
    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Nokta animasyonu için timer
    _timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      setState(() {
        _dotCount = (_dotCount + 1) % 4; // 0, 1, 2, 3 döngüsü
        _updateLoadingText();
      });
    });
  }
  
  void _updateLoadingText() {
    String dots = '';
    for (int i = 0; i < _dotCount; i++) {
      dots += '.';
    }
    _loadingText = "Yakında Eklenecek$dots";
  }
  
  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          "Yapım Aşamasında", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF121212),
              Color(0xFF1E3A8A),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animasyon
                Container(
                  height: 300,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Lottie.network(
                    'https://assets1.lottiefiles.com/packages/lf20_iv4dsx3q.json', // Kod yazma animasyonu
                    fit: BoxFit.contain,
                  ),
                ),
                
                SizedBox(height: 30),
                
                // "Yakında Eklenecek" yazısı - Animasyonlu (AnimatedBuilder kullanarak)
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _animation.value,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _loadingText,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }
                ),
                
                SizedBox(height: 20),
                
                // Özellik Adı
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.feature,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Açıklama metni
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    widget.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
                
                SizedBox(height: 40),
                
                // Geri dön butonu
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    "Geri Dön",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // İlerleme durumu
                _buildProgressIndicator(),
                
                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // İlerleme göstergesi
  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: 0.75, // %75 tamamlandı
              minHeight: 10,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
        ),
        SizedBox(height: 10),
        Text(
          "Geliştirme durumu: %75",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}