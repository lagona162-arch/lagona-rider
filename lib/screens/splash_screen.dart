import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/constants/app_colors.dart';
import 'auth/auth_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _bounceController;
  late AnimationController _smokeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Controller for smooth horizontal movement (driving forward)
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Controller for vertical bounce (road bumps) - faster frequency
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Controller for smoke particles
    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Slide animation - smooth continuous forward movement
    _slideAnimation = Tween<double>(
      begin: -100.0,
      end: 100.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.linear,
    ));

    // Bounce animation - subtle vertical movement (like road bumps)
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: -6.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bounceController.dispose();
    _smokeController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // Wait for splash screen animation
    await Future.delayed(const Duration(seconds: 2));
    
    // Load user if authenticated
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadUser();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated motorcycle icon - driving effect with smoke
              SizedBox(
                width: 300,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Smoke particles behind the motorcycle
                    AnimatedBuilder(
                      animation: Listenable.merge([_slideController, _bounceController, _smokeController]),
                      builder: (context, child) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: List.generate(3, (index) {
                            return _SmokeParticle(
                              controller: _smokeController,
                              delay: index * 0.25,
                              slideOffset: _slideAnimation.value,
                              bounceOffset: _bounceAnimation.value,
                            );
                          }),
                        );
                      },
                    ),
                    // Animated motorcycle with combined movements
                    AnimatedBuilder(
                      animation: Listenable.merge([_slideController, _bounceController]),
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            _slideAnimation.value,
                            _bounceAnimation.value,
                          ),
                          child: Transform.rotate(
                            // Dynamic tilt based on movement direction
                            angle: (_slideAnimation.value / 100) * 0.03,
                            child: Icon(
                              Icons.delivery_dining,
                              size: 100,
                              color: AppColors.textWhite,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Lagona Rider',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textWhite,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Delivery Made Easy',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textWhite.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 40),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.textWhite),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Smoke particle widget that animates behind the motorcycle
class _SmokeParticle extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final double slideOffset;
  final double bounceOffset;

  const _SmokeParticle({
    required this.controller,
    required this.delay,
    required this.slideOffset,
    required this.bounceOffset,
  });

  @override
  Widget build(BuildContext context) {
    // Create delayed animation
    final delayedAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOut,
      ),
    ));

    return AnimatedBuilder(
      animation: delayedAnimation,
      builder: (context, child) {
        // Calculate smoke position (behind the motorcycle)
        // Motorcycle is at center, smoke should be to the left (behind it)
        // Smoke moves backward and upward as it fades
        final smokeX = slideOffset - 50 - (delayedAnimation.value * 40);
        final smokeY = bounceOffset - (delayedAnimation.value * 30);
        
        // Opacity fades out as smoke disperses
        final opacity = (1.0 - delayedAnimation.value).clamp(0.0, 1.0) * 0.5;
        
        // Size increases as smoke expands and disperses
        final size = 10.0 + (delayedAnimation.value * 25);

        // Only show smoke if it has opacity
        if (opacity <= 0.01) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 150 + smokeX, // Center of container (300/2) + offset
          top: 75 + smokeY, // Center vertically (150/2) + offset
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.7),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    blurRadius: size * 1.2,
                    spreadRadius: size * 0.5,
                  ),
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    blurRadius: size * 0.6,
                    spreadRadius: size * 0.2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

