import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotePage extends StatefulWidget {
  @override
  _NotePageState createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  final List<String> _days = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar'
  ];

  Map<String, String> _notes = {};

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      for (String day in _days) {
        _notes[day] = prefs.getString(day) ?? '';
      }
    });
  }

  Future<void> _saveNote(String day, String note) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(day, note);
    setState(() {
      _notes[day] = note;
    });
  }

  Future<void> _resetNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _notes = {for (var day in _days) day: ''};
    });
  }

  void _openNoteEditor(String day) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          day: day,
          currentNote: _notes[day] ?? '',
          onSave: (newNote) {
            _saveNote(day, newNote);
          },
        ),
      ),
    );
  }

  void _showResetAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Dikkat'),
          content: Text('Tüm notlar silinecek. Emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                _resetNotes();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Resetle'),
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
        title: Text('Not Defteri'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade600,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _showResetAlert,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade100,
              Colors.teal.shade50,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: _days.map((day) {
              return Card(
                elevation: 4,
                margin: EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  title: Text(
                    day,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  trailing: Icon(Icons.edit, color: Colors.teal.shade600),
                  onTap: () => _openNoteEditor(day),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class NoteEditorPage extends StatelessWidget {
  final String day;
  final String currentNote;
  final ValueChanged<String> onSave;

  NoteEditorPage({
    required this.day,
    required this.currentNote,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController noteController = TextEditingController(text: currentNote);

    return Scaffold(
      appBar: AppBar(
        title: Text('$day Notları'),
        backgroundColor: Colors.teal.shade600,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: noteController,
                maxLines: null,
                expands: true,
                textAlign: TextAlign.start,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Notlarınızı buraya yazın...',
                  border: OutlineInputBorder(),
                  fillColor: Colors.white,
                  filled: true,
                ),
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                onSave(noteController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: Text(
                'Kaydet',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}