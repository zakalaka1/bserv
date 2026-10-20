import 'package:bserv/app/app_config.dart';
import 'package:bserv/app/book_service_app.dart';
import 'package:bserv/data/appointments/appointment_repository.dart';
import 'package:bserv/data/content/business_content_repository.dart';
import 'package:bserv/services/auth_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bserv/features/booking/customer_details_screen.dart';
import 'package:bserv/features/booking/blockoff_time_screen.dart';
import 'package:bserv/features/service_area/service_area_map.dart';

import 'dart:async';

class _TestAuthGateway implements AuthGateway {
  _TestAuthGateway({
    this.adminClaim = false,
    bool startAsAdmin = false,
    bool startAsAuthenticated = false,
    this.adminSignInError,
  }) : _state = AuthState(
         isAuthenticated: startAsAdmin || startAsAuthenticated,
         isAdmin: startAsAdmin,
       );

  final bool adminClaim;
  final Object? adminSignInError;
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
    _state = AuthState(isAuthenticated: value, isAdmin: value && isAdmin);
    _authStateController.add(_state);
  }

  Future<void> dispose() => _authStateController.close();
}

class _TestAppointmentRepository implements AppointmentRepository {
  _TestAppointmentRepository({
    this.latestAppointment,
    List<BlockedOffTime> blockedOffTimes = const [],
  }) : _blocked = [...blockedOffTimes];

  final drafts = <AppointmentDraft>[];
  final AppointmentRecord? latestAppointment;
  final List<BlockedOffTime> _blocked;
  final bookedSlots = <BookedSlot>[];
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

Future<_TestAuthGateway> _pumpApp(
  WidgetTester tester, {
  bool adminClaim = false,
  bool startAsAdmin = false,
  bool startAsAuthenticated = false,
  Object? adminSignInError,
  AppointmentRepository? appointmentRepository,
  BusinessContentRepository? businessContentRepository,
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
  await tester.pumpWidget(
    BookServiceApp(
      authGateway: authGateway,
      appointmentRepository:
          appointmentRepository ?? _TestAppointmentRepository(),
      businessContentRepository: contentRepository,
    ),
  );
  return authGateway;
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

    expect(find.text('Select Service Area'), findsOneWidget);
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
    while (selectedWeekday.weekday > DateTime.friday) {
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
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Block off time'), findsOneWidget);
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
    expect(find.text('Select Service Area'), findsOneWidget);
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

    var nextSunday = now;
    while (nextSunday.weekday != DateTime.sunday) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }
    expect(calendar.selectableDayPredicate!(nextSunday), isFalse);
    const slotIds = ['morning', 'midday', 'afternoon', 'evening'];
    for (final slotId in slotIds) {
      expect(find.byKey(ValueKey('booking-slot-$slotId')), findsOneWidget);
      final slotTile = tester.widget(
        find.byKey(ValueKey('booking-slot-$slotId')),
      );
      expect((slotTile as dynamic).enabled, isFalse);
    }
    final continueBeforeSelection = tester.widget<FilledButton>(
      find.byKey(const ValueKey('continue-selected-slot')),
    );
    expect(continueBeforeSelection.onPressed, isNull);

    final availableDay = find.text('${nextAvailableDate.day}');
    await tester.ensureVisible(availableDay);
    await tester.pumpAndSettle();
    await tester.tap(availableDay);
    await tester.pumpAndSettle();

    bool slotIsEnabled(String slotId) {
      final tile = tester.widget(find.byKey(ValueKey('booking-slot-$slotId')));
      return (tile as dynamic).enabled == true;
    }

    expect(slotIds.any(slotIsEnabled), isTrue);
    expect(slotIsEnabled('morning'), isFalse);
    expect(slotIsEnabled('midday'), isTrue);
    expect(find.text('Unavailable for this date'), findsOneWidget);
    final slotId = slotIds.firstWhere(slotIsEnabled);
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
      find.descendant(of: find.byType(AppBar), matching: find.text('Book')),
      findsOneWidget,
    );
    expect(find.text('Enter contact details'), findsOneWidget);
    expect(find.text('$dateLabel · $timeLabel'), findsOneWidget);
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
    expect(find.text('Select Service Area'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-details-back')), findsNothing);
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
  });

  testWidgets('Provider sign-in authenticates and exposes sign out', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('nav-login')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sign-in-google')));
    await tester.pumpAndSettle();

    expect(find.text('Select Service Area'), findsOneWidget);
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
      expect(
        find.byKey(const ValueKey('blockoff-screen-back')),
        findsOneWidget,
      );

      var selectedWeekday = DateUtils.dateOnly(DateTime.now());
      while (selectedWeekday.weekday > DateTime.friday) {
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
      await tester.tap(find.byKey(const ValueKey('blockoff-screen-back')));
      await tester.pumpAndSettle();
      expect(find.text('Select Service Area'), findsOneWidget);
    },
  );

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
    expect(find.text('Select Service Area'), findsOneWidget);
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

    expect(find.text('Select Service Area'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overflow-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-item-review')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-item-blockOff')), findsOneWidget);
  });
}
