import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';
import '../../core/services/supabase_service.dart';
import 'login_screen.dart';
import '../rider/rider_home_screen.dart';
import '../location/location_permission_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingLocation = true;
  bool _hasLocationPermission = false;
  final LocationService _locationService = LocationService();
  StreamSubscription? _authStateSubscription;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
      _setupAuthStateListener();
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.user == null) {
      authProvider.loadUser();
    }
  }

  void _setupAuthStateListener() {
    // Listen to Supabase auth state changes
    _authStateSubscription = SupabaseService.instance.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      if (mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        if (event == AuthChangeEvent.signedOut || session == null) {
          // User signed out - reset state
          _wasAuthenticated = false;
          setState(() {
            _isCheckingLocation = false;
            _hasLocationPermission = false;
          });
          // Only call signOut if not already signed out to avoid recursion
          if (authProvider.isAuthenticated) {
            authProvider.signOut();
          }
        } else if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
          // User signed in or session refreshed - reload user and check location
          final isNewLogin = !_wasAuthenticated;
          _wasAuthenticated = true;
          
          if (authProvider.user == null) {
            authProvider.loadUser().then((_) {
              if (mounted && authProvider.isAuthenticated && authProvider.user != null) {
                // Reset location state on new login
                if (isNewLogin) {
                  setState(() {
                    _hasLocationPermission = false;
                  });
                }
                _initializeAuth();
              }
            });
          } else {
            // Reset location state on new login
            if (isNewLogin) {
              setState(() {
                _hasLocationPermission = false;
              });
            }
            _initializeAuth();
          }
        }
      }
    });
  }

  Future<void> _initializeAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated || authProvider.user == null) {
      if (mounted) {
        setState(() {
          _isCheckingLocation = false;
          _hasLocationPermission = false;
        });
      }
      return;
    }

    // Reset location checking state when auth state changes
    if (mounted) {
      setState(() {
        _isCheckingLocation = true;
      });
    }

    await _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    if (!mounted) return;

    try {

      final status = await _locationService.checkPermissionStatus();
      
      if (!mounted) return;
      

      final wasGranted = status == LocationPermissionStatus.granted;
      


      setState(() {
        _hasLocationPermission = wasGranted;
        _isCheckingLocation = false;
      });
    } catch (e) {

      if (mounted) {
        setState(() {
          _hasLocationPermission = false;
          _isCheckingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Track authentication state changes
        final isAuthenticated = authProvider.isAuthenticated && authProvider.user != null;
        
        // Reset location state when transitioning from authenticated to unauthenticated
        if (!isAuthenticated && _wasAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isCheckingLocation = false;
                _hasLocationPermission = false;
                _wasAuthenticated = false;
              });
            }
          });
        }
        
        // Update wasAuthenticated flag
        if (isAuthenticated && !_wasAuthenticated) {
          _wasAuthenticated = true;
        }

        // Show loading while checking location permission
        if (_isCheckingLocation && isAuthenticated) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Check if user is authenticated
        if (isAuthenticated) {
          final role = authProvider.user!.role;
          
          if (role == AppConstants.roleRider) {
            // Check location permission for riders
            if (!_hasLocationPermission) {
              return _LocationPermissionWrapper(
                onPermissionGranted: () {
                  if (mounted) {
                    setState(() {
                      _hasLocationPermission = true;
                    });
                    _checkLocationPermission();
                  }
                },
              );
            } else {
              return const RiderHomeScreen();
            }
          } else {
            // Non-rider role - show error
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    const Text(
                      'This app is for Riders only',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please use the correct app for your role',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        await authProvider.signOut();
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            );
          }
        } else {
          // Not authenticated - show login screen
          return const LoginScreen();
        }
      },
    );
  }
}


class _LocationPermissionWrapper extends StatefulWidget {
  final VoidCallback onPermissionGranted;

  const _LocationPermissionWrapper({
    required this.onPermissionGranted,
  });

  @override
  State<_LocationPermissionWrapper> createState() => _LocationPermissionWrapperState();
}

class _LocationPermissionWrapperState extends State<_LocationPermissionWrapper>
    with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (!mounted) return;
    
    try {
      final status = await _locationService.checkPermissionStatus();
      
      if (mounted && status == LocationPermissionStatus.granted) {

        widget.onPermissionGranted();
      }
    } catch (e) {

    }
  }

  @override
  Widget build(BuildContext context) {
    return LocationPermissionScreen(
      onPermissionGranted: () {


        widget.onPermissionGranted();
      },
    );
  }
}

