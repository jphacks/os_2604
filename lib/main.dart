import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'services/db/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _DatabaseHost());
}

class _DatabaseHost extends StatefulWidget {
  const _DatabaseHost();

  @override
  State<_DatabaseHost> createState() => _DatabaseHostState();
}

class _DatabaseHostState extends State<_DatabaseHost> {
  late final AppDatabase _database = AppDatabase.production();
  late final DriftOnboardingStore _store = DriftOnboardingStore(_database);

  @override
  Widget build(BuildContext context) =>
      MorningCheckApp(onboardingStore: _store);

  @override
  void dispose() {
    unawaited(_database.close());
    super.dispose();
  }
}
