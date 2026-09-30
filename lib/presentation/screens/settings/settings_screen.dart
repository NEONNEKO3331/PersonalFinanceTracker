import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MoneyBee'),
            subtitle: Text('V1 · Offline personal finance tracker'),
          ),
          ListTile(
            leading: Icon(Icons.document_scanner_outlined),
            title: Text('OCR'),
            subtitle: Text('On-device PaddleOCR (PP-OCRv5)'),
          ),
          ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Storage'),
            subtitle: Text('Local SQLite only · no cloud sync in V1'),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy'),
            subtitle: Text('Receipt images & data stay on this device'),
          ),
        ],
      ),
    );
  }
}
