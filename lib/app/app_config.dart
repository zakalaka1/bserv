// ============================================================================
// APP CONFIGURATION - adjust business settings here.
// Values are compile-time constants: change them, then rebuild the app.
// ============================================================================

/// Which days customers can book and how far ahead.
abstract final class BookingSchedule {
  /// Days of the week the service operates (`DateTime.monday` is 1 ... `sunday` is 7).
  ///
  /// This is the only place the working week is set: add or remove a weekday to
  /// widen, shorten or shift it. Every calendar, booking and cancellation rule
  /// follows this set, so leave at least one day out.
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

  /// Customers may cancel no later than this many working days before the
  /// appointment date. Days outside [workingWeekdays] are skipped when counting
  /// back.
  static const int cancellationLeadWorkdays = 3;

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

  /// The last day a customer may cancel an appointment booked for
  /// [appointmentDate]; counts back [cancellationLeadWorkdays] working days.
  static DateTime cancellationDeadline(DateTime appointmentDate) {
    var day = appointmentDate;
    var remaining = cancellationLeadWorkdays;
    while (remaining > 0) {
      day = _addDays(day, -1);
      if (workingWeekdays.contains(day.weekday)) remaining--;
    }
    return day;
  }

  /// Whether a customer may still cancel on [today]. Both dates must be
  /// date-only; the deadline itself is inclusive.
  static bool isCancellableOn(
    DateTime appointmentDate, {
    required DateTime today,
  }) => !today.isAfter(cancellationDeadline(appointmentDate));
}

// ============================================================================
// SERVICES OFFERED - edit the service types shown on the landing page here.
// ============================================================================

/// The service types a booking can be started for, keyed by a unique id.
///
/// This is the only place a service type is added or removed: give each entry a
/// unique id, the `storageValue` written to the appointment document, and the
/// `label` customers and admins see. The first entry is the default selection on
/// the landing page; the dropdown, the booking flow, and the appointment
/// screens all follow automatically.
///
/// Removing a type is safe: appointments already saved with its storage value
/// keep showing that value in the order they were stored.
abstract final class ServiceCatalog {
  static const Map<String, ({String storageValue, String label})> serviceTypes =
      {
        'heatingSystemMaintenance': (
          storageValue: 'maintain heat',
          label: 'Heating system maintenance',
        ),
        'branchShredding': (
          storageValue: 'branch sredding',
          label: 'Branch shredding',
        ),
      };
}

// ============================================================================
// SERVICE AREA COVERAGE - edit the service areas, map outlines, and bookable
// postal codes here.
// ============================================================================

/// Where the business operates: how close the map opens, the outline drawn for
/// each service area on that map and the postal-code prefixes that are allowed
/// to book.
///
/// This is plain data, so coverage can be adjusted here and picked up by a
/// rebuild without touching the map or booking code.
abstract final class ServiceAreaCoverage {
  /// Zoom level the service-area map opens at, so the map starts on the GTA
  /// instead of the whole region.
  ///
  /// Each step doubles the size of everything on screen: 10 shows the GTA plus
  /// the surrounding cities, 11 (the default) fills a desktop window with the
  /// GTA while keeping all three markers on screen in any window about 470 px
  /// wide or more, and 13 and up draw the outlines large enough to tap away
  /// from the centre markers. Lower it if a narrower window clips the outer
  /// areas; the map can still be panned and zoomed by hand.
  static const double mapInitialZoom = 11;

  /// The service areas offered on the map, keyed by the id used in
  /// [areaBoundaries].
  ///
  /// This is the only place a service area is added or removed: give each entry
  /// a unique id, the marker's centre in decimal degrees, and the name shown on
  /// the map and in the booking flow. Add the matching outline to
  /// [areaBoundaries] so the area is drawn and tappable; an area with no
  /// outline still shows its marker but is not drawn as a region.
  static const Map<String, ({double latitude, double longitude, String name})>
  serviceAreas = {
    'downtown': (latitude: 43.6532, longitude: -79.3832, name: 'Downtown'),
    'etobicoke': (latitude: 43.6205, longitude: -79.5132, name: 'Etobicoke'),
    'scarborough': (
      latitude: 43.7731,
      longitude: -79.2578,
      name: 'Scarborough',
    ),
  };

  /// Outline of each service area, keyed by the id used in [serviceAreas].
  ///
  /// Coordinates are WGS84 decimal degrees written as `[latitude, longitude]`
  /// pairs - latitude first, matching `LatLng(latitude, longitude)` in the map
  /// code. Most map tools (geojson.io, "copy coordinates" in Google Maps)
  /// print the pair the other way round as `[longitude, latitude]`, so swap
  /// each pair before pasting it here.
  ///
  /// Each entry is one polygon ring: the corners listed in order around the
  /// perimeter. The ring closes automatically (the last corner joins back to
  /// the first), so the first corner must not be repeated at the end. Keeping
  /// the order clockwise (as below) is recommended.
  ///
  /// An area that is missing from this map, or that has fewer than three
  /// corners, simply renders without an outline - it is still selectable using
  /// its map marker.
  ///
  /// The squares below are placeholders centred on each area; replace them with
  /// the real street-level vertices.
  static const Map<String, List<List<double>>> areaBoundaries = {
    'downtown': [
      [43.6412, -79.3952],
      [43.6652, -79.3952],
      [43.6652, -79.3712],
      [43.6412, -79.3712],
    ],
    'etobicoke': [
      [43.5862159649061, -79.54002898689149],
      [43.6066031, -79.5575452],
      [43.6283813, -79.4762115],
      [43.5950535, -79.5015975],
    ],
    'scarborough': [
      [43.7611, -79.2698],
      [43.7851, -79.2698],
      [43.7851, -79.2458],
      [43.7611, -79.2458],
    ],
  };

  /// Forward Sortation Areas (the first three postal-code characters, upper
  /// case) that are inside the service area. A customer whose postal code
  /// starts with a prefix that is not listed here is told at booking that they
  /// are outside the service area.
  ///
  /// Replace the placeholder below with the real list, one prefix per entry,
  /// for example: 'M5A', 'M5V', 'M5T'.
  static const Set<String> allowedPostalPrefixes = {
    'M5V', // Placeholder - replace with the real service-area prefixes.
    'M8V',
  };

  /// Whether [postalCode] belongs to a serviced Forward Sortation Area.
  ///
  /// Spaces and letter case are ignored, so 'm5v 2t6', 'M5V2T6' and 'M5V 2T6'
  /// all resolve to the 'M5V' prefix.
  static bool isServicedPostalCode(String postalCode) {
    final normalized = postalCode.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (normalized.length < 3) return false;
    return allowedPostalPrefixes.contains(normalized.substring(0, 3));
  }
}
