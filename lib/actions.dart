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

class PlaylistActions {
  static final auth.ClientId _desktopClientId = auth.ClientId(
    '836288924762-iigge2a1e53nlmru0l5a462o2dnumqfm.apps.googleusercontent.com',
    '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',
  );
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _initialized = false;

  static final List<String> _scopes = [YouTubeApi.youtubeForceSslScope];

  static Future<void> initialize() async {
    if (_initialized) return;
    await _googleSignIn.initialize();
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

  static Future<auth.AuthClient?> _getAuthClient() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await initialize();
        GoogleSignInAccount? account = await _googleSignIn
            .attemptLightweightAuthentication();
        if (account == null) {
          if (_googleSignIn.supportsAuthenticate()) {
            account = await _googleSignIn.authenticate();
          } else {
            return null;
          }
        }
        GoogleSignInClientAuthorization? authorization = await account
            .authorizationClient
            .authorizationForScopes(_scopes);
        authorization ??= await account.authorizationClient.authorizeScopes(
          _scopes,
        );
        return authorization.authClient(scopes: _scopes);
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final directory = await getAppDirectory();
        final tokenFile = File(
          '${directory.path}${Platform.pathSeparator}token.json',
        );

        if (await tokenFile.exists()) {
          final content = await tokenFile.readAsString();
          final credentials = auth.AccessCredentials.fromJson(
            json.decode(content) as Map<String, dynamic>,
          );
          final baseClient = http.Client();
          final refreshed = await auth.refreshCredentials(
            _desktopClientId,
            credentials,
            baseClient,
          );
          await tokenFile.writeAsString(json.encode(refreshed.toJson()));
          return auth.authenticatedClient(baseClient, refreshed);
        }

        final client = await auth_io.clientViaUserConsent(
          _desktopClientId,
          _scopes,
          (url) async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );
        await tokenFile.writeAsString(json.encode(client.credentials.toJson()));
        return client;
      }
      return null;
    } catch (e) {
      debugPrint('Błąd autoryzacji: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // Przetwarzanie (USUWANIE)
  // ─────────────────────────────────────────────

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

    for (int i = 0; i < total; i++) {
      onProgress(i + 1, total, videoEntries[i].key);
      await reAddVideoToPlaylist(
        playlistId,
        videoEntries[i].value,
        dateOfAddition,
        updateHistoryInFile: false,
      );
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
      final directory = await getAppDirectory();
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
      final directory = await getAppDirectory();
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
      final directory = await getAppDirectory();
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

  static Future<Map<String, dynamic>> saveDeletedHistory(
    Map<String, dynamic> deletedNames,
  ) async {
    if (deletedNames.isEmpty) return {};
    try {
      final directory = await getAppDirectory();
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
}

// Przykład pomocniczego widgetu dla AdMob
class InlineBannerAd extends StatefulWidget {
  const InlineBannerAd({Key? key}) : super(key: key);

  @override
  _InlineBannerAdState createState() => _InlineBannerAdState();
}

class _InlineBannerAdState extends State<InlineBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Testowy ID Android
          : 'ca-app-pub-3940256099942544/2934735716', // Testowy ID iOS
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
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
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox(
      height: 50,
      child: Center(
        child: Text(
          "Ad...",
          style: TextStyle(color: Colors.white24, fontSize: 10),
        ),
      ),
    );
  }
}
