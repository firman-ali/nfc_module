import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nfc_module/nfc_module.dart';
import 'package:nfc_module/nfc_result.dart';

class NfcReadWriteScreen extends StatefulWidget {
  const NfcReadWriteScreen({super.key});

  @override
  State<NfcReadWriteScreen> createState() => _NfcReadWriteScreenState();
}

class _NfcReadWriteScreenState extends State<NfcReadWriteScreen> {
  final NfcModule _nfcModule = NfcModule();
  StreamSubscription<NfcEvent>? _nfcSubscription;

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
            _status =
                'Sukses Membaca Sektor ${event.sector}, Blok ${event.block}';
            _result = 'Data (Hex): ${event.dataHex}';
            break;
          case NfcWriteSuccess():
            _status =
                'Sukses Menulis ke Sektor ${event.sector}, Blok ${event.block}';
            _result = 'Data berhasil ditulis.';
            break;
          case NfcResetSuccess():
            _status = 'Kartu Berhasil Direset!';
            _result = '${event.sectorsReset} sektor telah dikosongkan.';
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

  void _prepareRead() async {
    final sector = int.tryParse(_sectorController.text);
    final block = int.tryParse(_blockController.text);
    if (sector == null || block == null || block < 0 || block > 2) {
      setState(
        () =>
            _status = 'Error: Sektor/Blok tidak valid. Blok harus antara 0-2.',
      );
      return;
    }
    try {
      final message = await _nfcModule.prepareReadBlock(
        sectorIndex: sector,
        blockIndex: block,
        keyHex: _defaultKey,
      );
      setState(() => _status = message);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  void _prepareWrite() async {
    final sector = int.tryParse(_sectorController.text);
    final block = int.tryParse(_blockController.text);
    final dataHex = _dataController.text;

    if (sector == null || block == null || block < 0 || block > 2) {
      setState(
        () =>
            _status = 'Error: Sektor/Blok tidak valid. Blok harus antara 0-2.',
      );
      return;
    }
    if (dataHex.isEmpty || dataHex.length != 32) {
      setState(() => _status = 'Error: Data hex harus 32 karakter.');
      return;
    }
    try {
      final message = await _nfcModule.prepareWriteBlock(
        sectorIndex: sector,
        blockIndex: block,
        keyHex: _defaultKey,
        dataHex: dataHex,
      );
      setState(() => _status = message);
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
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_result),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sectorController,
                      decoration: const InputDecoration(
                        labelText: 'Sektor',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _blockController,
                      decoration: const InputDecoration(
                        labelText: 'Blok (0-2)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dataController,
                maxLength: 32,
                decoration: const InputDecoration(
                  labelText: 'Data untuk Ditulis (32 Karakter Hex)',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.chrome_reader_mode_outlined),
                label: const Text('Baca Blok'),
                onPressed: _prepareRead,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.drive_file_rename_outline),
                label: const Text('Tulis ke Blok'),
                onPressed: _prepareWrite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
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
}
