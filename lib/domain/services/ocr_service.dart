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

    // ── Merchant ──────────────────────────────────────────────────────────
    // Prefer shop-like lines; skip reg/sst/address noise.
    var merchant = 'Unknown Merchant';
    final skipMerchant = RegExp(
      r'total|subtotal|change|cash|card|gst|sst|tax|invoice|receipt|jumlah|'
      r'reg\s*no|sst\s*no|order|table|qty|item|price|date|pax|balance|'
      r'jalan|taman|malaysia|johor|selangor|kl|penang|melaka|'
      r'host|tid|mid|batch|trace|inv\s*no|approval|entry\s*type|ref\s*no|'
      r'sale|mydebit|pin\s*verified|customer\s*copy|no\s*signature',
      caseSensitive: false,
    );
    final shopHint = RegExp(
      r'restoran|restaurant|kedai|cafe|kopi|mamak|warung|food|kitchen|'
      r'bistro|diner|stall|gerai|bank|ban\s*k|public|maybank|'
      r'supermarket|mart|pharmacy',
      caseSensitive: false,
    );

    // Pass 1: line that looks like a restaurant/shop/bank name
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

    // ── Amount ────────────────────────────────────────────────────────────
    // Strategy:
    // 1. Find lines containing TOTAL / JUMLAH / BALANCE
    // 2. Extract money tokens from those lines (+ nearby lines)
    // 3. Prefer values that look like real currency (have .xx OR contain comma)
    // 4. Fallback: largest plausible number in bottom half of receipt
    //
    // Supports: RM 4,962.00 | 4,962.00 | 4962.00 | R M 99.50
    double? amount;

    // Money token — allows OCR letter confusions inside digits
    final moneyRe = RegExp(
      r'(?:R\s*[MN]|MYR|\$)\s*' // prefer tokens that have RM/MYR/$ prefix
      r'([0-9OIlSBZG]{1,3}(?:,[0-9OIlSBZG]{3})+(?:\.[0-9OIlSBZG]{2})?'
      r'|[0-9OIlSBZG]+(?:\.[0-9OIlSBZG]{2}))'
      r'|'
      r'(?:R\s*[MN]|MYR|\$)?\s*'
      r'([0-9OIlSBZG]{1,3}(?:,[0-9OIlSBZG]{3})+(?:\.[0-9OIlSBZG]{2})?'
      r'|[0-9OIlSBZG]+(?:\.[0-9OIlSBZG]{2}))',
      caseSensitive: false,
    );

    final totalHint = RegExp(
      r'\btotal\b|grand\s*total|amount\s*due|net\s*total|'
      r'jumlah\s*bayar|bayaran|\bjumlah\b|\bbalance\b',
      caseSensitive: false,
    );
    // Lines that must NEVER be used as amount source
    final noiseLine = RegExp(
      r'sub[\s-]*total|subtotal|sst\s*\(?\s*\d|tax|rounding|service\s*charge|'
      r'approval|trace\s*no|batch\s*no|ref\s*no|tid\s|mid\s|inv\s*no|'
      r'host\s|entry\s*type|chip\s*entry|pin\s*verified|date\s*/\s*time',
      caseSensitive: false,
    );

    // Collect (score, value) — higher score wins
    final scored = <(int, double)>[];

    void collectFrom(String text, int baseScore) {
      for (final m in moneyRe.allMatches(text)) {
        // group 1 = with explicit RM prefix; group 2 = optional prefix
        final raw = m.group(1) ?? m.group(2);
        if (raw == null) continue;
        final v = _toDouble(raw);
        if (v == null || v < 0.5 || v >= 100000) continue;

        var score = baseScore;
        // Bonus: has decimal places (real money) or thousand separator
        if (raw.contains('.')) score += 5;
        if (raw.contains(',')) score += 8; // 4,962 strongly preferred
        // Bonus: original match had RM/MYR/$ nearby
        final matched = m.group(0)!.toUpperCase();
        if (matched.contains('RM') ||
            matched.contains('MYR') ||
            matched.contains('R M') ||
            matched.contains('\$')) {
          score += 10;
        }
        // Penalise very small numbers without decimals (often OCR noise)
        if (v < 10 && !raw.contains('.')) score -= 5;
        scored.add((score, v));
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (noiseLine.hasMatch(line)) continue;

      if (totalHint.hasMatch(line)) {
        // TOTAL line itself
        collectFrom(line, 30);
        // Amount often sits on the same visual row → next line
        if (i + 1 < lines.length && !noiseLine.hasMatch(lines[i + 1])) {
          collectFrom(lines[i + 1], 25);
        }
        if (i + 2 < lines.length && !noiseLine.hasMatch(lines[i + 2])) {
          collectFrom(lines[i + 2], 15);
        }
      }
    }

    // Also scan whole text for "RM x,xxx.xx" pattern (high confidence)
    collectFrom(fullText, 20);

    if (scored.isNotEmpty) {
      scored.sort((a, b) {
        final byScore = b.$1.compareTo(a.$1);
        if (byScore != 0) return byScore;
        // tie-break: larger amount (totals are usually the biggest number)
        return b.$2.compareTo(a.$2);
      });
      amount = scored.first.$2;
    }

    // Last resort: largest money-like value in bottom half
    if (amount == null) {
      var maxVal = 0.0;
      final start = (lines.length / 2).floor();
      for (var i = start; i < lines.length; i++) {
        if (noiseLine.hasMatch(lines[i])) continue;
        for (final m in moneyRe.allMatches(lines[i])) {
          final raw = m.group(1) ?? m.group(2);
          if (raw == null) continue;
          final v = _toDouble(raw);
          if (v != null && v > maxVal && v < 100000) maxVal = v;
        }
      }
      if (maxVal > 0) amount = maxVal;
    }

    // ── Date ──────────────────────────────────────────────────────────────
    String? dateStr;
    final dateRe = RegExp(r'(\d{1,4}[-/\.]\d{1,2}[-/\.]\d{1,4})');
    // Also catch "05OCT2026" style (common on bank slips)
    final dateAlphaRe = RegExp(
      r'(\d{1,2})(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)(\d{2,4})',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = dateRe.firstMatch(line);
      if (m != null) {
        dateStr = _normalizeDate(m.group(1)!);
        if (dateStr != null) break;
      }
      final ma = dateAlphaRe.firstMatch(line);
      if (ma != null) {
        dateStr = _normalizeAlphaDate(ma.group(1)!, ma.group(2)!, ma.group(3)!);
        if (dateStr != null) break;
      }
    }
    dateStr ??= DateTime.now().toIso8601String().substring(0, 10);

    final category = _categoryService.classify('$merchant $fullText');

    final skipItemLine = RegExp(
      r'total|subtotal|change|cash|card|gst|tax|invoice|receipt|jumlah|bayaran|'
      r'amount\s*due|approval|trace|batch|host|tid|mid|pin\s*verified',
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

  /// Convert OCR-extracted money string → double.
  /// Handles:
  ///   - thousand commas: "4,962.00" → 4962.00
  ///   - common OCR letter confusions: O→0, l/I→1, S→5, B→8, G→6, Z→2
  double? _toDouble(String s) {
    var t = s.trim();

    // OCR digit / letter confusions (very common on thermal paper)
    t = t
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('l', '1')
        .replaceAll('I', '1')
        .replaceAll('|', '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8')
        .replaceAll('G', '6')
        .replaceAll('Z', '2');

    // Keep only digits, dots, commas
    t = t.replaceAll(RegExp(r'[^\d.,]'), '');

    // Remove thousand separators (commas)
    t = t.replaceAll(',', '');

    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Fix common OCR glitches on shop / bank names.
  /// Examples:
  ///   "PUBLIC BAN K" → "PUBLIC BANK"
  ///   "ISESTORAN"    → "RESTORAN"
  ///   "RESTORANOMJ"  → "RESTORAN OM J"
  String _cleanMerchant(String raw) {
    var t = raw.trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');

    // Collapse OCR-split bank / common words
    // "BAN K" / "BAN  K" / "BA N K" → "BANK"
    t = t.replaceAll(
      RegExp(r'\bBA\s*N\s*K\b', caseSensitive: false),
      'BANK',
    );
    t = t.replaceAll(
      RegExp(r'\bPUBLI\s*C\b', caseSensitive: false),
      'PUBLIC',
    );
    // "MAY BANK" style already fine; fix "MAYBAN K"
    t = t.replaceAll(
      RegExp(r'\bMAY\s*BAN\s*K\b', caseSensitive: false),
      'MAYBANK',
    );

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
        r'^(RESTORAN|RESTAURANT|KEDAI|CAFE|KOPI|MAMAK|WARUNG|GERAI|BANK)([A-Z0-9])',
        caseSensitive: false,
      ),
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

  /// Parse bank-slip style dates like "05OCT2026"
  String? _normalizeAlphaDate(String day, String mon, String year) {
    const months = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
    };
    final m = months[mon.toUpperCase()];
    final d = int.tryParse(day);
    var y = int.tryParse(year);
    if (m == null || d == null || y == null) return null;
    if (y < 100) y += 2000;
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