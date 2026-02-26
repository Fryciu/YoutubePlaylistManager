// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Menedżer Playlist YouTube';

  @override
  String get historyTitle => 'Historia usuwania';

  @override
  String get savedPlaylists => 'Zapisane playlisty';

  @override
  String get removeVideos => 'Usuń filmy z playlisty';

  @override
  String get edit => 'Edytuj';

  @override
  String get remove => 'Usuń';

  @override
  String get forDeletion => 'Do usunięcia';

  @override
  String statusDeleted(int count) {
    return 'Usunięto: $count filmów';
  }

  @override
  String get apiKeyLabel => 'Wklej tutaj zawartość client_secret.json';

  @override
  String get saveApi => 'Zapisz API';

  @override
  String get jsonError => 'Błąd JSON';

  @override
  String get apiKeyExists => 'Klucz API istnieje';

  @override
  String get noApiKey => 'Brak klucza API';

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
  String get helpstep1 =>
      '1. Wklej ID playlisty lub pełny link z przeglądarki. Aplikacja automatycznie rozpozna właściwy identyfikator.';

  @override
  String get helpstep2 =>
      '2. Określ liczbę filmów do usunięcia (\'all\' lub liczba). Filmy usuwane są od pierwszych widocznych na playliście';

  @override
  String get helpstep3 =>
      '3. Kliknij \'Usuń filmy\' – aplikacja zajmie się resztą!';

  @override
  String get helpstep4 =>
      '4. Jeśli usuniesz coś przez pomyłkę, przejdź do \'Historii\'. Tam znajdziesz wszystkie swoje usunięte filmy, co pozwoli Ci je łatwo odnaleźć i przywrócić ręcznie na YouTube.';

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
  String get deleteAll => 'Usuń wszystko';
}
