import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nfc_module/nfc_module.dart';

class NfcWriteMultipleDataScreen extends StatefulWidget {
  const NfcWriteMultipleDataScreen({super.key});

  @override
  State<NfcWriteMultipleDataScreen> createState() =>
      _NfcWriteMultipleDataScreenState();
}

class _NfcWriteMultipleDataScreenState
    extends State<NfcWriteMultipleDataScreen> {
  final NfcModule _nfcModule = NfcModule();
  StreamSubscription<NfcEvent>? _nfcSubscription;
  List<Map<String, dynamic>> _multiOpResults = [];

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
      _multiOpResults = [];
      setState(() {
        switch (event) {
          case NfcReadSuccess():
            throw UnimplementedError();
          case NfcWriteSuccess():
            throw UnimplementedError();
          case NfcResetSuccess():
            throw UnimplementedError();
          case NfcMultiBlockReadSuccess():
            throw UnimplementedError();
          case NfcMultiBlockWriteSuccess():
          case NfcMultiBlockWriteSuccess():
            _status = 'Selesai Menulis ke Banyak Blok';
            _result = 'Lihat detail hasil di bawah.';
            _multiOpResults = event.results;
            break;
          case NfcError():
            _status = 'Error: ${event.errorCode}';
            _result = event.errorMessage;
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

  void _prepareMultiWrite() async {
    // Daftar target tulis yang di-hardcode untuk demonstrasi
    final targets = [
      const NfcWriteTarget(
        sectorIndex: 1,
        blockIndex: 0,
        dataHex: "AABBCCDDEEFFAABBCCDDEEFFAABBCCDD",
      ),
      const NfcWriteTarget(
        sectorIndex: 1,
        blockIndex: 1,
        dataHex: "11223344556677889900112233445566",
      ),
      const NfcWriteTarget(
        sectorIndex: 1,
        blockIndex: 2,
        dataHex: "00000000000000000000000000000000",
      ),
      // Contoh target yang akan gagal karena melanggar aturan keamanan
      const NfcWriteTarget(
        sectorIndex: 1,
        blockIndex: 3,
        dataHex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
      ),
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Tulis Ganda'),
        content: Text(
          'Anda akan menulis ke ${targets.length} blok. Tindakan ini akan menimpa data yang ada. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Tulis'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final message = await _nfcModule.prepareWriteMultipleBlocks(
          targets: targets,
          keyHex: _defaultKey,
        );
        setState(() {
          _status = message;
          _result = 'Menunggu tag...';
          _multiOpResults = [];
        });
      } catch (e) {
        setState(() => _status = 'Error: $e');
      }
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
              if (_multiOpResults.isNotEmpty) _buildMultiOpResultView(),
              const SizedBox(height: 24),
              // Action Buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                label: const Text('Tulis Multiple Blok'),
                onPressed: _prepareMultiWrite,
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

  Widget _buildMultiOpResultView() {
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
            final bool isRead = item.containsKey('dataHex');
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
                      ? (isRead
                            ? 'Baca: ${item['dataHex']}'
                            : 'Tulis: Berhasil')
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
