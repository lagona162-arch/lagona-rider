import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAuth();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user if authenticated but user data is missing
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.user == null) {
      // Try to reload user data
      authProvider.loadUser();
    }
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

    // Only check location permission for authenticated users
    // Document upload is only part of registration flow, not login flow
    await _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    if (!mounted) return;

    try {
      // Check permission status - this should be quick
      final status = await _locationService.checkPermissionStatus();
      
      if (!mounted) return;
      
      // Update state immediately - this triggers a rebuild
      final wasGranted = status == LocationPermissionStatus.granted;
      
      // Use setState to update - this will trigger build method
      // The build method will show RiderHomeScreen if wasGranted is true
      setState(() {
        _hasLocationPermission = wasGranted;
        _isCheckingLocation = false;
      });
    } catch (e) {
      // If there's an error, assume permission is not granted
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
        // Show loading only while checking location permission initially
        if (_isCheckingLocation) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated && authProvider.user != null) {
          // This is a rider-only app, so only show rider home screen
          final role = authProvider.user!.role;
          
          if (role == AppConstants.roleRider) {
            // Document upload is only shown during registration, not after login
            // After login, users go directly to home or location permission screen
            if (!_hasLocationPermission) {
              // Show location permission screen
              // This screen will handle permission request and update state when granted
              return _LocationPermissionWrapper(
                onPermissionGranted: () {
                  // When permission is granted, optimistically update state immediately
                  // This prevents black screen by triggering immediate rebuild
                  if (mounted) {
                    setState(() {
                      _hasLocationPermission = true;
                    });
                    
                    // Then verify the permission in the background
                    // If verification fails, we'll update state back to false
                    _checkLocationPermission().then((_) {
                      // Verification complete - state already updated
                      // If permission was not actually granted, state will be corrected
                    });
                  }
                },
              );
            } else {
              // Show rider home screen
              return const RiderHomeScreen();
            }
          } else {
            // If user is not a rider, show error or logout
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
          return const LoginScreen();
        }
      },
    );
  }
}

/// Wrapper widget for LocationPermissionScreen that handles navigation
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
    // Check permission status immediately when screen loads
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
    // When app comes back to foreground (e.g., from settings), check permission
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (!mounted) return;
    
    try {
      final status = await _locationService.checkPermissionStatus();
      
      if (mounted && status == LocationPermissionStatus.granted) {
        // Permission granted, call callback to update parent state
        widget.onPermissionGranted();
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return LocationPermissionScreen(
      onPermissionGranted: () {
        // When permission is granted, call the parent callback immediately
        // The callback will optimistically update state, triggering rebuild
        widget.onPermissionGranted();
      },
    );
  }
}

