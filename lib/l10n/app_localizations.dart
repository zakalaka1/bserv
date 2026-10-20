import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Service'**
  String get appTitle;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Notes & Pricing'**
  String get announcements;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @pricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get pricing;

  /// No description provided for @pricingNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Pricing information will be posted here.'**
  String get pricingNotAvailable;

  /// No description provided for @updateNotesAndPricing.
  ///
  /// In en, this message translates to:
  /// **'Update Notes and Pricing'**
  String get updateNotesAndPricing;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Add notes for customers'**
  String get notesHint;

  /// No description provided for @pricingHint.
  ///
  /// In en, this message translates to:
  /// **'Add pricing information for customers'**
  String get pricingHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @contentRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter content before saving.'**
  String get contentRequired;

  /// No description provided for @contentSaved.
  ///
  /// In en, this message translates to:
  /// **'Notes and pricing saved.'**
  String get contentSaved;

  /// No description provided for @contentSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save Notes and Pricing. Please try again.'**
  String get contentSaveFailed;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @latestAppointment.
  ///
  /// In en, this message translates to:
  /// **'Latest Appointment'**
  String get latestAppointment;

  /// No description provided for @signInToSeeLatestAppointment.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your latest appointment.'**
  String get signInToSeeLatestAppointment;

  /// No description provided for @noLatestAppointment.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any appointments yet.'**
  String get noLatestAppointment;

  /// No description provided for @latestAppointmentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your latest appointment. Please try again.'**
  String get latestAppointmentLoadFailed;

  /// No description provided for @appointmentDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get appointmentDateLabel;

  /// No description provided for @appointmentTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get appointmentTimeLabel;

  /// No description provided for @appointmentStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get appointmentStatusScheduled;

  /// No description provided for @appointmentStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get appointmentStatusCancelled;

  /// No description provided for @appointmentStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get appointmentStatusCompleted;

  /// No description provided for @appointmentPhotoStored.
  ///
  /// In en, this message translates to:
  /// **'Photo provided with this booking and securely stored.'**
  String get appointmentPhotoStored;

  /// No description provided for @noAppointmentPhoto.
  ///
  /// In en, this message translates to:
  /// **'No photo was provided with this booking.'**
  String get noAppointmentPhoto;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get login;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @switchToLeftHandedLayout.
  ///
  /// In en, this message translates to:
  /// **'Switch to left-handed layout'**
  String get switchToLeftHandedLayout;

  /// No description provided for @switchToRightHandedLayout.
  ///
  /// In en, this message translates to:
  /// **'Switch to right-handed layout'**
  String get switchToRightHandedLayout;

  /// No description provided for @switchToDarkTheme.
  ///
  /// In en, this message translates to:
  /// **'Switch to dark theme'**
  String get switchToDarkTheme;

  /// No description provided for @switchToLightTheme.
  ///
  /// In en, this message translates to:
  /// **'Switch to light theme'**
  String get switchToLightTheme;

  /// No description provided for @adminLoginMenu.
  ///
  /// In en, this message translates to:
  /// **'Admin Login'**
  String get adminLoginMenu;

  /// No description provided for @adminLogoutMenu.
  ///
  /// In en, this message translates to:
  /// **'Admin Logout'**
  String get adminLogoutMenu;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @blockOff.
  ///
  /// In en, this message translates to:
  /// **'Block-off'**
  String get blockOff;

  /// No description provided for @blockOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Block off time'**
  String get blockOffTitle;

  /// No description provided for @selectDateToBlock.
  ///
  /// In en, this message translates to:
  /// **'Select a date before choosing times to block.'**
  String get selectDateToBlock;

  /// No description provided for @selectTimeSlotsToBlock.
  ///
  /// In en, this message translates to:
  /// **'Select time slots to block'**
  String get selectTimeSlotsToBlock;

  /// No description provided for @blockOffSaved.
  ///
  /// In en, this message translates to:
  /// **'Blocked-off times saved.'**
  String get blockOffSaved;

  /// No description provided for @blockOffSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the blocked-off times. Try again.'**
  String get blockOffSaveFailed;

  /// No description provided for @eula.
  ///
  /// In en, this message translates to:
  /// **'EULA'**
  String get eula;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @menuActionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{item} is not available yet.'**
  String menuActionComingSoon(String item);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @selectServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Select Service Area'**
  String get selectServiceArea;

  /// No description provided for @tapServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Tap a highlighted area to continue.'**
  String get tapServiceArea;

  /// No description provided for @downtownServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Downtown'**
  String get downtownServiceArea;

  /// No description provided for @etobicokeServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Etobicoke'**
  String get etobicokeServiceArea;

  /// No description provided for @scarboroughServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Scarborough'**
  String get scarboroughServiceArea;

  /// No description provided for @continueBooking.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBooking;

  /// No description provided for @chooseAppointmentDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Choose appointment date and time'**
  String get chooseAppointmentDateAndTime;

  /// No description provided for @serviceAreaForBooking.
  ///
  /// In en, this message translates to:
  /// **'Service area: {area}'**
  String serviceAreaForBooking(String area);

  /// No description provided for @changeServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Change service area'**
  String get changeServiceArea;

  /// No description provided for @timeSlotMorning.
  ///
  /// In en, this message translates to:
  /// **'9 am - 11 am'**
  String get timeSlotMorning;

  /// No description provided for @timeSlotMidday.
  ///
  /// In en, this message translates to:
  /// **'11 am - 1 pm'**
  String get timeSlotMidday;

  /// No description provided for @timeSlotAfternoon.
  ///
  /// In en, this message translates to:
  /// **'1 pm - 3 pm'**
  String get timeSlotAfternoon;

  /// No description provided for @timeSlotEvening.
  ///
  /// In en, this message translates to:
  /// **'3 pm - 5 pm'**
  String get timeSlotEvening;

  /// No description provided for @selectDateForTimes.
  ///
  /// In en, this message translates to:
  /// **'Select a date to check this time.'**
  String get selectDateForTimes;

  /// No description provided for @timeSlotUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable for this date'**
  String get timeSlotUnavailable;

  /// No description provided for @timeSlotBookedByCustomer.
  ///
  /// In en, this message translates to:
  /// **'Already booked by a customer'**
  String get timeSlotBookedByCustomer;

  /// No description provided for @bookingSlotSelected.
  ///
  /// In en, this message translates to:
  /// **'You selected {date} at {time}.'**
  String bookingSlotSelected(String date, String time);

  /// No description provided for @customerDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter contact details'**
  String get customerDetailsTitle;

  /// No description provided for @appointmentSummary.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get appointmentSummary;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get customerName;

  /// No description provided for @followUpPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Follow-up phone (required)'**
  String get followUpPhoneRequired;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a follow-up phone number.'**
  String get phoneRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 9999999999, 999-999-9999, or 999-9999999 format.'**
  String get phoneInvalid;

  /// No description provided for @numberAndStreet.
  ///
  /// In en, this message translates to:
  /// **'Number and street'**
  String get numberAndStreet;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @postalCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Postal code (required)'**
  String get postalCodeRequired;

  /// No description provided for @postalCodeRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Enter a postal code.'**
  String get postalCodeRequiredError;

  /// No description provided for @postalCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use A9A9A9 or A9A 9A9 postal-code format.'**
  String get postalCodeInvalid;

  /// No description provided for @natureOfIssue.
  ///
  /// In en, this message translates to:
  /// **'Nature of the issue'**
  String get natureOfIssue;

  /// No description provided for @addPhotoAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add photo attachment'**
  String get addPhotoAttachment;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @photoPickerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open photo attachments. Please try again.'**
  String get photoPickerFailed;

  /// No description provided for @detailsReadyForReview.
  ///
  /// In en, this message translates to:
  /// **'Details are ready for review.'**
  String get detailsReadyForReview;

  /// No description provided for @bookedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Appointment Booked'**
  String get bookedSuccessfully;

  /// No description provided for @bookingSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your appointment. Please try again.'**
  String get bookingSaveFailed;

  /// No description provided for @savingBooking.
  ///
  /// In en, this message translates to:
  /// **'Saving appointment…'**
  String get savingBooking;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @bookingDateTime.
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String bookingDateTime(String date, String time);

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @providerSignInOnly.
  ///
  /// In en, this message translates to:
  /// **'Use a provider account to continue.'**
  String get providerSignInOnly;

  /// No description provided for @providerDataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'We only use the information needed to sign you in; we don\'t access or store the rest of your provider account.'**
  String get providerDataPrivacy;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get loginWithGoogle;

  /// No description provided for @loginWithFacebook.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Facebook'**
  String get loginWithFacebook;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'You are signed in'**
  String get signedIn;

  /// No description provided for @accountReady.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready to continue.'**
  String get accountReady;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @adminSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your administrator account.'**
  String get adminSignInPrompt;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get emailRequired;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get passwordRequired;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @adminSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in with these credentials.'**
  String get adminSignInFailed;

  /// No description provided for @adminInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect. Check the Authentication Emulator account and try again.'**
  String get adminInvalidCredentials;

  /// No description provided for @adminConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the Authentication Emulator. Check that demo-bserv is running and try again.'**
  String get adminConnectionFailed;

  /// No description provided for @adminTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in attempts. Wait a moment and try again.'**
  String get adminTooManyAttempts;

  /// No description provided for @adminAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'This account is not an administrator account.'**
  String get adminAccessRequired;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not sign you in. Please try again.'**
  String get signInFailed;

  /// No description provided for @mapAttribution.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttribution;

  /// No description provided for @announcementDate.
  ///
  /// In en, this message translates to:
  /// **'2026-10-02'**
  String get announcementDate;

  /// No description provided for @announcementHeading.
  ///
  /// In en, this message translates to:
  /// **'Service update'**
  String get announcementHeading;

  /// No description provided for @announcementMessage.
  ///
  /// In en, this message translates to:
  /// **'We are updating our service schedule. Please check here for the latest availability.'**
  String get announcementMessage;

  /// No description provided for @loginComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Sign in will be available soon.'**
  String get loginComingSoon;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
