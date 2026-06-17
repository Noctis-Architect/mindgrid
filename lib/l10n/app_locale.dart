enum AppLocale {
  en('en'),
  fa('fa');

  const AppLocale(this.code);
  final String code;

  static AppLocale fromCode(String? code) {
    return AppLocale.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLocale.en,
    );
  }
}
