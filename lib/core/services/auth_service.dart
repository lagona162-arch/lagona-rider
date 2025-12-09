import '../models/user_model.dart';
import 'supabase_service.dart';
import '../constants/app_constants.dart';

class AuthService {
  final _supabase = SupabaseService.instance;

  Future<UserModel?> signUp({
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
    try {

      const role = AppConstants.roleRider;
      
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
          'phone': phone,
        },
      );

      if (response.user != null) {

        final userData = <String, dynamic>{
          'id': response.user!.id,
          'full_name': fullName,
          'email': email,
          'password': password, 
          'role': role,
          'phone': phone,

          'access_status': 'pending', 
          'is_active': false, 
        };


        if (lastname != null) userData['lastname'] = lastname;
        if (firstname != null) userData['firstname'] = firstname;
        if (middleInitial != null) userData['middle_initial'] = middleInitial;
        if (birthdate != null) {

          userData['birthdate'] = birthdate.toIso8601String().split('T')[0];
        }
        if (address != null) userData['address'] = address;



        await _supabase.from('users').insert(userData);




        await _supabase.from('riders').insert({
          'id': response.user!.id,
          'status': AppConstants.riderStatusOffline, 
          'balance': 0,
          'commission_rate': 0, 
          'plate_number': plateNumber,
          'vehicle_type': vehicleType,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (currentAddress != null) 'current_address': currentAddress,
          if (latitude != null || longitude != null)
            'last_active': DateTime.now().toIso8601String(),
        });

        return await getUser(response.user!.id);
      }
      return null;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {

      try {
        await _supabase.auth.signOut();
      } catch (_) {

      }


      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(), 
        password: password,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Sign in request timed out. Please check your internet connection and try again.');
        },
      );

      if (response.user != null) {
        final user = await getUser(response.user!.id).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            _supabase.auth.signOut();
            throw Exception('Failed to load user data. Please try again.');
          },
        );
        
        if (user == null) {
          await _supabase.auth.signOut();
          throw Exception('Failed to load user data. Please try again.');
        }

        if (user.role != AppConstants.roleRider) {
          await _supabase.auth.signOut();
          throw Exception('This app is only for Riders. Please use the correct app for your role.');
        }
        

        if (!user.isActive) {
          String errorMessage;
          try {
            final userData = await _supabase
                .from('users')
                .select('access_status, is_active')
                .eq('id', response.user!.id)
                .single()
                .timeout(
                  const Duration(seconds: 5),
                  onTimeout: () {
                    throw Exception('Request timed out');
                  },
                );
            
            final accessStatus = (userData['access_status'] as String?)?.toLowerCase();
            final isActive = userData['is_active'] as bool? ?? false;
            
            if (accessStatus == AppConstants.accessStatusPending) {
              errorMessage = 'Your account is pending admin approval. Please wait for approval before signing in.';
            } else if (accessStatus == AppConstants.accessStatusRejected) {
              errorMessage = 'Your account has been rejected. Please contact support for more information.';
            } else if (accessStatus == AppConstants.accessStatusSuspended) {
              errorMessage = 'Your account has been suspended. Please contact support for more information.';
            } else {
              errorMessage = 'Your account is not approved. Please contact support for more information.';
            }
          } catch (e) {
            errorMessage = 'Your account is not approved. Please contact support for more information.';
          }
          
          await _supabase.auth.signOut();
          throw Exception(errorMessage);
        }
        
        return user;
      }
      return null;
    } catch (e) {
      
      // Only sign out if it's a specific error that requires it
      // Don't sign out for general errors to preserve the session
      if (e.toString().contains('Your account') || 
          e.toString().contains('This app is only for Riders') ||
          e.toString().contains('timed out') ||
          e.toString().contains('Failed to load')) {
        // These errors already signed out, just rethrow
        rethrow;
      }
      
      // For other errors, don't sign out - let the session persist
      // This allows hot restart to work
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {

      final response = await _supabase
          .from('users')
          .select('id, full_name, email, password, role, phone, lastname, firstname, middle_initial, birthdate, address, access_status, is_active, created_at')
          .eq('id', userId)
          .single()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timed out while loading user data');
            },
          );

      return UserModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  UserModel? getCurrentUser() {
    final user = _supabase.auth.currentUser;
    if (user != null) {

      return null;
    }
    return null;
  }

  bool get isAuthenticated => _supabase.auth.currentUser != null;

  String? get currentUserId => _supabase.auth.currentUser?.id;
}

