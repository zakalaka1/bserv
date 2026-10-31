import 'package:bserv/app/app_config.dart';
import 'package:bserv/app/book_service_app.dart';
import 'package:bserv/data/appointments/appointment_repository.dart';
import 'package:bserv/data/content/business_content_repository.dart';
import 'package:bserv/data/content/work_notes_repository.dart';
import 'package:bserv/data/user/user_settings_repository.dart';
import 'package:bserv/services/auth_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bserv/features/booking/customer_details_screen.dart';
import 'package:bserv/features/booking/blockoff_time_screen.dart';
import 'package:bserv/features/service_area/service_area_map.dart';

import 'dart:async';

/// The id `_TestAuthGateway` reports for every signed-in test user.
const _testUserId = 'test-user-uid';

class _TestAuthGateway implements AuthGateway {
  _TestAuthGateway({
    this.adminClaim = false,
    bool startAsAdmin = false,
    bool startAsAuthenticated = false,
    this.adminSignInError,
    String? userId,
  }) : userId = userId ?? _testUserId,
       _state = AuthState(
         isAuthenticated: startAsAdmin || startAsAuthenticated,
         isAdmin: startAsAdmin,
         userId: startAsAdmin || startAsAuthenticated
             ? userId ?? _testUserId
             : null,
       );

  final bool adminClaim;
  final Object? adminSignInError;
  final String userId;
  AuthState _state;
  final _authStateController = StreamController<AuthState>.broadcast();

  @override
  AuthState get currentState => _state;

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  Future<void> signInWithGoogle() async => _setAuthenticated(true);

  @override
  Future<void> signInWithFacebook() async => _setAuthenticated(true);

  @override
  Future<bool> signInAsAdmin({
    required String email,
    required String password,
  }) async {
    if (adminSignInError case final error?) {
      throw error;
    }
    if (!adminClaim) {
      await _setAuthenticated(false);
      return false;
    }
    await _setAuthenticated(true, isAdmin: true);
    return true;
  }

  @override
  Future<void> signOut() async => _setAuthenticated(false);

  Future<void> _setAuthenticated(bool value, {bool isAdmin = false}) async {
    _state = AuthState(
      isAuthenticated: value,
      isAdmin: value && isAdmin,
      userId: value ? userId : null,
    );
    _authStateController.add(_state);
  }

  Future<void> dispose() => _authStateController.close();
}

class _TestAppointmentRepository implements AppointmentRepository {
  _TestAppointmentRepository({
    this.latestAppointment,
    List<BlockedOffTime> blockedOffTimes = const [],
    List<AppointmentRecord> appointments = const [],
    this.updateError,
  }) : _blocked = [...blockedOffTimes],
       _appointments = [...appointments];

  final drafts = <AppointmentDraft>[];
  final AppointmentRecord? latestAppointment;
  final Object? updateError;
  final List<BlockedOffTime> _blocked;
  final bookedSlots = <BookedSlot>[];
  final List<AppointmentRecord> _appointments;
  final statusUpdates = <({String appointmentId, String status})>[];
  final noteUpdates = <({String appointmentId, String note})>[];
  final cancelledAppointments = <String>[];
  final photoUrlRequests = <String>[];
  final appointmentUpdates =
      <
        ({
          String appointmentId,
          String? customerName,
          String? issueDescription,
          XFile? photo,
        })
      >[];
  final blockedOffUpdates =
      <({DateTime date, Set<String> block, Set<String> unblock})>[];

  @override
  Future<void> createAppointment(AppointmentDraft draft) async {
    drafts.add(draft);
  }

  @override
  Stream<AppointmentRecord?> watchLatestAppointment() =>
      Stream.value(latestAppointment);

  @override
  Stream<List<BookedSlot>> watchBookedSlots() =>
      Stream.value(List.of(bookedSlots));

  @override
  Stream<List<BlockedOffTime>> watchBlockedOffTimes() =>
      Stream.value(List.of(_blocked));

  @override
  Future<void> updateBlockedOffTimes(
    DateTime date, {
    required Set<String> block,
    required Set<String> unblock,
  }) async {
    blockedOffUpdates.add((date: date, block: block, unblock: unblock));
  }

  @override
  Stream<List<AppointmentRecord>> watchAppointmentsByDate(DateTime date) {
    return Stream.value([
      for (final appointment in _appointments)
        if (DateUtils.isSameDay(appointment.appointmentDate, date)) appointment,
    ]);
  }

  @override
  Future<String?> appointmentPhotoUrl(String photoPath) async {
    photoUrlRequests.add(photoPath);
    // Widget tests have no storage bucket; the screen falls back gracefully.
    return null;
  }

  @override
  Future<void> updateAppointmentStatus(
    String appointmentId,
    String status,
  ) async {
    statusUpdates.add((appointmentId: appointmentId, status: status));
  }

  @override
  Future<void> updateAppointmentNote(String appointmentId, String note) async {
    noteUpdates.add((appointmentId: appointmentId, note: note));
  }

  @override
  Future<void> cancelAppointment(AppointmentRecord appointment) async {
    cancelledAppointments.add(appointment.id);
  }

  @override
  Future<void> updateOwnAppointment(
    String appointmentId, {
    String? customerName,
    String? issueDescription,
    XFile? photo,
  }) async {
    if (updateError case final error?) throw error;
    appointmentUpdates.add((
      appointmentId: appointmentId,
      customerName: customerName,
      issueDescription: issueDescription,
      photo: photo,
    ));
  }
}

class _TestBusinessContentRepository implements BusinessContentRepository {
  _TestBusinessContentRepository({
    required String notes,
    required String pricing,
  }) : _content = BusinessContent(notes: notes, pricing: pricing) {
    _contentController.add(_content);
  }

  BusinessContent _content;
  final _contentController = StreamController<BusinessContent>.broadcast();
  BusinessContent? savedContent;

  @override
  Stream<BusinessContent> watchContent({
    required String defaultNotes,
    required String defaultPricing,
  }) async* {
    yield _content;
    yield* _contentController.stream;
  }

  @override
  Future<void> saveContent({
    required String notes,
    required String pricing,
  }) async {
    savedContent = BusinessContent(notes: notes, pricing: pricing);
    _content = savedContent!;
    _contentController.add(_content);
  }

  Future<void> dispose() => _contentController.close();
}

class _TestWorkNotesRepository implements WorkNotesRepository {
  _TestWorkNotesRepository({this.notes = ''});

  String notes;
  final _controller = StreamController<WorkNotes>.broadcast();
  String? savedNotes;

  @override
  Stream<WorkNotes> watchWorkNotes({required String defaultNotes}) async* {
    yield WorkNotes(notes: notes);
    yield* _controller.stream;
  }

  @override
  Future<void> saveWorkNotes(String saved) async {
    savedNotes = saved;
    notes = saved;
    _controller.add(WorkNotes(notes: saved));
  }

  Future<void> dispose() => _controller.close();
}

class _TestUserSettingsRepository implements UserSettingsRepository {
  _TestUserSettingsRepository({Map<String, UserSettings> stored = const {}})
    : _stored = {...stored};

  final Map<String, UserSettings> _stored;
  final List<({String userId, UserSettings settings})> saves = [];

  UserSettings? savedSettingsFor(String userId) => _stored[userId];

  @override
  Stream<UserSettings> watchUserSettings({required String userId}) {
    return Stream.value(_stored[userId] ?? UserSettings.defaults);
  }

  @override
  Future<void> saveUserSettings({
    required String userId,
    required UserSettings settings,
  }) async {
    saves.add((userId: userId, settings: settings));
    _stored[userId] = settings;
  }
}

Future<_TestAuthGateway> _pumpApp(
  WidgetTester tester, {
  bool adminClaim = false,
  bool startAsAdmin = false,
  bool startAsAuthenticated = false,
  Object? adminSignInError,
  AppointmentRepository? appointmentRepository,
  BusinessContentRepository? businessContentRepository,
  WorkNotesRepository? workNotesRepository,
  UserSettingsRepository? userSettingsRepository,
}) async {
  final authGateway = _TestAuthGateway(
    adminClaim: adminClaim,
    startAsAdmin: startAsAdmin,
    startAsAuthenticated: startAsAuthenticated,
    adminSignInError: adminSignInError,
  );
  addTearDown(authGateway.dispose);
  final contentRepository =
      businessContentRepository ??
      _TestBusinessContentRepository(
        notes: 'Service update\n\nWe are updating our service schedule. Please check here for the latest availability.',
        pricing: 'Pricing information will be posted here.',
      );
  if (contentRepository case final _TestBusinessContentRepository repository) {
    addTearDown(repository.dispose);
  }
  final notesRepository = workNotesRepository ?? _TestWorkNotesRepository();
  if (notesRepository case final _TestWorkNotesRepository repository) {
    addTearDown(repository.dispose);
  }
  final settingsRepository =
      userSettingsRepository ?? _TestUserSettingsRepository();
  await tester.pumpWidget(
    BookServiceApp(
      authGateway: authGateway,
      appointmentRepository:
          appointmentRepository ?? _TestAppointmentRepository(),
      businessContentRepository: contentRepository,
      workNotesRepository: notesRepository,
      userSettingsRepository: settingsRepository,
    ),
  );
  return authGateway;
}

/// A date-only working day [workdaysAhead] working days from today.
DateTime _workingDateAhead(int workdaysAhead) {
  var date = DateUtils.dateOnly(DateTime.now());
  var remaining = workdaysAhead;
  while (remaining > 0) {
    date = DateUtils.addDaysToDate(date, 1);
    if (BookingSchedule.workingWeekdays.contains(date.weekday)) {
      remaining--;
    }
  }
  return date;
}

/// The first date on or after [from] whose weekday is not in
/// [BookingSchedule.workingWeekdays]. A valid working week leaves at least one
/// day out, so this is always within the next week.
DateTime _nextNonWorkingDate(DateTime from) {
  var date = DateUtils.dateOnly(from);
  while (BookingSchedule.workingWeekdays.contains(date.weekday)) {
    date = DateUtils.addDaysToDate(date, 1);
  }
  return date;
}

AppointmentRecord _latestAppointment({
  required DateTime appointmentDate,
  String status = 'scheduled',
}) {
  return AppointmentRecord(
    id: 'appointment-789',
    appointmentDate: appointmentDate,
    timeSlot: '1 pm - 3 pm',
    customerName: 'Jordan Customer',
    phone: '416-555-0182',
    streetAddress: '42 Main Street',
    city: 'Toronto',
    postalCode: 'M5V 2T6',
    issueDescription: 'Repair a leaking tap',
    status: status,
    createdAt: DateTime(2026, 10, 20),
  );
}

/// Opens today's morning booking card from the admin Review menu.
Future<void> _openMorningReviewDetails(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('overflow-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('menu-item-review')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('review-details-morning')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Announcements navigation opens the announcement screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-announcements')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('announcements-screen')), findsOneWidget);
    expect(find.text('Notes & Pricing'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('notes-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('pricing-section')), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Pricing'), findsOneWidget);
    expect(find.textContaining('Service update'), findsOneWidget);
    expect(
      find.text('Pricing information will be posted here.'),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final pageScrollController = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(pageScrollController.maxScrollExtent, 0);
    expect(
      tester.getRect(find.byKey(const ValueKey('pricing-section'))).bottom,
      lessThanOrEqualTo(tester.getBottomRight(find.byType(Scaffold)).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('notes-section'))).dy,
      lessThan(100),
    );
    expect(find.byKey(const ValueKey('save-notes-and-pricing')), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('Block-off screen selects a date and multiple time slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);
    DateTime? savedDate;
    Set<String>? blockedSlots;
    Set<String>? unblockedSlots;
    var selectedWeekday = DateUtils.dateOnly(DateTime.now());
    while (!BookingSchedule.workingWeekdays.contains(selectedWeekday.weekday)) {
      selectedWeekday = selectedWeekday.add(const Duration(days: 1));
    }
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: BlockoffTimeScreen(
              blockedOffTimes: Stream.value([
                BlockedOffTime(date: selectedWeekday, timeSlot: '11 am - 1 pm'),
              ]),
              bookedSlots: Stream.value([
                BookedSlot(date: selectedWeekday, timeSlot: '11 am - 1 pm'),
                BookedSlot(date: selectedWeekday, timeSlot: '1 pm - 3 pm'),
              ]),
              onSave: (date, block, unblock) async {
                savedDate = date;
                blockedSlots = block;
                unblockedSlots = unblock;
              },
              isLeftHanded: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final blockButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('block-selected-times')),
    );
    expect(blockButton.onPressed, isNull);
    for (final slot in ['morning', 'midday', 'afternoon', 'evening']) {
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(ValueKey('blockoff-slot-$slot')),
      );
      expect(tile.onChanged, isNull);
    }

    final calendar = tester.widget<CalendarDatePicker>(
      find.byKey(const ValueKey('blockoff-calendar')),
    );
    calendar.onDateChanged(selectedWeekday);
    await tester.pumpAndSettle();

    // Previously blocked slot is pre-checked; nothing to save yet.
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('blockoff-slot-afternoon')),
          )
          .onChanged,
      isNull,
    );
    expect(find.text('Already booked by a customer'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('blockoff-slot-midday')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('block-selected-times')),
          )
          .onPressed,
      isNull,
    );

    // Block morning and evening, unblock midday.
    for (final slot in ['morning', 'evening', 'midday']) {
      await tester.ensureVisible(find.byKey(ValueKey('blockoff-slot-$slot')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('blockoff-slot-$slot')));
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(
      find.byKey(const ValueKey('block-selected-times')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('block-selected-times')));
    await tester.pumpAndSettle();

    expect(savedDate, selectedWeekday);
    expect(blockedSlots, {'9 am - 11 am', '3 pm - 5 pm'});
    expect(unblockedSlots, {'11 am - 1 pm'});
  });

  testWidgets('Latest tab prompts signed-out customers to log in', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Latest Appointment'),
      ),
      findsOneWidget,
    );
    expect(find.text('Latest'), findsOneWidget);
    expect(
      find.text('Sign in to see your latest appointment.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Latest Appointment'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Latest tab offers Book when no appointment exists', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: _TestAppointmentRepository(),
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    expect(find.text("You don't have any appointments yet."), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
  });

  testWidgets('Latest tab shows the newest appointment in any status', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: AppointmentRecord(
        id: 'appointment-123',
        appointmentDate: DateTime(2026, 11, 3),
        timeSlot: '1 pm - 3 pm',
        customerName: 'Jordan Customer',
        phone: '416-555-0182',
        streetAddress: '42 Main Street',
        city: 'Toronto',
        postalCode: 'M5V 2T6',
        issueDescription: 'Repair a leaking tap',
        serviceType: 'maintain heat',
        status: 'cancelled',
        createdAt: DateTime(2026, 10, 20),
        photoPath: 'appointment-photos/user-1/appointment-123/photo.jpg',
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    final dateText = MaterialLocalizations.of(
      tester.element(find.byType(AppBar)),
    ).formatMediumDate(DateTime(2026, 11, 3));
    expect(find.text('Cancelled'), findsOneWidget);
    // The type of service is the first field shown for an appointment.
    expect(find.text('Type of service'), findsOneWidget);
    expect(find.text('Heating system maintenance'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Type of service')).dy,
      lessThan(tester.getTopLeft(find.text('Date')).dy),
    );
    expect(find.text(dateText), findsOneWidget);
    expect(find.text('1 pm - 3 pm'), findsOneWidget);
    expect(find.text('Jordan Customer'), findsOneWidget);
    expect(find.text('416-555-0182'), findsOneWidget);
    expect(find.text('42 Main Street'), findsOneWidget);
    expect(find.text('Toronto'), findsOneWidget);
    expect(find.text('M5V 2T6'), findsOneWidget);
    expect(find.text('Repair a leaking tap'), findsOneWidget);
    expect(
      find.text('Photo provided with this booking and securely stored.'),
      findsOneWidget,
    );
  });

  testWidgets('Latest Appointment confirms when no photo was attached', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: AppointmentRecord(
        id: 'appointment-456',
        appointmentDate: DateTime(2026, 11, 4),
        timeSlot: '9 am - 11 am',
        customerName: 'Taylor Customer',
        phone: '416-555-0183',
        streetAddress: '7 Queen Street',
        city: 'Toronto',
        postalCode: 'M5V 2T7',
        issueDescription: 'Check a faucet',
        status: 'scheduled',
        createdAt: DateTime(2026, 10, 21),
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    expect(
      find.text('No photo was provided with this booking.'),
      findsOneWidget,
    );
  });

  testWidgets('Latest appointment pill matches the review status tones', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
        status: 'cancelled',
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    final chipFinder = find.byType(Chip);
    final chip = tester.widget<Chip>(chipFinder);
    final colorScheme = Theme.of(tester.element(chipFinder)).colorScheme;
    final avatar = chip.avatar! as Icon;

    expect(find.text('Cancelled'), findsOneWidget);
    expect(chip.backgroundColor, colorScheme.errorContainer);
    expect(avatar.icon, Icons.cancel_outlined);
    expect(avatar.color, colorScheme.onErrorContainer);
    // A cancelled appointment can no longer be cancelled by the customer.
    expect(find.byKey(const ValueKey('cancel-appointment')), findsNothing);
  });

  testWidgets('Customer can cancel an appointment before the deadline', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    final cancelButton = find.byKey(const ValueKey('cancel-appointment'));
    expect(cancelButton, findsOneWidget);
    await tester.ensureVisible(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsOneWidget);
    expect(
      find.text(
        'This will cancel your appointment and free the time slot for another customer.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Yes')),
    );
    await tester.pumpAndSettle();

    expect(appointmentRepository.cancelledAppointments, ['appointment-789']);
    expect(find.text('Your appointment was cancelled.'), findsOneWidget);
  });

  testWidgets('Customer can back out of cancelling an appointment', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    final cancelButton = find.byKey(const ValueKey('cancel-appointment'));
    await tester.ensureVisible(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(appointmentRepository.cancelledAppointments, isEmpty);
    expect(cancelButton, findsOneWidget);
  });

  testWidgets('Cancel option is hidden inside the cancellation lead time', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(2),
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-appointment')), findsNothing);
  });

  testWidgets('Customer can edit the appointment name inline', (tester) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    final editName = find.byKey(const ValueKey('edit-name'));
    await tester.ensureVisible(editName);
    await tester.pumpAndSettle();
    await tester.tap(editName);
    await tester.pumpAndSettle();

    final editor = find.byKey(const ValueKey('name-editor'));
    expect(editor, findsOneWidget);
    await tester.enterText(editor, 'Jordan Builder');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('save-name')));
    await tester.pumpAndSettle();

    expect(appointmentRepository.appointmentUpdates, hasLength(1));
    final update = appointmentRepository.appointmentUpdates.single;
    expect(update.appointmentId, 'appointment-789');
    expect(update.customerName, 'Jordan Builder');
    expect(update.issueDescription, isNull);
    expect(update.photo, isNull);
    expect(find.text('Appointment updated.'), findsOneWidget);
    expect(find.byKey(const ValueKey('name-editor')), findsNothing);
  });

  testWidgets('Customer can edit the issue description inline', (tester) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    final editIssue = find.byKey(const ValueKey('edit-issue'));
    await tester.ensureVisible(editIssue);
    await tester.pumpAndSettle();
    await tester.tap(editIssue);
    await tester.pumpAndSettle();

    final editor = find.byKey(const ValueKey('issue-editor'));
    expect(editor, findsOneWidget);
    await tester.enterText(editor, 'Replace the bathroom tap');
    await tester.pumpAndSettle();

    final saveIssue = find.byKey(const ValueKey('save-issue'));
    await tester.ensureVisible(saveIssue);
    await tester.pumpAndSettle();
    await tester.tap(saveIssue);
    await tester.pumpAndSettle();

    expect(appointmentRepository.appointmentUpdates, hasLength(1));
    final update = appointmentRepository.appointmentUpdates.single;
    expect(update.issueDescription, 'Replace the bathroom tap');
    expect(update.customerName, isNull);
    expect(find.text('Appointment updated.'), findsOneWidget);
  });

  testWidgets('Discarding an inline edit leaves the appointment unchanged', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('name-editor')),
      'Discarded Name',
    );
    await tester.tap(find.byKey(const ValueKey('cancel-name')));
    await tester.pumpAndSettle();

    expect(appointmentRepository.appointmentUpdates, isEmpty);
    expect(find.byKey(const ValueKey('name-editor')), findsNothing);
    expect(find.text('Jordan Customer'), findsOneWidget);
  });

  testWidgets('A failed inline update keeps the editor open', (tester) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
      ),
      updateError: StateError('offline'),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('name-editor')),
      'Jordan Builder',
    );
    await tester.tap(find.byKey(const ValueKey('save-name')));
    await tester.pumpAndSettle();

    expect(appointmentRepository.appointmentUpdates, isEmpty);
    expect(
      find.text('Could not update your appointment. Please try again.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('name-editor')), findsOneWidget);
  });

  testWidgets('Latest appointment offers adding a missing photo', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-appointment-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('save-appointment-photo')), findsNothing);
    expect(
      find.byKey(const ValueKey('cancel-appointment-photo')),
      findsNothing,
    );
  });

  testWidgets('A stored photo is read-only on the latest appointment', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: AppointmentRecord(
        id: 'appointment-789',
        appointmentDate: _workingDateAhead(5),
        timeSlot: '1 pm - 3 pm',
        customerName: 'Jordan Customer',
        phone: '416-555-0182',
        streetAddress: '42 Main Street',
        city: 'Toronto',
        postalCode: 'M5V 2T6',
        issueDescription: 'Repair a leaking tap',
        status: 'scheduled',
        createdAt: DateTime(2026, 10, 20),
        photoPath: 'appointment-photos/customer-1/appointment-789/tap.jpg',
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    expect(
      find.text('Photo provided with this booking and securely stored.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('add-appointment-photo')), findsNothing);
  });

  testWidgets('Inline editing is hidden for a cancelled appointment', (
    tester,
  ) async {
    final appointmentRepository = _TestAppointmentRepository(
      latestAppointment: _latestAppointment(
        appointmentDate: _workingDateAhead(5),
        status: 'cancelled',
      ),
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-latest')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit-name')), findsNothing);
    expect(find.byKey(const ValueKey('edit-issue')), findsNothing);
    expect(find.byKey(const ValueKey('add-appointment-photo')), findsNothing);
  });

  testWidgets('Admin can update public Notes and Pricing content', (
    tester,
  ) async {
    const originalNotes =
        'Service update\n\nWe are updating our service schedule. Please check here for the latest availability.';
    const originalPricing = 'Pricing information will be posted here.';
    final contentRepository = _TestBusinessContentRepository(
      notes: originalNotes,
      pricing: originalPricing,
    );
    await _pumpApp(
      tester,
      startAsAdmin: true,
      businessContentRepository: contentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('nav-announcements')));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('save-notes-and-pricing')),
      findsOneWidget,
    );

    final notesField = find.byType(TextFormField).at(0);
    final pricingField = find.byType(TextFormField).at(1);
    await tester.enterText(notesField, 'Holiday hours: 10 am to 2 pm.');
    await tester.enterText(pricingField, 'Standard service call: \$125.');
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-notes-and-pricing')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(find.byKey(const ValueKey('save-notes-and-pricing')))
          .bottom,
      lessThanOrEqualTo(tester.getBottomRight(find.byType(Scaffold)).dy),
    );
    await tester.tap(find.byKey(const ValueKey('save-notes-and-pricing')));
    await tester.pumpAndSettle();

    expect(
      contentRepository.savedContent?.notes,
      'Holiday hours: 10 am to 2 pm.',
    );
    expect(
      contentRepository.savedContent?.pricing,
      'Standard service call: \$125.',
    );
    expect(find.text('Holiday hours: 10 am to 2 pm.'), findsNWidgets(2));
    expect(find.text('Standard service call: \$125.'), findsNWidgets(2));
    expect(find.text('Notes and pricing saved.'), findsOneWidget);
  });

  testWidgets('Service-area outlines are registered as tap targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester);

    final layer = tester.widget<PolygonLayer<ServiceArea>>(
      find.byKey(const ValueKey('service-area-boundaries')),
    );

    expect(layer.hitNotifier, isNotNull);
    expect(
      layer.polygons.map((polygon) => polygon.hitValue),
      containsAll(serviceAreas),
    );
  });

  testWidgets('The map opens at the configured service-area zoom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));

    expect(map.options.initialZoom, ServiceAreaCoverage.mapInitialZoom);
    expect(map.options.initialZoom, greaterThan(map.options.minZoom!));
    expect(map.options.initialZoom, lessThan(map.options.maxZoom!));
  });

  testWidgets('Tapping empty map space clears the selected service area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('hotspot-downtown')));
    await tester.pumpAndSettle();
    expect(find.text('Downtown'), findsOneWidget);
    expect(find.byKey(const ValueKey('continue-service-area')), findsOneWidget);

    // The top-right corner of the map is clear of the markers, the drawn
    // outlines and the controls pinned over the map.
    final mapRect = tester.getRect(find.byType(FlutterMap));
    await tester.tapAt(mapRect.topRight + const Offset(-16, 30));
    // flutter_map only reports a map tap once the double-tap window has passed.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Downtown'), findsNothing);
    expect(find.byKey(const ValueKey('continue-service-area')), findsNothing);
  });

  testWidgets('Booking continuation requires sign-in and preserves area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final appointmentRepository = _TestAppointmentRepository();
    // Morning is already taken on the first bookable day.
    final bookedDate = BookingSchedule.firstBookableDate(
      DateUtils.dateOnly(DateTime.now()),
    );
    appointmentRepository.bookedSlots.add(
      BookedSlot(date: bookedDate, timeSlot: '9 am - 11 am'),
    );
    await _pumpApp(tester, appointmentRepository: appointmentRepository);

    await tester.tap(find.byKey(const ValueKey('hotspot-downtown')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('service-area-boundaries')),
      findsOneWidget,
    );
    expect(find.text('Downtown'), findsOneWidget);
    expect(find.byKey(const ValueKey('continue-service-area')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(
      find.text(
        "We only use the information needed to sign you in; we don't access or store the rest of your provider account.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sign-in-google')), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in-facebook')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('sign-in-google'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('sign-in-facebook'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(const ValueKey('login-cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Downtown'), findsOneWidget);
    expect(find.byKey(const ValueKey('continue-service-area')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();

    expect(find.text('Downtown'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();

    final now = DateUtils.dateOnly(DateTime.now());
    final nextAvailableDate = BookingSchedule.firstBookableDate(now);
    const calendarKey = ValueKey('booking-calendar');
    final calendarFinder = find.byKey(calendarKey);
    final calendar = tester.widget<CalendarDatePicker>(calendarFinder);
    expect(calendar.selectableDayPredicate!(nextAvailableDate), isTrue);

    // A day the working week does not cover is never bookable.
    expect(calendar.selectableDayPredicate!(_nextNonWorkingDate(now)), isFalse);
    // The highlighted day defaults to the earliest bookable date, and its
    // available slots are loaded without the customer tapping the date first.
    expect(
      DateUtils.isSameDay(calendar.initialDate, nextAvailableDate),
      isTrue,
    );

    const slotIds = ['morning', 'midday', 'afternoon', 'evening'];
    bool slotIsEnabled(String slotId) {
      final tile = tester.widget(find.byKey(ValueKey('booking-slot-$slotId')));
      return (tile as dynamic).enabled == true;
    }

    for (final slotId in slotIds) {
      expect(find.byKey(ValueKey('booking-slot-$slotId')), findsOneWidget);
    }
    expect(slotIsEnabled('morning'), isFalse);
    expect(slotIsEnabled('midday'), isTrue);
    expect(find.text('Unavailable for this date'), findsOneWidget);

    final continueBeforeSelection = tester.widget<FilledButton>(
      find.byKey(const ValueKey('continue-selected-slot')),
    );
    expect(continueBeforeSelection.onPressed, isNull);

    final slotId = slotIds.firstWhere(slotIsEnabled);
    await tester.ensureVisible(find.byKey(ValueKey('booking-slot-$slotId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('booking-slot-$slotId')));
    await tester.pumpAndSettle();

    final continueButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('continue-selected-slot')),
    );
    expect(continueButton.onPressed, isNotNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('continue-selected-slot')),
    );
    await tester.pumpAndSettle();
    final dateLabel = MaterialLocalizations.of(tester.element(calendarFinder))
        .formatMediumDate(nextAvailableDate);
    await tester.tap(find.byKey(const ValueKey('continue-selected-slot')));
    await tester.pumpAndSettle();
    final timeLabel = switch (slotId) {
      'morning' => '9 am - 11 am',
      'midday' => '11 am - 1 pm',
      'afternoon' => '1 pm - 3 pm',
      _ => '3 pm - 5 pm',
    };
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Booking Details'),
      ),
      findsOneWidget,
    );
    expect(find.text('Enter contact information'), findsOneWidget);
    expect(find.text('$dateLabel · $timeLabel'), findsOneWidget);
    expect(
      find.text('Type of service: Heating system maintenance'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('customer-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-street')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-city')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-issue')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-customer-photo')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('book-customer-details')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-customer-details')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a follow-up phone number.'), findsOneWidget);
    expect(find.text('Enter a postal code.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('customer-phone')),
      '123456789',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-postal-code')),
      'M5V 2T6',
    );
    tester.testTextInput.hide();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('book-customer-details')),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-customer-details')));
    await tester.pumpAndSettle();
    expect(
      find.text('Use 9999999999, 999-999-9999, or 999-9999999 format.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('customer-phone')),
      '416-555-0182',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-postal-code')),
      'M5V 26',
    );
    tester.testTextInput.hide();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('book-customer-details')),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-customer-details')));
    await tester.pumpAndSettle();
    expect(
      find.text('Use A9A9A9 or A9A 9A9 postal-code format.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('customer-postal-code')),
      'Z9Z 9Z9',
    );
    tester.testTextInput.hide();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('book-customer-details')),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-customer-details')));
    await tester.pumpAndSettle();
    expect(
      find.text('This postal code is outside our service area.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('customer-phone')),
      '416-555-0182',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-name')),
      'Avery Smith',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-street')),
      '123 Main Street',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-city')),
      'Toronto',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-postal-code')),
      'm5v 2t6',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-issue')),
      'Repair a leaking kitchen tap',
    );
    tester.testTextInput.hide();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('book-customer-details')),
      find.byType(SingleChildScrollView).last,
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('book-customer-details')));
    await tester.pumpAndSettle();
    expect(find.text('Appointment Booked'), findsOneWidget);
    final bookingSnackbar = tester.widget<SnackBar>(find.byType(SnackBar));
    final colorScheme = Theme.of(tester.element(find.byType(SnackBar)))
        .colorScheme;
    expect(bookingSnackbar.behavior, SnackBarBehavior.floating);
    expect(bookingSnackbar.backgroundColor, colorScheme.primaryContainer);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('customer-details-appbar-back')),
      findsNothing,
    );
    expect(appointmentRepository.drafts, hasLength(1));
    final savedDraft = appointmentRepository.drafts.single;
    expect(savedDraft.appointmentDate, nextAvailableDate);
    expect(savedDraft.timeSlot, timeLabel);
    expect(savedDraft.customerName, 'Avery Smith');
    expect(savedDraft.phone, '416-555-0182');
    expect(savedDraft.streetAddress, '123 Main Street');
    expect(savedDraft.city, 'Toronto');
    expect(savedDraft.postalCode, 'm5v 2t6');
    expect(savedDraft.issueDescription, 'Repair a leaking kitchen tap');
    // The dropdown selection is stored in the trade's own wording.
    expect(savedDraft.serviceType, 'maintain heat');
  });

  testWidgets('Provider sign-in authenticates and exposes sign out', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-login')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-login')));
    await tester.pumpAndSettle();
    expect(find.text('You are signed in'), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-out')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sign-in-google')), findsOneWidget);
  });

  testWidgets('Customer form validates formats and limits free-text fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);
    var successfulBooks = 0;
    final submittedDrafts = <AppointmentDraft>[];
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: CustomerDetailsScreen(
              serviceArea: serviceAreas.first,
              serviceType: serviceTypes.first,
              appointmentDate: DateUtils.dateOnly(DateTime.now()),
              timeSlot: '9 am - 11 am',
              onBook: (draft) async {
                submittedDrafts.add(draft);
                successfulBooks++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const validPhoneNumbers = ['4165550182', '416-555-0182', '416-5550182'];
    const validPostalCodes = ['M5V2T6', 'm5v 2t6'];
    for (var index = 0; index < validPhoneNumbers.length; index++) {
      await tester.enterText(
        find.byKey(const ValueKey('customer-phone')),
        validPhoneNumbers[index],
      );
      await tester.enterText(
        find.byKey(const ValueKey('customer-postal-code')),
        validPostalCodes[index % validPostalCodes.length],
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('book-customer-details')));
      await tester.pumpAndSettle();
      expect(find.text('Appointment Booked'), findsNothing);
      expect(successfulBooks, index + 1);
      expect(submittedDrafts, hasLength(index + 1));
      expect(submittedDrafts.last.phone, validPhoneNumbers[index]);
      expect(
        submittedDrafts.last.postalCode,
        validPostalCodes[index % validPostalCodes.length],
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    await tester.enterText(
      find.byKey(const ValueKey('customer-name')),
      'Avery/Smith*+${'n' * 40}',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-street')),
      '123 Main St. #4 +${'s' * 60}',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-city')),
      'Toronto!+${'c' * 40}',
    );
    await tester.enterText(
      find.byKey(const ValueKey('customer-issue')),
      'Leak / crack: inspect & repair!+${'i' * 350}',
    );

    String valueOfField(Key key) {
      final textField = tester.widget<TextField>(
        find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
      );
      return textField.controller!.text;
    }

    expect(valueOfField(const ValueKey('customer-name')).length, 30);
    expect(valueOfField(const ValueKey('customer-street')).length, 50);
    expect(valueOfField(const ValueKey('customer-city')).length, 30);
    expect(valueOfField(const ValueKey('customer-issue')).length, 300);
    expect(valueOfField(const ValueKey('customer-name')), isNot(contains('+')));
    expect(
      valueOfField(const ValueKey('customer-street')),
      isNot(contains('+')),
    );
    expect(valueOfField(const ValueKey('customer-city')), isNot(contains('+')));
    expect(
      valueOfField(const ValueKey('customer-issue')),
      isNot(contains('+')),
    );
  });

  testWidgets('App bar exposes overflow, handedness, and theme controls', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byKey(const ValueKey('overflow-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('handedness-toggle')), findsOneWidget);
    expect(find.byKey(const ValueKey('theme-toggle')), findsOneWidget);
  });

  testWidgets('Handedness toggle updates its accessible action', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byTooltip('Switch to left-handed layout'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('handedness-toggle')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to right-handed layout'), findsOneWidget);
  });

  testWidgets('Left-handed mode mirrors the landing app-bar controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester);

    final overflow = find.byKey(const ValueKey('overflow-menu'));
    final handedness = find.byKey(const ValueKey('handedness-toggle'));
    final theme = find.byKey(const ValueKey('theme-toggle'));

    // Right-handed: the front-hand glyph and the controls trailing the bar.
    expect(find.byIcon(Icons.front_hand_rounded), findsOneWidget);
    final rightHandedTheme = tester.getTopLeft(theme).dx;
    expect(tester.getTopLeft(overflow).dx, lessThan(rightHandedTheme));

    await tester.tap(handedness);
    await tester.pumpAndSettle();

    // Left-handed: the back-hand glyph and the reversed controls on the left.
    expect(find.byIcon(Icons.back_hand_rounded), findsOneWidget);
    final leftTheme = tester.getTopLeft(theme).dx;
    final leftHandedness = tester.getTopLeft(handedness).dx;
    final leftOverflow = tester.getTopLeft(overflow).dx;
    expect(leftTheme, lessThan(leftHandedness));
    expect(leftHandedness, lessThan(leftOverflow));
    // The whole group stays on the leading half of the app bar.
    expect(leftTheme, lessThan(48));
    expect(leftOverflow, lessThan(rightHandedTheme));
  });

  testWidgets('Right-handed back arrow joins the trailing controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester, startAsAuthenticated: true);

    await tester.tap(find.byKey(const ValueKey('hotspot-downtown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();

    final back = find.byKey(const ValueKey('booking-calendar-appbar-back'));
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Booking Details'),
    );
    final overflow = find.byKey(const ValueKey('overflow-menu'));
    final handedness = find.byKey(const ValueKey('handedness-toggle'));
    final theme = find.byKey(const ValueKey('theme-toggle'));

    expect(back, findsOneWidget);
    // The arrow leads the trailing cluster, right beside the title, and the
    // three controls keep their order behind it.
    expect(
      tester.getTopLeft(overflow).dx - tester.getTopRight(back).dx,
      inInclusiveRange(0, 1),
    );
    expect(
      tester.getTopLeft(handedness).dx,
      greaterThan(tester.getTopLeft(overflow).dx),
    );
    expect(
      tester.getTopLeft(theme).dx,
      greaterThan(tester.getTopLeft(handedness).dx),
    );
    expect(tester.getTopRight(theme).dx, closeTo(390, 1));
    // The title centers between the bar's leading edge and the cluster.
    expect(
      tester.getTopLeft(title).dx,
      closeTo(tester.getTopLeft(back).dx - tester.getTopRight(title).dx, 1),
    );
  });

  testWidgets('Wide bars center the title instead of stretching it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester, startAsAuthenticated: true);

    await tester.tap(find.byKey(const ValueKey('hotspot-downtown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();

    final back = find.byKey(const ValueKey('booking-calendar-appbar-back'));
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Booking Details'),
    );

    // The title is narrower than the free space, so it is pushed inward from
    // both edges by the same amount rather than filling the slot.
    final leftGap = tester.getTopLeft(title).dx;
    final rightGap = tester.getTopLeft(back).dx - tester.getTopRight(title).dx;
    expect(leftGap, closeTo(rightGap, 1));
    expect(leftGap, greaterThan(32));
    // It never runs under the control cluster.
    expect(tester.getTopRight(title).dx, lessThan(tester.getTopLeft(back).dx));

    // The mirrored layout centers the title the same way.
    await tester.tap(find.byKey(const ValueKey('handedness-toggle')));
    await tester.pumpAndSettle();
    final mirroredLeftGap =
        tester.getTopLeft(title).dx - tester.getTopRight(back).dx;
    expect(mirroredLeftGap, closeTo(800 - tester.getTopRight(title).dx, 1));
    expect(mirroredLeftGap, greaterThan(32));
  });

  testWidgets('Left-handed mode mirrors the controls on back-arrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester, startAsAuthenticated: true);

    await tester.tap(find.byKey(const ValueKey('handedness-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hotspot-downtown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();

    final overflow = find.byKey(const ValueKey('overflow-menu'));
    final handedness = find.byKey(const ValueKey('handedness-toggle'));
    final theme = find.byKey(const ValueKey('theme-toggle'));
    final back = find.byKey(const ValueKey('booking-calendar-appbar-back'));
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Booking Details'),
    );

    // The mirrored cluster leads with the controls in reverse order and the
    // back arrow innermost, right beside the title.
    expect(
      tester.getTopLeft(theme).dx,
      lessThan(tester.getTopLeft(handedness).dx),
    );
    expect(
      tester.getTopLeft(handedness).dx,
      lessThan(tester.getTopLeft(overflow).dx),
    );
    expect(
      tester.getTopLeft(back).dx - tester.getTopRight(overflow).dx,
      inInclusiveRange(0, 1),
    );
    expect(tester.getTopLeft(theme).dx, lessThan(48));
    expect(tester.getTopRight(back).dx, lessThan(tester.getTopLeft(title).dx));
    // The title centers between the leading cluster and the trailing edge.
    expect(
      tester.getTopLeft(title).dx - tester.getTopRight(back).dx,
      closeTo(390 - tester.getTopRight(title).dx, 1),
    );
  });

  testWidgets('Left-handed mode mirrors the controls on title-only screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('handedness-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-announcements')));
    await tester.pumpAndSettle();

    final overflow = find.byKey(const ValueKey('overflow-menu'));
    final theme = find.byKey(const ValueKey('theme-toggle'));
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Notes & Pricing'),
    );

    // There is no back arrow, so the mirrored controls are the whole group.
    expect(tester.getTopLeft(theme).dx, lessThan(48));
    // The title centers between the leading controls and the trailing edge.
    expect(
      tester.getTopLeft(title).dx - tester.getTopRight(overflow).dx,
      closeTo(390 - tester.getTopRight(title).dx, 1),
    );
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('Right-handed title-only screens center the title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('nav-announcements')));
    await tester.pumpAndSettle();

    final overflow = find.byKey(const ValueKey('overflow-menu'));
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Notes & Pricing'),
    );

    // The title centers between the leading edge and the trailing controls.
    expect(
      tester.getTopLeft(title).dx,
      closeTo(tester.getTopLeft(overflow).dx - tester.getTopRight(title).dx, 1),
    );
  });

  testWidgets('Theme toggle changes to dark mode and back', (tester) async {
    await _pumpApp(tester);

    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to light theme'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);
  });

  testWidgets('Handedness and theme choices are saved for the signed-in user', (
    tester,
  ) async {
    final settings = _TestUserSettingsRepository();
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      userSettingsRepository: settings,
    );
    await tester.pumpAndSettle();

    // A brand-new account starts right-handed, following the device theme.
    expect(find.byTooltip('Switch to left-handed layout'), findsOneWidget);
    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);
    expect(settings.saves, isEmpty);

    await tester.tap(find.byKey(const ValueKey('handedness-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    expect(settings.saves, hasLength(2));
    expect(settings.saves.last.userId, _testUserId);
    final saved = settings.savedSettingsFor(_testUserId)!;
    expect(saved.isLeftHanded, isTrue);
    expect(saved.themeMode, ThemeMode.dark);
  });

  testWidgets('A saved layout is restored the next time the user signs in', (
    tester,
  ) async {
    final settings = _TestUserSettingsRepository(
      stored: {
        _testUserId: const UserSettings(
          isLeftHanded: true,
          themeMode: ThemeMode.dark,
        ),
      },
    );
    await _pumpApp(
      tester,
      startAsAuthenticated: true,
      userSettingsRepository: settings,
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to right-handed layout'), findsOneWidget);
    expect(find.byTooltip('Switch to light theme'), findsOneWidget);
  });

  testWidgets('Signed-out visitors keep their layout for the session only', (
    tester,
  ) async {
    final settings = _TestUserSettingsRepository();
    await _pumpApp(tester, userSettingsRepository: settings);

    await tester.tap(find.byKey(const ValueKey('handedness-toggle')));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to right-handed layout'), findsOneWidget);
    expect(settings.saves, isEmpty);
  });

  testWidgets('Signing out returns to the default layout', (tester) async {
    final settings = _TestUserSettingsRepository(
      stored: {
        _testUserId: const UserSettings(
          isLeftHanded: true,
          themeMode: ThemeMode.dark,
        ),
      },
    );
    final authGateway = await _pumpApp(
      tester,
      startAsAuthenticated: true,
      userSettingsRepository: settings,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Switch to right-handed layout'), findsOneWidget);

    await authGateway.signOut();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to left-handed layout'), findsOneWidget);
    expect(find.byTooltip('Switch to dark theme'), findsOneWidget);
  });

  for (final destination in [
    (name: 'Book', key: const ValueKey('nav-book')),
    (name: 'Announcements', key: const ValueKey('nav-announcements')),
  ]) {
    testWidgets(
      'M3 overflow menu matches the prototype on ${destination.name}',
      (tester) async {
        await _pumpApp(tester);
        await tester.tap(find.byKey(destination.key));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('overflow-menu')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('menu-item-adminLogin')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('menu-item-eula')), findsOneWidget);
        expect(find.byKey(const ValueKey('menu-item-info')), findsOneWidget);
        expect(find.byKey(const ValueKey('menu-item-review')), findsNothing);
        expect(find.byKey(const ValueKey('menu-item-blockOff')), findsNothing);
        expect(find.byKey(const ValueKey('menu-item-workNotes')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('menu-item-info')));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Info is not available yet.'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  testWidgets('Admin menu includes Review and Block-off', (tester) async {
    await _pumpApp(tester, startAsAdmin: true);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('menu-item-adminLogout')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-adminLogin')), findsNothing);
    expect(find.byKey(const ValueKey('menu-item-review')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-blockOff')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-workNotes')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-eula')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-info')), findsOneWidget);
  });

  testWidgets(
    'Admin Block-off menu opens the screen and saves blocked-off slots',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appointmentRepository = _TestAppointmentRepository();
      await _pumpApp(
        tester,
        startAsAdmin: true,
        appointmentRepository: appointmentRepository,
      );
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-item-blockOff')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Block off time'),
        ),
        findsOneWidget,
      );

      var selectedWeekday = DateUtils.dateOnly(DateTime.now());
      while (!BookingSchedule.workingWeekdays.contains(
        selectedWeekday.weekday,
      )) {
        selectedWeekday = selectedWeekday.add(const Duration(days: 1));
      }
      tester
          .widget<CalendarDatePicker>(
            find.byKey(const ValueKey('blockoff-calendar')),
          )
          .onDateChanged(selectedWeekday);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('blockoff-slot-morning')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('block-selected-times')));
      await tester.pumpAndSettle();

      expect(find.text('Blocked-off times saved.'), findsOneWidget);
      expect(appointmentRepository.blockedOffUpdates, hasLength(1));
      expect(appointmentRepository.blockedOffUpdates.single.block, {
        '9 am - 11 am',
      });
      await tester.tap(find.byKey(const ValueKey('nav-book')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('service-type-dropdown')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Block-off screen nav bar navigates like other screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, startAsAdmin: true);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-blockOff')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Block off time'),
      ),
      findsOneWidget,
    );

    // Choosing a nav destination leaves the block-off screen and shows the
    // selected tab, matching the landing (Service Area) screen's behavior.
    await tester.tap(find.byKey(const ValueKey('nav-announcements')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('announcements-screen')), findsOneWidget);
    expect(find.text('Block off time'), findsNothing);
  });

  testWidgets(
    'Admin Review overview defaults to today and offers Details for bookings',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var selectedWeekday = DateUtils.dateOnly(DateTime.now());
      while (!BookingSchedule.workingWeekdays.contains(
        selectedWeekday.weekday,
      )) {
        selectedWeekday = selectedWeekday.add(const Duration(days: 1));
      }

      final appointmentRepository = _TestAppointmentRepository(
        blockedOffTimes: [
          BlockedOffTime(date: selectedWeekday, timeSlot: '1 pm - 3 pm'),
        ],
      );
      appointmentRepository.bookedSlots.addAll([
        BookedSlot(date: selectedWeekday, timeSlot: '1 pm - 3 pm'),
        BookedSlot(date: selectedWeekday, timeSlot: '11 am - 1 pm'),
      ]);

      await _pumpApp(
        tester,
        startAsAdmin: true,
        appointmentRepository: appointmentRepository,
      );
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-item-review')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Review bookings'),
        ),
        findsOneWidget,
      );

      // The overview opens on today (or the next working day).
      final calendar = tester.widget<CalendarDatePicker>(
        find.byKey(const ValueKey('review-calendar')),
      );
      expect(
        DateUtils.isSameDay(calendar.initialDate, selectedWeekday),
        isTrue,
      );

      // Customer bookings are actionable; blocked-off slots are labelled, and
      // free slots have neither a label nor a button.
      expect(
        find.byKey(const ValueKey('review-details-midday')),
        findsOneWidget,
      );
      expect(find.text('Blocked off'), findsOneWidget);
      for (final slot in ['morning', 'afternoon', 'evening']) {
        expect(find.byKey(ValueKey('review-details-$slot')), findsNothing);
      }

      // Details opens the day's schedule under the shared AppBar.
      await tester.tap(find.byKey(const ValueKey('review-details-midday')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Review bookings'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('review-details-back')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('review-details-slot-midday')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Review still opens bookings on a day the working week no longer covers',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final today = DateUtils.dateOnly(DateTime.now());
      final dayOff = _nextNonWorkingDate(today);
      final laterDayOff = _nextNonWorkingDate(
        DateUtils.addDaysToDate(dayOff, 1),
      );

      final appointmentRepository = _TestAppointmentRepository();
      appointmentRepository.bookedSlots.add(
        BookedSlot(date: dayOff, timeSlot: '9 am - 11 am'),
      );

      await _pumpApp(
        tester,
        startAsAdmin: true,
        appointmentRepository: appointmentRepository,
      );
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-item-review')));
      await tester.pumpAndSettle();

      final calendar = tester.widget<CalendarDatePicker>(
        find.byKey(const ValueKey('review-calendar')),
      );

      // The day is outside the configured working week...
      expect(BookingSchedule.workingWeekdays.contains(dayOff.weekday), isFalse);
      // ...but its booking keeps it reachable for review.
      expect(calendar.selectableDayPredicate!(dayOff), isTrue);
      // A day off with nothing booked stays closed.
      expect(calendar.selectableDayPredicate!(laterDayOff), isFalse);
    },
  );

  testWidgets('Left-handed mode swaps the Review slot columns', (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedWeekday = DateUtils.dateOnly(DateTime.now());
    while (!BookingSchedule.workingWeekdays.contains(selectedWeekday.weekday)) {
      selectedWeekday = selectedWeekday.add(const Duration(days: 1));
    }

    final appointmentRepository = _TestAppointmentRepository();
    appointmentRepository.bookedSlots.add(
      BookedSlot(date: selectedWeekday, timeSlot: '9 am - 11 am'),
    );

    await _pumpApp(
      tester,
      startAsAdmin: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-review')));
    await tester.pumpAndSettle();

    final details = find.byKey(const ValueKey('review-details-morning'));
    final hour = find.text('9 am - 11 am');

    // Right-handed: the hour label leads and the Details button trails it.
    expect(
      tester.getTopRight(hour).dx,
      lessThan(tester.getTopLeft(details).dx),
    );

    // Left-handed: the columns swap, putting the button under the left thumb.
    await tester.tap(find.byKey(const ValueKey('handedness-toggle')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopRight(details).dx,
      lessThan(tester.getTopLeft(hour).dx),
    );
  });

  testWidgets('Left-handed mode moves the Block-off checkbox under the thumb', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, startAsAdmin: true);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-blockOff')));
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('blockoff-slot-morning'));
    final morning = find.text('9 am - 11 am');

    ListTileControlAffinity? affinity() =>
        tester.widget<CheckboxListTile>(tile).controlAffinity;
    Rect checkbox() => tester.getRect(
      find.descendant(of: tile, matching: find.byType(Checkbox)),
    );

    // Right-handed: the checkbox trails, under a right thumb.
    expect(affinity(), ListTileControlAffinity.trailing);
    expect(checkbox().left, greaterThan(tester.getRect(morning).right));

    // Left-handed: the checkbox leads, like the Review screen's Details
    // button, putting the actionable control under a left thumb.
    await tester.tap(find.byKey(const ValueKey('handedness-toggle')));
    await tester.pumpAndSettle();

    expect(affinity(), ListTileControlAffinity.leading);
    expect(checkbox().right, lessThan(tester.getRect(morning).left));
  });

  testWidgets(
    'Admin Review details shows the day, slot states, statuses and day steps',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var workday = DateUtils.dateOnly(DateTime.now());
      while (!BookingSchedule.workingWeekdays.contains(workday.weekday)) {
        workday = workday.add(const Duration(days: 1));
      }
      final nextDay = DateUtils.addDaysToDate(workday, 1);
      final photoPath = 'appointment-photos/uid/apt-morning/tap.jpg';

      final appointmentRepository = _TestAppointmentRepository(
        blockedOffTimes: [
          BlockedOffTime(date: workday, timeSlot: '1 pm - 3 pm'),
        ],
        appointments: [
          AppointmentRecord(
            id: 'apt-morning',
            appointmentDate: workday,
            timeSlot: '9 am - 11 am',
            customerName: 'Ada Lovelace',
            phone: '416-555-0100',
            streetAddress: '12 King St',
            city: 'Toronto',
            postalCode: 'M5H 1A1',
            issueDescription: 'Leaking tap',
            serviceType: 'maintain heat',
            status: 'scheduled',
            createdAt: DateTime(2026, 1, 1),
            photoPath: photoPath,
          ),
        ],
      );
      appointmentRepository.bookedSlots.addAll([
        BookedSlot(date: workday, timeSlot: '9 am - 11 am'),
        BookedSlot(date: workday, timeSlot: '1 pm - 3 pm'),
      ]);

      await _pumpApp(
        tester,
        startAsAdmin: true,
        appointmentRepository: appointmentRepository,
      );
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-item-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review-details-morning')));
      await tester.pumpAndSettle();

      final materialLocalizations = MaterialLocalizations.of(
        tester.element(find.byType(AppBar)),
      );
      expect(
        find.text(materialLocalizations.formatFullDate(workday)),
        findsOneWidget,
      );
      for (final slot in ['morning', 'midday', 'afternoon', 'evening']) {
        expect(
          find.byKey(ValueKey('review-details-slot-$slot')),
          findsOneWidget,
        );
      }

      // The service type leads the booking details.
      expect(find.text('Type of service'), findsOneWidget);
      expect(find.text('Heating system maintenance'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Type of service')).dy,
        lessThan(tester.getTopLeft(find.text('Name')).dy),
      );

      // The booked slot shows the customer's details and the photo fallback.
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('416-555-0100'), findsOneWidget);
      expect(find.text('12 King St, Toronto, M5H 1A1'), findsOneWidget);
      expect(find.text('Leaking tap'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('review-photo-missing-apt-morning')),
        findsOneWidget,
      );
      expect(appointmentRepository.photoUrlRequests, [photoPath]);

      // Blocked and free slots are labelled; only bookings get status buttons.
      expect(find.text('Blocked off'), findsOneWidget);
      expect(find.text('Free'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('review-status-morning')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('review-status-midday')), findsNothing);

      // The control reflects the stored status and offers a way back to it.
      final morningStatusControl = find.byKey(
        const ValueKey('review-status-morning'),
      );
      expect(
        tester.widget<SegmentedButton<String>>(morningStatusControl).selected,
        {'scheduled'},
      );
      expect(
        find.descendant(
          of: morningStatusControl,
          matching: find.text('Schedule'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      expect(appointmentRepository.statusUpdates, [
        (appointmentId: 'apt-morning', status: 'completed'),
      ]);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(appointmentRepository.statusUpdates.last, (
        appointmentId: 'apt-morning',
        status: 'cancelled',
      ));

      // The arrows step one day at a time in both directions.
      await tester.tap(find.byKey(const ValueKey('review-details-next-day')));
      await tester.pumpAndSettle();
      expect(
        find.text(materialLocalizations.formatFullDate(nextDay)),
        findsOneWidget,
      );
      expect(find.text('Ada Lovelace'), findsNothing);
      expect(find.text('Free'), findsNWidgets(4));

      await tester.tap(
        find.byKey(const ValueKey('review-details-previous-day')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(materialLocalizations.formatFullDate(workday)),
        findsOneWidget,
      );
      expect(find.text('Ada Lovelace'), findsOneWidget);

      // Going back reopens the overview on the day that was last viewed.
      await tester.tap(find.byKey(const ValueKey('review-details-back')));
      await tester.pumpAndSettle();
      final calendar = tester.widget<CalendarDatePicker>(
        find.byKey(const ValueKey('review-calendar')),
      );
      expect(DateUtils.isSameDay(calendar.initialDate, workday), isTrue);
    },
  );

  testWidgets('Review details can revert an appointment back to Scheduled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var workday = DateUtils.dateOnly(DateTime.now());
    while (!BookingSchedule.workingWeekdays.contains(workday.weekday)) {
      workday = workday.add(const Duration(days: 1));
    }

    final appointmentRepository = _TestAppointmentRepository(
      appointments: [
        AppointmentRecord(
          id: 'apt-completed',
          appointmentDate: workday,
          timeSlot: '9 am - 11 am',
          customerName: 'Ada Lovelace',
          phone: '416-555-0100',
          streetAddress: '12 King St',
          city: 'Toronto',
          postalCode: 'M5H 1A1',
          issueDescription: 'Leaking tap',
          status: 'completed',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );
    appointmentRepository.bookedSlots.add(
      BookedSlot(date: workday, timeSlot: '9 am - 11 am'),
    );

    await _pumpApp(
      tester,
      startAsAdmin: true,
      appointmentRepository: appointmentRepository,
    );
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-details-morning')));
    await tester.pumpAndSettle();

    final statusControl = find.byKey(const ValueKey('review-status-morning'));
    expect(tester.widget<SegmentedButton<String>>(statusControl).selected, {
      'completed',
    });

    // Scheduled sits between Complete and Cancel so a mistaken status change
    // can be undone.
    await tester.ensureVisible(statusControl);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: statusControl, matching: find.text('Schedule')),
    );
    await tester.pumpAndSettle();
    expect(appointmentRepository.statusUpdates, [
      (appointmentId: 'apt-completed', status: 'scheduled'),
    ]);
  });

  testWidgets('Admin adds a comment to a booking from Review details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var workday = DateUtils.dateOnly(DateTime.now());
    while (!BookingSchedule.workingWeekdays.contains(workday.weekday)) {
      workday = DateUtils.addDaysToDate(workday, 1);
    }

    final appointmentRepository = _TestAppointmentRepository(
      appointments: [
        AppointmentRecord(
          id: 'apt-note',
          appointmentDate: workday,
          timeSlot: '9 am - 11 am',
          customerName: 'Ada Lovelace',
          phone: '416-555-0100',
          streetAddress: '12 King St',
          city: 'Toronto',
          postalCode: 'M5H 1A1',
          issueDescription: 'Leaking tap',
          status: 'scheduled',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    appointmentRepository.bookedSlots.add(
      BookedSlot(date: workday, timeSlot: '9 am - 11 am'),
    );

    await _pumpApp(
      tester,
      startAsAdmin: true,
      appointmentRepository: appointmentRepository,
    );
    await _openMorningReviewDetails(tester);

    // The card stays compact until the admin asks for the comment editor.
    final toggle = find.byKey(const ValueKey('review-note-toggle-apt-note'));
    final field = find.byKey(const ValueKey('review-note-field-apt-note'));
    expect(find.text('Add comment'), findsOneWidget);
    expect(field, findsNothing);

    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Bring a second wrench.');
    await tester.tap(find.byKey(const ValueKey('review-note-save-apt-note')));
    await tester.pumpAndSettle();

    expect(appointmentRepository.noteUpdates, [
      (appointmentId: 'apt-note', note: 'Bring a second wrench.'),
    ]);
    expect(find.text('Comment saved.'), findsOneWidget);
    // Saving collapses the editor and leaves the note readable in the card.
    expect(field, findsNothing);
    expect(find.text('Edit comment'), findsOneWidget);
    expect(find.text('Bring a second wrench.'), findsOneWidget);
  });

  testWidgets('Admin edits an existing comment on a booking', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var workday = DateUtils.dateOnly(DateTime.now());
    while (!BookingSchedule.workingWeekdays.contains(workday.weekday)) {
      workday = DateUtils.addDaysToDate(workday, 1);
    }

    final appointmentRepository = _TestAppointmentRepository(
      appointments: [
        AppointmentRecord(
          id: 'apt-note-edit',
          appointmentDate: workday,
          timeSlot: '9 am - 11 am',
          customerName: 'Ada Lovelace',
          phone: '416-555-0100',
          streetAddress: '12 King St',
          city: 'Toronto',
          postalCode: 'M5H 1A1',
          issueDescription: 'Leaking tap',
          status: 'scheduled',
          createdAt: DateTime(2026, 1, 1),
          adminNote: 'Call before arriving',
        ),
      ],
    );

    appointmentRepository.bookedSlots.add(
      BookedSlot(date: workday, timeSlot: '9 am - 11 am'),
    );

    await _pumpApp(
      tester,
      startAsAdmin: true,
      appointmentRepository: appointmentRepository,
    );
    await _openMorningReviewDetails(tester);

    // A stored note is visible straight away and invites an edit.
    expect(find.text('Edit comment'), findsOneWidget);
    expect(find.text('Call before arriving'), findsOneWidget);

    final toggle = find.byKey(
      const ValueKey('review-note-toggle-apt-note-edit'),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('review-note-field-apt-note-edit'));
    final textField = tester.widget<TextField>(field);
    expect(textField.controller?.text, 'Call before arriving');

    await tester.enterText(field, 'Call first. Gate code 1234.');
    await tester.tap(
      find.byKey(const ValueKey('review-note-save-apt-note-edit')),
    );
    await tester.pumpAndSettle();

    expect(appointmentRepository.noteUpdates, [
      (appointmentId: 'apt-note-edit', note: 'Call first. Gate code 1234.'),
    ]);
    expect(find.text('Call first. Gate code 1234.'), findsOneWidget);
  });

  testWidgets('Cancelling a comment draft leaves the stored note untouched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var workday = DateUtils.dateOnly(DateTime.now());
    while (!BookingSchedule.workingWeekdays.contains(workday.weekday)) {
      workday = DateUtils.addDaysToDate(workday, 1);
    }

    final appointmentRepository = _TestAppointmentRepository(
      appointments: [
        AppointmentRecord(
          id: 'apt-note-cancel',
          appointmentDate: workday,
          timeSlot: '9 am - 11 am',
          customerName: 'Ada Lovelace',
          phone: '416-555-0100',
          streetAddress: '12 King St',
          city: 'Toronto',
          postalCode: 'M5H 1A1',
          issueDescription: 'Leaking tap',
          status: 'scheduled',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    appointmentRepository.bookedSlots.add(
      BookedSlot(date: workday, timeSlot: '9 am - 11 am'),
    );

    await _pumpApp(
      tester,
      startAsAdmin: true,
      appointmentRepository: appointmentRepository,
    );
    await _openMorningReviewDetails(tester);

    final toggle = find.byKey(
      const ValueKey('review-note-toggle-apt-note-cancel'),
    );
    final field = find.byKey(
      const ValueKey('review-note-field-apt-note-cancel'),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    await tester.enterText(field, 'Draft that should be discarded');
    await tester.tap(
      find.byKey(const ValueKey('review-note-cancel-apt-note-cancel')),
    );
    await tester.pumpAndSettle();

    expect(appointmentRepository.noteUpdates, isEmpty);
    expect(field, findsNothing);
    expect(find.text('Add comment'), findsOneWidget);

    // Re-opening starts from the stored note, not the discarded draft.
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
  });

  testWidgets(
    'Review details uses the error tone for Cancelled and the primary tone '
    'for Blocked off',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var workday = DateUtils.dateOnly(DateTime.now());
      while (!BookingSchedule.workingWeekdays.contains(workday.weekday)) {
        workday = workday.add(const Duration(days: 1));
      }

      final appointmentRepository = _TestAppointmentRepository(
        blockedOffTimes: [
          BlockedOffTime(date: workday, timeSlot: '1 pm - 3 pm'),
        ],
        appointments: [
          AppointmentRecord(
            id: 'apt-cancelled',
            appointmentDate: workday,
            timeSlot: '9 am - 11 am',
            customerName: 'Grace Hopper',
            phone: '416-555-0123',
            streetAddress: '1 Queen St',
            city: 'Toronto',
            postalCode: 'M5H 2M5',
            issueDescription: 'Replace the faucet',
            status: 'cancelled',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      appointmentRepository.bookedSlots.add(
        BookedSlot(date: workday, timeSlot: '9 am - 11 am'),
      );

      await _pumpApp(
        tester,
        startAsAdmin: true,
        appointmentRepository: appointmentRepository,
      );
      await tester.tap(find.byKey(const ValueKey('overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-item-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review-details-morning')));
      await tester.pumpAndSettle();

      final colorScheme = Theme.of(
        tester.element(
          find.byKey(const ValueKey('review-details-slot-morning')),
        ),
      ).colorScheme;

      Chip pillFor(String label) => tester.widget<Chip>(
        find.ancestor(of: find.text(label), matching: find.byType(Chip)),
      );

      // A cancellation is a recorded outcome, so it carries the error tone.
      final cancelledPill = pillFor('Cancelled');
      expect(cancelledPill.backgroundColor, colorScheme.errorContainer);
      expect(
        tester.widget<Text>(find.text('Cancelled')).style?.color,
        colorScheme.onErrorContainer,
      );

      // A blocked-off hold shares the primary accent with booked slots.
      final blockedPill = pillFor('Blocked off');
      expect(blockedPill.backgroundColor, colorScheme.primaryContainer);
      expect(
        tester.widget<Text>(find.text('Blocked off')).style?.color,
        colorScheme.onPrimaryContainer,
      );

      // The slot icon follows the pill instead of the old error red. The pill
      // avatar uses the same icon, and the leading icon comes first.
      final leadingIcon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byKey(const ValueKey('review-details-slot-afternoon')),
              matching: find.byIcon(Icons.event_busy_outlined),
            )
            .first,
      );
      expect(leadingIcon.color, colorScheme.primary);
    },
  );

  testWidgets('Review screen nav bar navigates like other screens', (
    tester,
  ) async {
    await _pumpApp(tester, startAsAdmin: true);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-review')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-calendar')), findsOneWidget);

    // Choosing a nav destination leaves the review screen and shows the
    // selected tab, matching the block-off screen's behavior.
    await tester.tap(find.byKey(const ValueKey('nav-announcements')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('announcements-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-calendar')), findsNothing);
  });

  testWidgets('Admin Login nav bar navigates like other screens', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-adminLogin')));
    await tester.pumpAndSettle();

    expect(find.text('Admin Login'), findsOneWidget);

    // Choosing a nav destination leaves the admin login screen and shows the
    // selected tab, matching the landing (Service Area) screen's behavior.
    await tester.tap(find.byKey(const ValueKey('nav-announcements')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('announcements-screen')), findsOneWidget);
    expect(find.text('Admin Login'), findsNothing);
  });

  testWidgets('Admin Logout signs out and restores the public menu', (
    tester,
  ) async {
    await _pumpApp(tester, startAsAdmin: true);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('menu-item-adminLogout')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-adminLogin')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('menu-item-adminLogout')));
    await tester.pumpAndSettle();

    // Logging out redirects the admin to the public landing screen.
    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('menu-item-adminLogin')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-adminLogout')), findsNothing);
    expect(find.byKey(const ValueKey('menu-item-review')), findsNothing);
    expect(find.byKey(const ValueKey('menu-item-blockOff')), findsNothing);
  });

  testWidgets('Admin Login menu opens the email/password screen', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-adminLogin')));
    await tester.pumpAndSettle();

    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-sign-in')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-login-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
  });

  testWidgets('Email account without admin claim cannot access admin UI', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-adminLogin')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-email')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('admin-sign-in')));
    await tester.pumpAndSettle();

    expect(
      find.text('This account is not an administrator account.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('admin-email')), findsOneWidget);
  });

  testWidgets('Admin Login explains invalid Firebase credentials', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      adminSignInError: FirebaseAuthException(code: 'invalid-credential'),
    );
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-adminLogin')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-email')),
      'admin@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const ValueKey('admin-sign-in')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Email or password is incorrect. Check the Authentication Emulator account and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Admin Login explains Auth Emulator connectivity errors', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      adminSignInError: FirebaseAuthException(code: 'network-request-failed'),
    );
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-adminLogin')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-email')),
      'admin@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-password')),
      'some-password',
    );
    await tester.tap(find.byKey(const ValueKey('admin-sign-in')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Could not reach the Authentication Emulator. Check that demo-bserv is running and try again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Claimed admin signs in and receives admin menu actions', (
    tester,
  ) async {
    await _pumpApp(tester, adminClaim: true);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-adminLogin')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('admin-email')),
      'admin@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-password')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('admin-sign-in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-item-review')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-blockOff')), findsOneWidget);
  });

  testWidgets('Service area screen offers the type-of-service dropdown', (
    tester,
  ) async {
    await _pumpApp(tester);

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('service-type-dropdown')),
    );
    expect(dropdown.initialValue, 'heatingSystemMaintenance');
    expect(find.text('Type of service'), findsOneWidget);
    expect(find.text('Heating system maintenance'), findsOneWidget);
  });

  testWidgets('the type-of-service dropdown lists every configured type', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('service-type-dropdown')));
    await tester.pumpAndSettle();
    // Adding or removing an entry in ServiceCatalog.serviceTypes changes the
    // dropdown with no other code change.
    for (final type in ServiceCatalog.serviceTypes.values) {
      expect(find.text(type.label), findsWidgets, reason: type.label);
    }

    final last = ServiceCatalog.serviceTypes.entries.last;
    await tester.tap(find.text(last.value.label).last);
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('service-type-dropdown')),
    );
    expect(dropdown.initialValue, last.key);
  });

  testWidgets('Book tab app bar steps back from details to calendar to map', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, startAsAuthenticated: true);

    // The map has no app-bar heading yet, so it has no back arrow either.
    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Book')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('hotspot-downtown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-calendar')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Booking Details'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('booking-calendar-appbar-back')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('booking-calendar')), findsNothing);
    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking-calendar-appbar-back')),
      findsNothing,
    );

    // Continuing again reaches the contact form, which backs out to the
    // calendar.
    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('booking-slot-midday')),
    );
    await tester.tap(find.byKey(const ValueKey('booking-slot-midday')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('continue-selected-slot')),
    );
    await tester.tap(find.byKey(const ValueKey('continue-selected-slot')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('customer-name')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('customer-details-appbar-back')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('booking-calendar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('booking-calendar-appbar-back')),
      findsOneWidget,
    );
  });

  testWidgets('Admin overlays leave no nav destination highlighted', (
    tester,
  ) async {
    await _pumpApp(tester, startAsAdmin: true);
    expect(find.byType(NavigationBarTheme), findsNothing);

    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-blockOff')));
    await tester.pumpAndSettle();

    final overlayTheme = tester.widget<NavigationBarTheme>(
      find.byType(NavigationBarTheme),
    );
    expect(overlayTheme.data.indicatorColor, Colors.transparent);

    // Choosing a tab leaves the overlay and restores the tab highlight.
    await tester.tap(find.byKey(const ValueKey('nav-book')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBarTheme), findsNothing);
    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
  });

  testWidgets('Admin Work Notes opens from the menu and saves notes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final workNotesRepository = _TestWorkNotesRepository(
      notes: 'Order filters.',
    );
    await _pumpApp(
      tester,
      startAsAdmin: true,
      workNotesRepository: workNotesRepository,
    );

    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-item-workNotes')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Work Notes'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('work-notes-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('work-notes-card')), findsOneWidget);
    expect(find.text('Order filters.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      'Call back the supplier.',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-work-notes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-work-notes')));
    await tester.pumpAndSettle();

    expect(workNotesRepository.savedNotes, 'Call back the supplier.');
    expect(find.text('Work notes saved.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('work-notes-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('work-notes-card')), findsNothing);
    expect(find.byKey(const ValueKey('service-type-dropdown')), findsOneWidget);
  });

  testWidgets('landing app bar shows the company logo for the current theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, startAsAuthenticated: true);

    final logo = find.descendant(
      of: find.byType(AppBar),
      matching: find.byKey(const ValueKey('company-logo')),
    );
    expect(logo, findsOneWidget);
    // The test binding starts in the light theme.
    expect(
      (tester.widget<Image>(logo).image as AssetImage).assetName,
      'assets/images/logo_light.png',
    );

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Image>(logo).image as AssetImage).assetName,
      'assets/images/logo_dark.png',
    );

    // The logo belongs to the landing screen; later booking steps show text.
    await tester.tap(find.byKey(const ValueKey('hotspot-downtown')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continue-service-area')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('company-logo')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Booking Details'),
      ),
      findsOneWidget,
    );
  });
}
