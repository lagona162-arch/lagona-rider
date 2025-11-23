import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/rider_service.dart';
import '../../core/services/location_service.dart';
import '../auth/login_screen.dart';
import 'rider_deliveries_screen.dart';
import 'rider_profile_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _locationUpdateTimer;
  final RiderService _riderService = RiderService();
  final LocationService _locationService = LocationService();
  bool _isAppInForeground = true;

  final List<Widget> _screens = [
    const RiderDeliveriesScreen(),
    const RiderProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocationUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      _startLocationUpdates();
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      _isAppInForeground = false;
      _stopLocationUpdates();
    }
  }

  /// Start periodic location updates (every 7.5 seconds - middle of 5-10 range)
  void _startLocationUpdates() {
    _stopLocationUpdates(); // Stop any existing timer
    
    // Update immediately on start
    _updateRiderLocation();
    
    // Then update every 7.5 seconds (middle of 5-10 second range)
    _locationUpdateTimer = Timer.periodic(
      const Duration(milliseconds: 7500),
      (_) => _updateRiderLocation(),
    );
  }

  /// Stop location updates
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  /// Update rider's location in the database
  Future<void> _updateRiderLocation() async {
    if (!_isAppInForeground || !mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;

      // Check if user is active
      if (authProvider.user?.isActive != true) return;

      // Get current location
      final position = await _locationService.getCurrentPosition();
      
      // Get address from coordinates (optional, but helpful)
      String? address;
      try {
        address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
      } catch (_) {
        // If reverse geocoding fails, continue without address
      }

      // Update rider location in database
      await _riderService.updateRiderLocation(
        authProvider.user!.id,
        position.latitude,
        position.longitude,
        address,
      );
    } catch (e) {
      // Silently handle errors (permission denied, location unavailable, etc.)
      // Don't spam the user with errors for background location updates
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

