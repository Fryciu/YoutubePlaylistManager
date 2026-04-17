import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'actions.dart';
import 'history_page.dart';
import 'task_queue.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'asyncbutton.dart';
//import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  //(await SharedPreferences.getInstance()).clear();
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();

  final initialProfile = await PlaylistActions.getInitialProfile();
  runApp(MyApp(initialProfile: initialProfile));
}

Future<Directory> getAppDirectory() async {
  if (Platform.isWindows) {
    return File(Platform.resolvedExecutable).parent;
  } else {
    return await getApplicationDocumentsDirectory();
  }
}

// Nowa — zwraca folder specyficzny dla konta
Future<Directory> getUserDirectory() async {
  final base = await getAppDirectory();
  final email = PlaylistActions.currentUserNotifier.value?.email;
  if (email == null) return base; // fallback gdy niezalogowany
  final safe = email.replaceAll(RegExp(r'[^\w@.]'), '_');
  final dir = Directory('${base.path}${Platform.pathSeparator}$safe');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<void> saveJSON(dynamic data, {String type = "API_key"}) async {
  try {
    final directory = type.toLowerCase() == 'api_key'
        ? await getAppDirectory()
        : await getUserDirectory();
    final String fileName = type.toLowerCase() == 'api_key'
        ? 'api_key.json'
        : 'playlisty.json';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(json.encode(data));
  } catch (e) {
    debugPrint("Błąd zapisu: $e");
  }
}

Future<Map<String, dynamic>> loadJSON({String type = "API_key"}) async {
  try {
    final directory = type.toLowerCase() == 'api_key'
        ? await getAppDirectory()
        : await getUserDirectory();
    final String fileName = type.toLowerCase() == 'api_key'
        ? 'api_key.json'
        : 'playlisty.json';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      return json.decode(await file.readAsString());
    }
  } catch (e) {
    debugPrint("Błąd odczytu ($type): $e");
  }
  return {};
}

class MyApp extends StatelessWidget {
  final UserProfile? initialProfile;
  const MyApp({Key? key, this.initialProfile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pl'), Locale('en')],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      ),
      home: HomePage(initialProfile: initialProfile),
    );
  }
}

class HomePage extends StatefulWidget {
  final UserProfile? initialProfile;
  const HomePage({Key? key, this.initialProfile}) : super(key: key);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  List<dynamic> _playlists = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await migrateOldDataIfNeeded(); // <-- dodaj
    Map<String, dynamic> data = await loadJSON(type: "playlisty");
    setState(() {
      _playlists = data['playlists'] ?? [];
      _isLoading = false;
    });
  }

  // Naprawiona metoda usuwania pojedynczej playlisty
  Future<void> _deletePlaylist(int index) async {
    setState(() {
      _playlists.removeAt(index);
    });
    await saveJSON({"playlists": _playlists}, type: "playlisty");
  }

  Future<void> migrateOldDataIfNeeded() async {
    final email = PlaylistActions.currentUserNotifier.value?.email;
    if (email == null) return;

    final base = await getAppDirectory();
    final userDir = await getUserDirectory();

    for (final fileName in ['history.json', 'playlisty.json']) {
      final oldFile = File('${base.path}${Platform.pathSeparator}$fileName');
      final newFile = File('${userDir.path}${Platform.pathSeparator}$fileName');

      if (await oldFile.exists() && !await newFile.exists()) {
        await oldFile.copy(newFile.path);
        await oldFile.delete();
        debugPrint('[Migration] Przeniesiono $fileName → ${newFile.path}');
      }
    }
  }

  void _showPlaylistSelectionDialog(
    BuildContext context,
    List<Map<String, String>> playlists,
  ) {
    final l10n = AppLocalizations.of(context)!;
    List<Map<String, String>> selected = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isAllSelected =
                selected.length == playlists.length && playlists.isNotEmpty;
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.chooseplaylists,
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    "${selected.length}/${playlists.length}",
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      activeColor: Colors.blue,
                      title: Text(
                        l10n.selectAll,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: isAllSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selected = List.from(playlists);
                          } else {
                            selected.clear();
                          }
                        });
                      },
                    ),
                    const Divider(color: Colors.white24),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final p = playlists[index];
                          return CheckboxListTile(
                            activeColor: Colors.green,
                            title: Text(
                              p['name']!,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            subtitle: Text(
                              "ID: ${p['id']}",
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                            value: selected.contains(p),
                            onChanged: (val) {
                              setDialogState(() {
                                val == true
                                    ? selected.add(p)
                                    : selected.remove(p);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Anuluj",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selected.isEmpty
                        ? Colors.grey
                        : Colors.green,
                  ),
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          setState(() {
                            final existingIds = _playlists
                                .map((pl) => pl['id'])
                                .toSet();
                            for (var s in selected) {
                              if (!existingIds.contains(s['id']))
                                _playlists.add(s);
                            }
                          });
                          await saveJSON({
                            "playlists": _playlists,
                          }, type: "playlisty");
                          if (mounted) Navigator.pop(context);
                        },
                  child: Text(l10n.addSelected),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final dynamic item = _playlists.removeAt(oldIndex);
      _playlists.insert(newIndex, item);
    });
    await saveJSON({"playlists": _playlists}, type: "playlisty");
  }

  void _showEditSheet(Map<String, dynamic> item, int index) {
    final l10n = AppLocalizations.of(context)!;
    final nameEdit = TextEditingController(text: item['name']);
    final idEdit = TextEditingController(text: item['id']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.edit,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildInput(nameEdit, l10n.nameLabel),
            const SizedBox(height: 10),
            _buildInput(idEdit, l10n.idLabel),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                setState(() {
                  _playlists[index] = {
                    "name": nameEdit.text,
                    "id": idEdit.text,
                  };
                });
                await saveJSON({"playlists": _playlists}, type: "playlisty");
                if (mounted) Navigator.pop(context);
              },
              child: Text(l10n.saveChanges),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  final GlobalKey _contentKey = GlobalKey();
  double _availableSpace = 0;

  void _updateAvailableSpace(BoxConstraints constraints) {
    // Zwiększamy opóźnienie do 350ms, żeby mieć PEWNOŚĆ,
    // że ExpansionTile skończył się rozwijać na telefonie.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      final RenderBox? renderBox =
          _contentKey.currentContext?.findRenderObject() as RenderBox?;

      if (renderBox != null) {
        final contentHeight = renderBox.size.height;
        // Obliczamy miejsce: Max wysokość ekranu - wysokość listy - mały margines (10)
        final newSpace = (constraints.maxHeight - contentHeight - 10).clamp(
          0.0,
          double.infinity,
        );

        // Bardzo ważne: setState tylko jeśli różnica jest istotna
        if ((newSpace - _availableSpace).abs() > 5) {
          setState(() {
            _availableSpace = newSpace;
          });
        }
      }
    });
  }

  void _showDeleteAllPlaylistsDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          l10n.confirmDeleteTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(l10n.deleteAllPlaylistsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              setState(() => _playlists.clear());
              await saveJSON({"playlists": []}, type: "playlisty");
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.listCleared)));
              }
            },
            child: Text(
              l10n.deleteAll,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(l10n.appTitle),
        actions: [const TaskQueueButton()],
      ),
      drawer: AppMenuDrawer(
        onInitData: _initData,
        onClearPlaylists: () => setState(() => _playlists.clear()),
      ),
      endDrawer: const TaskQueueDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<UserProfile?>(
              valueListenable: PlaylistActions.currentUserNotifier,
              builder: (context, user, child) {
                // ── Niezalogowany ──────────────────────────────────────────
                // ── Niezalogowany ──────────────────────────────────────────
                if (user == null) {
                  return Center(
                    child: SingleChildScrollView(
                      // Dodane, aby na małych ekranach reklama nie zasłoniła tekstu
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: Colors.white24,
                              size: 64,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              l10n.notlogged,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 32),
                            AppAsyncButton(
                              icon: Icons.login,
                              label: l10n.login,
                              onPressed: () async {
                                await PlaylistActions.signInExplicitly();
                                await _initData();
                              },
                            ),
                            // --- SEKCJA REKLAMY ---
                            const SizedBox(
                              height: 48,
                            ), // Większy odstęp dla przejrzystości
                            const Text(
                              "ADVERTISEMENT", // Możesz dodać klucz w ARB np. l10n.ads
                              style: TextStyle(
                                color: Colors.white10,
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InlineBannerAd(size: AdSize.mediumRectangle),
                            // ----------------------
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // ── Zalogowany ─────────────────────────────────────────────
                return LayoutBuilder(
                  builder: (context, constraints) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _updateAvailableSpace(constraints),
                    );
                    return Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Column(
                                key: _contentKey,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            right: 5,
                                          ),
                                          // Wewnątrz Twojego widgetu (np. _buildPlaylistCard)
                                          child: AppAsyncButton(
                                            textStyle: const TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.blueGrey[900],
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 15,
                                                  ),
                                            ),
                                            icon: Icons
                                                .playlist_add_check, // Ikona koloru niebieskiego wewnątrz widgetu
                                            label: l10n.importplaylists
                                                .toUpperCase(),
                                            // Przekazujemy logikę:
                                            onPressed: () async {
                                              // Wywołujemy akcję (AppAsyncButton zajmie się resztą, jeśli to potrwa długo)
                                              final allPlaylists =
                                                  await PlaylistActions.fetchUserPlaylists();

                                              if (allPlaylists.isEmpty) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        l10n.noPlaylistsFound,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return;
                                              }

                                              if (context.mounted) {
                                                _showPlaylistSelectionDialog(
                                                  context,
                                                  allPlaylists,
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 5,
                                          ),
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF1E1E1E,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 15,
                                                  ),
                                              side: const BorderSide(
                                                color: Colors.white10,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.history,
                                              color: Colors.green,
                                              size: 20,
                                            ),
                                            label: Text(
                                              l10n.historyTitle.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            ),
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const HistoryPage(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 40),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        l10n.savedPlaylists,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (_playlists.isNotEmpty)
                                        TextButton.icon(
                                          onPressed:
                                              _showDeleteAllPlaylistsDialog,
                                          icon: const Icon(
                                            Icons.delete_sweep,
                                            color: Colors.redAccent,
                                          ),
                                          label: Text(
                                            l10n.deleteAll,
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _playlists.length,
                                    onReorder: _onReorder,
                                    itemBuilder: (context, index) =>
                                        _buildPlaylistCard(
                                          _playlists[index],
                                          index,
                                          ValueKey(
                                            "item_${_playlists[index]['id']}_$index",
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_availableSpace > 30)
                          Container(
                            color: Colors.black,
                            key: ValueKey(
                              'ad_container_${_availableSpace.floor()}',
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 4, bottom: 2),
                                  child: Text(
                                    "Sponsored by:",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white30,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                InlineBannerAd(
                                  size: AdSize(
                                    width: MediaQuery.of(
                                      context,
                                    ).size.width.floor(),
                                    height: _availableSpace.floor(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildPlaylistCard(Map<String, dynamic> item, int index, Key key) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item['name'] ?? l10n.noName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ),
              const Icon(Icons.reorder, color: Colors.white24),
            ],
          ),
          const SizedBox(height: 8),
          _richInfo("${l10n.idorlink}: ", item['id'] ?? ""),
          const SizedBox(height: 15),
          Row(
            children: [
              _cardButton(
                l10n.edit,
                const Color(0xFF3A3A3A),
                () => _showEditSheet(item, index),
              ),
              const SizedBox(width: 8),
              _cardButton(
                l10n.remove,
                const Color(0xFF3A3A3A),
                () => _deletePlaylist(index),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: AppAsyncButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              icon: Icons.play_arrow,
              label: l10n.chooseVideos_to_be_removed,
              onPressed: () async {
                // Nie potrzebujesz już tutaj showDialog!
                final videos = await PlaylistActions.fetchPlaylistItems(
                  item['id'] as String? ?? '',
                );

                if (videos.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.noVideosFound)));
                  }
                  return;
                }

                if (!mounted) return;
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VideoSelectionPage(playlistData: item, videos: videos),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _richInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white70),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _cardButton(String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Lewy drawer — główne menu
// ─────────────────────────────────────────────

class AppMenuDrawer extends StatelessWidget {
  final Future<void> Function() onInitData;
  final VoidCallback onClearPlaylists;

  const AppMenuDrawer({
    Key? key,
    required this.onInitData,
    required this.onClearPlaylists,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: const Color(0xFF141414),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Konto Google ──────────────────────────────────────────────
            ValueListenableBuilder<UserProfile?>(
              valueListenable: PlaylistActions.currentUserNotifier,
              builder: (context, user, _) {
                final bool isLoggedIn = user != null;
                return Container(
                  color: Colors.green[900],
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: isLoggedIn
                            ? Colors.green[700]
                            : Colors.white10,
                        backgroundImage: (isLoggedIn && user.photoUrl != null)
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: (!isLoggedIn || user.photoUrl == null)
                            ? Icon(
                                isLoggedIn
                                    ? Icons.person
                                    : Icons.person_outline,
                                color: Colors.white,
                                size: 28,
                              )
                            : null,
                      ),
                      const SizedBox(height: 10),
                      if (isLoggedIn) ...[
                        Text(
                          user.displayName ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          user.email ?? '',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                          label: Text(
                            l10n.logout,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await PlaylistActions.signOut();
                            onClearPlaylists();
                          },
                        ),
                      ] else ...[
                        Text(
                          l10n.notlogged,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.login,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: Text(
                            l10n.login,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await PlaylistActions.signInExplicitly();
                            await onInitData();
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // ── Pozycje menu ──────────────────────────────────────────────
            _MenuItem(
              icon: Icons.help_outline,
              label: l10n.helptitle,
              iconColor: Colors.white70,
              onTap: () {
                Navigator.pop(context);
                _showTutorialDialog(context);
              },
            ),
            _MenuItem(
              icon: Icons.queue_play_next,
              label: 'Kolejka zadań',
              iconColor: Colors.orange,
              trailing: ValueListenableBuilder<List<TaskEntry>>(
                valueListenable: TaskQueue.instance.tasks,
                builder: (_, tasks, __) {
                  final n = TaskQueue.instance.activeCount;
                  final hasQuota = tasks.any(
                    (t) => t.status.value == TaskStatus.quotaExceeded,
                  );
                  if (n == 0 && !hasQuota) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: hasQuota ? Colors.red : Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      hasQuota ? '!' : '$n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              onTap: () {
                Navigator.pop(context);
                // Otwórz prawy drawer przez krótkie opóźnienie
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (context.mounted) {
                    Scaffold.of(context).openEndDrawer();
                  }
                });
              },
            ),

            const Divider(color: Colors.white12, indent: 16, endIndent: 16),

            // ── Wsparcie ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Wsparcie',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.email_outlined,
              label: 'Napisz do mnie',
              sublabel: 'fryciuuu@email.com',
              iconColor: Colors.blueAccent,
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri(
                  scheme: 'mailto',
                  path: 'fryciuuu@email.com',
                  query: 'subject=YT Playlist Manager',
                );
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),
            _MenuItem(
              icon: Icons.coffee_outlined,
              label: 'Buy Me a Coffee',
              sublabel: 'buymeacoffee.com/mojanazwa',
              iconColor: const Color(0xFFFFDD00),
              onTap: () async {
                Navigator.pop(context);
                final uri = Uri.parse('https://buymeacoffee.com/mojanazwa');
                if (await canLaunchUrl(uri)) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),

            const Spacer(),

            // ── Stopka ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'YT Playlist Manager',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.sublabel,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Ekran wyboru filmów do usunięcia
// ─────────────────────────────────────────────

void _showTutorialDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(l10n.helptitle, style: const TextStyle(color: Colors.green)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.helpstep1, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text(l10n.helpstep2, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text(l10n.helpstep3, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text(l10n.helpstep4, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text(l10n.helpstep5, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.understand,
            style: const TextStyle(color: Colors.green),
          ),
        ),
      ],
    ),
  );
}

class VideoSelectionPage extends StatefulWidget {
  final Map<String, dynamic> playlistData;
  final List<VideoItem> videos;

  const VideoSelectionPage({
    Key? key,
    required this.playlistData,
    required this.videos,
  }) : super(key: key);

  @override
  _VideoSelectionPageState createState() => _VideoSelectionPageState();
}

class _VideoSelectionPageState extends State<VideoSelectionPage> {
  late Set<int> _selectedPositions;
  final TextEditingController _rangeController = TextEditingController();
  bool _syncingFromText = false;
  bool _syncingFromGrid = false;
  double _availableSpace = 0;

  @override
  void initState() {
    super.initState();
    _selectedPositions = {};
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  // Parsowanie "1-5,7,9-11" → Set<int>
  Set<int> _parseRangeText(String text) {
    final Set<int> result = {};
    final int maxPos = widget.videos.length;
    for (final part in text.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('-')) {
        final parts = trimmed.split('-');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0].trim());
          final end = int.tryParse(parts[1].trim());
          if (start != null && end != null && start <= end) {
            for (int i = start; i <= end && i <= maxPos; i++) {
              if (i >= 1) result.add(i);
            }
          }
        }
      } else {
        final num = int.tryParse(trimmed);
        if (num != null && num >= 1 && num <= maxPos) result.add(num);
      }
    }
    return result;
  }

  // Konwersja Set<int> → "1-5,7,9-11"
  String _selectionToRangeText(Set<int> positions) {
    if (positions.isEmpty) return '';
    final sorted = positions.toList()..sort();
    final List<String> parts = [];
    int start = sorted[0];
    int end = sorted[0];

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        parts.add(start == end ? '$start' : '$start-$end');
        start = sorted[i];
        end = sorted[i];
      }
    }
    parts.add(start == end ? '$start' : '$start-$end');
    return parts.join(',');
  }

  void _onRangeTextChanged(String text) {
    if (_syncingFromGrid) return;
    _syncingFromText = true;
    setState(() {
      _selectedPositions = _parseRangeText(text);
    });
    _syncingFromText = false;
  }

  void _toggleVideo(int position) {
    setState(() {
      if (_selectedPositions.contains(position)) {
        _selectedPositions.remove(position);
      } else {
        _selectedPositions.add(position);
      }
    });
    if (!_syncingFromText) {
      _syncingFromGrid = true;
      _rangeController.text = _selectionToRangeText(_selectedPositions);
      _syncingFromGrid = false;
    }
  }

  void _selectAll() {
    setState(() {
      _selectedPositions = Set.from(
        List.generate(widget.videos.length, (i) => i + 1),
      );
    });
    _rangeController.text = widget.videos.length > 1
        ? '1-${widget.videos.length}'
        : '1';
  }

  void _clearSelection() {
    setState(() {
      _selectedPositions.clear();
    });
    _rangeController.clear();
  }

  /// Właściwa logika usuwania — wykrywa quota i rzuca [QuotaExceededException].
  /// Może być wywołana zarówno przy pierwszym uruchomieniu jak i przy wznowieniu.
  static Future<void> _deleteWork({
    required TaskEntry entry,
    required Map<String, dynamic> playlistData,
    required List<VideoItem> videos,
  }) async {
    final startTime = DateTime.now();
    int? estimatedTotal;

    // Jeśli to wznowienie po quota — bierzemy tylko pozostałe filmy z entry
    final List<VideoItem> toDelete = (entry.remainingItems != null)
        ? entry.remainingItems!.cast<VideoItem>()
        : videos;

    final int total = videos.length;
    final int alreadyDone = total - toDelete.length;

    Map<String, dynamic>? partialToSave;

    try {
      await PlaylistActions.processPlaylistItemsWithQuota(
        playlistData,
        toDelete,
        (current, totalCount, title) {
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          int? eta;
          if (current > 0 && elapsed > 0) {
            final avg = elapsed / current;
            eta = ((totalCount - current) * avg).round();
            estimatedTotal ??= (totalCount * avg).round();
          }
          entry.progress.value = ProgressInfo(
            alreadyDone + current,
            total,
            title,
            etaSeconds: eta,
            estimatedTotalSeconds: estimatedTotal,
          );
        },
        onPartialResult: (data) {
          partialToSave = data;
        },
      );
    } on QuotaExceededException {
      // Zapisz częściową historię zanim wyjątek poleci dalej do TaskQueue
      if (partialToSave != null && partialToSave!.isNotEmpty) {
        await PlaylistActions.saveDeletedHistory(partialToSave!);
      }
      rethrow;
    }

    if (partialToSave != null && partialToSave!.isNotEmpty) {
      await PlaylistActions.saveDeletedHistory(partialToSave!);
    }
  }

  Future<void> _startDeletion() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedPositions.isEmpty) return;

    final selectedVideos = widget.videos
        .where((v) => _selectedPositions.contains(v.position))
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(l10n.confirmTitle),
        content: Text(l10n.deleteConfirmMessage(selectedVideos.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final playlistName = widget.playlistData['name'] as String? ?? 'Playlista';
    final capturedPlaylistData = Map<String, dynamic>.from(widget.playlistData);
    final capturedVideos = List<VideoItem>.from(selectedVideos);

    // Dodaj do kolejki — UI nie blokuje się
    TaskQueue.instance.add(
      label: 'Usuń z: $playlistName (${selectedVideos.length} filmów)',
      icon: '🗑️',
      work: (entry) => _deleteWork(
        entry: entry,
        playlistData: capturedPlaylistData,
        videos: capturedVideos,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Usuwanie ${selectedVideos.length} filmów dodane do kolejki',
          ),
          backgroundColor: Colors.green[800],
          action: SnackBarAction(
            label: 'Kolejka',
            textColor: Colors.white,
            onPressed: () {
              // Otwórz drawer przez nawigator — wróć do home
              Navigator.pop(context, true);
            },
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final int total = widget.videos.length;
    final int selectedCount = _selectedPositions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      endDrawer: const TaskQueueDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.green,
        actions: [
          TextButton(
            onPressed: selectedCount == total ? _clearSelection : _selectAll,
            child: Text(
              selectedCount == total ? l10n.unselectAll : l10n.selectAll,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => _showTutorialDialog(context),
          ),
          const TaskQueueButton(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Header: pole tekstowe z zakresem ──────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: const Color(0xFF1A1A1A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _rangeController,
                          onChanged: _onRangeTextChanged,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: l10n.rangeHint,
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: _selectedPositions.isNotEmpty
                                ? Container(
                                    margin: const EdgeInsets.all(6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[800],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      l10n.selectedCount(
                                        _selectedPositions.length,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Lazy grid z miniaturkami ───────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 16 / 9,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final video = widget.videos[index];
                      final isSelected = _selectedPositions.contains(
                        video.position,
                      );
                      return GestureDetector(
                        onTap: () => _toggleVideo(video.position),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.green
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                video.thumbnailUrl.isNotEmpty
                                    ? Image.network(
                                        video.thumbnailUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                              color: Color(0xFF2A2A2A),
                                              child: Icon(
                                                Icons.play_circle_outline,
                                                color: Colors.white24,
                                              ),
                                            ),
                                      )
                                    : const ColoredBox(
                                        color: Color(0xFF2A2A2A),
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          color: Colors.white24,
                                        ),
                                      ),
                                if (isSelected)
                                  Container(
                                    color: Colors.green.withOpacity(0.35),
                                    child: const Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${video.position}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.black54,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 3,
                                    ),
                                    child: Text(
                                      video.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: widget.videos.length),
                  ),
                ),
              ],
            ),
          ),
          if (_availableSpace > 30)
            Container(
              color: Colors.black,
              key: ValueKey('ad_sel_${_availableSpace.floor()}'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      "Sponsored by:",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white30,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  InlineBannerAd(
                    size: AdSize(
                      width: MediaQuery.of(context).size.width.floor(),
                      height: _availableSpace.floor() - 30,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      // Przycisk usuń na dole
      bottomNavigationBar: selectedCount > 0
          ? SafeArea(
              child: Container(
                color: const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: Text(l10n.deleteAction(selectedCount)),
                  onPressed: _startDeletion,
                ),
              ),
            )
          : null,
    );
  }
}

String _formatEta(int seconds) {
  if (seconds <= 0) return '⏱ Kończenie...';
  if (seconds < 60) return '⏱ Pozostało: ~${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '⏱ Pozostało: ~${m}min ${s}s';
}

void showProgressDialog(BuildContext context, String title) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: ValueListenableBuilder<ProgressInfo>(
        valueListenable: currentProgress,
        builder: (context, info, child) {
          double progress = info.total > 0 ? info.current / info.total : 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress, color: Colors.green),
              const SizedBox(height: 15),
              ProgressAdWidget(
                estimatedTotalSeconds: info.estimatedTotalSeconds,
              ),
              const SizedBox(height: 15),
              Text(
                "${info.current} / ${info.total}",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (info.etaSeconds != null) ...[
                const SizedBox(height: 6),
                Text(
                  _formatEta(info.etaSeconds!),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                info.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class ProgressInfo {
  final int current;
  final int total;
  final String status;
  final int? etaSeconds; // null = jeszcze nie wiadomo
  final int? estimatedTotalSeconds; // łączny szacowany czas całej operacji
  ProgressInfo(
    this.current,
    this.total,
    this.status, {
    this.etaSeconds,
    this.estimatedTotalSeconds,
  });
}

final ValueNotifier<ProgressInfo> currentProgress = ValueNotifier(
  ProgressInfo(0, 0, "initialization"),
);
