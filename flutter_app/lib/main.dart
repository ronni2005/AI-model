// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/assessment_screen.dart';
import 'screens/results_screen.dart';
import 'screens/records_screen.dart';
import 'screens/patient_summary_screen.dart';
import 'services/database_service.dart';
import 'services/speech_service.dart';
import 'services/locale_service.dart';
import 'models/patient_record.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock only on mobile
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  await Future.wait([
    DatabaseService.instance.init(),
    SpeechService.instance.init(),
    LocaleService.instance.load('en'),
  ]);
  // Inference service has no async init needed (pure Dart)

  runApp(const RuralHealthApp());
}

// ════════════════════════════════════════════════════════════
// ROOT APP
// ════════════════════════════════════════════════════════════

class RuralHealthApp extends StatefulWidget {
  const RuralHealthApp({super.key});
  static _RuralHealthAppState? _state;
  static void refreshLocale() => _state?.setState(() {});

  @override
  State<RuralHealthApp> createState() {
    _state = _RuralHealthAppState();
    return _state!;
  }
}

class _RuralHealthAppState extends State<RuralHealthApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RuralHealth AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      onGenerateRoute: AppRouter.generate,
    );
  }
}

// ════════════════════════════════════════════════════════════
// THEME
// ════════════════════════════════════════════════════════════

class AppTheme {
  static const Color primary       = Color(0xFF1B6B3A);
  static const Color primaryLight  = Color(0xFF43A05F);
  static const Color accent        = Color(0xFF00897B);
  static const Color bgPage        = Color(0xFFF2F7F3);
  static const Color cardBg        = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1A2E1C);
  static const Color textSecondary = Color(0xFF5A7560);
  static const Color emergency     = Color(0xFFB71C1C);
  static const Color urgent        = Color(0xFFE65100);
  static const Color normal        = Color(0xFF2E7D32);

  static Color riskColor(String r) {
    switch (r) {
      case 'Emergency': return emergency;
      case 'Urgent':    return urgent;
      default:          return normal;
    }
  }

  static Color riskBgColor(String r) {
    switch (r) {
      case 'Emergency': return const Color(0xFFFDECEC);
      case 'Urgent':    return const Color(0xFFFFF3E0);
      default:          return const Color(0xFFE8F5E9);
    }
  }

  static IconData riskIcon(String r) {
    switch (r) {
      case 'Emergency': return Icons.emergency_rounded;
      case 'Urgent':    return Icons.warning_amber_rounded;
      default:          return Icons.check_circle_rounded;
    }
  }

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: primary, primary: primary, secondary: accent),
    scaffoldBackgroundColor: bgPage,
    textTheme: GoogleFonts.notoSansTextTheme().copyWith(
      displaySmall:  GoogleFonts.notoSans(fontSize: 28, fontWeight: FontWeight.bold,  color: textPrimary),
      headlineMedium:GoogleFonts.notoSans(fontSize: 20, fontWeight: FontWeight.w600,  color: textPrimary),
      titleLarge:    GoogleFonts.notoSans(fontSize: 17, fontWeight: FontWeight.w600,  color: textPrimary),
      titleMedium:   GoogleFonts.notoSans(fontSize: 15, fontWeight: FontWeight.w500,  color: textPrimary),
      titleSmall:    GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w600,  color: textPrimary),
      bodyLarge:     GoogleFonts.notoSans(fontSize: 15, color: textPrimary),
      bodyMedium:    GoogleFonts.notoSans(fontSize: 13, color: textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.notoSans(
          fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.notoSans(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBg, elevation: 1.5, shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 2)),
    ),
  );
}

// ════════════════════════════════════════════════════════════
// ROUTER
// ════════════════════════════════════════════════════════════

class AppRouter {
  static Route<dynamic> generate(RouteSettings s) {
    switch (s.name) {
      case '/':
        return _fade(const HomeScreen());
      case '/assessment':
        return _slide(const AssessmentScreen());
      case '/results':
        // FIX: Ensure the parameter name matches 'record' (or whatever you named it in results_screen.dart)
        final args = s.arguments as PatientRecord; 
        return _slide(ResultsScreen(record: args)); 
      case '/records':
        return _slide(const RecordsScreen());
      case '/summary':
        // FIX: Ensure the parameter name matches what is defined in PatientSummaryScreen
        final args = s.arguments as PatientRecord;
        return _slide(PatientSummaryScreen(record: args));
      default:
        return _fade(const HomeScreen());
    }
  }

  static PageRoute _fade(Widget p) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => p,
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 250));

  static PageRoute _slide(Widget p) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => p,
      transitionsBuilder: (_, a, __, c) => SlideTransition(
        position: Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: c,
      ),
      transitionDuration: const Duration(milliseconds: 320));
}