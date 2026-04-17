// task_queue.dart
//
// Ten plik jest zachowany dla kompatybilności importu w main.dart.
// Wszystkie klasy (TaskEntry, TaskQueue, TaskStatus, TaskQueueButton,
// TaskQueueDrawer, QuotaExceededException) są teraz zdefiniowane
// wyłącznie w history_page.dart — re-eksportujemy je tutaj.
//
// Dzięki temu main.dart nie wymaga żadnych zmian.

export 'history_page.dart'
    show
        QuotaExceededException,
        TaskStatus,
        TaskEntry,
        TaskQueue,
        TaskQueueButton,
        TaskQueueDrawer;
