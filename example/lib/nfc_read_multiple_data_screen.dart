import 'dart:async';
import 'dart:typed_data';

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
  List<Map<String, dynamic>> _multiOpResults = [];

  String _status = 'Selamat datang!';
  String _result = '-';
  String _progressStatus = '';
  final Uint8List _defaultKey = Uint8List.fromList([
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
    0xFF,
  ]);
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
          case NfcResetSuccess():
            throw UnimplementedError();
          case NfcMultiBlockReadSuccess():
            _status = 'Sukses Membaca Banyak Blok';
            _result = 'Lihat detail hasil di bawah.';
            _multiOpResults = event.results;
            _progressStatus = "";
            break;
          case NfcMultiBlockWriteSuccess():
            throw UnimplementedError();
          case NfcError():
            _status = 'Error: ${event.errorCode}';
            _result = event.errorMessage;
            _progressStatus = "";
            break;
          case NfcProgressUpdate():
            _status = 'Sesi sedang berlangsung...';
            _progressStatus =
                '${event.operation} ${event.completed} dari ${event.total}. Tempelkan lagi untuk melanjutkan.';
            break;
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
      const NfcReadTarget(sectorIndex: 0, blockIndex: 0),
      const NfcReadTarget(sectorIndex: 0, blockIndex: 1),
      const NfcReadTarget(sectorIndex: 0, blockIndex: 2),
      const NfcReadTarget(sectorIndex: 1, blockIndex: 0),
      const NfcReadTarget(sectorIndex: 1, blockIndex: 1),
      const NfcReadTarget(sectorIndex: 1, blockIndex: 2),
    ];

    try {
      final message = await _nfcModule.prepareReadMultipleBlocks(
        targets: targets,
        keyBytes: _defaultKey,
      );
      setState(() {
        _status = message;
        _result = 'Menunggu tag...';
        _multiOpResults = [];
        _progressStatus = '';
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
      _progressStatus = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSessionActive = _progressStatus.isNotEmpty;

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
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'STATUS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (isSessionActive) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        _progressStatus,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Result Panel
              if (!isSessionActive && _result != '-')
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_result),
                  ),
                ),
              const SizedBox(height: 24),
              if (_multiOpResults.isNotEmpty) _buildMultiReadResultView(),
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
          itemCount: _multiOpResults.length,
          itemBuilder: (context, index) {
            final item = _multiOpResults[index];
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
                      ? 'Data: ${item['dataBytes']}'
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
