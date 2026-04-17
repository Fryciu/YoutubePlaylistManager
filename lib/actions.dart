import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis/youtube/v3.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'main.dart'; // Upewnij się, że getAppDirectory() jest tam dostępny
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth_io;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Dodaj import
import 'package:shared_preferences/shared_preferences.dart';
import 'history_page.dart' show QuotaExceededException;
import 'keys.dart';

class UserProfile {
  final String? displayName;
  final String? photoUrl;
  final String? email; // <-- dodaj
  UserProfile({this.displayName, this.photoUrl, this.email});
}

class VideoItem {
  final String playlistItemId;
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final int position;

  VideoItem({
    required this.playlistItemId,
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.position,
  });
}

class AuthSession {
  final String token;
  final String userId;

  AuthSession(this.token, this.userId);

  // Konwersja do Mapy (którą potem zamienimy na String)
  Map<String, dynamic> toJson() => {'token': token, 'userId': userId};

  // Tworzenie obiektu z Mapy
  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(json['token'], json['userId']);
  }
}

class PlaylistActions {
  static final keylist = readkeys();
  static final auth.ClientId _desktopClientId = auth.ClientId(
    keylist[0],
    keylist[1],
  );
  static final auth.ClientId _mobileClientId = auth.ClientId(
    keylist[2],
    null, // Mobile/natywny klient nie używa client secret
  );
  static bool _authInProgress = false;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _initialized = false;

  static auth.AuthClient? _cachedAuthClient;
  static String? _cachedEmail;

  // W actions.dart
  static final List<String> _scopes = [
    YouTubeApi.youtubeForceSslScope,
    'openid', // Dodaj to
    'https://www.googleapis.com/auth/userinfo.profile', // I to
    'email',
  ];
  static ValueNotifier<UserProfile?> currentUserNotifier = ValueNotifier(null);
  static Future<void> initialize() async {
    final keylist = readkeys();
    if (_initialized) return;
    await _googleSignIn.initialize(serverClientId: keylist[3]);
    _initialized = true;
    debugPrint('GoogleSignIn zainicjalizowany.');
  }

  // ─────────────────────────────────────────────
  // Parser ID / Linków
  // ─────────────────────────────────────────────

  static String extractPlaylistId(String input) {
    input = input.trim();
    if (input.isEmpty) return "";

    if (input.contains("list=")) {
      try {
        final uri = Uri.parse(input);
        return uri.queryParameters['list'] ?? input;
      } catch (e) {
        return input;
      }
    }
    return input;
  }

  // ─────────────────────────────────────────────
  // Autoryzacja
  // ─────────────────────────────────────────────

  static Future<UserProfile?> getInitialProfile() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await initialize();

        // 1. Sprawdź cache profilu — zero UI, zero sieci
        final cached = await _loadProfileFromCache();
        if (cached != null) {
          debugPrint('[Auth] Profil z cache: ${cached.email}');
          currentUserNotifier.value = cached;
          // Klient zostanie zbudowany leniwie przy pierwszym fetch — nie robimy nic w tle
          return cached;
        }

        // 2. Brak cache — próba cichego logowania przez SDK (BEZ UI)
        final account = await _googleSignIn.attemptLightweightAuthentication();
        debugPrint('[Auth] Ciche logowanie: ${account?.email ?? "brak"}');
        if (account == null) return null;

        final profile = UserProfile(
          displayName: account.displayName,
          photoUrl: account.photoUrl,
          email: account.email,
        );
        currentUserNotifier.value = profile;
        await _saveProfileToCache(profile);
        return profile;
      } else {
        // Desktop
        final directory = await getAppDirectory();
        final tokenFile = File(
          '${directory.path}${Platform.pathSeparator}token.json',
        );
        if (await tokenFile.exists()) {
          await _getAuthClient();
          return currentUserNotifier.value;
        }
      }
    } catch (e) {
      debugPrint('[Auth] Błąd sprawdzania sesji na starcie: $e');
    }
    return null;
  }

  // Zapis profilu
  static Future<void> _saveProfileToCache(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_displayName', profile.displayName ?? '');
    await prefs.setString('user_photoUrl', profile.photoUrl ?? '');
    await prefs.setString('user_email', profile.email ?? '');
  }

  // Odczyt profilu
  static Future<UserProfile?> _loadProfileFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('user_email');
    if (email == null || email.isEmpty) return null;
    return UserProfile(
      displayName: prefs.getString('user_displayName'),
      photoUrl: prefs.getString('user_photoUrl'),
      email: email,
    );
  }

  // ── NOWE METODY: persystencja tokenów na mobile ──────────────────────────────

  static Future<void> _saveTokensToPrefs(auth.AccessCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('oauth_access_token', creds.accessToken.data);
    await prefs.setString(
      'oauth_token_expiry',
      creds.accessToken.expiry.toIso8601String(),
      //DateTime.now()
      //    .subtract(Duration(minutes: 10))
      //    .toIso8601String(), // Udajemy, że wygasł 10 min temu
    );
    print(creds.accessToken.expiry);
    await prefs.setString('oauth_refresh_token', creds.refreshToken ?? '');
    final scopeList = creds.scopes;
    await prefs.setString('oauth_scopes', scopeList.join(','));
    debugPrint('[Auth] Tokeny zapisane do SharedPreferences');
  }

  static Future<void> _clearTokensFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('oauth_access_token');
    await prefs.remove('oauth_token_expiry');
    await prefs.remove('oauth_refresh_token');
    await prefs.remove('oauth_scopes');
    debugPrint('[Auth] Tokeny usunięte z SharedPreferences');
  }

  // Czyszczenie przy wylogowaniu
  static Future<void> _clearProfileCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_displayName');
    await prefs.remove('user_photoUrl');
    await prefs.remove('user_email');
  }

  // Przywraca klienta OAuth z zapisanych tokenów — BEZ UI, BEZ sieci (poza ewentualnym refresh)
  static Future<auth.AuthClient?> _loadAuthClientFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('oauth_access_token');
      final expiryStr = prefs.getString('oauth_token_expiry');
      final refreshToken = prefs.getString('oauth_refresh_token');
      final scopesStr = prefs.getString('oauth_scopes');

      if (accessToken == null || expiryStr == null) return null;

      final expiry = DateTime.tryParse(expiryStr);
      if (expiry == null) return null;

      final scopes = scopesStr?.split(',') ?? _scopes;

      final credentials = auth.AccessCredentials(
        auth.AccessToken('Bearer', accessToken, expiry.toUtc()),
        refreshToken?.isEmpty ?? true ? null : refreshToken,
        scopes,
      );

      final baseClient = http.Client();

      // Jeśli token wygasł i mamy refresh token — odśwież cicho
      if (expiry.isBefore(DateTime.now().toUtc()) &&
          credentials.refreshToken != null) {
        debugPrint('[Auth] Token wygasł — cichy refresh z SharedPreferences');
        final clientId = (Platform.isAndroid || Platform.isIOS)
            ? _mobileClientId
            : _desktopClientId;
        try {
          final refreshed = await auth.refreshCredentials(
            clientId,
            credentials,
            baseClient,
          );
          await _saveTokensToPrefs(refreshed);
          return auth.authenticatedClient(baseClient, refreshed);
        } catch (e) {
          debugPrint('[Auth] Cichy refresh nieudany: $e');
          await _clearTokensFromPrefs();
          return null;
        }
      }
      debugPrint("expiry $expiry");
      if (expiry.isAfter(DateTime.now().toUtc())) {
        debugPrint(
          '[Auth] Przywrócono klienta z SharedPreferences (token ważny)',
        );
        return auth.authenticatedClient(baseClient, credentials);
      }
    } catch (e) {
      debugPrint('[Auth] Błąd ładowania tokenów z prefs: $e');
    }
    return null;
  }

  // W pliku actions.dart zmodyfikuj metodę _getAuthClient:

  static Future<auth.AuthClient?> _getAuthClient() async {
    // 1. Sprawdzenie Cache w RAM
    if (_cachedAuthClient != null) {
      final credentials = _cachedAuthClient!.credentials;
      // Margines 5 minut, aby uniknąć błędów synchronizacji czasu
      final bool isExpired = credentials.accessToken.expiry.isBefore(
        DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );

      if (!isExpired) {
        final currentEmail = currentUserNotifier.value?.email;
        if (currentEmail == null || currentEmail == _cachedEmail) {
          return _cachedAuthClient;
        }
      }
      debugPrint('[Auth] Cache wygasł lub nieaktualny — czyszczę...');
      _cachedAuthClient = null;
    }

    if (_authInProgress) return null;
    _authInProgress = true;

    try {
      // --- LOGIKA DLA ANDROID / IOS ---
      if (Platform.isAndroid || Platform.isIOS) {
        await initialize();

        // 3. Próba cichego logowania przez SDK (jeśli prefs zawiodły)
        final account = await _googleSignIn.attemptLightweightAuthentication();
        if (account == null) return null;

        debugPrint('[Auth] Ciche logowanie SDK OK: ${account.email}');

        GoogleSignInClientAuthorization? authorization;
        try {
          authorization = await account.authorizationClient
              .authorizationForScopes(_scopes);
        } catch (e) {
          debugPrint('[Auth] Błąd pobierania grantu: $e');
        }

        // 4. Jeśli brak uprawnień — poproś z UI (ostatnia deska ratunku)
        if (authorization == null) {
          debugPrint('[Auth] Brak uprawnień — wywołuję UI...');
          try {
            authorization = await account.authorizationClient.authorizeScopes(
              _scopes,
            );
          } catch (e) {
            debugPrint('[Auth] Użytkownik odrzucił logowanie: $e');
            return null;
          }
        }

        final mobileClient = authorization.authClient(scopes: _scopes);

        // Aktualizacja profilu
        currentUserNotifier.value = UserProfile(
          displayName: account.displayName,
          photoUrl: account.photoUrl,
          email: account.email,
        );

        await _saveProfileToCache(currentUserNotifier.value!);
        await _saveTokensToPrefs(mobileClient.credentials);

        _cachedAuthClient = mobileClient;
        _cachedEmail = account.email;
        return mobileClient;
      }

      // --- LOGIKA DLA DESKTOP (Windows/Linux/MacOS) ---
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final directory = await getAppDirectory();
        final tokenFile = File(
          '${directory.path}${Platform.pathSeparator}token.json',
        );
        auth.AuthClient? desktopClient;

        if (await tokenFile.exists()) {
          try {
            final content = await tokenFile.readAsString();
            final credentials = auth.AccessCredentials.fromJson(
              json.decode(content),
            );
            final baseClient = http.Client();

            // Jeśli token wygasł — odświeżamy desktopowym ClientID
            if (credentials.accessToken.expiry.isBefore(
              DateTime.now().toUtc().add(const Duration(minutes: 5)),
            )) {
              debugPrint('[Auth] Desktop: Odświeżam token...');
              final refreshed = await auth.refreshCredentials(
                _desktopClientId,
                credentials,
                baseClient,
              );
              await tokenFile.writeAsString(json.encode(refreshed.toJson()));
              desktopClient = auth.authenticatedClient(baseClient, refreshed);
            } else {
              desktopClient = auth.authenticatedClient(baseClient, credentials);
            }
          } catch (e) {
            debugPrint('[Auth] Desktop: Błąd odświeżania, usuwam token: $e');
            if (await tokenFile.exists()) await tokenFile.delete();
          }
        }

        // Jeśli nadal brak klienta (pierwsze logowanie)
        if (desktopClient == null) {
          desktopClient = await auth_io
              .clientViaUserConsent(_desktopClientId, _scopes, (url) async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              })
              .timeout(const Duration(minutes: 3));

          await tokenFile.writeAsString(
            json.encode(desktopClient.credentials.toJson()),
          );
        }

        // Pobieranie danych profilu dla Desktopu
        try {
          final infoResponse = await http.get(
            Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
            headers: {
              'Authorization':
                  'Bearer ${desktopClient.credentials.accessToken.data}',
            },
          );
          if (infoResponse.statusCode == 200) {
            final data = json.decode(infoResponse.body);
            currentUserNotifier.value = UserProfile(
              displayName: data['name'],
              photoUrl: data['picture'],
              email: data['email'],
            );
          }
        } catch (e) {
          debugPrint('[Auth] Desktop: Błąd pobierania userinfo: $e');
        }

        _cachedAuthClient = desktopClient;
        _cachedEmail = currentUserNotifier.value?.email;
        return desktopClient;
      }

      return null;
    } catch (e) {
      debugPrint('[Auth] Krytyczny błąd w _getAuthClient: $e');
      return null;
    } finally {
      _authInProgress = false;
    }
  }

  // W klasie PlaylistActions w pliku actions.dart
  static Future<void> signOut() async {
    _cachedAuthClient = null;
    _cachedEmail = null;
    try {
      await _clearProfileCache(); // <-- dodaj
      await _clearTokensFromPrefs(); // ← DODAJ

      // 1. Wylogowanie Mobile
      if (Platform.isAndroid || Platform.isIOS) {
        await _googleSignIn.signOut();
        await _googleSignIn.disconnect();
        debugPrint('[Auth] Wylogowano z Google (Mobile)');
      }

      // 2. Wylogowanie Desktop (usuwanie tokenu)
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final directory = await getAppDirectory();
        final tokenFile = File(
          '${directory.path}${Platform.pathSeparator}token.json',
        );
        if (await tokenFile.exists()) {
          await tokenFile.delete();
          debugPrint('[Auth] Usunięto token sesji (Desktop)');
        }
      }
      currentUserNotifier.value = null; // To powiadomi UI o wylogowaniu
    } catch (e) {
      debugPrint('[Auth] Błąd podczas wylogowywania: $e');
    }
  }
  // ─────────────────────────────────────────────
  // Przetwarzanie (USUWANIE)
  // ─────────────────────────────────────────────

  // plik actions.dart wewnątrz klasy PlaylistActions

  static Future<void> signInExplicitly() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await initialize();

      GoogleSignInAccount? account = await _googleSignIn
          .attemptLightweightAuthentication();

      if (account == null) {
        if (!_googleSignIn.supportsAuthenticate()) return;
        account = await _googleSignIn.authenticate(); // UI tylko tutaj
      }

      currentUserNotifier.value = UserProfile(
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        email: account.email,
      );

      GoogleSignInClientAuthorization? authorization;
      try {
        authorization = await account.authorizationClient
            .authorizationForScopes(_scopes);
      } catch (e) {
        debugPrint('[Auth] authorizationForScopes error: $e');
      }

      authorization ??= await account.authorizationClient.authorizeScopes(
        _scopes,
      ); // UI scope tylko tutaj

      _cachedAuthClient = authorization.authClient(scopes: _scopes);
      _cachedEmail = account.email;
      await _saveProfileToCache(currentUserNotifier.value!);
      // Zapisz tokeny trwale — żeby przy kolejnym uruchomieniu nie było popup
      await _saveTokensToPrefs(_cachedAuthClient!.credentials);
      debugPrint('[Auth] signInExplicitly: cache zbudowany');
    } else {
      await _getAuthClient();
    }
  }

  // plik actions.dart

  static Future<List<Map<String, String>>> fetchUserPlaylists() async {
    final auth.AuthClient? authClient = await _getAuthClient();
    if (authClient == null) return [];

    final youtubeApi = YouTubeApi(authClient);
    List<Map<String, String>> myPlaylists = [];
    String? pageToken;

    try {
      do {
        // Pobieranie playlist zalogowanego użytkownika (mine: true)
        final response = await youtubeApi.playlists.list(
          ['snippet', 'id', 'contentDetails'],
          mine: true,
          maxResults: 50,
          pageToken: pageToken,
        );

        if (response.items != null) {
          for (var item in response.items!) {
            myPlaylists.add({
              "name": item.snippet?.title ?? "Bez nazwy",
              "id": item.id ?? "",
              "deleteCount": "all", // Domyślna wartość
            });
          }
        }
        pageToken = response.nextPageToken;
      } while (pageToken != null);
    } catch (e) {
      debugPrint("Błąd podczas pobierania playlist: $e");
    }

    return myPlaylists;
  }

  // ─────────────────────────────────────────────
  // Pobieranie filmów z playlisty (miniaturki)
  // ─────────────────────────────────────────────

  static Future<List<VideoItem>> fetchPlaylistItems(String rawInput) async {
    final auth.AuthClient? authClient = await _getAuthClient();
    if (authClient == null) return [];

    final youtubeApi = YouTubeApi(authClient);
    final String playlistId = extractPlaylistId(rawInput);
    if (playlistId.isEmpty) return [];

    final List<VideoItem> items = [];
    String? pageToken;
    int position = 0;

    try {
      do {
        final response = await youtubeApi.playlistItems.list(
          ['id', 'snippet'],
          playlistId: playlistId,
          maxResults: 50,
          pageToken: pageToken,
        );

        for (final item in response.items ?? []) {
          final snippet = item.snippet;
          if (snippet == null) continue;
          position++;
          items.add(
            VideoItem(
              playlistItemId: item.id ?? '',
              videoId: snippet.resourceId?.videoId ?? '',
              title: snippet.title ?? 'Bez tytułu',
              thumbnailUrl:
                  snippet.thumbnails?.medium?.url ??
                  snippet.thumbnails?.default_?.url ??
                  '',
              position: position,
            ),
          );
        }
        pageToken = response.nextPageToken;
      } while (pageToken != null);
    } catch (e) {
      debugPrint('Błąd pobierania filmów: $e');
    }

    return items;
  }

  static bool hasCachedClient() {
    return _cachedAuthClient != null;
  }

  static Future<Map<String, dynamic>> processPlaylistItems(
    Map<String, dynamic> playlistData,
    List<VideoItem> selectedItems,
    Function(int current, int total, String title) onProgress,
  ) async {
    final auth.AuthClient? authClient = await _getAuthClient();
    if (authClient == null) return {};

    final youtubeApi = YouTubeApi(authClient);
    final String timeRegistry = _nowTimestamp();
    final Map<String, dynamic> deletedNames = {};

    final String rawInput = playlistData['id'] as String? ?? '';
    final String playlistId = extractPlaylistId(rawInput);
    if (playlistId.isEmpty) return {};

    final String playlistTitle = playlistData['name'] as String? ?? 'Unknown';
    final int total = selectedItems.length;

    deletedNames[playlistId] = {
      'Name': playlistTitle,
      'Dates': {timeRegistry: <String, String>{}},
    };

    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      onProgress(i + 1, total, item.title);
      try {
        await youtubeApi.playlistItems.delete(item.playlistItemId);
        (deletedNames[playlistId]['Dates'][timeRegistry]
                as Map<String, String>)[item.title] =
            item.videoId;
      } catch (e) {
        debugPrint("Błąd usuwania '${item.title}': $e");
      }
    }

    return deletedNames;
  }

  static Future<Map<String, dynamic>> processPlaylist(
    Map<String, dynamic> playlistData,
    Function(int current, int total, String title) onProgress,
  ) async {
    final auth.AuthClient? authClient = await _getAuthClient();
    if (authClient == null) return {};

    final youtubeApi = YouTubeApi(authClient);
    final String timeRegistry = _nowTimestamp();
    final Map<String, dynamic> deletedNames = {};

    final String rawInput = playlistData['id'] as String? ?? '';
    final String playlistId = extractPlaylistId(rawInput);
    if (playlistId.isEmpty) return {};

    // POBIERANIE FAKTYCZNEJ DŁUGOŚCI PLAYLISTY
    int totalVideosInPlaylist = 0;
    String playlistTitle = playlistData['name'] as String? ?? 'Unknown';

    try {
      final pList = await youtubeApi.playlists.list(
        ['contentDetails', 'snippet'],
        id: [playlistId],
      );
      if (pList.items != null && pList.items!.isNotEmpty) {
        totalVideosInPlaylist =
            pList.items!.first.contentDetails?.itemCount?.toInt() ?? 0;
        playlistTitle = pList.items!.first.snippet?.title ?? playlistTitle;
      }
    } catch (e) {
      debugPrint("Nie udało się pobrać metadanych playlisty: $e");
    }

    final dynamic countRaw = playlistData['deleteCount'];
    int videosToDelete = (countRaw.toString().toLowerCase() == 'all')
        ? totalVideosInPlaylist
        : int.tryParse(countRaw.toString()) ?? 0;

    // Zabezpieczenie przed usunięciem więcej niż jest
    if (videosToDelete > totalVideosInPlaylist && totalVideosInPlaylist > 0) {
      videosToDelete = totalVideosInPlaylist;
    }

    int deletedCount = 0;
    String? pageToken;

    while (deletedCount < videosToDelete) {
      PlaylistItemListResponse response;
      try {
        response = await youtubeApi.playlistItems.list(
          ['id', 'snippet'],
          playlistId: playlistId,
          maxResults: 50,
          pageToken: pageToken,
        );
      } catch (e) {
        break;
      }

      final items = response.items;
      if (items == null || items.isEmpty) break;

      deletedNames[playlistId] ??= {
        'Name': playlistTitle,
        'Dates': {timeRegistry: <String, String>{}},
      };

      for (final item in items) {
        if (deletedCount >= videosToDelete) break;
        final String? playlistItemId = item.id;
        final String? videoTitle = item.snippet?.title;
        final String? videoId = item.snippet?.resourceId?.videoId;

        if (playlistItemId == null || videoTitle == null || videoId == null)
          continue;

        try {
          onProgress(deletedCount + 1, videosToDelete, videoTitle);
          await youtubeApi.playlistItems.delete(playlistItemId);
          deletedCount++;

          (deletedNames[playlistId]['Dates'][timeRegistry]
                  as Map<String, String>)[videoTitle] =
              videoId;
        } catch (e) {
          debugPrint("Błąd usuwania '$videoTitle': $e");
        }
      }
      pageToken = response.nextPageToken;
      if (pageToken == null) break;
    }
    return deletedNames;
  }

  // ─────────────────────────────────────────────
  // Przywracanie (BATCH)
  // ─────────────────────────────────────────────

  static Future<void> reAddAllVideosFromDate(
    String rawPlaylistId,
    Map<String, dynamic> videos,
    String dateOfAddition,
    Function(int current, int total, String title) onProgress,
  ) async {
    final String playlistId = extractPlaylistId(rawPlaylistId);
    final videoEntries = videos.entries.toList();
    final int total = videoEntries.length;

    final auth.AuthClient? authClient = await _getAuthClient();
    if (authClient != null) {
      final youtubeApi = YouTubeApi(authClient);
      for (int i = 0; i < total; i++) {
        onProgress(i + 1, total, videoEntries[i].key);
        await youtubeApi.playlistItems.insert(
          PlaylistItem(
            snippet: PlaylistItemSnippet(
              playlistId: playlistId,
              resourceId: ResourceId(
                kind: 'youtube#video',
                videoId: videoEntries[i].value,
              ),
            ),
          ),
          ['snippet'],
        );
      }
    }

    await _manualDeleteDateFromHistory(playlistId, dateOfAddition);
  }

  static Future<bool> reAddVideoToPlaylist(
    String rawPlaylistId,
    String videoId,
    String dateOfAddition, {
    bool updateHistoryInFile = true,
  }) async {
    final String playlistId = extractPlaylistId(rawPlaylistId);
    final auth.AuthClient? authClient = await _getAuthClient();
    if (authClient == null) return false;
    final youtubeApi = YouTubeApi(authClient);

    try {
      await youtubeApi.playlistItems.insert(
        PlaylistItem(
          snippet: PlaylistItemSnippet(
            playlistId: playlistId,
            resourceId: ResourceId(kind: 'youtube#video', videoId: videoId),
          ),
        ),
        ['snippet'],
      );
    } on DetailedApiRequestError catch (e) {
      if (e.status != 409) return false;
    } catch (e) {
      return false;
    }

    if (updateHistoryInFile) {
      await _manualUpdateHistory(playlistId, videoId, dateOfAddition);
    }
    return true;
  }

  // ─────────────────────────────────────────────
  // Zarządzanie plikiem historii
  // ─────────────────────────────────────────────

  static Future<void> _manualDeleteDateFromHistory(
    String playlistId,
    String date,
  ) async {
    try {
      final directory = await getUserDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}history.json',
      );
      if (!await file.exists()) return;

      final Map<String, dynamic> history = json.decode(
        await file.readAsString(),
      );
      if (history.containsKey(playlistId)) {
        (history[playlistId]['Dates'] as Map).remove(date);
        if ((history[playlistId]['Dates'] as Map).isEmpty)
          history.remove(playlistId);
        await file.writeAsString(
          const JsonEncoder.withIndent('    ').convert(history),
        );
      }
    } catch (e) {
      debugPrint("Błąd usuwania daty z historii: $e");
    }
  }

  static Future<void> _manualUpdateHistory(
    String playlistId,
    String videoId,
    String date,
  ) async {
    try {
      final directory = await getUserDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}history.json',
      );
      if (!await file.exists()) return;

      final Map<String, dynamic> history = json.decode(
        await file.readAsString(),
      );
      if (history.containsKey(playlistId)) {
        final dates = history[playlistId]['Dates'] as Map<String, dynamic>;
        if (dates.containsKey(date)) {
          final videos = dates[date] as Map<String, dynamic>;
          videos.removeWhere((key, value) => value == videoId);
          if (videos.isEmpty) dates.remove(date);
          if (dates.isEmpty) history.remove(playlistId);
          await file.writeAsString(
            const JsonEncoder.withIndent('    ').convert(history),
          );
        }
      }
    } catch (e) {
      debugPrint("Błąd aktualizacji historii: $e");
    }
  }

  static Future<void> removeEntirePlaylistFromHistory(
    String rawPlaylistId,
  ) async {
    final String playlistId = extractPlaylistId(rawPlaylistId);
    try {
      final directory = await getUserDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}history.json',
      );
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      Map<String, dynamic> history = json.decode(content);
      if (history.containsKey(playlistId)) {
        history.remove(playlistId);
        await file.writeAsString(
          const JsonEncoder.withIndent('    ').convert(history),
        );
      }
    } catch (e) {
      debugPrint("Błąd podczas usuwania z historii: $e");
    }
  }

  static Future<void> removeDateFromHistory(
    String rawPlaylistId,
    String date,
  ) async {
    final String playlistId = extractPlaylistId(rawPlaylistId);
    try {
      final directory = await getUserDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}history.json',
      );
      if (!await file.exists()) return;
      final content = await file.readAsString();
      if (content.isEmpty) return;
      Map<String, dynamic> history = json.decode(content);
      if (!history.containsKey(playlistId)) return;
      (history[playlistId]['Dates'] as Map).remove(date);
      if ((history[playlistId]['Dates'] as Map).isEmpty) {
        history.remove(playlistId);
      }
      await file.writeAsString(
        const JsonEncoder.withIndent('    ').convert(history),
      );
    } catch (e) {
      debugPrint("Błąd podczas usuwania daty z historii: $e");
    }
  }

  static Future<void> removeSingleVideoFromHistory(
    String rawPlaylistId,
    String date,
    String videoTitle,
  ) async {
    final String playlistId = extractPlaylistId(rawPlaylistId);
    try {
      final directory = await getUserDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}history.json',
      );
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.isEmpty) return;

      Map<String, dynamic> history = json.decode(content);
      if (!history.containsKey(playlistId)) return;

      final dates = history[playlistId]['Dates'] as Map<String, dynamic>;
      if (!dates.containsKey(date)) return;

      (dates[date] as Map).remove(videoTitle);

      // Jeśli data jest pusta — usuń ją
      if ((dates[date] as Map).isEmpty) {
        dates.remove(date);
      }

      // Jeśli playlista jest pusta — usuń ją
      if (dates.isEmpty) {
        history.remove(playlistId);
      }

      await file.writeAsString(
        const JsonEncoder.withIndent('    ').convert(history),
      );
    } catch (e) {
      debugPrint("Błąd podczas usuwania wpisu z historii: $e");
    }
  }

  static Future<Map<String, dynamic>> saveDeletedHistory(
    Map<String, dynamic> deletedNames,
  ) async {
    if (deletedNames.isEmpty) return {};
    try {
      final directory = await getUserDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}history.json',
      );
      Map<String, dynamic> history = (await file.exists())
          ? json.decode(await file.readAsString())
          : {};

      deletedNames.forEach((id, data) {
        if (history.containsKey(id)) {
          (history[id]['Dates'] as Map).addAll(data['Dates']);
        } else {
          history[id] = data;
        }
      });
      await file.writeAsString(
        const JsonEncoder.withIndent('    ').convert(history),
      );
      return history;
    } catch (e) {
      return {};
    }
  }

  static String _nowTimestamp() => DateTime.now().toString().split('.').first;

  // ─────────────────────────────────────────────
  // Usuwanie z wykrywaniem quota (Bug 2 fix)
  // ─────────────────────────────────────────────

  /// Like [processPlaylistItems] but throws [QuotaExceededException] when the
  /// YouTube API returns a 403 quota error, carrying the unprocessed items so
  /// the TaskQueue can retry them later.
  ///
  /// [onProgress]      — called with (current, total, title) after each delete.
  /// [onPartialResult] — called with a partial history map whenever at least
  ///                     one video has been successfully deleted.
  static Future<void> processPlaylistItemsWithQuota(
    Map<String, dynamic> playlistData,
    List<VideoItem> selectedItems,
    Function(int current, int total, String title) onProgress, {
    required Function(Map<String, dynamic> partial) onPartialResult,
  }) async {
    final auth.AuthClient? authClient = await _getAuthClient();
    if (authClient == null) return;

    final youtubeApi = YouTubeApi(authClient);
    final String timeRegistry = _nowTimestamp();
    final Map<String, dynamic> deletedNames = {};

    final String rawInput = playlistData['id'] as String? ?? '';
    final String playlistId = extractPlaylistId(rawInput);
    if (playlistId.isEmpty) return;

    final String playlistTitle = playlistData['name'] as String? ?? 'Unknown';
    final int total = selectedItems.length;

    deletedNames[playlistId] = {
      'Name': playlistTitle,
      'Dates': {timeRegistry: <String, String>{}},
    };

    for (int i = 0; i < selectedItems.length; i++) {
      final item = selectedItems[i];
      onProgress(i + 1, total, item.title);
      try {
        await youtubeApi.playlistItems.delete(item.playlistItemId);
        (deletedNames[playlistId]['Dates'][timeRegistry]
                as Map<String, String>)[item.title] =
            item.videoId;
        // Notify caller of partial progress after every successful deletion
        onPartialResult(Map<String, dynamic>.from(deletedNames));
      } on DetailedApiRequestError catch (e) {
        // 403 = quota exceeded; surface remaining items for retry
        if (e.status == 403) {
          final remaining = selectedItems.sublist(i);
          // Notify caller of what we managed before hitting quota
          if ((deletedNames[playlistId]['Dates'][timeRegistry]
                  as Map<String, String>)
              .isNotEmpty) {
            onPartialResult(Map<String, dynamic>.from(deletedNames));
          }
          throw QuotaExceededException(remaining);
        }
        debugPrint("Błąd usuwania (api) '\${item.title}': \$e");
      } catch (e) {
        debugPrint("Błąd usuwania '\${item.title}': \$e");
      }
    }
  }
}

// W pliku actions.dart

// actions.dart

class DynamicBottomAd extends StatefulWidget {
  final double availableHeight;
  final Widget placeholder;

  const DynamicBottomAd({
    Key? key,
    required this.availableHeight,
    required this.placeholder,
  }) : super(key: key);

  @override
  _DynamicBottomAdState createState() => _DynamicBottomAdState();
}

class _DynamicBottomAdState extends State<DynamicBottomAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _selectedSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) {
      if (Platform.isAndroid || Platform.isIOS) {
        _loadAdaptiveAd();
      } else {
        // Desktop — tylko ustaw rozmiar żeby placeholder się wyrenderował
        setState(() {
          _selectedSize = widget.availableHeight >= 250
              ? AdSize.mediumRectangle
              : AdSize.banner;
        });
      }
    }
  }

  Future<void> _loadAdaptiveAd() async {
    // Pobieramy szerokość ekranu bez wcięć systemowych
    final width =
        MediaQuery.of(context).size.width -
        MediaQuery.of(context).padding.left -
        MediaQuery.of(context).padding.right;

    AdSize adaptiveSize;
    if (widget.availableHeight >= 250) {
      // Duże miejsce — spróbuj inline adaptive (może być wysoki)
      adaptiveSize =
          await AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(
            width.truncate(),
          );
    } else if (widget.availableHeight >= 50) {
      // Małe miejsce — zwykły banner 320x50
      adaptiveSize = AdSize.banner;
    } else {
      return; // Za mało miejsca
    }

    // Upewnij się że reklama nie przekroczy dostępnej wysokości
    final adHeight = adaptiveSize.height.toDouble();
    if (adHeight > widget.availableHeight) {
      adaptiveSize = AdSize.banner; // Fallback do najmniejszego
    }

    if (!mounted) return;
    setState(() => _selectedSize = adaptiveSize);

    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716',
      request: const AdRequest(),
      size: adaptiveSize,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _bannerAd = null);
          debugPrint('Ad failed: $error');
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedSize == null) return const SizedBox.shrink();

    final adWidth = _selectedSize!.width.toDouble();
    final adHeight = _selectedSize!.height.toDouble();

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 500),
      firstChild: widget.placeholder,
      secondChild: SizedBox(
        width: adWidth,
        height: adHeight,
        child: _bannerAd != null ? AdWidget(ad: _bannerAd!) : const SizedBox(),
      ),
      crossFadeState: _isLoaded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}

// Przykład pomocniczego widgetu dla AdMob

// actions.dart

// ─────────────────────────────────────────────────────────────────────────────
// Reklamy kontekstowe — dobierane na podstawie szacowanego czasu operacji
// < 10s  → baner (InlineBannerAd)
// 10–45s → krótki filmik (interstitial)
// > 45s  → filmik z nagrodą (rewarded)
// ─────────────────────────────────────────────────────────────────────────────

/// Wyświetla właściwy typ reklamy na podstawie szacowanego czasu całej operacji.
/// Gdy [estimatedTotalSeconds] jest null (pierwsza sekunda, brak danych),
/// pokazuje baner jako bezpieczny fallback.
class ProgressAdWidget extends StatefulWidget {
  final int? estimatedTotalSeconds;

  const ProgressAdWidget({Key? key, this.estimatedTotalSeconds})
    : super(key: key);

  @override
  State<ProgressAdWidget> createState() => _ProgressAdWidgetState();
}

class _ProgressAdWidgetState extends State<ProgressAdWidget> {
  _AdType? _lockedType;
  final List<int> _estimationBuffer = []; // Przechowuje ostatnie estymacje

  @override
  void didUpdateWidget(ProgressAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Jeśli typ nie jest jeszcze zablokowany i mamy nową estymatę
    if (_lockedType == null && widget.estimatedTotalSeconds != null) {
      _estimationBuffer.add(widget.estimatedTotalSeconds!);

      // Czekamy, aż uzbieramy 3 próbki (lub mniej, jeśli operacja jest krótka)
      if (_estimationBuffer.length >= 3) {
        double average =
            _estimationBuffer.reduce((a, b) => a + b) /
            _estimationBuffer.length;
        setState(() {
          _lockedType = _resolveType(average.round());
        });
      }
    }
  }

  _AdType _resolveType(int secs) {
    if (secs < 10) return _AdType.banner;
    if (secs <= 45) return _AdType.interstitial;
    return _AdType.rewarded;
  }

  @override
  Widget build(BuildContext context) {
    // Dopóki nie mamy średniej z 3 próbek, możemy pokazywać mały loader lub banner
    final type = _lockedType ?? _AdType.banner;

    switch (type) {
      case _AdType.banner:
        return const InlineBannerAd(size: AdSize.mediumRectangle);
      case _AdType.interstitial:
        return const _InterstitialProgressAd();
      case _AdType.rewarded:
        return const _RewardedProgressAd();
    }
  }
}

enum _AdType { banner, interstitial, rewarded }

// ── Krótki filmik (interstitial) ─────────────────────────────────────────────

class _InterstitialProgressAd extends StatefulWidget {
  const _InterstitialProgressAd({Key? key}) : super(key: key);

  @override
  State<_InterstitialProgressAd> createState() =>
      _InterstitialProgressAdState();
}

class _InterstitialProgressAdState extends State<_InterstitialProgressAd> {
  InterstitialAd? _ad;
  bool _shown = false;
  bool _showFallbackBanner = false; // Nowa flaga

  static const _androidId = 'ca-app-pub-3940256099942544/1033173712';
  static const _iosId = 'ca-app-pub-3940256099942544/4411468910';

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) _load();
  }

  void _load() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid ? _androidId : _iosId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _ad!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              setState(
                () => _showFallbackBanner = true,
              ); // Pokaż banner po zamknięciu
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              setState(
                () => _showFallbackBanner = true,
              ); // Pokaż banner jeśli wideo padło
            },
          );
          if (mounted && !_shown) {
            _shown = true;
            _ad!.show();
          }
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ad] Interstitial failed: $error');
          setState(() => _showFallbackBanner = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showFallbackBanner) {
      return const InlineBannerAd(size: AdSize.mediumRectangle);
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '🎬 Ładowanie reklamy wideo...',
        style: TextStyle(color: Colors.white38, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }
}

// ── Filmik z nagrodą (rewarded) ───────────────────────────────────────────────

class _RewardedProgressAd extends StatefulWidget {
  const _RewardedProgressAd({Key? key}) : super(key: key);

  @override
  State<_RewardedProgressAd> createState() => _RewardedProgressAdState();
}

class _RewardedProgressAdState extends State<_RewardedProgressAd> {
  RewardedAd? _ad;
  bool _shown = false;
  bool _showFallbackBanner = false; // Nowa flaga

  static const _androidId = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosId = 'ca-app-pub-3940256099942544/1712485313';

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) _load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _load() {
    RewardedAd.load(
      adUnitId: Platform.isAndroid ? _androidId : _iosId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _ad!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              setState(
                () => _showFallbackBanner = true,
              ); // Pokaż banner po wideo
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              setState(() => _showFallbackBanner = true);
            },
          );
          if (mounted && !_shown) {
            _shown = true;
            _ad!.show(onUserEarnedReward: (_, reward) => {});
          }
        },
        onAdFailedToLoad: (error) {
          setState(() => _showFallbackBanner = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showFallbackBanner) {
      return const InlineBannerAd(size: AdSize.mediumRectangle);
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '🎁 Ładowanie reklamy z nagrodą...',
        style: TextStyle(color: Colors.white38, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class InlineBannerAd extends StatefulWidget {
  final AdSize size; // Dodajemy parametr rozmiaru

  const InlineBannerAd({
    Key? key,
    this.size = AdSize.mediumRectangle, // Domyślny rozmiar
  }) : super(key: key);

  @override
  _InlineBannerAdState createState() => _InlineBannerAdState();
}

class _InlineBannerAdState extends State<InlineBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      _loadAd();
    }
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716',
      request: const AdRequest(),
      size: widget.size, // Używamy rozmiaru z parametru widgetu
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _bannerAd = null);
          debugPrint('Ad failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}
