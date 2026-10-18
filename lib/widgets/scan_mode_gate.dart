import 'package:flutter/material.dart';

import '../screens/scan_screen.dart';
import '../services/db/health_record_repository.dart';
import '../services/settings/scan_mode_store.dart';

/// Resolve the persisted mode before creating a camera or starting a scan.
class ScanModeGate extends StatefulWidget {
  const ScanModeGate({
    super.key,
    required this.repository,
    required this.standard,
    this.research,
    this.store,
  });
  final HealthRecordRepository repository;
  final ScanSession Function() standard;
  final ScanSession Function()? research;
  final ScanModeStore? store;
  @override
  State<ScanModeGate> createState() => _ScanModeGateState();
}

class _ScanModeGateState extends State<ScanModeGate> {
  late Future<bool> _mode =
      widget.store?.loadResearchMode() ?? Future.value(false);
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _mode,
    builder: (context, snapshot) {
      if (snapshot.hasError ||
          (snapshot.data == true && widget.research == null)) {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('計測モードを読み込めませんでした'),
                FilledButton(
                  onPressed: () => setState(() {
                    _mode =
                        widget.store?.loadResearchMode() ?? Future.value(false);
                  }),
                  child: const Text('再試行'),
                ),
              ],
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return ScanScreen(
        repository: widget.repository,
        researchMode: snapshot.data == true,
        createSession: snapshot.data == true
            ? widget.research!
            : widget.standard,
      );
    },
  );
}
