import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'main.dart';
import 'actions.dart';
import 'l10n/app_localizations.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Map<String, dynamic> _historyData = {};
  bool _loading = true;
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final directory = await getAppDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}history.json',
      );

      if (await file.exists()) {
        final content = await file.readAsString();
        if (mounted) {
          setState(() {
            _historyData = json.decode(content);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("Błąd ładowania historii: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showProgress(String title) {
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
                const InlineBannerAd(),
                const SizedBox(height: 15),
                Text(
                  "${info.current} / ${info.total}",
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(l10n.deletedvideoshistory),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          IconButton(
            icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => _ascending = !_ascending),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _historyData.isEmpty
          ? Center(
              child: Text(
                l10n.nohistory,
                style: const TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              itemCount: _historyData.length,
              itemBuilder: (context, index) {
                String playlistId = _historyData.keys.elementAt(index);
                return _buildPlaylistSection(
                  playlistId,
                  _historyData[playlistId],
                );
              },
            ),
    );
  }

  Widget _buildPlaylistSection(String playlistId, dynamic data) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic> dates = data['Dates'] ?? {};
    var sortedDates = dates.keys.toList();
    sortedDates.sort((a, b) => _ascending ? a.compareTo(b) : b.compareTo(a));

    return Card(
      color: const Color(0xFF121212),
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        iconColor: Colors.green,
        collapsedIconColor: Colors.white54,
        title: Text(
          data['Name'] ?? l10n.unknownplaylist,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "ID: $playlistId",
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
          onPressed: () => _confirmDeletePlaylist(playlistId),
        ),
        children: sortedDates
            .map((date) => _buildDateSection(playlistId, date, dates[date]))
            .toList(),
      ),
    );
  }

  Widget _buildDateSection(String playlistId, String date, dynamic videos) {
    final l10n = AppLocalizations.of(context)!;
    Map<String, dynamic> videoMap = Map<String, dynamic>.from(videos);

    return Container(
      color: const Color(0xFF1A1A1A),
      child: ExpansionTile(
        title: Text(
          date,
          style: const TextStyle(color: Colors.green, fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.settings_backup_restore,
                color: Colors.green,
              ),
              onPressed: () async {
                currentProgress.value = ProgressInfo(
                  0,
                  videoMap.length,
                  l10n.prepearing,
                );
                _showProgress(l10n.reinstatingvideos);
                await PlaylistActions.reAddAllVideosFromDate(
                  playlistId,
                  videoMap,
                  date,
                  (current, total, title) {
                    currentProgress.value = ProgressInfo(current, total, title);
                  },
                );
                if (mounted) {
                  Navigator.pop(context);
                  _loadHistory();
                }
              },
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          ],
        ),
        children: videoMap.entries
            .map(
              (v) => ListTile(
                dense: true,
                title: Text(
                  v.key,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add, color: Colors.green, size: 20),
                  onPressed: () async {
                    bool success = await PlaylistActions.reAddVideoToPlaylist(
                      playlistId,
                      v.value,
                      date,
                      updateHistoryInFile: true,
                    );
                    if (success) _loadHistory();
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _confirmDeletePlaylist(String playlistId) async {
    final l10n = AppLocalizations.of(context)!; // Pobranie tłumaczeń
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          l10n.confirmDeleteTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.confirmDeleteContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.deleteAll,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PlaylistActions.removeEntirePlaylistFromHistory(playlistId);
      _loadHistory();
    }
  }
}
