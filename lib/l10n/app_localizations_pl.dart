// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'ManageTube';

  @override
  String get historyTitle => 'Historia usuwania';

  @override
  String get savedPlaylists => 'Zapisane playlisty';

  @override
  String get chooseVideos_to_be_removed =>
      'Wybierz filmy do usunięcia z playlisty';

  @override
  String get edit => 'Edytuj';

  @override
  String get remove => 'Usuń';

  @override
  String get forDeletion => 'Do usunięcia';

  @override
  String statusDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'filmów',
      few: 'filmy',
      one: 'film',
    );
    return 'Usunięto: $count $_temp0';
  }

  @override
  String get addNewPlaylist => 'Dodaj nową playlistę';

  @override
  String get playlistName => 'Nazwa playlisty';

  @override
  String get playlistId => 'ID playlisty lub jej link';

  @override
  String get deleteCountHint => 'Liczba filmów (\'all\' lub liczba)';

  @override
  String get addPlaylistBtn => 'Dodaj playlistę';

  @override
  String get saveChanges => 'Zapisz zmiany';

  @override
  String get noName => 'Brak nazwy';

  @override
  String get deleteSuccess => 'Zakończono usuwanie i zapisano historię.';

  @override
  String get idorlink => 'ID lub link do playlisty';

  @override
  String get helptitle => 'Jak korzystać z aplikacji?';

  @override
  String get notlogged =>
      'Witaj w ManageTube, aplikacji do zarządzania playlistami na YouTube. Zanim zaczniesz, zapoznaj się z poradnikiem klikając pytajnik w prawym górnym rogu.';

  @override
  String get helpstep1 =>
      '1. Zaloguj się na swoje konto Google klikając na ikonę profilu (obok pytajnika)';

  @override
  String get helpstep2 =>
      '2. Zaimportuj playlisty za pomocą przycisku \'Wybierz playlisty do importu\'.';

  @override
  String get helpstep3 =>
      '3. Po zaimportowaniu playlist, określ z której chcesz usunąć filmy, po czym kliknij zielony przycisk z napisem \'Wybierz filmy do usunięcia z playlisty\' z wybranej playlisty.';

  @override
  String get helpstep4 =>
      '4. Wybierz filmy które chcesz usunąć i kliknij \'Usuń x film/filmy/filmów\' – aplikacja zajmie się resztą!';

  @override
  String get helpstep5 =>
      '5. Jeśli usuniesz coś przez pomyłkę, przejdź do \'Historii\'. Tam znajdziesz wszystkie swoje usunięte filmy, co pozwoli Ci je łatwo odnaleźć i przywrócić ręcznie na YouTube.';

  @override
  String get understand => 'Rozumiem';

  @override
  String get nohistory => 'Brak historii';

  @override
  String get deletedvideoshistory => 'Historia usuniętych filmów';

  @override
  String get unknownplaylist => 'Nieznana playlista';

  @override
  String get prepearing => 'Przygotowanie...';

  @override
  String get reinstatingvideos => 'Przywracanie filmów';

  @override
  String get confirmDeleteTitle => 'Usuń z historii';

  @override
  String get confirmDeleteContent =>
      'Czy na pewno chcesz usunąć całą tę playlistę z historii? Te dane przepadną.';

  @override
  String get cancel => 'Anuluj';

  @override
  String get deleteAll => 'Usuń wszystkie';

  @override
  String get login => 'Zaloguj się';

  @override
  String get logout => 'Wyloguj się';

  @override
  String get importplaylists => 'Wybierz playlisty do importu';

  @override
  String get chooseplaylists => 'Wybierz playlisty';

  @override
  String get selectAll => 'Zaznacz wszystkie';

  @override
  String get unselectAll => 'Odznacz wszystkie';

  @override
  String get addSelected => 'Dodaj wybrane';

  @override
  String get noPlaylistsFound => 'Nie znaleziono playlist.';

  @override
  String get confirmTitle => 'Potwierdzenie';

  @override
  String deleteConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'filmów',
      few: 'filmy',
      one: 'film',
    );
    return 'Czy na pewno chcesz usunąć $count $_temp0 z playlisty?';
  }

  @override
  String get deleteAllPlaylistsConfirm =>
      'Czy na pewno chcesz usunąć wszystkie zapisane playlisty?';

  @override
  String get listCleared => 'Lista wyczyszczona.';

  @override
  String get loading => 'Łączenie...';

  @override
  String get deletingVideos => 'Usuwanie filmów';

  @override
  String get nameLabel => 'Nazwa';

  @override
  String get idLabel => 'ID';

  @override
  String get rangeHint => 'Wpisz zakresy (np. 1-5,7,9-11):';

  @override
  String selectedCount(int count) {
    return '$count zaznaczonych';
  }

  @override
  String deleteAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'FILMÓW',
      few: 'FILMY',
      one: 'FILM',
    );
    return 'USUŃ $count $_temp0';
  }

  @override
  String get noVideosFound => 'Nie znaleziono filmów';
}
