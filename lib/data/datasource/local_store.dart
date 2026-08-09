import 'package:flutter/foundation.dart';
import '../models/app_user.dart';
import '../models/app_settings.dart';

class LocalStore extends ChangeNotifier {
  AppUser? _currentUser;
  AppSettings? _settings;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  AppSettings? get settings => _settings;
  bool get simulation => _settings?.simulacion == 'S';

  void setSession(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearSession() {
    _currentUser = null;
    notifyListeners();
  }

  void setSettings(AppSettings s) {
    _settings = s;
    notifyListeners();
  }
}
