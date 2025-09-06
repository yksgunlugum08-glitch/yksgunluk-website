import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yksgunluk/hizli_islemler/hobi/hobi_model.dart';

class HobbyBalanceScreen extends StatefulWidget {
  const HobbyBalanceScreen({Key? key}) : super(key: key);

  @override
  State<HobbyBalanceScreen> createState() => _HobbyBalanceScreenState();
}

class _HobbyBalanceScreenState extends State<HobbyBalanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _hobbyNameController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  List<Hobby> _hobbies = [];
  
  // Renk seçenekleri
  final List<Color> _colorOptions = [
    const Color(0xFF43A047), // Yeşil
    const Color(0xFFE53935), // Kırmızı
    const Color(0xFF5E35B1), // Mor
    const Color(0xFF1A73E8), // Mavi
    const Color(0xFFEF6C00), // Turuncu
    const Color(0xFF00ACC1), // Turkuaz
    const Color(0xFFD81B60), // Pembe
    const Color(0xFF6D4C41), // Kahverengi
  ];
  
  // Seçili değerler
  int _selectedColorIndex = 0;
  double _selectedDuration = 30.0; // dakika cinsinden
  Map<String, bool> _selectedDays = {
    'Pazartesi': false,
    'Salı': false,
    'Çarşamba': false,
    'Perşembe': false,
    'Cuma': false,
    'Cumartesi': false,
    'Pazar': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Türkçe tarih formatı desteği
    initializeDateFormatting('tr_TR', null).then((_) {
      _loadHobbies();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _hobbyNameController.dispose();
    super.dispose();
  }
  
  // Firebase'den hobiler yükleniyor
  Future<void> _loadHobbies() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userId = _auth.currentUser?.uid ?? 'test_user';
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('hobbies')
          .get();
            
      final loadedHobbies = snapshot.docs.map((doc) {
        return Hobby.fromFirestore(doc);
      }).toList();
        
      setState(() {
        _hobbies = loadedHobbies;
        _isLoading = false;
      });
    } catch (e) {
      print('Hobiler yüklenirken hata oluştu: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Yeni hobi ekle
  Future<void> _addHobby() async {
    if (_hobbyNameController.text.isEmpty || !_selectedDays.values.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen hobi adı girin ve en az bir gün seçin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final userId = _auth.currentUser?.uid ?? 'test_user';
      
      // Hobi adına göre en uygun ikonu bul
      final iconKey = Hobby.findBestIconKey(_hobbyNameController.text);
      
      // Yeni hobi nesnesi oluştur
      final newHobby = Hobby(
        id: '', // Firestore'da otomatik oluşturulacak
        name: _hobbyNameController.text,
        color: _colorOptions[_selectedColorIndex],
        duration: _selectedDuration,
        selectedDays: Map<String, bool>.from(_selectedDays),
        iconKey: iconKey,
      );
      
      // Firestore'a kaydet
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('hobbies')
          .add(newHobby.toFirestore());
          
      // ID ile hobi nesnesini güncelle
      final hobbyWithId = Hobby(
        id: docRef.id,
        name: newHobby.name,
        color: newHobby.color,
        duration: newHobby.duration,
        selectedDays: newHobby.selectedDays,
        iconKey: newHobby.iconKey,
      );
      
      setState(() {
        _hobbies.add(hobbyWithId);
        // Değerleri sıfırla
        _hobbyNameController.clear();
        _selectedColorIndex = 0;
        _selectedDuration = 30.0;
        _selectedDays = {
          'Pazartesi': false,
          'Salı': false,
          'Çarşamba': false,
          'Perşembe': false,
          'Cuma': false,
          'Cumartesi': false,
          'Pazar': false,
        };
      });
      
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hobi başarıyla eklendi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hobi eklenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Hobi güncelle
  Future<void> _updateHobby(Hobby hobby, Map<String, bool> newSelectedDays, double newDuration) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'test_user';
      
      // Firestore'da güncelle
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('hobbies')
          .doc(hobby.id)
          .update({
            'selectedDays': newSelectedDays,
            'duration': newDuration,
          });
          
      // Yerel listede güncelle
      setState(() {
        final index = _hobbies.indexWhere((h) => h.id == hobby.id);
        if (index != -1) {
          _hobbies[index] = Hobby(
            id: hobby.id,
            name: hobby.name,
            color: hobby.color,
            duration: newDuration,
            selectedDays: newSelectedDays,
            iconKey: hobby.iconKey,
          );
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hobi güncellendi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hobi güncellenirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Hobi sil
  Future<void> _deleteHobby(String hobbyId) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'test_user';
      
      // Firestore'dan sil
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('hobbies')
          .doc(hobbyId)
          .delete();
          
      // Yerel listeden sil
      setState(() {
        _hobbies.removeWhere((hobby) => hobby.id == hobbyId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hobi silindi'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hobi silinirken hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Hobi düzenleme modalını göster
  void _showEditHobbyModal(Hobby hobby) {
    double editDuration = hobby.duration;
    Map<String, bool> editDays = Map<String, bool>.from(hobby.selectedDays);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık kısmı (sabit)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${hobby.name} Düzenle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: this.context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Hobi Sil'),
                                    content: Text('${hobby.name} hobisini silmek istediğinize emin misiniz?'),
                                    actions: [
                                      TextButton(
                                        child: const Text('İptal'),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      TextButton(
                                        child: const Text('Sil', style: TextStyle(color: Colors.red)),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteHobby(hobby.id);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // İçerik kısmı (kaydırılabilir)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hobi bilgileri
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: hobby.color.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    hobby.icon,
                                    color: hobby.color,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  hobby.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Uyarı mesajı
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Sınava hazırlandığınız bu dönemde hobiniz için günde en fazla 45 dakika ayırmanız önerilir.',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Günlük süre ayarı
                            Text(
                              'Günlük Süre: ${editDuration.round()} dakika',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            
                            Slider(
                              value: editDuration,
                              min: 15,
                              max: 60,
                              divisions: 9,
                              label: '${editDuration.round()} dk',
                              onChanged: (value) {
                                setState(() {
                                  editDuration = value;
                                });
                              },
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Gün seçimi
                            Text(
                              'Hangi Günler?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            Wrap(
                              spacing: 8.0,
                              children: editDays.entries.map((entry) {
                                final day = entry.key;
                                final selected = entry.value;
                                
                                return FilterChip(
                                  label: Text(day),
                                  selected: selected,
                                  onSelected: (newValue) {
                                    setState(() {
                                      editDays[day] = newValue;
                                    });
                                  },
                                  backgroundColor: Colors.grey.shade100,
                                  selectedColor: hobby.color.withOpacity(0.2),
                                  checkmarkColor: hobby.color,
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Kaydet butonu
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _updateHobby(hobby, editDays, editDuration);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hobby.color,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Kaydet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
  
  // Yeni hobi ekleme modalını göster
  void _showAddHobbyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık Kısmı (Sabit)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yeni Hobi Ekle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  
                  // İçerik Kısmı (Kaydırılabilir)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Uyarı mesajı
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Sınav dönemindeyken hobiler önemli bir dinlenme aracıdır, ancak alışkanlık haline getirmeden sınırlı sürede tutmak başarınızı destekleyecektir.',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Hobi adı
                            TextField(
                              controller: _hobbyNameController,
                              decoration: InputDecoration(
                                labelText: 'Hobi Adı',
                                hintText: 'Ör: Kitap Okuma, Yürüyüş, Resim Yapma...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Renk seçimi
                            Text(
                              'Renk Seç',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            SizedBox(
                              height: 50,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _colorOptions.length,
                                itemBuilder: (context, index) {
                                  final isSelected = index == _selectedColorIndex;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedColorIndex = index;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _colorOptions[index],
                                        shape: BoxShape.circle,
                                        border: isSelected
                                            ? Border.all(color: Colors.black, width: 2)
                                            : null,
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Günlük süre ayarı
                            Text(
                              'Günlük Süre: ${_selectedDuration.round()} dakika',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            
                            Slider(
                              value: _selectedDuration,
                              min: 15,
                              max: 60,
                              divisions: 9,
                              label: '${_selectedDuration.round()} dk',
                              onChanged: (value) {
                                setState(() {
                                  _selectedDuration = value;
                                });
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Gün seçimi
                            Text(
                              'Hangi Günler?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            Wrap(
                              spacing: 8.0,
                              children: _selectedDays.entries.map((entry) {
                                final day = entry.key;
                                final selected = entry.value;
                                
                                return FilterChip(
                                  label: Text(day),
                                  selected: selected,
                                  onSelected: (newValue) {
                                    setState(() {
                                      _selectedDays[day] = newValue;
                                    });
                                  },
                                  backgroundColor: Colors.grey.shade100,
                                  selectedColor: _colorOptions[_selectedColorIndex].withOpacity(0.2),
                                  checkmarkColor: _colorOptions[_selectedColorIndex],
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 40),
                            
                            // Ekle butonu
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _addHobby,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _colorOptions[_selectedColorIndex],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Hobi Ekle',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
  
  // Haftalık zaman grafik verisini oluştur
  List<BarChartGroupData> _getBarGroups() {
    const dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    
    return List.generate(7, (dayIndex) {
      final dayName = dayNames[dayIndex];
      final hobbiesForDay = _hobbies.where(
        (hobby) => hobby.selectedDays[dayName] == true
      ).toList();
      
      final barRods = <BarChartRodData>[];
      double startY = 0;
      
      for (final hobby in hobbiesForDay) {
        barRods.add(
          BarChartRodData(
            toY: hobby.duration,
            fromY: startY,
            color: hobby.color,
            width: 18,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        );
        startY += hobby.duration;
      }
      
      return BarChartGroupData(
        x: dayIndex,
        barRods: barRods,
      );
    });
  }
  
  // Belirli bir gün için toplam süre
  double _getDayTotalDuration(String dayName) {
    return _hobbies
        .where((hobby) => hobby.selectedDays[dayName] == true)
        .fold(0, (sum, hobby) => sum + hobby.duration);
  }
  
  // Günlük hobiler
  List<Hobby> _getHobbiesForDay(String dayName) {
    return _hobbies
        .where((hobby) => hobby.selectedDays[dayName] == true)
        .toList();
  }
  
  // Haftalık toplam süre
  double _getWeeklyTotalDuration() {
    double total = 0;
    const dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    
    for (final dayName in dayNames) {
      total += _getDayTotalDuration(dayName);
    }
    
    return total;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Üst kısım - App Bar
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.blue.shade700,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Hobi Planlayıcı',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1606761568499-6d2451b23c66?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=1080&fit=max',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.blue.shade200,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 50, color: Colors.white),
                        ),
                      );
                    },
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black45,
                          Colors.transparent,
                          Colors.black54,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Tab Bar
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue.shade700,
                tabs: const [
                  Tab(text: 'HOBİLERİM'),
                  Tab(text: 'ZAMAN PLANI'),
                  Tab(text: 'TAVSİYELER'),
                ],
              ),
            ),
            pinned: true,
          ),
          
          // Tab Bar View İçeriği
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // HOBİLERİM Tab
                _buildHobbiesTab(),
                
                // ZAMAN PLANI Tab
                _buildScheduleTab(),
                
                // TAVSİYELER Tab
                _buildTipsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHobbyModal,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }
  
  // HOBİLERİM Tab içeriği
  Widget _buildHobbiesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Özet kart
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Haftalık Özet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_hobbies.length} Hobi',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatColumn(
                        '${_getWeeklyTotalDuration().toStringAsFixed(0)} dk',
                        'Haftalık Toplam',
                        Icons.access_time_filled,
                        Colors.blue.shade700,
                      ),
                      _buildStatColumn(
                        '${(_getWeeklyTotalDuration() / 60).toStringAsFixed(1)} saat',
                        'Toplam Süre',
                        Icons.timer,
                        Colors.green,
                      ),
                      _buildStatColumn(
                        '${(_getWeeklyTotalDuration() / 7).toStringAsFixed(0)} dk',
                        'Günlük Ortalama',
                        Icons.timeline,
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Hobiler başlık
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
            child: Text(
              'Hobiler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          
          // Hobi kartları
          Expanded(
            child: _hobbies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_esports,
                          size: 72,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz hiç hobi eklemediniz',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yeni hobi eklemek için + butonuna basın',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _hobbies.length,
                    itemBuilder: (context, index) {
                      final hobby = _hobbies[index];
                      return _buildHobbyCard(hobby);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  // İstatistik sütunu
  Widget _buildStatColumn(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  // Hobi kartı
  Widget _buildHobbyCard(Hobby hobby) {
    // Seçili günleri metin olarak göster
    final selectedDaysText = hobby.selectedDays.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.substring(0, 3))
        .join(', ');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showEditHobbyModal(hobby),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hobby.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hobby.icon,
                      color: hobby.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hobby.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${hobby.duration.round()} dakika / gün',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          selectedDaysText.isEmpty ? 'Gün seçilmedi' : selectedDaysText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toplam: ${(hobby.duration * hobby.selectedDays.values.where((selected) => selected).length).toStringAsFixed(0)} dk/hafta',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ZAMAN PLANI Tab içeriği
  Widget _buildScheduleTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Haftalık grafik kartı
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Haftalık Hobi Zamanı',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    height: 240,
                    child: _hobbies.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bar_chart,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Henüz veri yok',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.center,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                                  final dayHobbies = _getHobbiesForDay(['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][group.x.toInt()]);
                                  
                                  if (dayHobbies.isEmpty) return null;
                                  
                                  double startY = 0;
                                  
                                  // Hangi hobiye tıklandığını bul
                                  for (final hobby in dayHobbies) {
                                    if (rod.fromY == startY) {
                                      return BarTooltipItem(
                                        '${hobby.name}: ${hobby.duration.round()} dk',
                                        const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      );
                                    }
                                    startY += hobby.duration;
                                  }
                                  
                                  return null;
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        dayNames[value.toInt()],
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value % 30 == 0) {
                                      return Text(
                                        '${value.toInt()}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawHorizontalLine: true,
                              drawVerticalLine: false,
                              horizontalInterval: 30,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade200,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(
                              show: false,
                            ),
                            barGroups: _getBarGroups(),
                            maxY: 120,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Günlük plan başlık
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
            child: Text(
              'Günlük Plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          
          // Günlük plan listesi
          Expanded(
            child: _hobbies.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz hiç hobi planlanmadı',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Haftanız boş görünüyor,\nHobi planlayın!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
                      final dayName = dayNames[index];
                      final hobbiesForDay = _getHobbiesForDay(dayName);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      hobbiesForDay.isEmpty
                                          ? 'Boş'
                                          : 'Toplam: ${_getDayTotalDuration(dayName).toStringAsFixed(0)} dk',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              if (hobbiesForDay.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(
                                    child: Text(
                                      'Bu gün için planlanmış hobi yok',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...hobbiesForDay.map((hobby) => Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: hobby.color.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          hobby.icon,
                                          color: hobby.color,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          hobby.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: hobby.color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${hobby.duration.round()} dk',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: hobby.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  // TAVSİYELER Tab içeriği
  Widget _buildTipsTab() {
    // Tavsiyeler
    final tips = [
      {
        'title': 'Dengeli Bir Yaklaşım Benimseyin',
        'description': 'Sınav döneminde hobiler, zihninizi tazelemek için önemlidir, ancak sınırlı tutmak gerekir.',
        'icon': Icons.balance,
        'color': Colors.blue.shade700,
      },
      {
        'title': 'Günlük Rutininizde Sınırlandırın',
        'description': 'Hobiler için günde en fazla 50-60 dakika ayırın. Daha fazlası ders çalışma sürenizi azaltabilir.',
        'icon': Icons.access_time,
        'color': Colors.green,
      },
      {
        'title': 'Hobilerinizi de Kullanarak Bir Günlük Rutin Oluştur',
        'description': 'Ders ve Eğlence Alışkanlıklarınızı Kullanarak Kendiniz İçin Rutinler Oluşturun Bu Ders Çalışmanızı Kolaylaştırır',
        'icon': Icons.timer_outlined,
        'color': Colors.orange,
      },
      {
        'title': 'Sadece Bir İki Hobi Seçin',
        'description': 'Çok fazla hobi edinmek dikkatinizi dağıtabilir. En keyif aldığınız 3-4 hobi ile sınırlı kalın.',
        'icon': Icons.filter_2,
        'color': Colors.purple,
      },
      {
        'title': 'Hafta Sonlarına Yoğunlaştırın',
        'description': 'Hobinize ayırdığınız zamanı hafta sonlarında yaparak hafta içi derse daha çok odaklanın.',
        'icon': Icons.weekend,
        'color': Colors.teal,
      },
      {
        'title': 'Zihni Dinlendiren Hobiler Seçin',
        'description': 'Kitap okumak, yürüyüş, resim gibi sakinleştirici hobiler, sınav stresini azaltmak için idealdir.',
        'icon': Icons.spa,
        'color': Colors.indigo,
      },
      {
        'title': 'Hobinizi Ödül Olarak Kullanın',
        'description': 'Belirlediğiniz bir çalışma hedefini tamamladıktan sonra kendinizi hobinizle ödüllendirin.',
        'icon': Icons.emoji_events,
        'color': Colors.amber,
      },
      {
        'title': 'Sosyal Medyadan Uzak Durun',
        'description': 'Sosyal medya takibi bir hobi değil, dikkat dağıtıcıdır. Bunun yerine gerçek hobiler edinin.',
        'icon': Icons.do_not_disturb,
        'color': Colors.red,
      },
    ];
    
    // İlham alıntıları
    final quotes = [
      '"Başarı, dengeli bir yaşamın sonucudur. Sadece çalışmak ya da sadece dinlenmek değil, ikisinin uyumudur."',
      '"Sınav döneminde bile kısa molalar vermek, beynin daha verimli çalışmasını sağlar."',
      '"Kaliteli bir mola, saatlerce verimsiz çalışmaktan daha değerlidir."',
      '"Dengeli bir zihin, en iyi performansı gösterir."',
    ];
    
    final randomQuote = quotes[DateTime.now().day % quotes.length];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İlham alıntısı
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.blue.shade700,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.format_quote,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    randomQuote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sınav Dönemi Uyarısı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade800,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sınav Sürecine Özel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bu dönemde hobiler, zihinsel dinlenme sağlar ancak sınava hazırlığınızı engellememesi için sınırlı tutulmalıdır.',
                        style: TextStyle(
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Sınav Döneminde Hobi Tavsiyeleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tavsiyeler listesi
          ...tips.map((tip) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (tip['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tip['icon'] as IconData,
                      color: tip['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip['description'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )).toList(),
          
          const SizedBox(height: 16),
          
          // İdeal Hobi-Ders Dengesi Tablosu
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İdeal Ders-Hobi Dengesi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      width: 1,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FlexColumnWidth(1.2),
                      1: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                        ),
                        children: const [
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Ders / Hobi',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          TableCell(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Önerilen Durum',
                               ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('8 : 1'),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Sınavda Deerece Seviyesinde Başarı Alabilmek İçin iyi Bir Oran'),
                          ),
                        ],
                      ),
                      TableRow(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('5 : 1'),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Güzel Bir Sıralama İçin İyi Bir Oran'),
                          ),
                        ],
                      ),
                      TableRow(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('3 : 1'),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Ortalamanın Altı Başarı Oranı'),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('1 : 1 veya altı'),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red, size: 16),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text('Eyvah Eyvah!!!'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// SliverAppBar Delegate
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}