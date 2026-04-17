// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ManageTube';

  @override
  String get historyTitle => 'Deletion History';

  @override
  String get savedPlaylists => 'Saved Playlists';

  @override
  String get chooseVideos_to_be_removed =>
      'Choose videos to be removed from playlist';

  @override
  String get edit => 'Edit';

  @override
  String get remove => 'Remove';

  @override
  String get forDeletion => 'To be deleted';

  @override
  String statusDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos',
      one: 'video',
    );
    return 'Deleted: $count $_temp0';
  }

  @override
  String get addNewPlaylist => 'Add new playlist';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get playlistId => 'Playlist ID or link';

  @override
  String get deleteCountHint => 'Number of videos (\'all\' or number)';

  @override
  String get addPlaylistBtn => 'Add playlist';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get noName => 'No name';

  @override
  String get deleteSuccess => 'Deletion completed and history saved.';

  @override
  String get idorlink => 'ID or link to playlist';

  @override
  String get helptitle => 'How to use the app?';

  @override
  String get notlogged =>
      'Welcome to ManageTube, app for managing youtube playlists. Before you begin, get familiar with the app guide by clicking the question mark in upper right corner.';

  @override
  String get helpstep1 =>
      '1. Log in to your Google account by clicking the profile icon (next to the question mark).';

  @override
  String get helpstep2 =>
      '2. Import playlists using the \'Choose playlists to import\' button.';

  @override
  String get helpstep3 =>
      '3. After importing playlists, specify which you want to remove videos from, and press the green button saying \'Choose videos to be removed from playlist\' of the chosen playlist';

  @override
  String get helpstep4 =>
      '4. Choose videos you want to be removed by clicking on them, and then click \'DELETE x video/videos\' – the app will handle the rest!';

  @override
  String get helpstep5 =>
      '5. If you delete something by mistake, go to \'History\'. You will find all your deleted videos there, allowing you to easily find and manually restore them on YouTube.';

  @override
  String get understand => 'I understand';

  @override
  String get nohistory => 'No history';

  @override
  String get deletedvideoshistory => 'Deleted videos history';

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
      'Are you sure you want to delete this entire playlist from history? This data will be lost.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteAll => 'Delete all';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get importplaylists => 'Choose playlists to import';

  @override
  String get chooseplaylists => 'Choose playlists';

  @override
  String get selectAll => 'Select all';

  @override
  String get unselectAll => 'Unselect all';

  @override
  String get addSelected => 'Add selected';

  @override
  String get noPlaylistsFound => 'No playlists found.';

  @override
  String get confirmTitle => 'Confirmation';

  @override
  String deleteConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos',
      one: 'video',
    );
    return 'Are you sure you want to delete $count $_temp0 from the playlist?';
  }

  @override
  String get deleteAllPlaylistsConfirm =>
      'Are you sure you want to delete all saved playlists?';

  @override
  String get listCleared => 'List cleared.';

  @override
  String get loading => 'Connecting...';

  @override
  String get deletingVideos => 'Deleting videos';

  @override
  String get nameLabel => 'Name';

  @override
  String get idLabel => 'ID';

  @override
  String get rangeHint => 'Enter ranges (e.g., 1-5,7,9-11):';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String deleteAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'VIDEOS',
      one: 'VIDEO',
    );
    return 'DELETE $count $_temp0';
  }

  @override
  String get noVideosFound => 'No videos found';
}
