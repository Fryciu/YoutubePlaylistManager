// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'YouTube Playlist Manager';

  @override
  String get historyTitle => 'Deletion History';

  @override
  String get savedPlaylists => 'Saved Playlists';

  @override
  String get removeVideos => 'Remove videos from playlist';

  @override
  String get edit => 'Edit';

  @override
  String get remove => 'Remove';

  @override
  String get forDeletion => 'To be deleted';

  @override
  String statusDeleted(int count) {
    return 'Deleted: $count videos';
  }

  @override
  String get apiKeyLabel => 'Paste client_secret.json content here';

  @override
  String get saveApi => 'Save API';

  @override
  String get jsonError => 'JSON Error';

  @override
  String get apiKeyExists => 'API Key exists';

  @override
  String get noApiKey => 'No API Key';

  @override
  String get addNewPlaylist => 'Add new playlist';

  @override
  String get playlistName => 'Playlist Name';

  @override
  String get playlistId => 'Playlist ID or link';

  @override
  String get deleteCountHint => 'Number of videos (\'all\' or digit)';

  @override
  String get addPlaylistBtn => 'Add Playlist';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get noName => 'No Name';

  @override
  String get deleteSuccess => 'Deletion finished and history saved.';

  @override
  String get idorlink => 'ID or link to the playlist';

  @override
  String get helptitle => 'How to use the app?';

  @override
  String get helpstep1 =>
      '1. Paste the playlist ID or the full browser link. The app will automatically detect the correct ID.';

  @override
  String get helpstep2 =>
      '2. Set the number of videos to delete (\'all\' or a specific number). Videos are removed starting from the first ones visible on the playlist.';

  @override
  String get helpstep3 =>
      '3. Click \'Remove videos\' – the app will handle the rest!';

  @override
  String get helpstep4 =>
      '4. If you delete something by mistake, go to \'History\'. You will find all your deleted videos there, allowing you to easily find and restore them manually on YouTube.';

  @override
  String get understand => 'Got it';

  @override
  String get nohistory => 'No history found';

  @override
  String get deletedvideoshistory => 'Deleted Videos History';

  @override
  String get unknownplaylist => 'Unknown playlist';

  @override
  String get prepearing => 'Preparing...';

  @override
  String get reinstatingvideos => 'Restoring videos';

  @override
  String get confirmDeleteTitle => 'Remove from history';

  @override
  String get confirmDeleteContent =>
      'Are you sure you want to remove this entire playlist from history? This data will be lost.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteAll => 'Delete all';
}
