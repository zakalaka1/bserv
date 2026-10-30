import 'dart:async';

import 'package:flutter/material.dart';

import '../data/appointments/appointment_repository.dart';
import '../data/content/business_content_repository.dart';
import '../data/content/work_notes_repository.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/auth/admin_login_screen.dart';
import '../features/booking/blockoff_time_screen.dart';
import '../features/booking/booking_calendar_screen.dart';
import '../features/booking/customer_details_screen.dart';
import '../features/booking/latest_appointment_screen.dart';
import '../features/review/review_booking_details_screen.dart';
import '../features/review/review_bookings_screen.dart';
import '../features/service_area/service_area_map.dart';
import '../features/worknotes/worknotes_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_gateway.dart';

enum _ShellMenuAction {
  adminLogin,
  adminLogout,
  review,
  blockOff,
  workNotes,
  eula,
  info,
}

/// The step the Book tab is showing; the shell mirrors it so the shared app bar
/// can title the screen and offer a matching back arrow.
enum BookTabStep { serviceArea, calendar, customerDetails }

class BookServiceShell extends StatefulWidget {
  const BookServiceShell({
    super.key,
    required this.isAuthenticated,
    required this.isAdminLoggedIn,
    required this.authGateway,
    required this.appointmentRepository,
    required this.businessContentRepository,
    required this.workNotesRepository,
    required this.isLeftHanded,
    required this.onToggleHandedness,
    required this.onToggleTheme,
  });

  final bool isAdminLoggedIn;
  final bool isAuthenticated;
  final AuthGateway authGateway;
  final AppointmentRepository appointmentRepository;
  final BusinessContentRepository businessContentRepository;
  final WorkNotesRepository workNotesRepository;
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
  bool _showReviewScreen = false;
  bool _showReviewDetailsScreen = false;
  // The day the review screens show; null means "today".
  DateTime? _reviewDate;
  // Created once so rebuilds don't resubscribe to Firestore. The review,
  // review details and block-off screens all read the same queries, and they
  // hand over within a single frame, so the queries are fanned out instead of
  // being listened to directly by each screen.
  _SharedQuery<List<BlockedOffTime>>? _blockedOffTimesQuery;
  _SharedQuery<List<BookedSlot>>? _bookedSlotsQuery;
  bool _showWorkNotes = false;
  BookTabStep _bookingStep = BookTabStep.serviceArea;

  Stream<List<BlockedOffTime>> get _blockedOffTimes => _blockedOffTimesQuery ??=
      _SharedQuery(widget.appointmentRepository.watchBlockedOffTimes());

  Stream<List<BookedSlot>> get _bookedSlots => _bookedSlotsQuery ??=
      _SharedQuery(widget.appointmentRepository.watchBookedSlots());

  @override
  void dispose() {
    _blockedOffTimesQuery?.dispose();
    _bookedSlotsQuery?.dispose();
    super.dispose();
  }

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
      _ShellMenuAction.workNotes => localizations.workNotes,
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
      _ShellMenuAction.workNotes => Icons.work_outline,
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
        _ShellMenuAction.workNotes,
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
                  widget.authGateway
                      .signOut()
                      .then((_) {
                        if (!mounted) return;
                        setState(() {
                          // Logging out returns the admin to the public landing
                          // screen and clears any admin-only overlay.
                          _showBlockoffScreen = false;
                          _showReviewScreen = false;
                          _showReviewDetailsScreen = false;
                          _showWorkNotes = false;
                          _reviewDate = null;
                          _selectedIndex = 1;
                        });
                      })
                      .catchError((_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(localizations.signInFailed)),
                          );
                        }
                      });
                } else if (action == _ShellMenuAction.review) {
                  setState(() {
                    _reviewDate = null;
                    _showReviewDetailsScreen = false;
                    _showBlockoffScreen = false;
                    _showWorkNotes = false;
                    _showReviewScreen = true;
                  });
                } else if (action == _ShellMenuAction.blockOff) {
                  setState(() {
                    _showReviewDetailsScreen = false;
                    _showReviewScreen = false;
                    _showWorkNotes = false;
                    _showBlockoffScreen = true;
                  });
                } else if (action == _ShellMenuAction.workNotes) {
                  setState(() {
                    _showReviewDetailsScreen = false;
                    _showReviewScreen = false;
                    _showBlockoffScreen = false;
                    _showWorkNotes = true;
                  });
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

  /// The app-bar controls in their right-handed order. Left-handed users get
  /// them mirrored into the leading slot on every screen.
  List<Widget> _buildAppBarControls(
    AppLocalizations localizations,
    bool isDark,
  ) {
    return <Widget>[
      _buildOverflowMenu(localizations),
      IconButton(
        key: const ValueKey('handedness-toggle'),
        tooltip: widget.isLeftHanded
            ? localizations.switchToRightHandedLayout
            : localizations.switchToLeftHandedLayout,
        isSelected: widget.isLeftHanded,
        onPressed: widget.onToggleHandedness,
        icon: const Icon(Icons.front_hand_rounded),
        selectedIcon: const Icon(Icons.back_hand_rounded),
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
    ];
  }

  /// The app-bar back arrow, or null when the current screen has no history to
  /// go back to. It joins the app-bar control cluster, innermost so it sits
  /// right beside the title and the other controls follow it.
  Widget? _buildAppBarBackButton(AppLocalizations localizations) {
    if (_showAdminLogin) {
      return IconButton(
        key: const ValueKey('admin-login-back'),
        tooltip: localizations.cancel,
        onPressed: _leaveAdminLogin,
        icon: const Icon(Icons.arrow_back),
      );
    }
    if (_showWorkNotes) {
      return IconButton(
        key: const ValueKey('work-notes-back'),
        tooltip: localizations.back,
        onPressed: _leaveWorkNotes,
        icon: const Icon(Icons.arrow_back),
      );
    }
    if (_showReviewDetailsScreen) {
      return IconButton(
        key: const ValueKey('review-details-back'),
        tooltip: localizations.back,
        onPressed: _leaveReviewDetailsScreen,
        icon: const Icon(Icons.arrow_back),
      );
    }
    if (_selectedIndex != 1) {
      return null;
    }
    return switch (_bookingStep) {
      BookTabStep.customerDetails => IconButton(
        key: const ValueKey('customer-details-appbar-back'),
        tooltip: localizations.back,
        onPressed: _bookTabKey.currentState?.leaveCustomerDetails,
        icon: const Icon(Icons.arrow_back),
      ),
      BookTabStep.calendar => IconButton(
        key: const ValueKey('booking-calendar-appbar-back'),
        tooltip: localizations.back,
        onPressed: _bookTabKey.currentState?.leaveCalendar,
        icon: const Icon(Icons.arrow_back),
      ),
      BookTabStep.serviceArea => null,
    };
  }

  /// The centered app-bar title. It fills the space beside the control cluster
  /// and centers itself there, so every screen keeps its title clear of both
  /// the edge and the controls, with or without a back arrow.
  Widget _buildAppBarTitle(String title) {
    return Center(
      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  /// The company logo on the landing screen, centered in the title slot. The
  /// light and dark assets are the same mark tuned for each theme.
  Widget _buildAppBarLogo(bool isDark) {
    return Center(
      child: Image.asset(
        isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
        key: const ValueKey('company-logo'),
        height: 40,
        fit: BoxFit.contain,
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
        : _showWorkNotes
        ? localizations.workNotes
        : _showBlockoffScreen
        ? localizations.blockOffTitle
        : _showReviewDetailsScreen || _showReviewScreen
        ? localizations.reviewBookings
        : _selectedIndex == 1 && _bookingStep != BookTabStep.serviceArea
        ? localizations.bookingDetails
        : _selectedIndex == 1
        // The landing screen shows the company logo instead of a heading.
        ? ''
        : titles[_selectedIndex];
    // The service-area map is the landing screen, so it shows the logo in place
    // of a title. Overlays reuse the selected tab, so they take precedence.
    final onLandingScreen =
        !_showAdminLogin &&
        !_showWorkNotes &&
        !_showBlockoffScreen &&
        !_showReviewScreen &&
        !_showReviewDetailsScreen &&
        _selectedIndex == 1 &&
        _bookingStep == BookTabStep.serviceArea;
    final controls = _buildAppBarControls(localizations, isDark);
    final backButton = _buildAppBarBackButton(localizations);
    // The back arrow belongs to the control cluster, innermost so it sits right
    // beside the title, with the three controls keeping their usual order
    // behind it. Left-handed users get the whole cluster mirrored onto the
    // leading edge, so everything stays under one thumb. The title centers in
    // the clear space beside the cluster.
    final controlsWithBack = <Widget>[?backButton, ...controls];
    final mirrored = widget.isLeftHanded;

    // IndexedStack keeps each tab's state while the shared app bars stay fixed.
    return Scaffold(
      appBar: AppBar(
        // The shell owns every leading widget, so Flutter must not add one.
        automaticallyImplyLeading: false,
        // The title widget fills the open space beside the control cluster and
        // centers itself there. The toolbar must not center it as well: with
        // one cluster on a single edge, that would clamp wide titles against
        // the controls instead of centering them.
        centerTitle: false,
        leadingWidth: mirrored
            ? controlsWithBack.length * kMinInteractiveDimension
            : null,
        leading: mirrored
            ? Row(children: controlsWithBack.reversed.toList())
            : null,
        titleSpacing: mirrored ? 8 : null,
        title: onLandingScreen
            ? _buildAppBarLogo(isDark)
            : _buildAppBarTitle(title),
        actions: mirrored ? null : controlsWithBack,
      ),
      body: _showAdminLogin
          ? AdminLoginScreen(
              authGateway: widget.authGateway,
              onCancel: _leaveAdminLogin,
              onAdminLoginComplete: _onAdminLoginComplete,
            )
          : _showWorkNotes
          ? WorkNotesScreen(repository: widget.workNotesRepository)
          : _showReviewDetailsScreen
          ? ReviewBookingDetailsScreen(
              date: _reviewDate ?? DateUtils.dateOnly(DateTime.now()),
              onDateChanged: (date) => setState(() => _reviewDate = date),
              appointmentRepository: widget.appointmentRepository,
              blockedOffTimes: _blockedOffTimes,
            )
          : _showReviewScreen
          ? ReviewBookingsScreen(
              blockedOffTimes: _blockedOffTimes,
              bookedSlots: _bookedSlots,
              initialDate: _reviewDate,
              isLeftHanded: widget.isLeftHanded,
              onOpenDetails: (date, _) => setState(() {
                _reviewDate = date;
                _showReviewDetailsScreen = true;
              }),
            )
          : _showBlockoffScreen
          ? BlockoffTimeScreen(
              blockedOffTimes: _blockedOffTimes,
              bookedSlots: _bookedSlots,
              isLeftHanded: widget.isLeftHanded,
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
                  onStepChanged: (step) => setState(() => _bookingStep = step),
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
      bottomNavigationBar: _buildNavigationBar(localizations),
    );
  }

  /// The nav bar stays visible under admin overlays but drops its selected
  /// highlight, because those overlays are not tabs.
  Widget _buildNavigationBar(AppLocalizations localizations) {
    final overlayVisible =
        _showAdminLogin ||
        _showWorkNotes ||
        _showReviewScreen ||
        _showReviewDetailsScreen ||
        _showBlockoffScreen;
    final colorScheme = Theme.of(context).colorScheme;
    final unselectedLabelStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: colorScheme.onSurfaceVariant);
    final navigationBar = NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() {
        _selectedIndex = index;
        // Choosing a tab leaves any full-screen overlay (review, review
        // details, block-off, admin login, or work notes) so the nav bar
        // navigates exactly as it does on every other screen.
        _showReviewDetailsScreen = false;
        _showReviewScreen = false;
        _reviewDate = null;
        _showBlockoffScreen = false;
        _showWorkNotes = false;
        _showAdminLogin = false;
      }),
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
    );

    if (!overlayVisible) return navigationBar;

    // Clear the selected pill and the selected (filled) icon and label colours.
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: colorScheme.onSurfaceVariant),
        ),
        labelTextStyle: WidgetStatePropertyAll(unselectedLabelStyle),
      ),
      child: navigationBar,
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

  void _leaveWorkNotes() {
    setState(() => _showWorkNotes = false);
  }

  void _leaveReviewDetailsScreen() {
    // The details screen hands its date back, so the overview reopens on the
    // day the admin was last looking at.
    setState(() => _showReviewDetailsScreen = false);
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
      _bookingStep = BookTabStep.serviceArea;
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
    required this.onStepChanged,
    required this.onBooked,
  });

  final bool isAuthenticated;
  final VoidCallback onLoginRequested;
  final AppointmentRepository appointmentRepository;
  final ValueChanged<BookTabStep> onStepChanged;
  final VoidCallback onBooked;

  @override
  State<BookTabScreen> createState() => BookTabScreenState();
}

class BookTabScreenState extends State<BookTabScreen> {
  ServiceArea? _selectedArea;
  ServiceType? _serviceType;
  bool _showCalendar = false;
  bool _showCustomerDetails = false;
  DateTime? _appointmentDate;
  String? _appointmentTimeSlot;
  // Created once so rebuilds don't resubscribe to Firestore. The calendar can be
  // left and reopened, and the query under it is single-subscription, so it is
  // shared: listening to it directly a second time would throw "Stream has
  // already been listened to".
  _SharedQuery<List<BookedSlot>>? _bookedSlotsQuery;

  Stream<List<BookedSlot>> get _bookedSlots => _bookedSlotsQuery ??=
      _SharedQuery(widget.appointmentRepository.watchBookedSlots());

  @override
  void dispose() {
    _bookedSlotsQuery?.dispose();
    super.dispose();
  }

  void _continueToBooking(ServiceArea area, ServiceType serviceType) {
    if (!widget.isAuthenticated) {
      widget.onLoginRequested();
      return;
    }
    setState(() {
      _selectedArea = area;
      _serviceType = serviceType;
      _showCalendar = true;
    });
    widget.onStepChanged(BookTabStep.calendar);
  }

  @override
  Widget build(BuildContext context) {
    if (_showCustomerDetails &&
        _selectedArea != null &&
        _serviceType != null &&
        _appointmentDate != null &&
        _appointmentTimeSlot != null) {
      return CustomerDetailsScreen(
        serviceArea: _selectedArea!,
        serviceType: _serviceType!,
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
        onContinue: (date, slot) {
          setState(() {
            _appointmentDate = date;
            _appointmentTimeSlot = slot;
            _showCustomerDetails = true;
          });
          widget.onStepChanged(BookTabStep.customerDetails);
        },
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
    widget.onStepChanged(BookTabStep.calendar);
  }

  void leaveCalendar() {
    setState(() => _showCalendar = false);
    widget.onStepChanged(BookTabStep.serviceArea);
  }

  void _book() {
    setState(() {
      _showCustomerDetails = false;
      _showCalendar = false;
      _selectedArea = null;
      _serviceType = null;
      _appointmentDate = null;
      _appointmentTimeSlot = null;
    });
    widget.onStepChanged(BookTabStep.serviceArea);
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

/// A [Stream] that several screens can listen to at once, replaying the latest
/// value to listeners that arrive later.
///
/// The shell shares the blocked-off and booked-slot queries with the review
/// overview, the review details page and the block-off screen. Those queries
/// are single-subscription Firestore streams, and a screen hands over to the
/// next one inside a single frame (the outgoing element only cancels its
/// subscription once the frame ends), so letting each screen listen to the
/// query directly throws "Stream has already been listened to". Subscribing
/// once here keeps the query alive for the shell's lifetime and fans its
/// snapshots out to every screen instead.
class _SharedQuery<T> extends Stream<T> {
  _SharedQuery(Stream<T> source) {
    _subscription = source.listen(
      (value) {
        _latest = value;
        _hasLatest = true;
        _controller.add(value);
      },
      onError: _controller.addError,
      // The source completing is not the same as the shared query being done:
      // a query that finishes (or is replaced) must still hand its last
      // snapshot to screens that open later, so only [dispose] closes the
      // broadcast controller.
    );
  }

  final StreamController<T> _controller = StreamController<T>.broadcast();
  late final StreamSubscription<T> _subscription;
  T? _latest;
  bool _hasLatest = false;

  /// One stream per listener: the latest snapshot it missed (if any), then
  /// every snapshot that follows.
  late final Stream<T> _perListener = Stream<T>.multi((controller) {
    var cancelled = false;
    final subscription = _controller.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = () {
      cancelled = true;
      return subscription.cancel();
    };
    if (_hasLatest) {
      final latest = _latest as T;
      // Replay asynchronously: listeners are usually StreamBuilders that
      // subscribe from initState, and an event delivered synchronously would
      // rebuild the tree while it is still being built.
      scheduleMicrotask(() {
        if (!cancelled && !controller.isClosed) controller.add(latest);
      });
    }
  });

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _perListener.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Releases the single subscription to the underlying query.
  Future<void> dispose() async {
    await _controller.close();
    await _subscription.cancel();
  }
}
