import 'dart:async';
import 'package:hive/hive.dart';
import '../services/hive_service.dart';

/// Robust, fault-tolerant save service for a single "active game" slot.
/// - Adds lightweight throttling to reduce write churn.
/// - Writes a backup before overwriting the current save.
/// - Guards against corrupted data by validating on load and falling back to backup.
/// - Exposes a stream so UI can react to save changes (optional).
class GameSaveService {
  static const String _currentKey = 'current'; // main save
  static const String _backupKey  = 'current_backup'; // last good save
  static const int _schemaVersion = 1; // bump if snapshot shape changes on your side

  // Save throttle (avoid hammering disk)
  static const Duration _throttle = Duration(milliseconds: 250);

  // Access to the Hive box created in HiveService.init()
  Box<Map> get _box => HiveService.savedGamesBox;

  DateTime _lastSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _saving = false;
  final List<Map<String, dynamic>> _saveQueue = [];

  /// Basic sanity checks to avoid writing obviously broken data.
  /// Adjust keys according to your snapshot shape if you want stricter checks.
  bool _isValidSnapshot(Map<String, dynamic> s) {
    // Minimal, non-breaking checks:
    if (s.isEmpty) return false;
    // Example recommended keys (keep them soft to not crash):
    // 'players', 'hands', 'scores', 'currentTurnIndex'
    // Do not enforce strictly unless your encoder guarantees them.
    return true;
  }

  /// Internal write with backup & metadata, no throttling.
  Future<void> _writeNow(Map<String, dynamic> snapshot) async {
    // create a shallow copy so we don't mutate caller's map
    final toWrite = <String, dynamic>{
      ...snapshot,
      '_meta': {
        'schemaVersion': _schemaVersion,
        'savedAt': DateTime.now().toIso8601String(),
      },
    };

    // 1) keep previous current as backup
    final prev = _box.get(_currentKey);
    if (prev != null) {
      await _box.put(_backupKey, prev);
    }

    // 2) write new current
    await _box.put(_currentKey, toWrite);
  }

  /// Public save API with throttling and a tiny "queue" to serialize writes.
  Future<void> save(Map<String, dynamic> snapshot, {bool force = false}) async {
    if (!_isValidSnapshot(snapshot)) {
      // Don't write junk. Simply ignore.
      return;
    }

    final now = DateTime.now();
    final allowNow = force || now.difference(_lastSaveAt) >= _throttle;

    if (allowNow && !_saving) {
      _saving = true;
      try {
        await _writeNow(snapshot);
        _lastSaveAt = now;
      } finally {
        _saving = false;
        // flush queued saves (keep only the newest to avoid replaying old states)
        if (_saveQueue.isNotEmpty) {
          final last = _saveQueue.removeLast();
          _saveQueue.clear();
          await save(last, force: true);
        }
      }
    } else {
      // queue latest snapshot (coalescing)
      _saveQueue
        ..clear()
        ..add(snapshot);
    }
  }

  /// Loads the last good snapshot.
  /// If the primary is corrupt, try backup, otherwise clear and return null.
  Future<Map<String, dynamic>?> load() async {
    Map? raw = _box.get(_currentKey);
    if (raw != null) {
      try {
        final map = Map<String, dynamic>.from(raw);
        return map;
      } catch (_) {
        // fall through to backup
      }
    }

    Map? bak = _box.get(_backupKey);
    if (bak != null) {
      try {
        final map = Map<String, dynamic>.from(bak);
        // restore backup as current for convenience
        await _box.put(_currentKey, bak);
        return map;
      } catch (_) {
        // ignore
      }
    }

    // unrecoverable -> clear
    await clear();
    return null;
  }

  Future<bool> hasSaved() async => _box.containsKey(_currentKey);

  /// Remove both current and backup saves.
  Future<void> clear() async {
    if (_box.containsKey(_currentKey)) {
      await _box.delete(_currentKey);
    }
    if (_box.containsKey(_backupKey)) {
      await _box.delete(_backupKey);
    }
  }

  /// Optional: watch changes to the current key.
  Stream<Map<String, dynamic>?> watch() async* {
    // yield initial value
    yield await load();

    // Listen to box updates
    await for (final _ in _box.watch(key: _currentKey)) {
      yield await load();
    }
  }
}
