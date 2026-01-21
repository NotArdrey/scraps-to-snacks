import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scraps_to_snacks/pages/login_page.dart';
import 'package:scraps_to_snacks/pages/main_scaffold.dart';
import 'package:scraps_to_snacks/pages/splash_page.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://iwpmcttfpvwmqsgyofsx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3cG1jdHRmcHZ3bXFzZ3lvZnN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5NzcwNTUsImV4cCI6MjA4NDU1MzA1NX0.2bOpR-NcfBK6xUUUL66HwXh3P2CdS7_qYGtMM0hyx44',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scraps to Snacks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Fresh Green
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF81C784),
          surface: Colors.white,
          background: Colors.white,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.outfitTextTheme(),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPage();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return const MainScaffold();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
