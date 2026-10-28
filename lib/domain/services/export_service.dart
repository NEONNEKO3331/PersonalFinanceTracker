import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../entities/transaction.dart';
import '../../presentation/providers/transaction_provider.dart';

/// Builds an office-style income & expense XLSX workbook.
class ExportService {
  static final _moneyFmt = CustomNumericNumFormat(formatCode: '#,##0.00');
  static final _thin = Border(borderStyle: BorderStyle.Thin);
  static final _medium = Border(borderStyle: BorderStyle.Medium);

  static final _titleStyle = CellStyle(
    bold: true,
    fontSize: 16,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  static final _subtitleStyle = CellStyle(
    fontSize: 11,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _headerStyle = CellStyle(
    bold: true,
    fontSize: 11,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    backgroundColorHex: ExcelColor.fromHexString('#2C2416'),
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    leftBorder: _thin,
    rightBorder: _thin,
    topBorder: _thin,
    bottomBorder: _thin,
  );

  static final _cellStyle = CellStyle(
    fontSize: 10,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thin,
    rightBorder: _thin,
    topBorder: _thin,
    bottomBorder: _thin,
  );

  static final _cellCenter = CellStyle(
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _thin,
    rightBorder: _thin,
    topBorder: _thin,
    bottomBorder: _thin,
  );

  static final _moneyStyle = CellStyle(
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    numberFormat: _moneyFmt,
    leftBorder: _thin,
    rightBorder: _thin,
    topBorder: _thin,
    bottomBorder: _thin,
  );

  static final _totalLabelStyle = CellStyle(
    bold: true,
    fontSize: 11,
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    backgroundColorHex: ExcelColor.fromHexString('#FFF8E7'),
    leftBorder: _medium,
    rightBorder: _thin,
    topBorder: _medium,
    bottomBorder: _medium,
  );

  static final _totalMoneyStyle = CellStyle(
    bold: true,
    fontSize: 11,
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    numberFormat: _moneyFmt,
    backgroundColorHex: ExcelColor.fromHexString('#FFF8E7'),
    leftBorder: _thin,
    rightBorder: _thin,
    topBorder: _medium,
    bottomBorder: _medium,
  );

  static final _sectionStyle = CellStyle(
    bold: true,
    fontSize: 12,
    horizontalAlign: HorizontalAlign.Left,
  );

  static final _labelStyle = CellStyle(
    bold: true,
    fontSize: 10,
    horizontalAlign: HorizontalAlign.Left,
  );

  /// Returns absolute path of the written .xlsx file.
  ///
  /// Prefer passing [periodLabel] / [periodDetail] / [fileStamp] directly.
  /// The [period] + optional [customRange] overload is kept for convenience.
  Future<String> exportToXlsx({
    required List<Transaction> transactions,
    HomePeriod? period,
    DateRange? customRange,
    String? periodLabel,
    String? periodDetail,
    String? fileStamp,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final resolvedPeriod = period ?? HomePeriod.month;
    final label = periodLabel ??
        (resolvedPeriod == HomePeriod.week
            ? 'This week'
            : resolvedPeriod == HomePeriod.month
                ? 'This month'
                : 'Custom range');
    final detail = periodDetail ??
        (customRange != null
            ? customRange.label
            : _periodDetail(resolvedPeriod, n));
    final stamp = fileStamp ??
        (resolvedPeriod == HomePeriod.week
            ? '${DateFormat('yyyy-MM-dd').format(n)}_week'
            : resolvedPeriod == HomePeriod.custom && customRange != null
                ? customRange.fileStamp
                : DateFormat('yyyy-MM').format(n));

    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.createdAt.compareTo(b.createdAt);
      });

    var income = 0.0;
    var expense = 0.0;
    final catMap = <String, double>{};
    for (final t in sorted) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
        catMap[t.category] = (catMap[t.category] ?? 0) + t.amount;
      }
    }
    final balance = income - expense;

    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    if (defaultSheet != 'Income & Expense') {
      excel.rename(defaultSheet, 'Income & Expense');
    }

    _buildLedgerSheet(
      excel['Income & Expense'],
      sorted: sorted,
      periodLabel: label,
      periodDetail: detail,
      generatedAt: n,
      income: income,
      expense: expense,
      balance: balance,
    );

    _buildSummarySheet(
      excel['Summary'],
      periodLabel: label,
      periodDetail: detail,
      generatedAt: n,
      income: income,
      expense: expense,
      balance: balance,
      count: sorted.length,
      catMap: catMap,
    );

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('Failed to encode XLSX');
    }

    final dir = await getTemporaryDirectory();
    final filePath = p.join(dir.path, 'MoneyBee_$stamp.xlsx');
    await File(filePath).writeAsBytes(bytes, flush: true);
    return filePath;
  }

  String _periodDetail(HomePeriod period, DateTime n) {
    if (period == HomePeriod.month) {
      return DateFormat('MMMM yyyy').format(n);
    }
    if (period == HomePeriod.custom) {
      return '';
    }
    final weekday = n.weekday;
    final start = DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: weekday - 1));
    final end = start.add(const Duration(days: 6));
    final fmt = DateFormat('dd MMM yyyy');
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }

  void _buildLedgerSheet(
    Sheet sheet, {
    required List<Transaction> sorted,
    required String periodLabel,
    required String periodDetail,
    required DateTime generatedAt,
    required double income,
    required double expense,
    required double balance,
  }) {
    // Column widths (approx characters)
    final widths = <int, double>{
      0: 6, // No.
      1: 12, // Date
      2: 10, // Type
      3: 18, // Category
      4: 24, // Description
      5: 14, // Income
      6: 14, // Expense
      7: 22, // Remarks
    };
    widths.forEach(sheet.setColumnWidth);

    // Title
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 0),
    );
    _set(
      sheet,
      0,
      0,
      TextCellValue('PERSONAL INCOME & EXPENSE STATEMENT'),
      _titleStyle,
    );
    sheet.setRowHeight(0, 28);

    // Meta
    _set(sheet, 0, 1, TextCellValue('Period'), _labelStyle);
    _set(
      sheet,
      1,
      1,
      TextCellValue('$periodLabel ($periodDetail)'),
      _subtitleStyle,
    );
    _set(sheet, 4, 1, TextCellValue('Prepared'), _labelStyle);
    _set(
      sheet,
      5,
      1,
      TextCellValue(DateFormat('dd MMM yyyy, HH:mm').format(generatedAt)),
      _subtitleStyle,
    );
    _set(sheet, 0, 2, TextCellValue('Currency'), _labelStyle);
    _set(sheet, 1, 2, TextCellValue('Malaysian Ringgit (RM)'), _subtitleStyle);
    _set(sheet, 4, 2, TextCellValue('Source'), _labelStyle);
    _set(sheet, 5, 2, TextCellValue('MoneyBee'), _subtitleStyle);

    // Table header row (row index 4)
    const headerRow = 4;
    const headers = [
      'No.',
      'Date',
      'Type',
      'Category',
      'Description',
      'Income (RM)',
      'Expense (RM)',
      'Remarks',
    ];
    for (var c = 0; c < headers.length; c++) {
      _set(sheet, c, headerRow, TextCellValue(headers[c]), _headerStyle);
    }
    sheet.setRowHeight(headerRow, 22);

    // Data rows
    for (var i = 0; i < sorted.length; i++) {
      final t = sorted[i];
      final r = headerRow + 1 + i;
      final isIncome = t.type == TransactionType.income;

      _set(sheet, 0, r, IntCellValue(i + 1), _cellCenter);
      _set(
        sheet,
        1,
        r,
        TextCellValue(DateFormat('dd/MM/yyyy').format(t.date)),
        _cellCenter,
      );
      _set(
        sheet,
        2,
        r,
        TextCellValue(isIncome ? 'Income' : 'Expense'),
        _cellCenter,
      );
      _set(
        sheet,
        3,
        r,
        TextCellValue(Categories.displayName(t.category)),
        _cellStyle,
      );
      _set(sheet, 4, r, TextCellValue(t.merchant), _cellStyle);

      if (isIncome) {
        _set(sheet, 5, r, DoubleCellValue(_round2(t.amount)), _moneyStyle);
        _set(sheet, 6, r, TextCellValue(''), _cellStyle);
      } else {
        _set(sheet, 5, r, TextCellValue(''), _cellStyle);
        _set(sheet, 6, r, DoubleCellValue(_round2(t.amount)), _moneyStyle);
      }
      _set(sheet, 7, r, TextCellValue(t.note ?? ''), _cellStyle);
    }

    // Totals row
    final totalRow = headerRow + 1 + sorted.length;
    for (var c = 0; c < 5; c++) {
      _set(
        sheet,
        c,
        totalRow,
        TextCellValue(c == 4 ? 'TOTAL' : ''),
        _totalLabelStyle,
      );
    }
    _set(sheet, 5, totalRow, DoubleCellValue(_round2(income)), _totalMoneyStyle);
    _set(
      sheet,
      6,
      totalRow,
      DoubleCellValue(_round2(expense)),
      _totalMoneyStyle,
    );
    _set(sheet, 7, totalRow, TextCellValue(''), _totalMoneyStyle);

    // Net balance line
    final balRow = totalRow + 2;
    _set(sheet, 4, balRow, TextCellValue('Net Balance (RM)'), _labelStyle);
    _set(
      sheet,
      5,
      balRow,
      DoubleCellValue(_round2(balance)),
      CellStyle(
        bold: true,
        fontSize: 12,
        horizontalAlign: HorizontalAlign.Right,
        numberFormat: _moneyFmt,
      ),
    );

    final noteRow = balRow + 2;
    _set(
      sheet,
      0,
      noteRow,
      TextCellValue(
        'Note: This statement was generated by MoneyBee for personal record-keeping.',
      ),
      CellStyle(fontSize: 9, italic: true),
    );
  }

  void _buildSummarySheet(
    Sheet sheet, {
    required String periodLabel,
    required String periodDetail,
    required DateTime generatedAt,
    required double income,
    required double expense,
    required double balance,
    required int count,
    required Map<String, double> catMap,
  }) {
    sheet.setColumnWidth(0, 28);
    sheet.setColumnWidth(1, 16);
    sheet.setColumnWidth(2, 12);

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0),
    );
    _set(
      sheet,
      0,
      0,
      TextCellValue('FINANCIAL SUMMARY'),
      _titleStyle,
    );
    sheet.setRowHeight(0, 26);

    _set(sheet, 0, 1, TextCellValue('Period'), _labelStyle);
    _set(sheet, 1, 1, TextCellValue('$periodLabel ($periodDetail)'), _subtitleStyle);
    _set(sheet, 0, 2, TextCellValue('Prepared'), _labelStyle);
    _set(
      sheet,
      1,
      2,
      TextCellValue(DateFormat('dd MMM yyyy, HH:mm').format(generatedAt)),
      _subtitleStyle,
    );
    _set(sheet, 0, 3, TextCellValue('Currency'), _labelStyle);
    _set(sheet, 1, 3, TextCellValue('RM'), _subtitleStyle);

    // Overview box
    _set(sheet, 0, 5, TextCellValue('Overview'), _sectionStyle);

    const ovHeaders = ['Item', 'Amount (RM)', ''];
    for (var c = 0; c < 2; c++) {
      _set(sheet, c, 6, TextCellValue(ovHeaders[c]), _headerStyle);
    }

    final overview = [
      ('Total Income', income),
      ('Total Expense', expense),
      ('Net Balance', balance),
    ];
    for (var i = 0; i < overview.length; i++) {
      final r = 7 + i;
      final style = i == 2
          ? CellStyle(
              bold: true,
              fontSize: 10,
              leftBorder: _thin,
              rightBorder: _thin,
              topBorder: _thin,
              bottomBorder: _thin,
              backgroundColorHex: ExcelColor.fromHexString('#FFF8E7'),
            )
          : _cellStyle;
      final money = i == 2
          ? CellStyle(
              bold: true,
              fontSize: 10,
              horizontalAlign: HorizontalAlign.Right,
              numberFormat: _moneyFmt,
              leftBorder: _thin,
              rightBorder: _thin,
              topBorder: _thin,
              bottomBorder: _thin,
              backgroundColorHex: ExcelColor.fromHexString('#FFF8E7'),
            )
          : _moneyStyle;
      _set(sheet, 0, r, TextCellValue(overview[i].$1), style);
      _set(sheet, 1, r, DoubleCellValue(_round2(overview[i].$2)), money);
    }

    _set(sheet, 0, 11, TextCellValue('Transaction count'), _labelStyle);
    _set(sheet, 1, 11, IntCellValue(count), _subtitleStyle);

    // Category breakdown
    _set(sheet, 0, 13, TextCellValue('Expense by Category'), _sectionStyle);
    _set(sheet, 0, 14, TextCellValue('Category'), _headerStyle);
    _set(sheet, 1, 14, TextCellValue('Amount (RM)'), _headerStyle);
    _set(sheet, 2, 14, TextCellValue('% of Expense'), _headerStyle);

    final catEntries = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (var i = 0; i < catEntries.length; i++) {
      final r = 15 + i;
      final amt = catEntries[i].value;
      final pct = expense > 0 ? (amt / expense * 100) : 0.0;
      _set(
        sheet,
        0,
        r,
        TextCellValue(Categories.displayName(catEntries[i].key)),
        _cellStyle,
      );
      _set(sheet, 1, r, DoubleCellValue(_round2(amt)), _moneyStyle);
      _set(
        sheet,
        2,
        r,
        TextCellValue('${pct.toStringAsFixed(1)}%'),
        _cellCenter,
      );
    }

    if (catEntries.isNotEmpty) {
      final totalR = 15 + catEntries.length;
      _set(sheet, 0, totalR, TextCellValue('Total Expense'), _totalLabelStyle);
      _set(
        sheet,
        1,
        totalR,
        DoubleCellValue(_round2(expense)),
        _totalMoneyStyle,
      );
      _set(sheet, 2, totalR, TextCellValue('100.0%'), _totalMoneyStyle);
    }

    final foot = 17 + catEntries.length + 1;
    _set(
      sheet,
      0,
      foot,
      TextCellValue(
        'Generated by MoneyBee · For personal use only · Not a certified financial statement',
      ),
      CellStyle(fontSize: 9, italic: true),
    );
  }

  void _set(Sheet sheet, int col, int row, CellValue value, CellStyle style) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value;
    cell.cellStyle = style;
  }

  double _round2(double v) => double.parse(v.toStringAsFixed(2));
}