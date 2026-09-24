/// Build flavours. Selected once at start-up, never read from a widget.
enum Flavor { dev, staging, prod }

class Env {
  Env._();

  /// Set from `main()` before [setup] runs.
  static Flavor flavor = Flavor.dev;

  /// Host only — no trailing slash, no `/api`.
  ///
  /// TODO(backend): staging/prod hosts are not published yet; all three
  /// flavours currently point at the single environment we were given.
  static String get host {
    switch (flavor) {
      case Flavor.dev:
        return 'https://tacaml.com';
      case Flavor.staging:
        return 'https://tacaml.com';
      case Flavor.prod:
        return 'https://tacaml.com';
    }
  }

  /// Everything the app calls hangs off here: `/auth/login`, `/v2/bootstrap`, …
  static String get apiBase => '$host/api';

  static bool get isProd => flavor == Flavor.prod;
}
