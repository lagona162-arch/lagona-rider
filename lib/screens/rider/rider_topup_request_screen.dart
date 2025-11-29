import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/topup_service.dart';
import '../../core/services/rider_service.dart';
import '../../core/models/rider_model.dart';
import '../../core/models/loading_station_model.dart';
import '../../core/services/supabase_service.dart';
import '../../core/constants/app_colors.dart';

class RiderTopUpRequestScreen extends StatefulWidget {
  const RiderTopUpRequestScreen({super.key});

  @override
  State<RiderTopUpRequestScreen> createState() => _RiderTopUpRequestScreenState();
}

class _RiderTopUpRequestScreenState extends State<RiderTopUpRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final TopUpService _topUpService = TopUpService();
  final RiderService _riderService = RiderService();
  bool _isLoading = false;
  bool _isLoadingData = true;
  RiderModel? _rider;
  LoadingStationModel? _loadingStation;
  static const double _minimumTopUpAmount = 100.0;

  @override
  void initState() {
    super.initState();
    _loadRiderData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRiderData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) {
        throw Exception('User not authenticated');
      }

      final rider = await _riderService.getRider(authProvider.user!.id);
      
      if (rider.loadingStationId != null) {
        final supabase = SupabaseService.instance;
        final lsResponse = await supabase
            .from('loading_stations')
            .select()
            .eq('id', rider.loadingStationId)
            .maybeSingle();
        
        LoadingStationModel? loadingStation;
        if (lsResponse != null) {
          loadingStation = LoadingStationModel.fromJson(lsResponse as Map<String, dynamic>);
        }

        if (mounted) {
          setState(() {
            _rider = rider;
            _loadingStation = loadingStation;
            _isLoadingData = false;
          });

          if (rider.balance <= 0) {
            final suggestedAmount = _minimumTopUpAmount;
            _amountController.text = suggestedAmount.toStringAsFixed(0);
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _rider = rider;
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _setAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _requestTopUp() async {
    if (_formKey.currentState!.validate()) {
      if (_rider == null || _rider!.loadingStationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rider is not linked to a Loading Station'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.user == null) {
          throw Exception('User not authenticated');
        }

        final amount = double.parse(_amountController.text.trim());

        await _topUpService.createTopUp(
          initiatedBy: authProvider.user!.id,
          riderId: authProvider.user!.id,
          loadingStationId: _rider!.loadingStationId,
          amount: amount,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Top-up request submitted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request Top-Up'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_rider == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request Top-Up'),
        ),
        body: const Center(
          child: Text('Failed to load rider information'),
        ),
      );
    }

    final currentBalance = _rider!.balance;
    final isInsufficientBalance = currentBalance <= 0;
    final hasLoadingStation = _rider!.loadingStationId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Top-Up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Request Top-Up Credits',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasLoadingStation
                    ? 'Request top-up credits from your Loading Station'
                    : 'You must be linked to a Loading Station to request top-up',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                color: isInsufficientBalance
                    ? AppColors.error.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isInsufficientBalance
                                ? Icons.warning_amber_rounded
                                : Icons.account_balance_wallet,
                            color: isInsufficientBalance
                                ? AppColors.error
                                : AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Balance',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₱${currentBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: isInsufficientBalance
                                        ? AppColors.error
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isInsufficientBalance) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
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
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your balance is insufficient. You need to top-up to continue accepting deliveries.',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasLoadingStation && _loadingStation != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Loading Station',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _loadingStation!.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_loadingStation!.address != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _loadingStation!.address!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Top-Up Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (isInsufficientBalance) ...[
                Text(
                  'Quick Top-Up Options',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickAmountButton(100),
                    _buildQuickAmountButton(250),
                    _buildQuickAmountButton(500),
                    _buildQuickAmountButton(1000),
                    _buildQuickAmountButton(2000),
                    _buildQuickAmountButton(5000),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₱)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: const OutlineInputBorder(),
                  helperText: isInsufficientBalance
                      ? 'Minimum top-up amount is ₱$_minimumTopUpAmount'
                      : 'Enter the amount you want to top-up (minimum ₱$_minimumTopUpAmount)',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount < _minimumTopUpAmount) {
                    return 'Minimum top-up amount is ₱$_minimumTopUpAmount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (hasLoadingStation && !_isLoading)
                    ? _requestTopUp
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isInsufficientBalance
                      ? AppColors.error
                      : AppColors.primary,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Text(
                        isInsufficientBalance
                            ? 'Request Top-Up to Continue'
                            : 'Submit Request',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              if (!hasLoadingStation) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                        Icons.error_outline,
                        color: AppColors.statusPending,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You need to link your account to a Loading Station first.',
                          style: TextStyle(
                            color: AppColors.statusPending,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Card(
                color: AppColors.primary.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Note',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your top-up request will be sent to your Loading Station for approval. Once approved, the credits will be added to your balance.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(double amount) {
    final isSelected = _amountController.text == amount.toStringAsFixed(0);
    return InkWell(
      onTap: () => _setAmount(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          '₱${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

