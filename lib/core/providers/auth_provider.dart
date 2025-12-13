import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _authService.isAuthenticated && _user != null;

  Future<bool> signIn(String email, String password) async {

    _user = null;
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.signIn(
        email: email,
        password: password,
      );
      _isLoading = false;
      _error = null; 
      notifyListeners();
      return _user != null;
    } catch (e) {

      _user = null;
      _error = e.toString().replaceAll('Exception: ', ''); 
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? plateNumber,
    String? vehicleType,

    String? lastname,
    String? firstname,
    String? middleInitial,
    DateTime? birthdate,
    String? address,
    double? latitude,
    double? longitude,
    String? currentAddress,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {

      _user = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        plateNumber: plateNumber,
        vehicleType: vehicleType,
        lastname: lastname,
        firstname: firstname,
        middleInitial: middleInitial,
        birthdate: birthdate,
        address: address,
        latitude: latitude,
        longitude: longitude,
        currentAddress: currentAddress,
      );
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> loadUser() async {
    if (_authService.isAuthenticated && _authService.currentUserId != null) {
      try {
        _user = await _authService.getUser(_authService.currentUserId!);
        _error = null; 
        notifyListeners();
      } catch (e) {
        // Only sign out if it's an authentication/authorization error
        // Don't sign out for network errors or temporary issues
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('not approved') ||
            errorString.contains('pending') ||
            errorString.contains('rejected') ||
            errorString.contains('suspended') ||
            errorString.contains('only for riders')) {
          _user = null;
          _error = e.toString();
          await signOut();
        } else {
          // For other errors (network, timeout, etc.), keep the session
          // but show the error
          _user = null;
          _error = 'Failed to load user data. Please try again.';
        }
        notifyListeners();
      }
    } else {
      _user = null;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

