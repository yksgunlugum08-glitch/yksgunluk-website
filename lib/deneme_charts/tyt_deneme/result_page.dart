import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddResultPage extends StatefulWidget {
  @override
  _AddResultPageState createState() => _AddResultPageState();
}

class _AddResultPageState extends State<AddResultPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _correctControllers = {
    'Matematik': TextEditingController(),
    'Türkçe': TextEditingController(),
    'Sosyal': TextEditingController(),
    'Fizik': TextEditingController(),
    'Kimya': TextEditingController(),
    'Biyoloji': TextEditingController(),
  };
  final Map<String, TextEditingController> _wrongControllers = {
    'Matematik': TextEditingController(),
    'Türkçe': TextEditingController(),
    'Sosyal': TextEditingController(),
    'Fizik': TextEditingController(),
    'Kimya': TextEditingController(),
    'Biyoloji': TextEditingController(),
  };
  final TextEditingController _dateController = TextEditingController();

  @override
  void dispose() {
    _correctControllers.values.forEach((controller) => controller.dispose());
    _wrongControllers.values.forEach((controller) => controller.dispose());
    _dateController.dispose();
    super.dispose();
  }

  Widget _buildSubjectField(String subject, int maxTotal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            TextFormField(
              controller: _correctControllers[subject],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Doğru Sayısı'),
              validator: (value) {
                int? correct = int.tryParse(value ?? '');
                int? wrong = int.tryParse(_wrongControllers[subject]?.text ?? '0');
                if (correct == null || correct < 0) {
                  return 'Lütfen geçerli bir doğru sayısı girin';
                }
                if ((correct + (wrong ?? 0)) > maxTotal) {
                  return 'Doğru ve yanlış toplamı $maxTotal\'den fazla olamaz';
                }
                return null;
              },
            ),
            TextFormField(
              controller: _wrongControllers[subject],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Yanlış Sayısı (Varsayılan: 0)'),
              validator: (value) {
                int? wrong = int.tryParse(value ?? '0');
                if (wrong != null && wrong < 0) {
                  return 'Lütfen geçerli bir yanlış sayısı girin';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToFirebase(String date, double totalScore) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dersler = {
      'Matematik': {'max': 40, 'fireKey': 'matematik'},
      'Türkçe': {'max': 40, 'fireKey': 'turkce'},
      'Sosyal': {'max': 20, 'fireKey': 'sosyal'},
      'Fizik': {'max': 7, 'fireKey': 'fizik'},
      'Kimya': {'max': 7, 'fireKey': 'kimya'},
      'Biyoloji': {'max': 6, 'fireKey': 'biyoloji'},
    };

    Map<String, dynamic> fields = {};
    for (var ders in dersler.keys) {
      int correct = int.tryParse(_correctControllers[ders]?.text ?? '0') ?? 0;
      int wrong = int.tryParse(_wrongControllers[ders]?.text ?? '0') ?? 0;
      int max = dersler[ders]!['max'] is int
          ? dersler[ders]!['max'] as int
          : int.tryParse(dersler[ders]!['max'].toString()) ?? 0;
      int bos = max - (correct + wrong);
      double net = correct - wrong * 0.25;
      String fireKey = dersler[ders]!['fireKey'].toString();
      fields[fireKey] = {
        'dogru': correct,
        'yanlis': wrong,
        'bos': bos,
        'net': net,
      };
    }

    // Önce aynı tarihli veri varsa sil (güncelleme için)
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tytDenemeSonuclari')
        .where('date', isEqualTo: date)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tytDenemeSonuclari')
        .add({
      'date': date,
      'score': totalScore,
      ...fields,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String? _dateValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Lütfen bir tarih girin';
    }
    try {
      DateFormat('dd-MM-yyyy').parseStrict(value);
    } catch (e) {
      return 'Lütfen geçerli bir tarih girin (örn: 06-07-2025)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Yeni Sonuç Ekle"),
        backgroundColor: Colors.lightBlue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(labelText: 'Tarih (örn: 06-07-2025)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    DateInputFormatter(),
                  ],
                  validator: _dateValidator,
                ),
                _buildSubjectField('Matematik', 40),
                _buildSubjectField('Türkçe', 40),
                _buildSubjectField('Sosyal', 20),
                _buildSubjectField('Fizik', 7),
                _buildSubjectField('Kimya', 7),
                _buildSubjectField('Biyoloji', 6),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
              ),
              child: Text('İptal', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState?.validate() ?? false) {
                  String date = _dateController.text;

                  double totalScore = _correctControllers.keys.map((subject) {
                    int correct = int.tryParse(_correctControllers[subject]?.text ?? '0') ?? 0;
                    int wrong = int.tryParse(_wrongControllers[subject]?.text ?? '0') ?? 0;
                    return correct - (wrong * 0.25);
                  }).reduce((a, b) => a + b);

                  await _saveToFirebase(date, totalScore);

                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
              ),
              child: Text('Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// Otomatik olarak 06072025 -> 06-07-2025 formatına çevirir
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('-', '');
    if (text.length > 8) return oldValue;
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2 || i == 4) buffer.write('-');
      buffer.write(text[i]);
    }
    return newValue.copyWith(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}