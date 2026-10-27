import 'package:bserv/app/app_config.dart';
import 'package:bserv/features/service_area/service_area_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 2026-10-19 is a Monday.
  final monday = DateTime(2026, 10, 19);
  final saturday = DateTime(2026, 10, 24);
  final sunday = DateTime(2026, 10, 25);

  test('customers cannot book before the minimum lead time', () {
    expect(BookingSchedule.minimumLeadDays, 2);
    expect(BookingSchedule.isBookableDate(monday, today: monday), isFalse);
    expect(
      BookingSchedule.isBookableDate(DateTime(2026, 10, 20), today: monday),
      isFalse,
    );
    expect(
      BookingSchedule.isBookableDate(DateTime(2026, 10, 21), today: monday),
      isTrue,
    );
  });

  test('the admin can still block off today and tomorrow', () {
    expect(BookingSchedule.isWorkingDate(monday, today: monday), isTrue);
    expect(
      BookingSchedule.isWorkingDate(DateTime(2026, 10, 20), today: monday),
      isTrue,
    );
  });

  test('weekends are never bookable', () {
    expect(BookingSchedule.isBookableDate(saturday, today: monday), isFalse);
    expect(BookingSchedule.isBookableDate(sunday, today: monday), isFalse);
  });

  test('past dates and dates beyond the booking window are not bookable', () {
    expect(
      BookingSchedule.isWorkingDate(DateTime(2026, 10, 16), today: monday),
      isFalse,
    );
    final last = BookingSchedule.lastBookableDate(monday);
    expect(
      last,
      DateTime(
        monday.year,
        monday.month + BookingSchedule.monthsAhead,
        monday.day,
      ),
    );
    expect(
      BookingSchedule.isWorkingDate(
        last.add(const Duration(days: 1)),
        today: monday,
      ),
      isFalse,
    );
  });

  test('firstBookableDate is the day after tomorrow, skipping weekends', () {
    expect(BookingSchedule.firstBookableDate(monday), DateTime(2026, 10, 21));
    // Thursday + 2 days is Saturday, so the next working day is Monday.
    expect(
      BookingSchedule.firstBookableDate(DateTime(2026, 10, 22)),
      DateTime(2026, 10, 26),
    );
    expect(BookingSchedule.firstBookableDate(saturday), DateTime(2026, 10, 26));
    expect(BookingSchedule.firstBookableDate(sunday), DateTime(2026, 10, 27));
  });

  test('firstWorkingDate skips only the weekend', () {
    expect(BookingSchedule.firstWorkingDate(monday), monday);
    expect(BookingSchedule.firstWorkingDate(saturday), DateTime(2026, 10, 26));
  });

  test('the cancellation deadline counts back three working days', () {
    expect(BookingSchedule.cancellationLeadWorkdays, 3);
    // Monday: Fri, Thu, Wed of the previous week.
    expect(
      BookingSchedule.cancellationDeadline(monday),
      DateTime(2026, 10, 14),
    );
    // Tuesday: Mon, Fri, Thu (the weekend is skipped).
    expect(
      BookingSchedule.cancellationDeadline(DateTime(2026, 10, 20)),
      DateTime(2026, 10, 15),
    );
    // Thursday: Wed, Tue, Mon.
    expect(
      BookingSchedule.cancellationDeadline(DateTime(2026, 10, 22)),
      DateTime(2026, 10, 19),
    );
  });

  test('cancelling is allowed up to and including the deadline', () {
    expect(BookingSchedule.isCancellableOn(monday, today: monday), isFalse);
    expect(
      BookingSchedule.isCancellableOn(monday, today: DateTime(2026, 10, 14)),
      isTrue,
    );
    expect(
      BookingSchedule.isCancellableOn(monday, today: DateTime(2026, 10, 16)),
      isFalse,
    );
    // A date already in the past cannot be cancelled either.
    expect(
      BookingSchedule.isCancellableOn(DateTime(2026, 10, 12), today: monday),
      isFalse,
    );
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
