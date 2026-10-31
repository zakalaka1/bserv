import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/appointments/appointment_repository.dart';
import '../data/content/business_content_repository.dart';
import '../data/content/work_notes_repository.dart';
import '../data/user/user_settings_repository.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_gateway.dart';
import 'book_service_shell.dart';

class BookServiceApp extends StatefulWidget {
  const BookServiceApp({
    super.key,
    required this.authGateway,
    required this.appointmentRepository,
    required this.businessContentRepository,
    required this.workNotesRepository,
    required this.userSettingsRepository,
  });

  final AuthGateway authGateway;
  final AppointmentRepository appointmentRepository;
  final BusinessContentRepository businessContentRepository;
  final WorkNotesRepository workNotesRepository;
  final UserSettingsRepository userSettingsRepository;

  @override
  State<BookServiceApp> createState() => _BookServiceAppState();
}

class _BookServiceAppState extends State<BookServiceApp> {
  ThemeMode _themeMode = UserSettings.defaults.themeMode;
  bool _isLeftHanded = UserSettings.defaults.isLeftHanded;
  AuthState _authState = const AuthState.signedOut();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<UserSettings>? _settingsSubscription;
  // The account the settings subscription belongs to; null while signed out.
  String? _settingsUserId;

  @override
  void initState() {
    super.initState();
    _authState = widget.authGateway.currentState;
    _watchUserSettings(_authState.userId);
    _authSubscription = widget.authGateway.authStateChanges.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _authState = value;
        // Adopting the new account's layout happens before the frame builds,
        // so one user's theme never flashes inside another user's session.
        _watchUserSettings(value.userId);
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }

  /// Follows the signed-in account's saved layout. Signed-out visitors get the
  /// defaults for the session and nothing is written for them.
  void _watchUserSettings(String? userId) {
    if (userId == _settingsUserId) {
      return;
    }
    _settingsUserId = userId;
    _settingsSubscription?.cancel();
    _settingsSubscription = null;

    // Start from the defaults until the account's settings arrive; a new
    // account has no document yet, so it stays right-handed in system mode.
    _themeMode = UserSettings.defaults.themeMode;
    _isLeftHanded = UserSettings.defaults.isLeftHanded;
    if (userId == null) {
      return;
    }

    _settingsSubscription = widget.userSettingsRepository
        .watchUserSettings(userId: userId)
        .listen((settings) {
          if (!mounted) {
            return;
          }
          setState(() {
            _themeMode = settings.themeMode;
            _isLeftHanded = settings.isLeftHanded;
          });
        });
  }

  void _toggleTheme(bool isCurrentlyDark) {
    setState(() {
      _themeMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    });
    _saveUserSettings();
  }

  void _toggleHandedness() {
    setState(() => _isLeftHanded = !_isLeftHanded);
    _saveUserSettings();
  }

  /// Writes the current layout to the signed-in account. Signed-out visitors
  /// keep it for the session only.
  void _saveUserSettings() {
    final userId = _settingsUserId;
    if (userId == null) {
      return;
    }
    unawaited(_writeUserSettings(userId));
  }

  Future<void> _writeUserSettings(String userId) async {
    try {
      await widget.userSettingsRepository.saveUserSettings(
        userId: userId,
        settings: UserSettings(
          isLeftHanded: _isLeftHanded,
          themeMode: _themeMode,
        ),
      );
    } catch (_) {
      // A failed write only costs the preference on the next launch; the
      // session already shows the new value and must not break on it.
    }
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
        workNotesRepository: widget.workNotesRepository,
        isLeftHanded: _isLeftHanded,
        onToggleHandedness: _toggleHandedness,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
