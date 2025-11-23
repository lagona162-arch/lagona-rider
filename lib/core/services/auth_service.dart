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
    // New fields
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
      // This is a rider-only app, so role is always 'rider'
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
        // Prepare user data
        final userData = <String, dynamic>{
          'id': response.user!.id,
          'full_name': fullName,
          'email': email,
          'password': password, // Note: In production, this should be hashed
          'role': role,
          'phone': phone,
          // New access_status gate; keep legacy is_active for backward-compat
          'access_status': 'pending', // admin will set to 'approved'
          'is_active': false, // legacy flag (derived from access_status by app)
        };

        // Add new fields if provided
        if (lastname != null) userData['lastname'] = lastname;
        if (firstname != null) userData['firstname'] = firstname;
        if (middleInitial != null) userData['middle_initial'] = middleInitial;
        if (birthdate != null) {
          // Store birthdate as YYYY-MM-DD format
          userData['birthdate'] = birthdate.toIso8601String().split('T')[0];
        }
        if (address != null) userData['address'] = address;

        // Create user record in users table
        // New riders start as inactive until admin approves them
        await _supabase.from('users').insert(userData);

        // Create rider record (this is a rider-only app)
        // Note: commission_rate will be automatically set by database trigger
        // based on the rider's role in commission_settings table
        await _supabase.from('riders').insert({
          'id': response.user!.id,
          'status': AppConstants.riderStatusOffline, // Start as offline until admin approves
          'balance': 0,
          'commission_rate': 0, // Will be overridden by database trigger if commission_settings exists
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
      // Clear any existing session first to avoid conflicts
      try {
        await _supabase.auth.signOut();
      } catch (_) {
        // Ignore errors when signing out (might not be signed in)
      }

      // Add timeout to prevent hanging
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(), // Normalize email
        password: password,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Sign in request timed out. Please check your internet connection and try again.');
        },
      );

      if (response.user != null) {
        // Get user data in a single query with timeout
        final user = await getUser(response.user!.id).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // Sign out on timeout to prevent partial authentication
            _supabase.auth.signOut();
            throw Exception('Failed to load user data. Please try again.');
          },
        );
        
        // Check if user is a rider - this app is rider-only
        if (user != null && user.role != AppConstants.roleRider) {
          // Sign out the user since they're not a rider
          await _supabase.auth.signOut();
          throw Exception('This app is only for Riders. Please use the correct app for your role.');
        }
        
        // Check if user is approved before allowing login
        if (user != null && !user.isActive) {
          // Sign out the user since they're not approved
          await _supabase.auth.signOut();
          
          // Get access_status to provide specific error message
          String errorMessage;
          try {
            final userData = await _supabase
                .from('users')
                .select('access_status')
                .eq('id', response.user!.id)
                .single()
                .timeout(
                  const Duration(seconds: 5),
                  onTimeout: () {
                    throw Exception('Request timed out');
                  },
                );
            
            final accessStatus = (userData['access_status'] as String?)?.toLowerCase();
            
            if (accessStatus == AppConstants.accessStatusPending) {
              errorMessage = 'Your account is pending admin approval. Please wait for approval before signing in.';
            } else if (accessStatus == AppConstants.accessStatusRejected) {
              errorMessage = 'Your account has been rejected. Please contact support for more information.';
            } else if (accessStatus == AppConstants.accessStatusSuspended) {
              errorMessage = 'Your account has been suspended. Please contact support for more information.';
            } else {
              errorMessage = 'Your account is not approved. Please contact support for more information.';
            }
          } catch (_) {
            // If we can't get access_status, use generic message
            errorMessage = 'Your account is not approved. Please contact support for more information.';
          }
          
          throw Exception(errorMessage);
        }
        
        return user;
      }
      return null;
    } catch (e) {
      // Ensure we're signed out on any error
      try {
        await _supabase.auth.signOut();
      } catch (_) {
        // Ignore sign out errors
      }
      
      // Re-throw if it's already our custom exception
      if (e.toString().contains('Your account') || 
          e.toString().contains('This app is only for Riders') ||
          e.toString().contains('timed out') ||
          e.toString().contains('Failed to load')) {
        rethrow;
      }
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      // Explicitly select access_status to ensure it's included
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
      // Note: This is a simplified version. In production, fetch from database
      return null;
    }
    return null;
  }

  bool get isAuthenticated => _supabase.auth.currentUser != null;

  String? get currentUserId => _supabase.auth.currentUser?.id;
}

