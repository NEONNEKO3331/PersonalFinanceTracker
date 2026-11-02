import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../entities/transaction.dart';

/// Full-data backup / restore (JSON). Survives uninstall when user saves the file.
class BackupService {
  static const formatVersion = 1;
  static const appName = 'MoneyBee';

  /// Write all transactions to a timestamped JSON file and return its path.
  Future<String> createBackupFile(List<Transaction> transactions) async {
    final now = DateTime.now();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final payload = <String, dynamic>{
      'formatVersion': formatVersion,
      'app': appName,
      'exportedAt': now.toIso8601String(),
      'count': transactions.length,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'moneybee_backup_$stamp.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file.path;
  }

  /// Share the backup file via system share sheet.
  Future<void> shareBackup(String path) async {
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/json')],
      subject: 'MoneyBee backup',
      text: 'MoneyBee full data backup — keep this file safe to restore later.',
    );
  }

  /// Parse a backup JSON string. Throws [FormatException] on invalid data.
  List<Transaction> parseBackup(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup is not a JSON object');
    }
    final list = decoded['transactions'];
    if (list is! List) {
      throw const FormatException('Missing "transactions" array');
    }
    return list
        .whereType<Map>()
        .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Read and parse a backup file from disk.
  Future<List<Transaction>> loadBackupFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('Backup file not found');
    }
    return parseBackup(await file.readAsString());
  }
}