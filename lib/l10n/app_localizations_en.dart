// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Book Service';

  @override
  String get announcements => 'Notes & Pricing';

  @override
  String get notes => 'Notes';

  @override
  String get pricing => 'Pricing';

  @override
  String get pricingNotAvailable => 'Pricing information will be posted here.';

  @override
  String get updateNotesAndPricing => 'Update Notes and Pricing';

  @override
  String get notesHint => 'Add notes for customers';

  @override
  String get pricingHint => 'Add pricing information for customers';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving…';

  @override
  String get contentRequired => 'Enter content before saving.';

  @override
  String get contentSaved => 'Notes and pricing saved.';

  @override
  String get contentSaveFailed =>
      'Could not save Notes and Pricing. Please try again.';

  @override
  String get workNotes => 'Work Notes';

  @override
  String get workNotesHint => 'Add work notes';

  @override
  String get workNotesSaved => 'Work notes saved.';

  @override
  String get workNotesSaveFailed =>
      'Could not save work notes. Please try again.';

  @override
  String get book => 'Book';

  @override
  String get latest => 'Latest';

  @override
  String get latestAppointment => 'Latest Appointment';

  @override
  String get signInToSeeLatestAppointment =>
      'Sign in to see your latest appointment.';

  @override
  String get noLatestAppointment => 'You don\'t have any appointments yet.';

  @override
  String get latestAppointmentLoadFailed =>
      'Could not load your latest appointment. Please try again.';

  @override
  String get appointmentDateLabel => 'Date';

  @override
  String get appointmentTimeLabel => 'Time';

  @override
  String get appointmentStatusScheduled => 'Scheduled';

  @override
  String get appointmentStatusCancelled => 'Cancelled';

  @override
  String get appointmentStatusCompleted => 'Completed';

  @override
  String get appointmentPhotoStored =>
      'Photo provided with this booking and securely stored.';

  @override
  String get noAppointmentPhoto => 'No photo was provided with this booking.';

  @override
  String get login => 'Sign in';

  @override
  String get moreOptions => 'More options';

  @override
  String get switchToLeftHandedLayout => 'Switch to left-handed layout';

  @override
  String get switchToRightHandedLayout => 'Switch to right-handed layout';

  @override
  String get switchToDarkTheme => 'Switch to dark theme';

  @override
  String get switchToLightTheme => 'Switch to light theme';

  @override
  String get adminLoginMenu => 'Admin Login';

  @override
  String get adminLogoutMenu => 'Admin Logout';

  @override
  String get review => 'Review';

  @override
  String get reviewBookings => 'Review bookings';

  @override
  String get details => 'Details';

  @override
  String get bookingDetails => 'Booking Details';

  @override
  String get blockOff => 'Block-off';

  @override
  String get blockOffTitle => 'Block off time';

  @override
  String get selectDateToBlock =>
      'Select a date before choosing times to block.';

  @override
  String get selectTimeSlotsToBlock => 'Select time slots to block';

  @override
  String get blockedOffStatus => 'Blocked off';

  @override
  String get blockOffSaved => 'Blocked-off times saved.';

  @override
  String get blockOffSaveFailed =>
      'Could not save the blocked-off times. Try again.';

  @override
  String get free => 'Free';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get markCompleted => 'Complete';

  @override
  String get markScheduled => 'Schedule';

  @override
  String get markCancelled => 'Cancel';

  @override
  String get statusUpdateFailed =>
      'Could not update the appointment status. Try again.';

  @override
  String get cancelAppointment => 'Cancel appointment';

  @override
  String get cancelAppointmentPrompt => 'Are you sure?';

  @override
  String get cancelAppointmentMessage =>
      'This will cancel your appointment and free the time slot for another customer.';

  @override
  String get yes => 'Yes';

  @override
  String get appointmentCancelled => 'Your appointment was cancelled.';

  @override
  String get appointmentCancelFailed =>
      'Could not cancel your appointment. Please try again.';

  @override
  String get edit => 'Edit';

  @override
  String get appointmentUpdated => 'Appointment updated.';

  @override
  String get appointmentUpdateFailed =>
      'Could not update your appointment. Please try again.';

  @override
  String get reviewDetailsLoadFailed =>
      'Could not load this day\'s bookings. Try again.';

  @override
  String get addComment => 'Add comment';

  @override
  String get editComment => 'Edit comment';

  @override
  String get commentHint => 'Add a note about this appointment';

  @override
  String get commentSaved => 'Comment saved.';

  @override
  String get commentSaveFailed =>
      'Could not save the comment. Please try again.';

  @override
  String get phone => 'Phone';

  @override
  String get address => 'Address';

  @override
  String get eula => 'EULA';

  @override
  String get info => 'Info';

  @override
  String menuActionComingSoon(String item) {
    return '$item is not available yet.';
  }

  @override
  String get close => 'Close';

  @override
  String get selectServiceArea => 'Select Service Area';

  @override
  String get tapServiceArea => 'Tap a highlighted area to continue.';

  @override
  String get typeOfService => 'Type of service';

  @override
  String get continueBooking => 'Continue';

  @override
  String get chooseAppointmentDateAndTime => 'Choose appointment date and time';

  @override
  String serviceAreaForBooking(String area) {
    return 'Service area: $area';
  }

  @override
  String serviceTypeForBooking(String type) {
    return 'Type of service: $type';
  }

  @override
  String get changeServiceArea => 'Change service area';

  @override
  String get timeSlotMorning => '9 am - 11 am';

  @override
  String get timeSlotMidday => '11 am - 1 pm';

  @override
  String get timeSlotAfternoon => '1 pm - 3 pm';

  @override
  String get timeSlotEvening => '3 pm - 5 pm';

  @override
  String get selectDateForTimes => 'Select a date to check this time.';

  @override
  String get timeSlotUnavailable => 'Unavailable for this date';

  @override
  String get timeSlotBookedByCustomer => 'Already booked by a customer';

  @override
  String bookingSlotSelected(String date, String time) {
    return 'You selected $date at $time.';
  }

  @override
  String get customerDetailsTitle => 'Enter contact information';

  @override
  String get appointmentSummary => 'Appointment';

  @override
  String get customerName => 'Name';

  @override
  String get followUpPhoneRequired => 'Follow-up phone (required)';

  @override
  String get phoneRequired => 'Enter a follow-up phone number.';

  @override
  String get phoneInvalid =>
      'Use 9999999999, 999-999-9999, or 999-9999999 format.';

  @override
  String get numberAndStreet => 'Number and street';

  @override
  String get city => 'City';

  @override
  String get postalCodeRequired => 'Postal code (required)';

  @override
  String get postalCodeRequiredError => 'Enter a postal code.';

  @override
  String get postalCodeInvalid => 'Use A9A9A9 or A9A 9A9 postal-code format.';

  @override
  String get postalCodeOutsideServiceArea =>
      'This postal code is outside our service area.';

  @override
  String get natureOfIssue => 'Nature of the issue';

  @override
  String get addPhotoAttachment => 'Add photo attachment';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get photoPickerFailed =>
      'Could not open photo attachments. Please try again.';

  @override
  String get detailsReadyForReview => 'Details are ready for review.';

  @override
  String get bookedSuccessfully => 'Appointment Booked';

  @override
  String get bookingSaveFailed =>
      'Could not save your appointment. Please try again.';

  @override
  String get savingBooking => 'Saving appointment…';

  @override
  String get back => 'Back';

  @override
  String bookingDateTime(String date, String time) {
    return '$date · $time';
  }

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get providerSignInOnly => 'Use a provider account to continue.';

  @override
  String get providerDataPrivacy =>
      'We only use the information needed to sign you in; we don\'t access or store the rest of your provider account.';

  @override
  String get loginWithGoogle => 'Sign in with Google';

  @override
  String get loginWithFacebook => 'Sign in with Facebook';

  @override
  String get cancel => 'Cancel';

  @override
  String get signedIn => 'You are signed in';

  @override
  String get accountReady => 'Your account is ready to continue.';

  @override
  String get signOut => 'Sign out';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get adminSignInPrompt => 'Sign in with your administrator account.';

  @override
  String get emailAddress => 'Email address';

  @override
  String get emailRequired => 'Enter your email address.';

  @override
  String get password => 'Password';

  @override
  String get passwordRequired => 'Enter your password.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get adminSignInFailed => 'Unable to sign in with these credentials.';

  @override
  String get adminInvalidCredentials =>
      'Email or password is incorrect. Check the Authentication Emulator account and try again.';

  @override
  String get adminConnectionFailed =>
      'Could not reach the Authentication Emulator. Check that demo-bserv is running and try again.';

  @override
  String get adminTooManyAttempts =>
      'Too many sign-in attempts. Wait a moment and try again.';

  @override
  String get adminAccessRequired =>
      'This account is not an administrator account.';

  @override
  String get signInFailed => 'We could not sign you in. Please try again.';

  @override
  String get mapAttribution => '© OpenStreetMap contributors';

  @override
  String get announcementDate => '2026-10-02';

  @override
  String get announcementHeading => 'Service update';

  @override
  String get announcementMessage =>
      'We are updating our service schedule. Please check here for the latest availability.';

  @override
  String get loginComingSoon => 'Sign in will be available soon.';
}
