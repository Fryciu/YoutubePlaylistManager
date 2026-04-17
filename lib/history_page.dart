import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'main.dart' show ProgressInfo;

// ─────────────────────────────────────────────────────────────────────────────
// Wyjątek quota
// ─────────────────────────────────────────────────────────────────────────────

class QuotaExceededException implements Exception {
  /// Filmy które NIE zdążyły być przetworzone — do ponowienia.
  final List<dynamic> remaining;
  QuotaExceededException(this.remaining);
}

// ─────────────────────────────────────────────────────────────────────────────
// Status zadania
// ─────────────────────────────────────────────────────────────────────────────

enum TaskStatus { pending, running, done, error, quotaExceeded, scheduled }

// ─────────────────────────────────────────────────────────────────────────────
// Model pojedynczego zadania
// ─────────────────────────────────────────────────────────────────────────────

class TaskEntry {
  final String id;
  final String label;
  final String icon;

  final ValueNotifier<ProgressInfo> progress;
  final ValueNotifier<TaskStatus> status;

  /// Komunikat błędu (np. "Quota przekroczona po 42/200 filmach")
  String? errorMessage;

  /// Filmy pozostałe do przetworzenia po błędzie quota
  List<dynamic>? remainingItems;

  /// Zaplanowana godzina wznowienia (jeśli użytkownik wybrał retry jutro)
  DateTime? scheduledAt;

  /// Wewnętrzny timer dla zaplanowanego wznowienia
  Timer? _scheduleTimer;

  /// Funkcja do wznowienia zadania — ustawiana przez TaskQueue
  Future<void> Function(TaskEntry entry)? _resumeWork;

  TaskEntry({required this.id, required this.label, required this.icon})
    : progress = ValueNotifier(ProgressInfo(0, 0, '')),
      status = ValueNotifier(TaskStatus.pending);

  void dispose() {
    _scheduleTimer?.cancel();
    progress.dispose();
    status.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Singleton kolejki
// ─────────────────────────────────────────────────────────────────────────────

class TaskQueue {
  TaskQueue._();
  static final TaskQueue instance = TaskQueue._();

  final ValueNotifier<List<TaskEntry>> tasks = ValueNotifier([]);
  int _counter = 0;

  /// Dodaje zadanie i uruchamia je natychmiast.
  /// [work] powinien rzucić [QuotaExceededException] gdy API zwróci 403/quota,
  /// przekazując w nim listę pozostałych elementów.
  void add({
    required String label,
    required String icon,
    required Future<void> Function(TaskEntry entry) work,
  }) {
    final entry = TaskEntry(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
      label: label,
      icon: icon,
    );
    entry._resumeWork = work;

    tasks.value = [...tasks.value, entry];
    _run(entry, work);
  }

  void _run(TaskEntry entry, Future<void> Function(TaskEntry entry) work) {
    entry.status.value = TaskStatus.running;
    work(entry)
        .then((_) {
          entry.status.value = TaskStatus.done;
        })
        .catchError((e) {
          if (e is QuotaExceededException) {
            entry.remainingItems = e.remaining;
            final done = entry.progress.value.current;
            final total = entry.progress.value.total;
            entry.errorMessage =
                'Quota przekroczona po $done/$total filmach.\n'
                'Pozostało ${e.remaining.length} do przetworzenia.';
            entry.status.value = TaskStatus.quotaExceeded;
          } else {
            entry.errorMessage = e.toString();
            entry.status.value = TaskStatus.error;
          }
          debugPrint('[TaskQueue] Błąd "${entry.label}": $e');
        });
  }

  /// Planuje wznowienie zadania o [scheduledAt].
  void scheduleRetry(
    TaskEntry entry,
    DateTime scheduledAt,
    Future<void> Function(TaskEntry entry) resumeWork,
  ) {
    entry._scheduleTimer?.cancel();

    final delay = scheduledAt.difference(DateTime.now());
    entry.scheduledAt = scheduledAt;
    entry.status.value = TaskStatus.scheduled;
    entry.errorMessage = null;
    tasks.value = [...tasks.value];

    entry._scheduleTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      entry.scheduledAt = null;
      entry._resumeWork = resumeWork;
      _run(entry, resumeWork);
    });
  }

  void dismiss(String id) {
    final List<TaskEntry> current = tasks.value;
    TaskEntry? found;
    for (final t in current) {
      if (t.id == id) {
        found = t;
        break;
      }
    }
    found?._scheduleTimer?.cancel();
    found?.dispose();
    tasks.value = current.where((t) => t.id != id).toList();
  }

  void dismissCompleted() {
    final toRemove = tasks.value
        .where(
          (t) =>
              t.status.value == TaskStatus.done ||
              t.status.value == TaskStatus.error,
        )
        .toList();
    for (final t in toRemove) {
      t.dispose();
    }
    tasks.value = tasks.value
        .where(
          (t) =>
              t.status.value != TaskStatus.done &&
              t.status.value != TaskStatus.error,
        )
        .toList();
  }

  int get activeCount => tasks.value
      .where(
        (t) =>
            t.status.value == TaskStatus.running ||
            t.status.value == TaskStatus.pending ||
            t.status.value == TaskStatus.scheduled,
      )
      .length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Przycisk w AppBarze z badge
// ─────────────────────────────────────────────────────────────────────────────

class TaskQueueButton extends StatelessWidget {
  const TaskQueueButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TaskEntry>>(
      valueListenable: TaskQueue.instance.tasks,
      builder: (context, tasks, _) {
        final activeCount = TaskQueue.instance.activeCount;
        final hasQuota = tasks.any(
          (t) => t.status.value == TaskStatus.quotaExceeded,
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.queue_play_next, color: Colors.white),
              tooltip: 'Kolejka zadań',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
            if (activeCount > 0 || hasQuota)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: hasQuota ? Colors.red : Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    hasQuota ? '!' : '$activeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Boczny drawer z listą zadań
// ─────────────────────────────────────────────────────────────────────────────

class TaskQueueDrawer extends StatelessWidget {
  const TaskQueueDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: ValueListenableBuilder<List<TaskEntry>>(
          valueListenable: TaskQueue.instance.tasks,
          builder: (context, tasks, _) {
            final hasDismissible = tasks.any(
              (t) =>
                  t.status.value == TaskStatus.done ||
                  t.status.value == TaskStatus.error,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kolejka zadań',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasDismissible)
                        TextButton.icon(
                          onPressed: TaskQueue.instance.dismissCompleted,
                          icon: const Icon(
                            Icons.done_all,
                            size: 16,
                            color: Colors.white54,
                          ),
                          label: const Text(
                            'Wyczyść',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                if (tasks.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.white24,
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Brak aktywnych zadań',
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: tasks.length,
                      itemBuilder: (context, i) => _TaskTile(
                        entry: tasks[i],
                        key: ValueKey(tasks[i].id),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kafelek pojedynczego zadania
// ─────────────────────────────────────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  final TaskEntry entry;
  const _TaskTile({required this.entry, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TaskStatus>(
      valueListenable: entry.status,
      builder: (context, status, _) {
        return ValueListenableBuilder<ProgressInfo>(
          valueListenable: entry.progress,
          builder: (context, info, _) {
            final double frac = info.total > 0 ? info.current / info.total : 0;

            Color accentColor;
            Widget leadingIcon;

            switch (status) {
              case TaskStatus.pending:
                accentColor = Colors.white38;
                leadingIcon = const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white38,
                  ),
                );
                break;
              case TaskStatus.running:
                accentColor = Colors.orange;
                leadingIcon = const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.orange,
                  ),
                );
                break;
              case TaskStatus.done:
                accentColor = Colors.green;
                leadingIcon = const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                );
                break;
              case TaskStatus.error:
                accentColor = Colors.redAccent;
                leadingIcon = const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 20,
                );
                break;
              case TaskStatus.quotaExceeded:
                accentColor = Colors.deepOrange;
                leadingIcon = const Icon(
                  Icons.block,
                  color: Colors.deepOrange,
                  size: 20,
                );
                break;
              case TaskStatus.scheduled:
                accentColor = Colors.blueAccent;
                leadingIcon = const Icon(
                  Icons.schedule,
                  color: Colors.blueAccent,
                  size: 20,
                );
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF242424),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nagłówek
                  Row(
                    children: [
                      Text(entry.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      leadingIcon,
                    ],
                  ),

                  // Pasek postępu
                  if (info.total > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 5,
                        backgroundColor: Colors.white10,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${info.current} / ${info.total}',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (info.etaSeconds != null &&
                            status == TaskStatus.running)
                          Text(
                            _fmtEta(info.etaSeconds!),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    if (info.status.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          info.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],

                  // ── Quota exceeded ────────────────────────────────────────
                  if (status == TaskStatus.quotaExceeded) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.deepOrange.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.deepOrange,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Quota YouTube przekroczona',
                                style: TextStyle(
                                  color: Colors.deepOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (entry.errorMessage != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              entry.errorMessage!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          const Text(
                            'Quota odnawia się codziennie o ~9:00 (zimą) '
                            'lub ~10:00 (latem) czasu polskiego.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.blueAccent,
                                width: 1,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(
                              Icons.schedule,
                              color: Colors.blueAccent,
                              size: 16,
                            ),
                            label: const Text(
                              'Zaplanuj na jutro',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: () =>
                                _showScheduleDialog(context, entry),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white24,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => TaskQueue.instance.dismiss(entry.id),
                          child: const Text(
                            'Odrzuć',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Scheduled ─────────────────────────────────────────────
                  if (status == TaskStatus.scheduled &&
                      entry.scheduledAt != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            color: Colors.blueAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Wznowienie o ${_fmtTime(entry.scheduledAt!)}',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => TaskQueue.instance.dismiss(entry.id),
                        child: const Text(
                          'Anuluj',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                    ),
                  ],

                  // ── Done / Error ───────────────────────────────────────────
                  if (status == TaskStatus.done ||
                      status == TaskStatus.error) ...[
                    if (status == TaskStatus.error &&
                        entry.errorMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => TaskQueue.instance.dismiss(entry.id),
                        child: Text(
                          status == TaskStatus.done ? 'Odrzuć' : 'Zamknij',
                          style: TextStyle(color: accentColor, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _fmtEta(int secs) {
    if (secs <= 0) return 'kończy...';
    if (secs < 60) return '~${secs}s';
    return '~${secs ~/ 60}m ${secs % 60}s';
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showScheduleDialog(BuildContext context, TaskEntry entry) async {
    final now = DateTime.now();
    // DST w Polsce: CEST = UTC+2, CET = UTC+1
    final isDst = now.timeZoneOffset.inHours >= 2;
    final defaultHour = isDst ? 10 : 9;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: defaultHour, minute: 5),
      helpText: 'Godzina wznowienia (jutro)',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.blueAccent,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;

    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day + 1,
      picked.hour,
      picked.minute,
    );

    final remaining = List<dynamic>.from(entry.remainingItems ?? []);
    final resumeWork = entry._resumeWork;
    if (resumeWork == null || remaining.isEmpty) return;

    TaskQueue.instance.scheduleRetry(entry, tomorrow, (e) async {
      e.remainingItems = remaining;
      await resumeWork(e);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Strona historii usuniętych filmów
// ─────────────────────────────────────────────────────────────────────────────

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // { playlistId: { "Dates": { "2024-01-01 12:00:00": ["id1", ...] } } }
  Map<String, dynamic> _history = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}history.json');
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _history = decoded;
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  // Łączna liczba usuniętych filmów w całej historii
  int get _totalVideos => _history.values.fold(0, (sum, playlist) {
    final dates = (playlist['Dates'] as Map?)?.values ?? [];
    return sum +
        dates.fold<int>(0, (s, videos) => s + ((videos as List?)?.length ?? 0));
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Historia usunięć',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_totalVideos > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '$_totalVideos filmów',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _history.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, color: Colors.white24, size: 56),
                  SizedBox(height: 12),
                  Text(
                    'Brak historii usunięć',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              itemCount: _history.length,
              itemBuilder: (context, i) {
                final playlistId = _history.keys.elementAt(i);
                final data = _history[playlistId] as Map<String, dynamic>;
                return _PlaylistHistoryTile(playlistId: playlistId, data: data);
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kafelek playlisty z rozwijaną historią dat
// ─────────────────────────────────────────────────────────────────────────────

class _PlaylistHistoryTile extends StatefulWidget {
  final String playlistId;
  final Map<String, dynamic> data;

  const _PlaylistHistoryTile({
    required this.playlistId,
    required this.data,
    Key? key,
  }) : super(key: key);

  @override
  State<_PlaylistHistoryTile> createState() => _PlaylistHistoryTileState();
}

class _PlaylistHistoryTileState extends State<_PlaylistHistoryTile> {
  bool _expanded = false;

  Map<String, dynamic> get _dates =>
      (widget.data['Dates'] as Map<String, dynamic>?) ?? {};

  int get _total =>
      _dates.values.fold(0, (s, v) => s + ((v as List?)?.length ?? 0));

  @override
  Widget build(BuildContext context) {
    final sortedDates = _dates.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // najnowsze pierwsze

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Nagłówek
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.playlist_play,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['name'] as String? ?? widget.playlistId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$_total usuniętych • ${_dates.length} sesji',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),

          // Rozwinięta lista dat
          if (_expanded)
            Column(
              children: [
                const Divider(color: Colors.white10, height: 1),
                ...sortedDates.map((date) {
                  final videos = (_dates[date] as List?) ?? [];
                  return _DateRow(date: date, videos: videos);
                }),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wiersz pojedynczej sesji usuwania
// ─────────────────────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final String date;
  final List videos;

  const _DateRow({required this.date, required this.videos, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.access_time, color: Colors.white24, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                Text(
                  '${videos.length} filmów',
                  style: const TextStyle(color: Colors.orange, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
