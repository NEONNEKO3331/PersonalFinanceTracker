import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paddle_ocr_flutter/paddle_ocr_flutter.dart';

import 'category_service.dart';

/// Result shape expected by Scan / Add screens.
abstract class OcrService {
  Future<Map<String, dynamic>> scanReceipt(String imagePath);
}

/// On-device PaddleOCR (PP-OCRv5 + ONNX). Android arm64 only.
class PaddleOcrService implements OcrService {
  final PaddleOcrFlutter _ocr = PaddleOcrFlutter();
  final CategoryService _categoryService;
  bool _ready = false;

  PaddleOcrService(this._categoryService);

  Future<void> _ensureInit() async {
    if (_ready) return;
    await _ocr.init();
    _ready = true;
  }

  @override
  Future<Map<String, dynamic>> scanReceipt(String imagePath) async {
    await _ensureInit();
    final results = await _ocr.recognize(imagePath);

    final lines = <String>[];
    for (final r in results) {
      lines.add(r.text);
    }

    return _parseReceipt(lines, imagePath);
  }

  Map<String, dynamic> _parseReceipt(List<String> lines, String imagePath) {
    final fullText = lines.join('\n');

    // Merchant: prefer shop-like lines; skip reg/sst/address noise.
    var merchant = 'Unknown Merchant';
    final skipMerchant = RegExp(
      r'total|subtotal|change|cash|card|gst|sst|tax|invoice|receipt|jumlah|'
      r'reg\s*no|sst\s*no|order|table|qty|item|price|date|pax|balance|'
      r'jalan|taman|malaysia|johor|selangor|kl|penang|melaka',
      caseSensitive: false,
    );
    final shopHint = RegExp(
      r'restoran|restaurant|kedai|cafe|kopi|mamak|warung|food|kitchen|'
      r'bistro|diner|stall|gerai',
      caseSensitive: false,
    );
    // Pass 1: line that looks like a restaurant/shop name
    for (final line in lines.take(15)) {
      final t = line.trim();
      if (t.length < 3 || t.length > 48) continue;
      if (RegExp(r'^[\d\s.,RM$¥€MYR/-]+$').hasMatch(t)) continue;
      if (skipMerchant.hasMatch(t) && !shopHint.hasMatch(t)) continue;
      if (shopHint.hasMatch(t)) {
        merchant = _cleanMerchant(t);
        break;
      }
    }
    // Pass 2: first reasonable header line
    if (merchant == 'Unknown Merchant') {
      for (final line in lines.take(12)) {
        final t = line.trim();
        if (t.length < 3 || t.length > 48) continue;
        if (RegExp(r'^[\d\s.,RM$¥€MYR/-]+$').hasMatch(t)) continue;
        if (skipMerchant.hasMatch(t)) continue;
        merchant = _cleanMerchant(t);
        break;
      }
    }

    // Amount — never take Subtotal; prefer Total / Balance (usually bottom).
    double? amount;
    final moneyRe = RegExp(
      r'(?:RM|MYR|\$)?\s*(\d{1,6}(?:[.,]\d{2})?)',
      caseSensitive: false,
    );

    // Priority: Balance / Total (MYR) > plain Total > other
    final strongTotal = RegExp(
      r'grand\s*total|amount\s*due|net\s*total|jumlah\s*bayar|'
      r'total\s*\(\s*myr\s*\)|total\s*\(\s*rm\s*\)|\bbalance\b',
      caseSensitive: false,
    );
    final plainTotal = RegExp(
      r'\btotal\b|bayaran|\bjumlah\b',
      caseSensitive: false,
    );
    final subtotalSkip = RegExp(
      r'sub[\s-]*total|subtotal|sst\s*\(?\s*\d|tax|rounding|service\s*charge',
      caseSensitive: false,
    );

    // (priority, lineIndex, value)
    final candidates = <(int, int, double)>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Never use Subtotal / SST / rounding lines as the amount source
      if (subtotalSkip.hasMatch(line)) continue;

      final int priority;
      if (strongTotal.hasMatch(line)) {
        priority = 3;
      } else if (plainTotal.hasMatch(line)) {
        priority = 2;
      } else {
        continue;
      }

      for (var j = i; j <= i + 2 && j < lines.length; j++) {
        if (subtotalSkip.hasMatch(lines[j]) && j != i) continue;
        final matches = moneyRe.allMatches(lines[j]).toList();
        if (matches.isEmpty) continue;
        final v = _toDouble(matches.last.group(1)!);
        // Ignore tiny noise (e.g. 0.01 rounding alone when not on Total line)
        if (v != null && v >= 0.5 && v < 100000) {
          candidates.add((priority, i, v));
          break;
        }
      }
    }

    if (candidates.isNotEmpty) {
      // Higher priority first; then later line; then larger amount
      candidates.sort((a, b) {
        final byPri = b.$1.compareTo(a.$1);
        if (byPri != 0) return byPri;
        final byLine = b.$2.compareTo(a.$2);
        if (byLine != 0) return byLine;
        return b.$3.compareTo(a.$3);
      });
      amount = candidates.first.$3;
    }

    // Fallback: largest amount in bottom third of receipt (totals live there)
    if (amount == null) {
      var maxVal = 0.0;
      final start = (lines.length * 2 / 3).floor();
      for (var i = start; i < lines.length; i++) {
        final line = lines[i];
        if (subtotalSkip.hasMatch(line)) continue;
        for (final m in moneyRe.allMatches(line)) {
          final v = _toDouble(m.group(1)!);
          if (v != null && v > maxVal && v < 100000) maxVal = v;
        }
      }
      if (maxVal > 0) amount = maxVal;
    }

    // Date
    String? dateStr;
    final dateRe = RegExp(r'(\d{1,4}[-/\.]\d{1,2}[-/\.]\d{1,4})');
    for (final line in lines) {
      final m = dateRe.firstMatch(line);
      if (m != null) {
        dateStr = _normalizeDate(m.group(1)!);
        if (dateStr != null) break;
      }
    }
    dateStr ??= DateTime.now().toIso8601String().substring(0, 10);

    final category = _categoryService.classify('$merchant $fullText');

    final skipItemLine = RegExp(
      r'total|subtotal|change|cash|card|gst|tax|invoice|receipt|jumlah|bayaran|amount\s*due',
      caseSensitive: false,
    );
    final items = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.length < 2 || t.length > 40) continue;
      if (skipItemLine.hasMatch(t)) continue;
      if (t == merchant) continue;
      items.add(t);
      if (items.length >= 8) break;
    }

    return {
      'merchant': merchant,
      'amount': amount ?? 0.0,
      'date': dateStr,
      'category': category,
      'confidence': amount != null ? 0.82 : 0.55,
      'items': items,
      'rawImagePath': imagePath,
      'rawText': fullText,
    };
  }

  double? _toDouble(String s) {
    return double.tryParse(s.replaceAll(',', ''));
  }

  /// Fix common OCR glitches on shop names (e.g. ISESTORAN → RESTORAN,
  /// RESTORANOMJ → RESTORAN OM J).
  String _cleanMerchant(String raw) {
    var t = raw.trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');

    // Common OCR: leading I/L/1 stuck on RESTORAN
    t = t.replaceFirst(
      RegExp(r'^[Il1|]\s*SESTORAN\b', caseSensitive: false),
      'RESTORAN',
    );
    t = t.replaceFirst(
      RegExp(r'^[Il1|]?SESTORAN\b', caseSensitive: false),
      'RESTORAN',
    );

    // Split glued shop prefix: RESTORANOMJ / KEDAIABC / CAFEXYZ
    t = t.replaceFirstMapped(
      RegExp(
        r'^(RESTORAN|RESTAURANT|KEDAI|CAFE|KOPI|MAMAK|WARUNG|GERAI)([A-Z0-9])',
        caseSensitive: false,
      ),
      (m) => '${m[1]} ${m[2]}',
    );

    // Soft-split short trailing stuck tokens: OMJ → OM J
    t = t.replaceAllMapped(
      RegExp(r'\b([A-Z]{2,3})([A-Z])\b'),
      (m) => '${m[1]} ${m[2]}',
    );

    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t.trim();
  }

  String? _normalizeDate(String raw) {
    final p = raw.split(RegExp(r'[-/\.]'));
    if (p.length != 3) return null;
    int? y, m, d;
    if (p[0].length == 4) {
      y = int.tryParse(p[0]);
      m = int.tryParse(p[1]);
      d = int.tryParse(p[2]);
    } else if (p[2].length == 4) {
      d = int.tryParse(p[0]);
      m = int.tryParse(p[1]);
      y = int.tryParse(p[2]);
    } else {
      d = int.tryParse(p[0]);
      m = int.tryParse(p[1]);
      y = int.tryParse(p[2]);
      if (y != null && y < 100) y += 2000;
    }
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return '${y.toString().padLeft(4, '0')}-'
        '${m.toString().padLeft(2, '0')}-'
        '${d.toString().padLeft(2, '0')}';
  }
}

/// Offline mock for UI development / non-Android builds.
class MockOcrService implements OcrService {
  @override
  Future<Map<String, dynamic>> scanReceipt(String imagePath) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return {
      'merchant': 'Kedai Makan',
      'amount': 25.50,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'category': 'food_dining',
      'confidence': 0.85,
      'items': ['Nasi Lemak', 'Teh O'],
      'rawImagePath': imagePath,
    };
  }
}

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService();
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  // Use MockOcrService() if paddle_ocr_flutter is not available on device.
  return PaddleOcrService(ref.watch(categoryServiceProvider));
});