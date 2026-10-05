import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/services/ocr_service.dart';

class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  Map<String, dynamic>? _result;
  bool _processing = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    // Higher quality + resolution helps PaddleOCR read digits (e.g. 4,962.00)
    // on thermal bank slips. Cap size so OCR stays reasonably fast.
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 1920,
      maxHeight: 2560,
    );
    if (file == null) return;
    setState(() {
      _image = file;
      _result = null;
      _error = null;
    });
    await _runOcr(file.path);
  }

  Future<void> _runOcr(String path) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final ocr = ref.read(ocrServiceProvider);
      final result = await ocr.scanReceipt(path);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _chooseSource() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _continueToAdd() {
    if (_result == null) return;
    context.push('/add', extra: _result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_image == null)
            _Placeholder(onTap: _chooseSource)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_image!.path),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),
          if (_image != null)
            OutlinedButton.icon(
              onPressed: _processing ? null : _chooseSource,
              icon: const Icon(Icons.refresh),
              label: const Text('Reselect image'),
            ),
          const SizedBox(height: 16),
          if (_processing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Running on-device OCR…'),
                ],
              ),
            ),
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'OCR failed: $_error\n\n'
                  'Tip: Use an arm64 Android device. '
                  'Or switch to MockOcrService in ocr_service.dart for UI testing.',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          if (_result != null && !_processing) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Divider(),
                    _row('Merchant', '${_result!['merchant']}'),
                    _row(
                      'Amount',
                      'RM ${(_result!['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    ),
                    _row('Date', '${_result!['date']}'),
                    _row('Category', '${_result!['category']}'),
                    _row(
                      'Confidence',
                      '${(((_result!['confidence'] as num?) ?? 0) * 100).toStringAsFixed(0)}%',
                    ),
                    // Debug: show raw OCR text so we can fix parsing
                    if (_result!['rawText'] != null) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      Text(
                        'Raw OCR (debug)',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        '${_result!['rawText']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _continueToAdd,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: const Text('Review & Save'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final VoidCallback onTap;

  const _Placeholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400, width: 1.5),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.document_scanner_outlined, size: 48),
              SizedBox(height: 8),
              Text('Tap to take or pick a receipt photo'),
            ],
          ),
        ),
      ),
    );
  }
}