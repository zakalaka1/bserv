// ============================================================================
// APP CONFIGURATION - adjust business settings here.
// Values are compile-time constants: change them, then rebuild the app.
// ============================================================================

/// Which days customers can book and how far ahead.
abstract final class BookingSchedule {
  /// Days of the week the service operates (`DateTime.monday` is 1 ... `sunday` is 7).
  static const Set<int> workingWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  /// How many months ahead of today appointments can be booked.
  static const int monthsAhead = 3;

  /// Customers cannot book sooner than this many days from today
  /// (2 = the day after tomorrow). The admin can still block off earlier days.
  static const int minimumLeadDays = 2;

  static DateTime lastBookableDate(DateTime today) =>
      DateTime(today.year, today.month + monthsAhead, today.day);

  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// A working day inside the calendar range. [today] and [date] must be date-only.
  static bool isWorkingDate(DateTime date, {required DateTime today}) =>
      !date.isBefore(today) &&
      !date.isAfter(lastBookableDate(today)) &&
      workingWeekdays.contains(date.weekday);

  /// A working day a customer may book, respecting [minimumLeadDays].
  static bool isBookableDate(DateTime date, {required DateTime today}) =>
      isWorkingDate(date, today: today) &&
      !date.isBefore(_addDays(today, minimumLeadDays));

  /// First working day on or after [today]; a valid initial date for admin calendars.
  static DateTime firstWorkingDate(DateTime today) => _nextWorkingDay(today);

  /// First day a customer may book; a valid initial customer calendar date.
  static DateTime firstBookableDate(DateTime today) =>
      _nextWorkingDay(_addDays(today, minimumLeadDays));

  static DateTime _nextWorkingDay(DateTime from) {
    var day = from;
    while (!workingWeekdays.contains(day.weekday)) {
      day = _addDays(day, 1);
    }
    return day;
  }
}
