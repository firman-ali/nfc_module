import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nfc_module/nfc_module.dart';

class NfcReadMultipleDataScreen extends StatefulWidget {
  const NfcReadMultipleDataScreen({super.key});

  @override
  State<NfcReadMultipleDataScreen> createState() =>
      _NfcReadMultipleDataScreenState();
}

class _NfcReadMultipleDataScreenState extends State<NfcReadMultipleDataScreen> {
  final NfcModule _nfcModule = NfcModule();
  StreamSubscription<NfcEvent>? _nfcSubscription;
  List<Map<String, dynamic>> _multiReadResults = [];

  String _status = 'Selamat datang!';
  String _result = '-';
  final String _defaultKey = "FFFFFFFFFFFF";
  final TextEditingController _sectorController = TextEditingController(
    text: '1',
  );
  final TextEditingController _blockController = TextEditingController(
    text: '0',
  );
  final TextEditingController _dataController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nfcModule.initializeNfc();
    _nfcSubscription = _nfcModule.onNfcEvent?.listen((event) {
      if (!mounted) return;
      setState(() {
        switch (event) {
          case NfcReadSuccess():
            throw UnimplementedError();
          case NfcWriteSuccess():
            throw UnimplementedError();
          case NfcResetSuccess():
            throw UnimplementedError();
          case NfcMultiBlockReadSuccess():
            _status = 'Sukses Membaca Banyak Blok';
            _result = 'Lihat detail hasil di bawah.';
            _multiReadResults = event.results;
            break;
          case NfcError():
            _status = 'Error: ${event.errorCode}';
            _result = event.errorMessage;
            break;
          case NfcMultiBlockReadSuccess():
            throw UnimplementedError();
        }
      });
    });
  }

  @override
  void dispose() {
    _nfcSubscription?.cancel();
    _nfcModule.dispose();
    _sectorController.dispose();
    _blockController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  void _prepareMultiRead() async {
    final targets = [
      const NfcReadTarget(sectorIndex: 1, blockIndex: 0),
      const NfcReadTarget(sectorIndex: 1, blockIndex: 1),
      const NfcReadTarget(sectorIndex: 2, blockIndex: 0),
      const NfcReadTarget(
        sectorIndex: 5,
        blockIndex: 0,
      ), // Contoh sektor yang mungkin gagal
    ];

    try {
      final message = await _nfcModule.prepareReadMultipleBlocks(
        targets: targets,
        keyHex: _defaultKey,
      );
      setState(() {
        _status = message;
        _result = 'Menunggu tag...';
        _multiReadResults = [];
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  void _cancel() async {
    await _nfcModule.cancelOperation();
    setState(() {
      _status = 'Operasi dibatalkan. Siap untuk perintah baru.';
      _result = '-';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC Read/Write Block')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Result Panel
              if (_multiReadResults.isNotEmpty) _buildMultiReadResultView(),
              const SizedBox(height: 24),
              // Action Buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                label: const Text('Baca Multiple Blok'),
                onPressed: _prepareMultiRead,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Batalkan Operasi'),
                onPressed: _cancel,
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiReadResultView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hasil Baca Ganda:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _multiReadResults.length,
          itemBuilder: (context, index) {
            final item = _multiReadResults[index];
            final bool success = item['success'];
            return Card(
              color: success
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: Icon(
                  success ? Icons.check_circle_outline : Icons.error_outline,
                  color: success ? Colors.green : Colors.red,
                ),
                title: Text('Sektor ${item['sector']}, Blok ${item['block']}'),
                subtitle: Text(
                  success
                      ? 'Data: ${item['dataHex']}'
                      : 'Error: ${item['error']}',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
