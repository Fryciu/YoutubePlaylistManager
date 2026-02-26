import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'YouTube Playlist Manager'**
  String get appTitle;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Deletion History'**
  String get historyTitle;

  /// No description provided for @savedPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Saved Playlists'**
  String get savedPlaylists;

  /// No description provided for @removeVideos.
  ///
  /// In en, this message translates to:
  /// **'Remove videos from playlist'**
  String get removeVideos;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @forDeletion.
  ///
  /// In en, this message translates to:
  /// **'To be deleted'**
  String get forDeletion;

  /// No description provided for @statusDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted: {count} videos'**
  String statusDeleted(int count);

  /// No description provided for @apiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Paste client_secret.json content here'**
  String get apiKeyLabel;

  /// No description provided for @saveApi.
  ///
  /// In en, this message translates to:
  /// **'Save API'**
  String get saveApi;

  /// No description provided for @jsonError.
  ///
  /// In en, this message translates to:
  /// **'JSON Error'**
  String get jsonError;

  /// No description provided for @apiKeyExists.
  ///
  /// In en, this message translates to:
  /// **'API Key exists'**
  String get apiKeyExists;

  /// No description provided for @noApiKey.
  ///
  /// In en, this message translates to:
  /// **'No API Key'**
  String get noApiKey;

  /// No description provided for @addNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add new playlist'**
  String get addNewPlaylist;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistName;

  /// No description provided for @playlistId.
  ///
  /// In en, this message translates to:
  /// **'Playlist ID or link'**
  String get playlistId;

  /// No description provided for @deleteCountHint.
  ///
  /// In en, this message translates to:
  /// **'Number of videos (\'all\' or digit)'**
  String get deleteCountHint;

  /// No description provided for @addPlaylistBtn.
  ///
  /// In en, this message translates to:
  /// **'Add Playlist'**
  String get addPlaylistBtn;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @noName.
  ///
  /// In en, this message translates to:
  /// **'No Name'**
  String get noName;

  /// No description provided for @deleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deletion finished and history saved.'**
  String get deleteSuccess;

  /// No description provided for @idorlink.
  ///
  /// In en, this message translates to:
  /// **'ID or link to the playlist'**
  String get idorlink;

  /// No description provided for @helptitle.
  ///
  /// In en, this message translates to:
  /// **'How to use the app?'**
  String get helptitle;

  /// No description provided for @helpstep1.
  ///
  /// In en, this message translates to:
  /// **'1. Paste the playlist ID or the full browser link. The app will automatically detect the correct ID.'**
  String get helpstep1;

  /// No description provided for @helpstep2.
  ///
  /// In en, this message translates to:
  /// **'2. Set the number of videos to delete (\'all\' or a specific number). Videos are removed starting from the first ones visible on the playlist.'**
  String get helpstep2;

  /// No description provided for @helpstep3.
  ///
  /// In en, this message translates to:
  /// **'3. Click \'Remove videos\' – the app will handle the rest!'**
  String get helpstep3;

  /// No description provided for @helpstep4.
  ///
  /// In en, this message translates to:
  /// **'4. If you delete something by mistake, go to \'History\'. You will find all your deleted videos there, allowing you to easily find and restore them manually on YouTube.'**
  String get helpstep4;

  /// No description provided for @understand.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get understand;

  /// No description provided for @nohistory.
  ///
  /// In en, this message translates to:
  /// **'No history found'**
  String get nohistory;

  /// No description provided for @deletedvideoshistory.
  ///
  /// In en, this message translates to:
  /// **'Deleted Videos History'**
  String get deletedvideoshistory;

  /// No description provided for @unknownplaylist.
  ///
  /// In en, this message translates to:
  /// **'Unknown playlist'**
  String get unknownplaylist;

  /// No description provided for @prepearing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get prepearing;

  /// No description provided for @reinstatingvideos.
  ///
  /// In en, this message translates to:
  /// **'Restoring videos'**
  String get reinstatingvideos;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this entire playlist from history? This data will be lost.'**
  String get confirmDeleteContent;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get deleteAll;
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
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
