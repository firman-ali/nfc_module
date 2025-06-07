import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nfc_module/nfc_module.dart';

class NfcResetScreen extends StatefulWidget {
  const NfcResetScreen({super.key});

  @override
  State<NfcResetScreen> createState() => _NfcResetScreenState();
}

class _NfcResetScreenState extends State<NfcResetScreen> {
  final NfcModule _nfcModule = NfcModule();
  StreamSubscription<NfcEvent>? _nfcSubscription;

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

  void _prepareReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Reset Kartu'),
        content: const Text(
          'Tindakan ini akan menghapus SEMUA data di kartu dan tidak dapat diurungkan. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final message = await _nfcModule.prepareResetCard(
          keyBytes: _defaultKey,
        );
        setState(() => _status = message);
      } catch (e) {
        setState(() => _status = 'Error: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nfcModule.initializeNfc();
    _nfcSubscription = _nfcModule.onNfcEvent?.listen((event) {
      if (!mounted) return;
      setState(() {
        switch (event) {
          case NfcResetSuccess():
            _status = 'Kartu Berhasil Direset!';
            _result = '${event.sectorsReset} sektor telah dikosongkan.';
            _progressStatus = '';
            break;
          case NfcError():
            _status = 'Error: ${event.errorCode}';
            _result = event.errorMessage;
            _progressStatus = '';
            break;
          case NfcMultiBlockReadSuccess():
            throw UnimplementedError();
          case NfcMultiBlockWriteSuccess():
            throw UnimplementedError();
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
    super.dispose();
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
                    if (_progressStatus.isNotEmpty) ...[
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
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_result),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.restore_page_outlined),
                label: const Text('Reset Kartu ke Pabrikan'),
                onPressed: _prepareReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
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
