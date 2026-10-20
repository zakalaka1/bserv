import 'package:flutter/material.dart';

import '../data/appointments/appointment_repository.dart';
import '../data/content/business_content_repository.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/auth/admin_login_screen.dart';
import '../features/booking/blockoff_time_screen.dart';
import '../features/booking/booking_calendar_screen.dart';
import '../features/booking/customer_details_screen.dart';
import '../features/booking/latest_appointment_screen.dart';
import '../features/service_area/service_area_map.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_gateway.dart';

enum _ShellMenuAction { adminLogin, adminLogout, review, blockOff, eula, info }

class BookServiceShell extends StatefulWidget {
  const BookServiceShell({
    super.key,
    required this.isAuthenticated,
    required this.isAdminLoggedIn,
    required this.authGateway,
    required this.appointmentRepository,
    required this.businessContentRepository,
    required this.isLeftHanded,
    required this.onToggleHandedness,
    required this.onToggleTheme,
  });

  final bool isAdminLoggedIn;
  final bool isAuthenticated;
  final AuthGateway authGateway;
  final AppointmentRepository appointmentRepository;
  final BusinessContentRepository businessContentRepository;
  final bool isLeftHanded;
  final VoidCallback onToggleHandedness;
  final ValueChanged<bool> onToggleTheme;

  @override
  State<BookServiceShell> createState() => _BookServiceShellState();
}

class _BookServiceShellState extends State<BookServiceShell> {
  final _bookTabKey = GlobalKey<BookTabScreenState>();
  int _selectedIndex = 1;
  int _loginReturnIndex = 1;
  bool _showAdminLogin = false;
  bool _showBlockoffScreen = false;
  // Created once so rebuilds don't resubscribe to Firestore.
  late final _blockedOffTimes = widget.appointmentRepository
      .watchBlockedOffTimes();
  late final _bookedSlots = widget.appointmentRepository.watchBookedSlots();
  bool _showCustomerDetails = false;

  String _menuActionLabel(
    AppLocalizations localizations,
    _ShellMenuAction action,
  ) {
    return switch (action) {
      _ShellMenuAction.adminLogin =>
        widget.isAdminLoggedIn
            ? localizations.adminLogoutMenu
            : localizations.adminLoginMenu,
      _ShellMenuAction.adminLogout => localizations.adminLogoutMenu,
      _ShellMenuAction.review => localizations.review,
      _ShellMenuAction.blockOff => localizations.blockOff,
      _ShellMenuAction.eula => localizations.eula,
      _ShellMenuAction.info => localizations.info,
    };
  }

  IconData _menuActionIcon(_ShellMenuAction action) {
    return switch (action) {
      _ShellMenuAction.adminLogin => Icons.admin_panel_settings_outlined,
      _ShellMenuAction.adminLogout => Icons.logout,
      _ShellMenuAction.review => Icons.event_note_outlined,
      _ShellMenuAction.blockOff => Icons.event_busy_outlined,
      _ShellMenuAction.eula => Icons.description_outlined,
      _ShellMenuAction.info => Icons.info_outline,
    };
  }

  void _showMenuActionDialog(
    AppLocalizations localizations,
    _ShellMenuAction action,
  ) {
    final label = _menuActionLabel(localizations, action);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: Text(localizations.menuActionComingSoon(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowMenu(AppLocalizations localizations) {
    final menuController = MenuController();
    final actions = [
      widget.isAdminLoggedIn
          ? _ShellMenuAction.adminLogout
          : _ShellMenuAction.adminLogin,
      if (widget.isAdminLoggedIn) ...[
        _ShellMenuAction.review,
        _ShellMenuAction.blockOff,
      ],
      _ShellMenuAction.eula,
      _ShellMenuAction.info,
    ];

    return MenuAnchor(
      controller: menuController,
      menuChildren: actions
          .map(
            (action) => MenuItemButton(
              key: ValueKey('menu-item-${action.name}'),
              leadingIcon: Icon(_menuActionIcon(action)),
              onPressed: () {
                menuController.close();
                if (action == _ShellMenuAction.adminLogin) {
                  setState(() => _showAdminLogin = true);
                } else if (action == _ShellMenuAction.adminLogout) {
                  widget.authGateway.signOut().catchError((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localizations.signInFailed)),
                      );
                    }
                  });
                } else if (action == _ShellMenuAction.blockOff) {
                  setState(() => _showBlockoffScreen = true);
                } else {
                  _showMenuActionDialog(localizations, action);
                }
              },
              child: Text(_menuActionLabel(localizations, action)),
            ),
          )
          .toList(),
      builder: (context, controller, child) => IconButton(
        key: const ValueKey('overflow-menu'),
        tooltip: localizations.moreOptions,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_vert),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final titles = [
      localizations.announcements,
      localizations.book,
      localizations.latestAppointment,
      localizations.login,
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _showAdminLogin
        ? localizations.adminLoginMenu
        : _showBlockoffScreen
        ? localizations.blockOffTitle
        : _showCustomerDetails
        ? localizations.book
        : titles[_selectedIndex];
    final showBack =
        _showAdminLogin || _showBlockoffScreen || _showCustomerDetails;

    // IndexedStack keeps each tab's state while the shared app bars stay fixed.
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !showBack,
        leading: _showAdminLogin
            ? IconButton(
                key: const ValueKey('admin-login-back'),
                tooltip: localizations.cancel,
                onPressed: _leaveAdminLogin,
                icon: const Icon(Icons.arrow_back),
              )
            : _showBlockoffScreen
            ? IconButton(
                key: const ValueKey('blockoff-screen-back'),
                tooltip: localizations.back,
                onPressed: _leaveBlockoffScreen,
                icon: const Icon(Icons.arrow_back),
              )
            : _showCustomerDetails
            ? IconButton(
                key: const ValueKey('customer-details-appbar-back'),
                tooltip: localizations.back,
                onPressed: _bookTabKey.currentState?.leaveCustomerDetails,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(title),
        actions: [
          _buildOverflowMenu(localizations),
          IconButton(
            key: const ValueKey('handedness-toggle'),
            tooltip: widget.isLeftHanded
                ? localizations.switchToRightHandedLayout
                : localizations.switchToLeftHandedLayout,
            isSelected: widget.isLeftHanded,
            onPressed: widget.onToggleHandedness,
            icon: const Icon(Icons.swipe_right_outlined),
            selectedIcon: const Icon(Icons.swipe_left_outlined),
          ),
          IconButton(
            key: const ValueKey('theme-toggle'),
            tooltip: isDark
                ? localizations.switchToLightTheme
                : localizations.switchToDarkTheme,
            isSelected: isDark,
            onPressed: () => widget.onToggleTheme(isDark),
            icon: const Icon(Icons.dark_mode_outlined),
            selectedIcon: const Icon(Icons.light_mode_outlined),
          ),
        ],
      ),
      body: _showAdminLogin
          ? AdminLoginScreen(
              authGateway: widget.authGateway,
              onCancel: _leaveAdminLogin,
              onAdminLoginComplete: _onAdminLoginComplete,
            )
          : _showBlockoffScreen
          ? BlockoffTimeScreen(
              blockedOffTimes: _blockedOffTimes,
              bookedSlots: _bookedSlots,
              onSave: (date, block, unblock) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await widget.appointmentRepository.updateBlockedOffTimes(
                    date,
                    block: block,
                    unblock: unblock,
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text(localizations.blockOffSaved)),
                  );
                } catch (_) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(localizations.blockOffSaveFailed)),
                  );
                }
              },
            )
          : IndexedStack(
              index: _selectedIndex,
              children: [
                AnnouncementsScreen(
                  isAdmin: widget.isAdminLoggedIn,
                  contentRepository: widget.businessContentRepository,
                ),
                BookTabScreen(
                  key: _bookTabKey,
                  isAuthenticated: widget.isAuthenticated,
                  onLoginRequested: () => _showLogin(returnIndex: 1),
                  appointmentRepository: widget.appointmentRepository,
                  onCustomerDetailsVisibilityChanged: (visible) =>
                      setState(() => _showCustomerDetails = visible),
                  onBooked: _onBookingComplete,
                ),
                LatestAppointmentScreen(
                  isAuthenticated: widget.isAuthenticated,
                  appointmentRepository: widget.appointmentRepository,
                  onLoginRequested: () => _showLogin(returnIndex: 2),
                  onBookRequested: _showBook,
                ),
                LoginTabScreen(
                  isAuthenticated: widget.isAuthenticated,
                  authGateway: widget.authGateway,
                  onCancel: _showBook,
                  onSignInComplete: _returnFromLogin,
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            key: const ValueKey('nav-announcements'),
            icon: const Icon(Icons.campaign_outlined),
            selectedIcon: const Icon(Icons.campaign),
            label: localizations.announcements,
          ),
          NavigationDestination(
            key: const ValueKey('nav-book'),
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: localizations.book,
          ),
          NavigationDestination(
            key: const ValueKey('nav-latest'),
            icon: const Icon(Icons.event_note_outlined),
            selectedIcon: const Icon(Icons.event_note),
            label: localizations.latest,
          ),
          NavigationDestination(
            key: const ValueKey('nav-login'),
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: localizations.login,
          ),
        ],
      ),
    );
  }

  void _showLogin({required int returnIndex}) {
    setState(() {
      _loginReturnIndex = returnIndex;
      _selectedIndex = 3;
    });
  }

  void _returnFromLogin() {
    setState(() => _selectedIndex = _loginReturnIndex);
  }

  void _showBook() {
    setState(() => _selectedIndex = 1);
  }

  void _leaveAdminLogin() {
    setState(() => _showAdminLogin = false);
  }

  void _leaveBlockoffScreen() {
    setState(() => _showBlockoffScreen = false);
  }

  void _onAdminLoginComplete() {
    setState(() {
      _showAdminLogin = false;
      _selectedIndex = 1;
    });
  }

  void _onBookingComplete() {
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    setState(() {
      _showCustomerDetails = false;
      _selectedIndex = 1;
    });
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.bookedSuccessfully,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }
}

class BookTabScreen extends StatefulWidget {
  const BookTabScreen({
    super.key,
    required this.isAuthenticated,
    required this.onLoginRequested,
    required this.appointmentRepository,
    required this.onCustomerDetailsVisibilityChanged,
    required this.onBooked,
  });

  final bool isAuthenticated;
  final VoidCallback onLoginRequested;
  final AppointmentRepository appointmentRepository;
  final ValueChanged<bool> onCustomerDetailsVisibilityChanged;
  final VoidCallback onBooked;

  @override
  State<BookTabScreen> createState() => BookTabScreenState();
}

class BookTabScreenState extends State<BookTabScreen> {
  ServiceArea? _selectedArea;
  bool _showCalendar = false;
  bool _showCustomerDetails = false;
  DateTime? _appointmentDate;
  String? _appointmentTimeSlot;
  // Created once so rebuilds don't resubscribe to Firestore.
  late final _bookedSlots = widget.appointmentRepository.watchBookedSlots();
  void _continueToBooking(ServiceArea area) {
    if (!widget.isAuthenticated) {
      widget.onLoginRequested();
      return;
    }
    setState(() {
      _selectedArea = area;
      _showCalendar = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showCustomerDetails &&
        _selectedArea != null &&
        _appointmentDate != null &&
        _appointmentTimeSlot != null) {
      return CustomerDetailsScreen(
        serviceArea: _selectedArea!,
        appointmentDate: _appointmentDate!,
        timeSlot: _appointmentTimeSlot!,
        onBook: (draft) async {
          await widget.appointmentRepository.createAppointment(draft);
          _book();
        },
      );
    }

    if (_showCalendar && _selectedArea != null) {
      return BookingCalendarScreen(
        serviceArea: _selectedArea!,
        bookedSlots: _bookedSlots,
        initialDate: _appointmentDate,
        initialTimeSlot: _appointmentTimeSlot,
        onBack: () => setState(() => _showCalendar = false),
        onContinue: (date, slot) => setState(() {
          _appointmentDate = date;
          _appointmentTimeSlot = slot;
          _showCustomerDetails = true;
          widget.onCustomerDetailsVisibilityChanged(true);
        }),
      );
    }

    return ServiceAreaMap(
      selectedArea: _selectedArea,
      onAreaSelected: (area) => setState(() => _selectedArea = area),
      onContinue: _continueToBooking,
    );
  }

  void leaveCustomerDetails() {
    setState(() => _showCustomerDetails = false);
    widget.onCustomerDetailsVisibilityChanged(false);
  }

  void _book() {
    setState(() {
      _showCustomerDetails = false;
      _showCalendar = false;
      _selectedArea = null;
      _appointmentDate = null;
      _appointmentTimeSlot = null;
    });
    widget.onCustomerDetailsVisibilityChanged(false);
    widget.onBooked();
  }
}

class LoginTabScreen extends StatefulWidget {
  const LoginTabScreen({
    super.key,
    required this.isAuthenticated,
    required this.authGateway,
    required this.onCancel,
    required this.onSignInComplete,
  });

  final bool isAuthenticated;
  final AuthGateway authGateway;
  final VoidCallback onCancel;
  final VoidCallback onSignInComplete;

  @override
  State<LoginTabScreen> createState() => _LoginTabScreenState();
}

class _LoginTabScreenState extends State<LoginTabScreen> {
  bool _isSigningIn = false;

  Future<void> _runAuthOperation(Future<void> Function() operation) async {
    setState(() => _isSigningIn = true);
    try {
      await operation();
      if (mounted && !widget.isAuthenticated) {
        widget.onSignInComplete();
      }
    } catch (_) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(localizations.signInFailed)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isAuthenticated
                      ? localizations.signedIn
                      : localizations.signInToContinue,
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isAuthenticated
                      ? localizations.accountReady
                      : localizations.providerSignInOnly,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                if (!widget.isAuthenticated) ...[
                  const SizedBox(height: 8),
                  Text(
                    localizations.providerDataPrivacy,
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                if (!widget.isAuthenticated) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('sign-in-google'),
                    onPressed: _isSigningIn
                        ? null
                        : () => _runAuthOperation(
                            widget.authGateway.signInWithGoogle,
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: _isSigningIn
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata),
                    label: Text(
                      _isSigningIn
                          ? localizations.signingIn
                          : localizations.loginWithGoogle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('sign-in-facebook'),
                    onPressed: _isSigningIn
                        ? null
                        : () => _runAuthOperation(
                            widget.authGateway.signInWithFacebook,
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: _isSigningIn
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.facebook),
                    label: Text(
                      _isSigningIn
                          ? localizations.signingIn
                          : localizations.loginWithFacebook,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  OutlinedButton.icon(
                    key: const ValueKey('sign-out'),
                    onPressed: _isSigningIn
                        ? null
                        : () => _runAuthOperation(widget.authGateway.signOut),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(localizations.signOut),
                  ),
                  const SizedBox(height: 12),
                ],
                TextButton(
                  key: const ValueKey('login-cancel'),
                  onPressed: _isSigningIn ? null : widget.onCancel,
                  child: Text(localizations.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
