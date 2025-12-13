import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/rider_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/notification_service.dart';
import 'rider_deliveries_screen.dart';
import 'rider_profile_screen.dart';
import 'rider_notifications_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _locationUpdateTimer;
  Timer? _notificationCheckTimer;
  final RiderService _riderService = RiderService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  bool _isAppInForeground = true;
  int _unreadNotificationCount = 0;

  final List<Widget> _screens = [
    const RiderDeliveriesScreen(),
    const RiderNotificationsScreen(),
    const RiderProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLocationUpdates();
    _startNotificationCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates();
    _stopNotificationCheck();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      _startLocationUpdates();
      _checkNotificationCount();
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      _isAppInForeground = false;
      _stopLocationUpdates();
    }
  }


  void _startLocationUpdates() {
    _stopLocationUpdates(); 
    

    _updateRiderLocation();
    

    _locationUpdateTimer = Timer.periodic(
      const Duration(milliseconds: 7500),
      (_) => _updateRiderLocation(),
    );
  }


  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }


  Future<void> _updateRiderLocation() async {
    if (!_isAppInForeground || !mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;


      if (authProvider.user?.isActive != true) return;


      final position = await _locationService.getCurrentPosition();
      

      String? address;
      try {
        address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
      } catch (_) {

      }


      await _riderService.updateRiderLocation(
        authProvider.user!.id,
        position.latitude,
        position.longitude,
        address,
      );
    } catch (e) {


    }
  }

  void _startNotificationCheck() {
    _stopNotificationCheck();
    _checkNotificationCount();
    _notificationCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkNotificationCount(),
    );
  }

  void _stopNotificationCheck() {
    _notificationCheckTimer?.cancel();
    _notificationCheckTimer = null;
  }

  Future<void> _checkNotificationCount() async {
    if (!_isAppInForeground || !mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;

      final count = await _notificationService.getUnreadCount(authProvider.user!.id);
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (e) {
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
              // AuthWrapper will handle navigation automatically
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
          if (index == 1) {
            _checkNotificationCount();
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Deliveries',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

