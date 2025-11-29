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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.user == null) {

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

        if (_isCheckingLocation) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated && authProvider.user != null) {

          final role = authProvider.user!.role;
          
          if (role == AppConstants.roleRider) {


            if (!_hasLocationPermission) {


              return _LocationPermissionWrapper(
                onPermissionGranted: () {


                  if (mounted) {
                    setState(() {
                      _hasLocationPermission = true;
                    });
                    


                    _checkLocationPermission().then((_) {


                    });
                  }
                },
              );
            } else {

              return const RiderHomeScreen();
            }
          } else {

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

