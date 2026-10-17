/// Navigation identifiers only; measurement and persistence contracts are pending.
abstract final class AppRoutes {
  static const home = '/';
  static const onboarding = '/onboarding';
  static const scan = '/scan';
  static const result = '/result';
  static const history = '/history';
  static const settings = '/settings';

  static const destinations = {
    onboarding: '初回設定',
    scan: '撮影',
    result: '結果',
    history: '履歴',
    settings: '設定',
  };
}
