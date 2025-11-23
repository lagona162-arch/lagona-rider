import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/registration_service.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/phone_number_formatter.dart';
import '../rider/rider_document_upload_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lastnameController = TextEditingController();
  final _firstnameController = TextEditingController();
  final _middleInitialController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _codeController = TextEditingController();
  final _plateNumberController = TextEditingController();
  
  DateTime? _selectedBirthdate;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isValidatingLSCode = false;
  String? _lsCodeError;
  bool _isFetchingAddress = false;
  List<Map<String, dynamic>> _addressSuggestions = [];
  double? _selectedLatitude;
  double? _selectedLongitude;
  Timer? _addressDebounce;
  final FocusNode _addressFocusNode = FocusNode();
  
  // Vehicle type is fixed to Motorcycle (two wheels) for now
  static const String _vehicleType = 'Motorcycle';
  
  // Get phone number without dashes for saving
  String _getPhoneNumberWithoutDashes() {
    return _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
  }

  // Calculate age from birthdate
  int? _calculateAge(DateTime? birthdate) {
    if (birthdate == null) return null;
    final today = DateTime.now();
    int age = today.year - birthdate.year;
    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  // Check if 18 or older
  bool _is18OrOlder(DateTime? birthdate) {
    final age = _calculateAge(birthdate);
    return age != null && age >= 18;
  }

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressChanged);
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus) {
        // Hide suggestions when address field loses focus
        setState(() {
          _addressSuggestions = [];
        });
      }
    });
  }

  Future<void> _selectBirthdate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Birthdate',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() {
        _selectedBirthdate = picked;
      });
    }
  }

  Future<void> _prefillAddressFromLocation() async {
    if (_isFetchingAddress) return;
    setState(() {
      _isFetchingAddress = true;
    });
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      final formatted = await locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      _addressController.text = formatted;
    } catch (e) {
      // Silent failure; user can type manually
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingAddress = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _addressController.removeListener(_onAddressChanged);
    _addressFocusNode.dispose();
    _lastnameController.dispose();
    _firstnameController.dispose();
    _middleInitialController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _codeController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  void _onAddressChanged() {
    // Only suggest when address field is focused
    if (!_addressFocusNode.hasFocus) return;
    _addressDebounce?.cancel();
    final query = _addressController.text.trim();
    // Clear selected coordinates when user edits the address
    _selectedLatitude = null;
    _selectedLongitude = null;
    if (query.isEmpty) {
      setState(() {
        _addressSuggestions = [];
      });
      return;
    }
    _addressDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final locationService = LocationService();
        final results = await locationService.searchAddressSuggestions(query);
        if (!mounted) return;
        setState(() {
          _addressSuggestions = results;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _addressSuggestions = [];
        });
      }
    });
  }

  Future<void> _validateLSCode() async {
    final lsCode = _codeController.text.trim();
    if (lsCode.isEmpty) {
      setState(() {
        _lsCodeError = 'Please enter Loading Station Code';
      });
      return;
    }

    setState(() {
      _isValidatingLSCode = true;
      _lsCodeError = null;
    });

    try {
      final registrationService = RegistrationService();
      final isValid = await registrationService.validateLSCode(lsCode);
      
      if (mounted) {
        setState(() {
          _isValidatingLSCode = false;
          if (!isValid) {
            _lsCodeError = 'Invalid Loading Station Code. Please check and try again.';
          } else {
            _lsCodeError = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidatingLSCode = false;
          _lsCodeError = 'Failed to validate Loading Station Code. Please try again.';
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final lsCode = _codeController.text.trim();
    
    // Validate LSCODE is not empty
    if (lsCode.isEmpty) {
      setState(() {
        _lsCodeError = 'Please enter Loading Station Code';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter Loading Station Code'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate LSCODE exists in database before proceeding
    setState(() {
      _isValidatingLSCode = true;
      _lsCodeError = null;
    });

    try {
      final registrationService = RegistrationService();
      final isValid = await registrationService.validateLSCode(lsCode);
      
      if (!isValid) {
        if (mounted) {
          setState(() {
            _isValidatingLSCode = false;
            _lsCodeError = 'Invalid Loading Station Code. Please check the code and try again.';
          });
          // Trigger form validation to show the error in the field
          _formKey.currentState?.validate();
        }
        return;
      }

      // Validate required fields (plate number is required)
      if (_plateNumberController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enter your plate number'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() {
          _isValidatingLSCode = false;
        });
        return;
      }

      // License card upload is NOT required during registration
      // It will be required in the document upload screen after registration

      // LSCODE is valid, proceed with registration
      if (!mounted) return;
      
      setState(() {
        _isValidatingLSCode = false;
        _lsCodeError = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Validate birthdate is provided and user is 18+
      if (_selectedBirthdate == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please select your birthdate'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() {
          _isValidatingLSCode = false;
        });
        return;
      }

      if (!_is18OrOlder(_selectedBirthdate)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('You must be at least 18 years old to register'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() {
          _isValidatingLSCode = false;
        });
        return;
      }
      
      // Sign up user (without license card URL - will be uploaded in document upload screen)
      // Get phone number without dashes for saving
      final phoneNumber = _phoneController.text.trim().isEmpty 
          ? null 
          : _getPhoneNumberWithoutDashes();
      
      // Build full name from parts if available, otherwise use full name field
      String fullName = _fullNameController.text.trim();
      if (_firstnameController.text.trim().isNotEmpty && 
          _lastnameController.text.trim().isNotEmpty) {
        final parts = <String>[
          _firstnameController.text.trim(),
          if (_middleInitialController.text.trim().isNotEmpty)
            _middleInitialController.text.trim(),
          _lastnameController.text.trim(),
        ];
        fullName = parts.join(' ');
      }
      
      // Determine coordinates/address:
      // - If user selected a suggestion, use its lat/lng and label
      // - Else, capture device location and reverse-geocode
      double? latitude = _selectedLatitude;
      double? longitude = _selectedLongitude;
      String? formattedAddress = _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim();
      if (latitude == null || longitude == null) {
        try {
          final locationService = LocationService();
          final position = await locationService.getCurrentPosition();
          latitude ??= position.latitude;
          longitude ??= position.longitude;
          formattedAddress = await locationService.getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );
        } catch (_) {
          // keep whatever the user typed
        }
      }

      final success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: fullName,
        phone: phoneNumber,
        plateNumber: _plateNumberController.text.trim(),
        vehicleType: _vehicleType, // Fixed to Motorcycle for now
        lastname: _lastnameController.text.trim().isEmpty 
            ? null 
            : _lastnameController.text.trim(),
        firstname: _firstnameController.text.trim().isEmpty 
            ? null 
            : _firstnameController.text.trim(),
        middleInitial: _middleInitialController.text.trim().isEmpty 
            ? null 
            : _middleInitialController.text.trim(),
        birthdate: _selectedBirthdate,
        address: formattedAddress,
        latitude: latitude,
        longitude: longitude,
        currentAddress: formattedAddress,
      );

      if (success && mounted) {
        // Link rider to loading station
        try {
          await registrationService.linkRiderToLoadingStation(
            authProvider.user!.id,
            lsCode,
          );
          
          if (mounted) {
            // Navigate to document upload screen after successful registration
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const RiderDocumentUploadScreen(),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration completed but failed to link to Loading Station: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Registration failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidatingLSCode = false;
          _lsCodeError = 'Failed to validate Loading Station Code. Please check your connection and try again.';
        });
        // Trigger form validation to show the error
        _formKey.currentState?.validate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up to get started',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 24),
                // Personal Information Section
                Text(
                  'Personal Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // Lastname
                TextFormField(
                  controller: _lastnameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Lastname *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your lastname';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Firstname
                TextFormField(
                  controller: _firstnameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Firstname *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your firstname';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Middle Initial
                TextFormField(
                  controller: _middleInitialController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 1,
                  decoration: const InputDecoration(
                    labelText: 'Middle Initial',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                // Birthdate (Age must be 18+)
                InkWell(
                  onTap: _selectBirthdate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthdate *',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: const OutlineInputBorder(),
                      helperText: 'Must be 18 years or older',
                    ),
                    child: Text(
                      _selectedBirthdate == null
                          ? 'Select your birthdate'
                          : '${_selectedBirthdate!.day}/${_selectedBirthdate!.month}/${_selectedBirthdate!.year} ${_calculateAge(_selectedBirthdate) != null ? "(${_calculateAge(_selectedBirthdate)} years old)" : ""}',
                      style: TextStyle(
                        color: _selectedBirthdate == null
                            ? Colors.grey
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
                if (_selectedBirthdate != null && !_is18OrOlder(_selectedBirthdate))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Text(
                      'You must be at least 18 years old',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Address
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  focusNode: _addressFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Address *',
                    prefixIcon: const Icon(Icons.home),
                    border: const OutlineInputBorder(),
                    helperText: 'Enter your complete address',
                    suffixIcon: IconButton(
                      tooltip: 'Use my location',
                      icon: _isFetchingAddress
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      onPressed: _isFetchingAddress ? null : _prefillAddressFromLocation,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your address';
                    }
                    return null;
                  },
                ),
                // Suggestions list below Address
                if (_addressFocusNode.hasFocus && _addressSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _addressSuggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final s = _addressSuggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            s['label'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            setState(() {
                              _addressController.text = s['label'] as String;
                              _selectedLatitude = s['latitude'] as double;
                              _selectedLongitude = s['longitude'] as double;
                              _addressSuggestions = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Full Name (Optional - can be auto-generated from firstname, MI, lastname)
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name (Optional)',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                    helperText: 'Will be auto-generated from name fields if left empty',
                  ),
                ),
                const SizedBox(height: 24),
                // Contact Information Section
                Text(
                  'Contact Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PhoneNumberFormatter(), // Custom formatter: displays as 0912-345-6789
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone (Optional)',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    helperText: 'Format: 0912-345-6789 (11 digits)',
                  ),
                  validator: (value) {
                    // Phone is optional, so empty is valid
                    if (value == null || value.isEmpty) {
                      return null;
                    }
                    
                    // Get digits only (without dashes)
                    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
                    
                    // Check if it's exactly 11 digits
                    if (digitsOnly.length != 11) {
                      return 'Phone number must be exactly 11 digits';
                    }
                    
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                // Plate Number
                const SizedBox(height: 16),
                TextFormField(
                  controller: _plateNumberController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Plate Number',
                    prefixIcon: Icon(Icons.confirmation_number),
                    border: OutlineInputBorder(),
                    helperText: 'Enter your vehicle plate number',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your plate number';
                    }
                    return null;
                  },
                ),
                // LSCODE is required for rider registration
                // Note: Vehicle type is fixed to Motorcycle (two wheels) for now
                // Note: License card upload will be done after registration in a separate screen
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Loading Station Code (LSCODE)',
                    prefixIcon: const Icon(Icons.qr_code),
                    border: const OutlineInputBorder(),
                    // Show helper text only when there's no error
                    helperText: _lsCodeError == null
                        ? 'Enter the Loading Station Code provided by your Loading Station'
                        : null,
                    helperMaxLines: 2,
                    helperStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    // Error text with proper styling
                    errorText: _lsCodeError,
                    errorStyle: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                    errorMaxLines: 3,
                    suffixIcon: _isValidatingLSCode
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    // Clear error when user starts typing
                    if (_lsCodeError != null) {
                      setState(() {
                        _lsCodeError = null;
                      });
                    }
                  },
                  onFieldSubmitted: (_) {
                    if (_codeController.text.trim().isNotEmpty && !_isValidatingLSCode) {
                      _validateLSCode();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the Loading Station Code';
                    }
                    // Return the validation error if it exists
                    return _lsCodeError;
                  },
                ),
                // Show validation status below the field
                if (_isValidatingLSCode)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Validating Loading Station Code...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final isLoading = authProvider.isLoading || _isValidatingLSCode;
                    return ElevatedButton(
                      onPressed: isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Sign Up',
                              style: TextStyle(fontSize: 16),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

