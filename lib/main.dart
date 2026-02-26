import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
// Importy dla lokalizacji
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'actions.dart';
import 'history_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Dodaj import

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize(); // Inicjalizacja reklam
  runApp(const MyApp());
}

Future<Directory> getAppDirectory() async {
  if (Platform.isWindows) {
    return File(Platform.resolvedExecutable).parent;
  } else {
    return await getApplicationDocumentsDirectory();
  }
}

Future<void> saveJSON(dynamic data, {String type = "API_key"}) async {
  try {
    final directory = await getAppDirectory();
    final String fileName = type.toLowerCase() == 'api_key'
        ? 'api_key.json'
        : 'playlisty.json';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    String jsonString = json.encode(data);
    await file.writeAsString(jsonString);
  } catch (e) {
    debugPrint("Błąd zapisu: $e");
  }
}

Future<Map<String, dynamic>> loadJSON({String type = "API_key"}) async {
  try {
    final directory = await getAppDirectory();
    final String fileName = type.toLowerCase() == 'api_key'
        ? 'api_key.json'
        : 'playlisty.json';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');

    if (await file.exists()) {
      final contents = await file.readAsString();
      return json.decode(contents);
    }
  } catch (e) {
    debugPrint("Błąd odczytu ($type): $e");
  }
  return {};
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // --- KONFIGURACJA TŁUMACZEŃ ---
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pl'), Locale('en')],
      // ------------------------------
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  List<dynamic> _playlists = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _deleteCountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    Map<String, dynamic> data = await loadJSON(type: "playlisty");

    setState(() {
      _playlists = data['playlists'] ?? [];
      _isLoading = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final dynamic item = _playlists.removeAt(oldIndex);
      _playlists.insert(newIndex, item);
    });
    await saveJSON({"playlists": _playlists}, type: "playlisty");
  }

  Future<void> _addNewPlaylist() async {
    if (_nameController.text.isEmpty || _idController.text.isEmpty) return;

    Map<String, String> newEntry = {
      "name": _nameController.text,
      "id": _idController.text,
      "deleteCount": _deleteCountController.text,
    };

    setState(() {
      _playlists.add(newEntry);
    });

    await saveJSON({"playlists": _playlists}, type: "playlisty");
    _nameController.clear();
    _idController.clear();
    _deleteCountController.clear();
  }

  Future<void> _deletePlaylist(int index) async {
    setState(() {
      _playlists.removeAt(index);
    });
    await saveJSON({"playlists": _playlists}, type: "playlisty");
  }

  void _showEditSheet(Map<String, dynamic> item, int index) {
    final l10n = AppLocalizations.of(context)!;
    final nameEdit = TextEditingController(text: item['name']);
    final idEdit = TextEditingController(text: item['id']);
    final countEdit = TextEditingController(
      text: item['deleteCount'].toString(),
    );

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
              l10n.edit, // Użycie tłumaczenia "Edytuj"
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildInput(nameEdit, "Nazwa"),
            const SizedBox(height: 10),
            _buildInput(idEdit, "ID"),
            const SizedBox(height: 10),
            _buildInput(countEdit, "Liczba filmów"),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                setState(() {
                  _playlists[index] = {
                    "name": nameEdit.text,
                    "id": idEdit.text,
                    "deleteCount": countEdit.text,
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

  void _showTutorialDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(l10n.helptitle, style: TextStyle(color: Colors.green)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.helpstep1, style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              Text(l10n.helpstep2, style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              Text(l10n.helpstep3, style: TextStyle(color: Colors.white70)),
              SizedBox(height: 10),
              Text(l10n.helpstep4, style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.understand, style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Skrót do tłumaczeń dla wygody
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showTutorialDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      l10n.addNewPlaylist,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildInput(_nameController, l10n.playlistName),
                    const SizedBox(height: 10),
                    _buildInput(_idController, l10n.playlistId),
                    const SizedBox(height: 10),
                    _buildInput(_deleteCountController, l10n.deleteCountHint),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C2C2C),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: _addNewPlaylist,
                      child: Text(
                        l10n.addPlaylistBtn,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const Divider(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: const BorderSide(color: Colors.white10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.history, color: Colors.green),
                        label: Text(
                          l10n.historyTitle.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text(
                      l10n.savedPlaylists,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _playlists.length,
                      onReorder: _onReorder,
                      itemBuilder: (context, index) {
                        final item = _playlists[index];
                        return _buildPlaylistCard(
                          item,
                          index,
                          ValueKey("item_${item['id']}_$index"),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
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
          _richInfo("${l10n.forDeletion}: ", item['deleteCount'] ?? ""),
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
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(l10n.removeVideos.toUpperCase()),
              onPressed: () async {
                // Reset postępu i pokazanie dialogu
                currentProgress.value = ProgressInfo(0, 0, "Łączenie...");
                showProgressDialog(context, "Usuwanie filmów");

                final deletedData = await PlaylistActions.processPlaylist(
                  item,
                  (current, total, title) {
                    currentProgress.value = ProgressInfo(current, total, title);
                  },
                );

                Navigator.pop(context); // Zamknij dialog

                if (deletedData.isNotEmpty) {
                  await PlaylistActions.saveDeletedHistory(deletedData);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.deleteSuccess)));
                }
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
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}

void showProgressDialog(BuildContext context, String title) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        // Używamy globalnego streamu lub prostego powiadomienia (poniżej uproszczona wersja przez ValueNotifier)
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: ValueListenableBuilder<ProgressInfo>(
            valueListenable: currentProgress,
            builder: (context, info, child) {
              double progress = info.total > 0 ? info.current / info.total : 0;

              // main.dart

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress, color: Colors.green),
                  const SizedBox(height: 15),

                  // REKLAMA GOOGLE NAD STATUSEM
                  const InlineBannerAd(),

                  const SizedBox(height: 15),
                  Text(
                    "${info.current} / ${info.total}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // ... reszta kodu statusu
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
        );
      },
    ),
  );
}

class ProgressInfo {
  final int current;
  final int total;
  final String status;
  ProgressInfo(this.current, this.total, this.status);
}

final ValueNotifier<ProgressInfo> currentProgress = ValueNotifier(
  ProgressInfo(0, 0, "Inicjalizacja..."),
);
