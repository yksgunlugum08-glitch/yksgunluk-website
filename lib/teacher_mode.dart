import 'package:flutter/foundation.dart';

class TeacherModeProvider with ChangeNotifier {
  bool _isTeacherMode = false;
  String? _selectedStudentId;
  String? _selectedStudentName;

  bool get isTeacherMode => _isTeacherMode;
  String? get selectedStudentId => _selectedStudentId;
  String? get selectedStudentName => _selectedStudentName;

  void setTeacherMode(bool value, {String? studentId, String? studentName}) {
    _isTeacherMode = value;
    _selectedStudentId = studentId;
    _selectedStudentName = studentName;
    notifyListeners();
  }
}