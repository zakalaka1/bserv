import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/appointments/appointment_repository.dart';
import '../data/content/business_content_repository.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_gateway.dart';
import 'book_service_shell.dart';

class BookServiceApp extends StatefulWidget {
  const BookServiceApp({
    super.key,
    required this.authGateway,
    required this.appointmentRepository,
    required this.businessContentRepository,
  });

  final AuthGateway authGateway;
  final AppointmentRepository appointmentRepository;
  final BusinessContentRepository businessContentRepository;

  @override
  State<BookServiceApp> createState() => _BookServiceAppState();
}

class _BookServiceAppState extends State<BookServiceApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isLeftHanded = false;
  AuthState _authState = const AuthState.signedOut();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authState = widget.authGateway.currentState;
    _authSubscription = widget.authGateway.authStateChanges.listen((value) {
      if (mounted) {
        setState(() => _authState = value);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _toggleTheme(bool isCurrentlyDark) {
    setState(() {
      _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _toggleHandedness() {
    setState(() => _isLeftHanded = !_isLeftHanded);
  }

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF246B5B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: BookServiceShell(
        isAdminLoggedIn: _authState.isAdmin,
        isAuthenticated: _authState.isAuthenticated,
        authGateway: widget.authGateway,
        appointmentRepository: widget.appointmentRepository,
        businessContentRepository: widget.businessContentRepository,
        isLeftHanded: _isLeftHanded,
        onToggleHandedness: _toggleHandedness,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
