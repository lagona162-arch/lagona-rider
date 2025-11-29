import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/delivery_model.dart';
import '../../core/models/rider_model.dart';
import '../../core/services/delivery_service.dart';
import '../../core/services/rider_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../delivery/delivery_detail_screen.dart';

class RiderDeliveriesScreen extends StatefulWidget {
  const RiderDeliveriesScreen({super.key});

  @override
  State<RiderDeliveriesScreen> createState() => _RiderDeliveriesScreenState();
}

class _RiderDeliveriesScreenState extends State<RiderDeliveriesScreen>
    with WidgetsBindingObserver {
  final DeliveryService _deliveryService = DeliveryService();
  final RiderService _riderService = RiderService();
  List<DeliveryModel> _deliveries = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  Timer? _refreshTimer;
  Timer? _assignmentCheckTimer;
  RiderModel? _rider;
  bool _isScreenVisible = true;
  bool _hasActiveDelivery = false;
  RealtimeChannel? _deliveriesChannel;
  

  static const double _detectionRadiusKm = 5.0; 
  static const Duration _refreshInterval = Duration(seconds: 5);
  static const Duration _assignmentCheckInterval = Duration(seconds: 3); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeliveries();
    _setupRealtimeSubscription();
    _startAssignmentCheckTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _assignmentCheckTimer?.cancel();
    _deliveriesChannel?.unsubscribe();
    super.dispose();
  }


  void _setupRealtimeSubscription() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    final supabase = SupabaseService.instance;
    
    _deliveriesChannel?.unsubscribe();
    
    final currentUserId = authProvider.user!.id;
    
    _deliveriesChannel = supabase
        .channel('deliveries_changes_${currentUserId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'deliveries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: AppConstants.deliveryStatusPending,
          ),
          callback: (payload) {
            if (mounted && _isScreenVisible && !_hasActiveDelivery) {
              _refreshDeliveries();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'deliveries',
          callback: (payload) {
            try {
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              
              if (newRecord == null) return;
              
              final newRiderId = newRecord['rider_id'] as String?;
              final oldRiderId = oldRecord?['rider_id'] as String?;
              
              final wasAssignedToMe = oldRiderId == currentUserId;
              final isNowAssignedToMe = newRiderId == currentUserId;
              
              if (mounted && _isScreenVisible) {
                if (isNowAssignedToMe && !wasAssignedToMe) {
                  _loadDeliveries();
                } else if (wasAssignedToMe || isNowAssignedToMe) {
                  _loadDeliveries();
                } else {
                  final status = newRecord['status'] as String?;
                  if (status == AppConstants.deliveryStatusPending && !_hasActiveDelivery) {
                    _refreshDeliveries();
                  }
                }
              }
            } catch (e) {
              if (mounted && _isScreenVisible) {
                _refreshDeliveries();
              }
            }
          },
        )
        .subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isScreenVisible = false;
      _stopRefreshTimer();
      _stopAssignmentCheckTimer();
    } else if (state == AppLifecycleState.resumed) {
      _isScreenVisible = true;
      _checkRiderStatus();
      _loadDeliveries();
      _startAssignmentCheckTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isScreenVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkRiderStatus();
        _refreshDeliveries();
      });
    }
  }

  void _refreshOnTabSwitch() {
    if (mounted && _isScreenVisible) {
      _refreshDeliveries();
    }
  }

  @override
  void didUpdateWidget(RiderDeliveriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mounted && _isScreenVisible) {
      _refreshDeliveries();
    }
  }


  Future<void> _checkRiderStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;

      final rider = await _riderService.getRider(authProvider.user!.id);
      

      final hasActiveDelivery = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
      
      if (mounted) {
        final wasAvailable = _rider?.status == AppConstants.riderStatusAvailable;
        final isNowAvailable = rider.status == AppConstants.riderStatusAvailable;
        
        setState(() {
          _rider = rider;
          _hasActiveDelivery = hasActiveDelivery;
        });
        

        if (hasActiveDelivery) {
          _stopRefreshTimer();
          return;
        }
        

        if (wasAvailable && !isNowAvailable) {
          _stopRefreshTimer();
        } else if (!wasAvailable && isNowAvailable) {

          _loadDeliveries();
        } else if (isNowAvailable && !hasActiveDelivery) {

          _startRefreshTimer();
        }
      }
    } catch (e) {

    }
  }


  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user?.isActive != true) {
      return; 
    }
    

    if (_hasActiveDelivery) {
      return;
    }
    

    if (_isScreenVisible &&
        !_hasActiveDelivery &&
        _rider?.status == AppConstants.riderStatusAvailable &&
        _rider?.latitude != null &&
        _rider?.longitude != null) {
      _refreshTimer = Timer.periodic(_refreshInterval, (timer) async {
        if (!mounted || !_isScreenVisible) {
          timer.cancel();
          return;
        }
        

        if (authProvider.user != null) {
          final hasActive = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
          if (hasActive) {
            if (mounted) {
              setState(() {
                _hasActiveDelivery = true;
              });
            }
            timer.cancel();
            return;
          }
        }
        
        if (_rider?.status == AppConstants.riderStatusAvailable && !_hasActiveDelivery) {
          _refreshDeliveries();
        } else {
          timer.cancel();
        }
      });
    }
  }


  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
  }

  void _startAssignmentCheckTimer() {
    _assignmentCheckTimer?.cancel();
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user?.isActive != true) {
      return;
    }
    
    _assignmentCheckTimer = Timer.periodic(_assignmentCheckInterval, (timer) async {
      if (!mounted || !_isScreenVisible) {
        timer.cancel();
        return;
      }
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        timer.cancel();
        return;
      }
      
      try {
        final hasActive = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
        if (hasActive && !_hasActiveDelivery) {
          if (mounted) {
            setState(() {
              _hasActiveDelivery = true;
            });
          }
          _loadDeliveries();
        } else if (!hasActive && _hasActiveDelivery) {
          if (mounted) {
            setState(() {
              _hasActiveDelivery = false;
            });
          }
          _loadDeliveries();
        }
      } catch (e) {
      }
    });
  }

  void _stopAssignmentCheckTimer() {
    _assignmentCheckTimer?.cancel();
  }


  Future<void> _refreshDeliveries() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.user?.isActive != true) {
      return;
    }
    
    final hasActiveDelivery = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
    if (hasActiveDelivery) {
      if (!_hasActiveDelivery) {
        _stopRefreshTimer();
        if (mounted) {
          setState(() {
            _hasActiveDelivery = true;
          });
        }
        _loadDeliveries();
        return;
      }
    } else if (_hasActiveDelivery) {
      if (mounted) {
        setState(() {
          _hasActiveDelivery = false;
        });
      }
    }
    
    if (_rider == null || _rider!.status != AppConstants.riderStatusAvailable) {
      return;
    }

    if (_rider!.latitude == null || _rider!.longitude == null) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      if (authProvider.user == null) {
        setState(() {
          _isRefreshing = false;
        });
        return;
      }


      final assignedDeliveries = await _deliveryService.getDeliveries(
        riderId: authProvider.user!.id,
      );
      

      final currentHasActiveDelivery = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
      
      if (mounted) {
        setState(() {
          _hasActiveDelivery = currentHasActiveDelivery;
        });
      }
      


      List<DeliveryModel> nearbyDeliveries = [];
      if (!currentHasActiveDelivery) {
        nearbyDeliveries = await _deliveryService.getDeliveriesWithinRadius(
          riderLatitude: _rider!.latitude!,
          riderLongitude: _rider!.longitude!,
          radiusKm: _detectionRadiusKm,
          loadingStationId: _rider!.loadingStationId,
          status: AppConstants.deliveryStatusPending,
        );
      } else {

        _stopRefreshTimer();
      }
      

      final unassignedDeliveries = nearbyDeliveries
          .where((delivery) => delivery.riderId == null)
          .toList();
      

      final filteredDeliveries = [
        ...assignedDeliveries,
        ...unassignedDeliveries,
      ];

      if (mounted) {
        setState(() {
          _deliveries = filteredDeliveries;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadDeliveries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }


      if (authProvider.user?.isActive != true) {
        if (!mounted) return;
        
        setState(() {
          _isLoading = false;
          _deliveries = []; 
        });
        

        _stopRefreshTimer();
        return;
      }
      

      final rider = await _riderService.getRider(authProvider.user!.id);
      
      if (!mounted) return;
      
      setState(() {
        _rider = rider;
      });
      


      final assignedDeliveries = await _deliveryService.getDeliveries(
        riderId: authProvider.user!.id,
      );
      

      final hasActiveDelivery = await _deliveryService.hasActiveDelivery(authProvider.user!.id);
      
      if (!mounted) return;
      
      setState(() {
        _hasActiveDelivery = hasActiveDelivery;
      });
      


      List<DeliveryModel> nearbyDeliveries = [];
      if (!hasActiveDelivery &&
          rider.status == AppConstants.riderStatusAvailable &&
          rider.latitude != null &&
          rider.longitude != null) {
        nearbyDeliveries = await _deliveryService.getDeliveriesWithinRadius(
          riderLatitude: rider.latitude!,
          riderLongitude: rider.longitude!,
          radiusKm: _detectionRadiusKm,
          loadingStationId: rider.loadingStationId,
          status: AppConstants.deliveryStatusPending,
        );
      } else if (!hasActiveDelivery) {


        final availableDeliveries = await _deliveryService.getDeliveries(
          status: AppConstants.deliveryStatusPending,
          loadingStationId: rider.loadingStationId,
        );
        nearbyDeliveries = availableDeliveries;
      }

      

      final unassignedDeliveries = nearbyDeliveries
          .where((delivery) => delivery.riderId == null)
          .toList();
      

      final filteredDeliveries = [
        ...assignedDeliveries,
        ...unassignedDeliveries,
      ];

      if (mounted) {
        setState(() {
          _deliveries = filteredDeliveries;
          _isLoading = false;
        });
        

        _setupRealtimeSubscription();
        _startAssignmentCheckTimer();

        if (!hasActiveDelivery) {
          _startRefreshTimer();
        } else {
          _stopRefreshTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPendingApprovalMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pending_actions,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Account Pending Approval',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your account is pending admin approval. Once approved, you will be able to accept deliveries and change your status.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isActive = authProvider.user?.isActive ?? false;
        final isDetecting = isActive &&
            !_hasActiveDelivery &&
            _rider?.status == AppConstants.riderStatusAvailable &&
            _rider?.latitude != null &&
            _rider?.longitude != null;
        
        return Scaffold(
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error: $_error'),
                          ElevatedButton(
                            onPressed: _loadDeliveries,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : !isActive
                      ? _buildPendingApprovalMessage()
                      : Column(
                  children: [

                    if (isDetecting)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isRefreshing)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.location_searching,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isRefreshing
                                    ? 'Detecting delivery requests within 5km...'
                                    : 'Detecting delivery requests within 5km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              'Auto-refresh: 6s',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_hasActiveDelivery)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Colors.orange[800],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You have an active delivery. Complete it to accept new deliveries.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Expanded(
                      child: _deliveries.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_shipping_outlined,
                                    size: 64,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No deliveries available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (isDetecting) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Searching for deliveries within 5km...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadDeliveries,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _deliveries.length,
                                itemBuilder: (context, index) {
                                  final delivery = _deliveries[index];
                                  final isAssigned = delivery.riderId != null;
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: isAssigned ? 3 : 1,
                                    color: isAssigned
                                        ? AppColors.primary.withValues(alpha: 0.05)
                                        : null,
                                    child: ListTile(
                                      leading: Icon(
                                        delivery.type == AppConstants.deliveryTypePabili
                                            ? Icons.shopping_bag
                                            : Icons.local_shipping,
                                        color: isAssigned
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                      title: Text(
                                        delivery.type == AppConstants.deliveryTypePabili
                                            ? 'Pabili Delivery'
                                            : 'Padala Delivery',
                                        style: TextStyle(
                                          fontWeight: isAssigned
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Status: ${delivery.status}',
                                          ),
                                          if (delivery.pickupAddress != null)
                                            Text(
                                              delivery.pickupAddress!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          if (isAssigned)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'ASSIGNED TO YOU',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.textWhite,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '₱${delivery.deliveryFee?.toStringAsFixed(2) ?? '0.00'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          if (isAssigned)
                                            Text(
                                              'Commission: ₱${delivery.commissionRider?.toStringAsFixed(2) ?? '0.00'}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                      onTap: () async {
                                        final result = await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => DeliveryDetailScreen(
                                              deliveryId: delivery.id,
                                            ),
                                          ),
                                        );
                                        if (mounted && _isScreenVisible) {
                                          _loadDeliveries();
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

