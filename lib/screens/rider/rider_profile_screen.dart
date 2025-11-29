import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/rider_model.dart';
import '../../core/services/rider_service.dart';
import '../../core/services/location_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import 'rider_topup_request_screen.dart';
import 'rider_location_picker_screen.dart';

class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final RiderService _riderService = RiderService();
  final LocationService _locationService = LocationService();
  RiderModel? _rider;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadRider();
  }

  Future<void> _loadRider() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        final rider = await _riderService.getRider(authProvider.user!.id);
        if (!mounted) return;
        setState(() {
          _rider = rider;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRider();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rider Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: const Text('Balance'),
                      trailing: Text(
                        '₱${_rider?.balance.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.motorcycle),
                      title: const Text('Vehicle Type'),
                      trailing: Text(_rider?.vehicleType ?? 'N/A'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.confirmation_number),
                      title: const Text('Plate Number'),
                      trailing: Text(_rider?.plateNumber ?? 'N/A'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.percent),
                      title: const Text('Commission Rate'),
                      trailing: Text(
                        '${_rider?.commissionRate.toStringAsFixed(2) ?? '0.00'}%',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_on),
                      title: const Text('Status'),
                      trailing: _isUpdatingStatus
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Consumer<AuthProvider>(
                              builder: (context, authProvider, _) {
                                final isActive = authProvider.user?.isActive ?? false;
                                final hasSufficientBalance = (_rider?.balance ?? 0) > 0;
                                
                                return Switch(
                                  value: _rider?.status == AppConstants.riderStatusAvailable,
                                  onChanged: (isActive && hasSufficientBalance)
                                      ? (bool value) async {
                                          if (_rider == null) return;
                                          
                                          setState(() {
                                            _isUpdatingStatus = true;
                                          });
                                          
                                          final newStatus = value
                                              ? AppConstants.riderStatusAvailable
                                              : AppConstants.riderStatusOffline;
                                          
                                          try {

                                            if (value) {

                                              final position = await _locationService.getCurrentPosition();
                                              

                                              final address = await _locationService.getAddressFromCoordinates(
                                                position.latitude,
                                                position.longitude,
                                              );
                                              

                                              await _riderService.updateRiderStatus(
                                                _rider!.id,
                                                newStatus,
                                                latitude: position.latitude,
                                                longitude: position.longitude,
                                                address: address,
                                              );
                                            } else {

                                              await _riderService.updateRiderStatus(
                                                _rider!.id,
                                                newStatus,
                                              );
                                            }
                                            
                                            if (!mounted) return;
                                            
                                            setState(() {
                                              _isUpdatingStatus = false;
                                            });
                                            

                                            _loadRider();
                                            

                                            if (!mounted) return;
                                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  value
                                                      ? 'Status updated to Available. Location updated.'
                                                      : 'Status updated to Offline',
                                                ),
                                                backgroundColor: AppColors.success,
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            
                                            setState(() {
                                              _isUpdatingStatus = false;
                                            });
                                            

                                            if (!mounted) return;
                                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                              SnackBar(
                                                content: Text('Failed to update status: $e'),
                                                backgroundColor: AppColors.error,
                                                duration: const Duration(seconds: 4),
                                              ),
                                            );
                                            

                                            _loadRider();
                                          }
                                        }
                                      : null, 
                                  activeThumbColor: AppColors.success,
                                  inactiveThumbColor: AppColors.textSecondary,
                                );
                              },
                            ),
                      subtitle: _rider != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _rider!.status == AppConstants.riderStatusAvailable
                                              ? AppColors.success
                                              : _rider!.status == AppConstants.riderStatusBusy
                                                  ? AppColors.statusPending
                                                  : AppColors.textSecondary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _rider!.status.toUpperCase(),
                                          style: TextStyle(
                                            color: AppColors.textWhite,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  Consumer<AuthProvider>(
                                    builder: (context, authProvider, _) {
                                      final isActive = authProvider.user?.isActive ?? false;
                                      if (!isActive) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppColors.error.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 16,
                                                  color: AppColors.error,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Your account is pending admin approval. You cannot change your status until approved.',
                                                    style: TextStyle(
                                                      color: AppColors.error,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      if ((_rider?.balance ?? 0) <= 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.statusPending.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppColors.statusPending.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.account_balance_wallet_outlined,
                                                  size: 16,
                                                  color: AppColors.statusPending,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'You need to top-up before going Available.',
                                                    style: TextStyle(
                                                      color: AppColors.statusPending,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RiderTopUpRequestScreen(),
                          ),
                        );
                        if (result == true) {
                          _loadRider();
                        }
                      },
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Request Top-Up'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RiderLocationPickerScreen(
                              currentRider: _rider,
                            ),
                          ),
                        ).then((_) {

                          _loadRider();
                        });
                      },
                      icon: const Icon(Icons.location_on),
                      label: const Text('Update Location on Map'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),

                  if (_rider?.latitude != null && _rider?.longitude != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Current Location',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${_rider!.latitude!.toStringAsFixed(6)}',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            Text(
                              'Lng: ${_rider!.longitude!.toStringAsFixed(6)}',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            if (_rider!.currentAddress != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _rider!.currentAddress!,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

