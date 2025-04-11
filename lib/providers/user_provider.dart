import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  String? _userId;
  String? _userName;

  User? get user => _user;
  String? get userId => _userId;
  String? get userName => _userName;

  void setUser(User? user) {
    _user = user;
    _userId = user?.uid;
    _userName = user?.displayName;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    _userId = null;
    _userName = null;
    notifyListeners();
  }
}
