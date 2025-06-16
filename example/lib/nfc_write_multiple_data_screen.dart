import 'dart:async';
import 'dart:typed_data';

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
      _multiOpResults = [];
      setState(() {
        switch (event) {
          case NfcResetSuccess():
            throw UnimplementedError();
          case NfcMultiBlockReadSuccess():
            throw UnimplementedError();
          case NfcMultiBlockWriteSuccess():
            _status = 'Selesai Menulis ke Banyak Blok';
            _multiOpResults = event.results;
            _progressStatus = '';
            break;
          case NfcError():
            _status = 'Error: ${event.errorCode}';
            _progressStatus = '';
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

  void _prepareMultiWrite() async {
    final targets = [
      NfcWriteTarget(
        sectorIndex: 0,
        blockIndex: 2,
        dataBytes: Uint8List.fromList([
          40,
          240,
          200,
          15,
          215,
          12,
          139,
          26,
          9,
          248,
          11,
          238,
          81,
          94,
          254,
          90,
        ]),
      ),
      NfcWriteTarget(
        sectorIndex: 1,
        blockIndex: 0,
        dataBytes: Uint8List.fromList([
          18,
          233,
          146,
          108,
          157,
          216,
          100,
          210,
          244,
          184,
          47,
          26,
          57,
          72,
          147,
          11,
        ]),
      ),
      NfcWriteTarget(
        sectorIndex: 1,
        blockIndex: 1,
        dataBytes: Uint8List.fromList([
          77,
          61,
          29,
          43,
          218,
          98,
          181,
          230,
          134,
          144,
          202,
          19,
          92,
          172,
          168,
          235,
        ]),
      ),
      NfcWriteTarget(
        sectorIndex: 1,
        blockIndex: 2,
        dataBytes: Uint8List.fromList([
          135,
          149,
          108,
          60,
          144,
          161,
          141,
          60,
          28,
          122,
          88,
          216,
          219,
          180,
          10,
          183,
        ]),
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
          keyBytes: _defaultKey,
        );
        setState(() {
          _status = message;
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
                  ).colorScheme.primaryContainer.withValues(alpha: 0.5),
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
            final bool isRead = item.containsKey('dataBytes');
            return Card(
              color: success
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
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
                            ? 'Baca: ${item['dataBytes']}'
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
