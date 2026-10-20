import 'package:bserv/app/app_config.dart';
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
}
