import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/supabase_service.dart';
import 'core/providers/auth_provider.dart';
import 'core/constants/app_colors.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    rethrow;
  }
  

  await SupabaseService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'Lagona Rider App',
        debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            primaryContainer: AppColors.primaryLight,
            secondary: AppColors.secondary,
            secondaryContainer: AppColors.secondaryLight,
            surface: AppColors.surface,
            error: AppColors.error,
            onPrimary: AppColors.textWhite,
            onSecondary: AppColors.textWhite,
            onSurface: AppColors.textPrimary,
            onError: AppColors.textWhite,
          ),
          scaffoldBackgroundColor: AppColors.background,
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.light().textTheme.copyWith(
                  bodyLarge: TextStyle(color: AppColors.textPrimary),
                  bodyMedium: TextStyle(color: AppColors.textPrimary),
                  bodySmall: TextStyle(color: AppColors.textSecondary),
                  headlineLarge: TextStyle(color: AppColors.textPrimary),
                  headlineMedium: TextStyle(color: AppColors.textPrimary),
                  headlineSmall: TextStyle(color: AppColors.textPrimary),
                  titleLarge: TextStyle(color: AppColors.textPrimary),
                  titleMedium: TextStyle(color: AppColors.textPrimary),
                  titleSmall: TextStyle(color: AppColors.textPrimary),
                  labelLarge: TextStyle(color: AppColors.textPrimary),
                  labelMedium: TextStyle(color: AppColors.textSecondary),
                  labelSmall: TextStyle(color: AppColors.textSecondary),
                ),
          ),
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.cardBackground,
            elevation: 2,
            shadowColor: AppColors.cardShadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.inputBorderFocused, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            helperStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            helperMaxLines: 2,
            errorStyle: TextStyle(
              color: AppColors.error,
              fontSize: 12,
              height: 1.4,
            ),
            errorMaxLines: 3,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.buttonPrimary,
              foregroundColor: AppColors.textWhite,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: AppColors.buttonDisabled,
              disabledForegroundColor: AppColors.textSecondary,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textWhite,
            elevation: 4,
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            selectedItemColor: AppColors.navSelected,
            unselectedItemColor: AppColors.navUnselected,
            backgroundColor: AppColors.surface,
            elevation: 8,
            selectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
            ),
          ),
          dividerTheme: DividerThemeData(
            color: AppColors.divider,
            thickness: 1,
          ),
          chipTheme: ChipThemeData(
            backgroundColor: AppColors.surface,
            selectedColor: AppColors.primary,
            labelStyle: TextStyle(color: AppColors.textPrimary),
            secondaryLabelStyle: TextStyle(color: AppColors.textWhite),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
