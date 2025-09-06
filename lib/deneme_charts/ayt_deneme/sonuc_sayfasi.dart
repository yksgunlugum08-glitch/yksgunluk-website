import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import 'package:yksgunluk/dumenden/app_state.dart';

class AYTAddResultPage extends StatefulWidget {
  @override
  _AYTAddResultPageState createState() => _AYTAddResultPageState();
}

class _AYTAddResultPageState extends State<AYTAddResultPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final Map<String, TextEditingController> _correctControllers = {};
  final Map<String, TextEditingController> _wrongControllers = {};

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

  @override
  Widget build(BuildContext context) {
    var appState = Provider.of<AppState>(context);
    List<String> subjects = [];
    Map<String, int> maxTotals = {};

    switch (appState.selectedBolum) {
      case 'Eşit Ağırlık':
        subjects = ['Edebiyat', 'Matematik', 'Tarih', 'Coğrafya'];
        maxTotals = {
          'Edebiyat': 24,
          'Matematik': 40,
          'Tarih': 10,
          'Coğrafya': 6,
        };
        break;
      case 'Sayısal':
        subjects = ['Matematik', 'Fizik', 'Kimya', 'Biyoloji'];
        maxTotals = {
          'Matematik': 40,
          'Fizik': 14,
          'Kimya': 13,
          'Biyoloji': 13,
        };
        break;
      case 'Sözel':
        subjects = [
          'Tarih Sos 1', 'Tarih Sos 2', 'Edebiyat', 'Coğrafya Sos 1', 'Coğrafya Sos 2', 'Felsefe', 'Din'
        ];
        maxTotals = {
          'Tarih Sos 1': 10,
          'Tarih Sos 2': 11,
          'Edebiyat': 24,
          'Coğrafya Sos 1': 6,
          'Coğrafya Sos 2': 11,
          'Felsefe': 12,
          'Din': 6,
        };
        break;
    }

    subjects.forEach((subject) {
      _correctControllers.putIfAbsent(subject, () => TextEditingController());
      _wrongControllers.putIfAbsent(subject, () => TextEditingController());
    });

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
                  decoration: InputDecoration(labelText: 'Tarih (ddMMyyyy)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    DateInputFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Lütfen bir tarih girin';
                    }
                    try {
                      DateFormat('dd-MM-yyyy').parseStrict(value);
                    } catch (e) {
                      return 'Lütfen geçerli bir tarih girin';
                    }
                    return null;
                  },
                ),
                ...subjects.map((subject) => _buildSubjectField(subject, maxTotals[subject]!)).toList(),
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

                  Map<String, int> dogrular = {};
                  Map<String, int> yanlislar = {};

                  for (var subject in subjects) {
                    int correct = int.tryParse(_correctControllers[subject]?.text ?? '0') ?? 0;
                    int wrong = int.tryParse(_wrongControllers[subject]?.text ?? '0') ?? 0;
                    dogrular[subject] = correct;
                    yanlislar[subject] = wrong;
                  }

                  // Firestore'a kayıt işlemi
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('aytDenemeSonuclari')
                        .add({
                      'date': date,
                      'dogru': dogrular,
                      'yanlis': yanlislar,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  }

                  Navigator.pop(context, {
                    'date': date,
                    'dogru': dogrular,
                    'yanlis': yanlislar,
                  });
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

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
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