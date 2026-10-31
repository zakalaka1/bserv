import 'package:bserv/app/app_config.dart';
import 'package:bserv/features/service_area/service_area_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fixed Monday anchor. The rules below are checked against whatever
  // `BookingSchedule.workingWeekdays` configures, so changing the working week
  // does not require updating these tests.
  final anchor = DateTime(2026, 10, 19);

  DateTime addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  bool isWorking(DateTime date) =>
      BookingSchedule.workingWeekdays.contains(date.weekday);

  /// [count] consecutive dates from [anchor], each with its day offset.
  List<({int offset, DateTime date})> datesFromAnchor([int count = 14]) => [
    for (var offset = 0; offset < count; offset++)
      (offset: offset, date: addDays(anchor, offset)),
  ];

  test('the schedule configuration is valid', () {
    expect(BookingSchedule.workingWeekdays, isNotEmpty);
    expect(
      BookingSchedule.workingWeekdays.length,
      lessThan(7),
      reason: 'the working week must leave at least one day out',
    );
    for (final weekday in BookingSchedule.workingWeekdays) {
      expect(
        weekday,
        inInclusiveRange(DateTime.monday, DateTime.sunday),
        reason: 'weekday $weekday',
      );
    }
    expect(BookingSchedule.minimumLeadDays, greaterThanOrEqualTo(0));
    expect(BookingSchedule.cancellationLeadWorkdays, greaterThan(0));
    expect(BookingSchedule.monthsAhead, greaterThan(0));
  });

  test('a date is a working date exactly when its weekday is configured', () {
    for (final entry in datesFromAnchor()) {
      expect(
        BookingSchedule.isWorkingDate(entry.date, today: anchor),
        isWorking(entry.date),
        reason: '${entry.date} (weekday ${entry.date.weekday})',
      );
    }
  });

  test('the admin can still block off today and tomorrow', () {
    // The lead time only holds customers back; it never closes the admin's
    // calendar, on any weekday.
    for (final entry in datesFromAnchor(BookingSchedule.minimumLeadDays + 1)) {
      expect(
        BookingSchedule.isWorkingDate(entry.date, today: anchor),
        isWorking(entry.date),
        reason: '${entry.date} (weekday ${entry.date.weekday})',
      );
    }
  });

  test('customers cannot book before the minimum lead time', () {
    expect(BookingSchedule.minimumLeadDays, greaterThanOrEqualTo(0));
    for (final entry in datesFromAnchor()) {
      expect(
        BookingSchedule.isBookableDate(entry.date, today: anchor),
        isWorking(entry.date) &&
            entry.offset >= BookingSchedule.minimumLeadDays,
        reason: '${entry.date} (weekday ${entry.date.weekday})',
      );
    }
  });

  test('days outside the working week are never bookable', () {
    final daysOff = datesFromAnchor(28)
        .where((entry) => !isWorking(entry.date))
        .toList();
    expect(
      daysOff,
      isNotEmpty,
      reason: 'the working week must leave at least one day out',
    );
    for (final entry in daysOff) {
      expect(
        BookingSchedule.isBookableDate(entry.date, today: anchor),
        isFalse,
        reason: '${entry.date} (weekday ${entry.date.weekday})',
      );
    }
  });

  test('past dates and dates beyond the booking window are not bookable', () {
    expect(
      BookingSchedule.isWorkingDate(addDays(anchor, -1), today: anchor),
      isFalse,
    );

    final last = BookingSchedule.lastBookableDate(anchor);
    expect(
      last,
      DateTime(
        anchor.year,
        anchor.month + BookingSchedule.monthsAhead,
        anchor.day,
      ),
    );

    // The first configured working day past the window is still outside it.
    var beyond = addDays(last, 1);
    while (!isWorking(beyond)) {
      beyond = addDays(beyond, 1);
    }
    expect(BookingSchedule.isWorkingDate(beyond, today: anchor), isFalse);
    expect(BookingSchedule.isBookableDate(beyond, today: anchor), isFalse);
  });

  test('firstWorkingDate is the next configured working day', () {
    for (final entry in datesFromAnchor()) {
      final first = BookingSchedule.firstWorkingDate(entry.date);
      expect(first.isBefore(entry.date), isFalse, reason: '${entry.date}');
      expect(isWorking(first), isTrue, reason: '$first');
      expect(first.difference(entry.date).inDays, lessThan(7));
    }
  });

  test('firstBookableDate is the earliest bookable day on or after today', () {
    for (final entry in datesFromAnchor()) {
      final first = BookingSchedule.firstBookableDate(entry.date);
      expect(
        BookingSchedule.isBookableDate(first, today: entry.date),
        isTrue,
        reason: '$first',
      );
      for (var day = entry.date; day.isBefore(first); day = addDays(day, 1)) {
        expect(
          BookingSchedule.isBookableDate(day, today: entry.date),
          isFalse,
          reason: '$day comes before $first',
        );
      }
    }
  });

  test('the cancellation deadline counts back the configured working days', () {
    expect(BookingSchedule.cancellationLeadWorkdays, greaterThan(0));
    for (final entry in datesFromAnchor()) {
      final deadline = BookingSchedule.cancellationDeadline(entry.date);
      expect(
        deadline.isAfter(entry.date),
        isFalse,
        reason: '${entry.date} -> $deadline',
      );
      expect(isWorking(deadline), isTrue, reason: '$deadline');

      // Exactly `cancellationLeadWorkdays` working days sit in
      // [deadline, appointment), and the deadline is the earliest of them.
      var workingDays = 0;
      for (
        var day = deadline;
        day.isBefore(entry.date);
        day = addDays(day, 1)
      ) {
        if (isWorking(day)) workingDays++;
      }
      expect(
        workingDays,
        BookingSchedule.cancellationLeadWorkdays,
        reason: '${entry.date} -> $deadline',
      );
    }
  });

  test('cancelling is allowed up to and including the deadline', () {
    for (final entry in datesFromAnchor()) {
      final deadline = BookingSchedule.cancellationDeadline(entry.date);
      expect(
        BookingSchedule.isCancellableOn(entry.date, today: deadline),
        isTrue,
        reason: '${entry.date} at its deadline',
      );
      expect(
        BookingSchedule.isCancellableOn(
          entry.date,
          today: addDays(deadline, 1),
        ),
        isFalse,
        reason: '${entry.date} one day late',
      );
      expect(
        BookingSchedule.isCancellableOn(
          entry.date,
          today: addDays(deadline, -1),
        ),
        isTrue,
        reason: '${entry.date} one day early',
      );
      expect(
        BookingSchedule.isCancellableOn(entry.date, today: entry.date),
        isFalse,
        reason: '${entry.date} on the day',
      );
    }
  });

  test(
    'every service area has a polygon boundary with three or more corners',
    () {
      expect(ServiceAreaCoverage.serviceAreas, isNotEmpty);
      for (final area in ServiceAreaCoverage.serviceAreas.entries) {
        expect(
          ServiceAreaCoverage.areaBoundaries[area.key],
          hasLength(greaterThanOrEqualTo(3)),
          reason: area.key,
        );
      }
    },
  );

  test('service areas and their outlines are configured together', () {
    expect(
      ServiceAreaCoverage.areaBoundaries.keys,
      unorderedEquals(ServiceAreaCoverage.serviceAreas.keys),
    );
  });

  test('the map list is built from the configured service areas', () {
    expect(
      serviceAreas.map((area) => area.id),
      orderedEquals(ServiceAreaCoverage.serviceAreas.keys),
    );
    expect(
      serviceAreas.map((area) => area.name),
      orderedEquals(
        ServiceAreaCoverage.serviceAreas.values.map((area) => area.name),
      ),
    );
  });

  test('service-area markers sit inside their drawn outlines', () {
    for (final area in serviceAreas) {
      final corners = area.boundary;
      final anchor = area.markerAnchor;
      double lowest(Iterable<double> values) =>
          values.reduce((a, b) => a < b ? a : b);
      double highest(Iterable<double> values) =>
          values.reduce((a, b) => a > b ? a : b);

      expect(
        anchor.latitude,
        inInclusiveRange(
          lowest(corners.map((corner) => corner.latitude)),
          highest(corners.map((corner) => corner.latitude)),
        ),
        reason: '${area.id} marker latitude',
      );
      expect(
        anchor.longitude,
        inInclusiveRange(
          lowest(corners.map((corner) => corner.longitude)),
          highest(corners.map((corner) => corner.longitude)),
        ),
        reason: '${area.id} marker longitude',
      );
    }
  });

  test('an area without an outline falls back to its configured centre', () {
    final area = ServiceArea(
      id: 'no-outline',
      center: serviceAreas.first.center,
      name: 'No outline',
    );

    expect(area.boundary, isEmpty);
    expect(area.markerAnchor, same(serviceAreas.first.center));
  });

  test('boundaries are latitude/longitude pairs', () {
    for (final boundary in ServiceAreaCoverage.areaBoundaries.values) {
      for (final corner in boundary) {
        expect(corner, hasLength(2));
        expect(corner[0], inInclusiveRange(-90, 90));
        expect(corner[1], inInclusiveRange(-180, 180));
      }
    }
  });

  test('only postal codes inside a listed FSA are serviced', () {
    expect(ServiceAreaCoverage.allowedPostalPrefixes, isNotEmpty);
    final prefix = ServiceAreaCoverage.allowedPostalPrefixes.first;
    expect(ServiceAreaCoverage.isServicedPostalCode('$prefix 2T6'), isTrue);
    expect(
      ServiceAreaCoverage.isServicedPostalCode('${prefix.toLowerCase()}2t6'),
      isTrue,
    );
    // 'Z' is not a valid Canadian FSA prefix, so this is never serviced.
    expect(ServiceAreaCoverage.isServicedPostalCode('Z9Z 9Z9'), isFalse);
    expect(ServiceAreaCoverage.isServicedPostalCode('M5'), isFalse);
    expect(ServiceAreaCoverage.isServicedPostalCode(''), isFalse);
  });

  test('every service type is fully configured', () {
    expect(ServiceCatalog.serviceTypes, isNotEmpty);
    final storageValues = <String>{};
    for (final entry in ServiceCatalog.serviceTypes.entries) {
      expect(entry.key.trim(), isNotEmpty);
      expect(entry.value.storageValue.trim(), isNotEmpty, reason: entry.key);
      expect(entry.value.label.trim(), isNotEmpty, reason: entry.key);
      expect(
        storageValues.add(entry.value.storageValue),
        isTrue,
        reason: 'duplicate storage value "${entry.value.storageValue}"',
      );
    }
  });

  test('the service-type list is built from the configured types', () {
    expect(serviceTypes, isNotEmpty);
    expect(
      serviceTypes.map((serviceType) => serviceType.id),
      orderedEquals(ServiceCatalog.serviceTypes.keys),
    );
    expect(
      serviceTypes.map((serviceType) => serviceType.storageValue),
      orderedEquals(
        ServiceCatalog.serviceTypes.values.map((type) => type.storageValue),
      ),
    );
    expect(
      serviceTypes.map((serviceType) => serviceType.label),
      orderedEquals(
        ServiceCatalog.serviceTypes.values.map((type) => type.label),
      ),
    );
  });

  test('a stored service-type value resolves to its configured label', () {
    for (final entry in ServiceCatalog.serviceTypes.entries) {
      expect(serviceTypeLabel(entry.value.storageValue), entry.value.label);
      expect(
        serviceTypeLabel('  ${entry.value.storageValue}  '),
        entry.value.label,
      );
    }
    // Unknown or missing values are shown as they were stored.
    expect(serviceTypeLabel('legacy value'), 'legacy value');
    expect(serviceTypeLabel(''), '');
    expect(serviceTypeLabel(null), '');
  });
}
