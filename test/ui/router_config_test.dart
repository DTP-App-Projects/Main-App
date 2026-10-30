import 'package:digital_trade_portal/core/push/push_service.dart';
import 'package:digital_trade_portal/core/session/session_cubit.dart';
import 'package:digital_trade_portal/core/session/session_store.dart';
import 'package:digital_trade_portal/core/utils/roots/app_router.dart';
import 'package:digital_trade_portal/core/utils/services/remote_services/service_locator.dart';
import 'package:digital_trade_portal/core/workspace/workspace_cubit.dart';
import 'package:digital_trade_portal/data/repositories/auth_repository.dart';
import 'package:digital_trade_portal/data/repositories/bootstrap_repository.dart';
import 'package:digital_trade_portal/data/repositories/ops_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../core/fake_backend.dart';

/// go_router runs a parent route's `redirect` for every child as well, and
/// hands it only the parent's own path. A "send the bare parent somewhere"
/// redirect therefore captures every child: it sent `/terms/doc/1` back to
/// the terms list and every `/compliance/...` screen to the complaints list.
void main() {
  setUpAll(() async {
    await useFakeStorage();
    final (client, _) = clientWith(FakeAdapter.json(const {}));
    final store = SessionStore();
    final bootstrap = BootstrapRepository(client);
    final workspace = WorkspaceCubit(store, OpsRepository(client));
    await getIt.reset();
    getIt
      ..registerSingleton<WorkspaceCubit>(workspace)
      ..registerSingleton<SessionCubit>(
        SessionCubit(store, bootstrap, workspace, PushService(AuthRepository(client), bootstrap, store)),
      );
  });

  test('no route with child pages has its own redirect', () {
    final offenders = <String>[];
    void walk(List<RouteBase> routes, String prefix) {
      for (final route in routes) {
        if (route is GoRoute) {
          final path = route.path.startsWith('/') ? route.path : '$prefix/${route.path}';
          if (route.routes.isNotEmpty && route.redirect != null) offenders.add(path);
          walk(route.routes, path);
        } else {
          walk(route.routes, prefix);
        }
      }
    }

    walk(AppRouter.router.configuration.routes, '');
    expect(offenders, isEmpty);
  });

  test('the terms and compliance children resolve to their own screens', () {
    String leaf(String location) =>
        AppRouter.router.configuration.findMatch(location).matches.last.route is GoRoute
            ? (AppRouter.router.configuration.findMatch(location).matches.last.route as GoRoute).path
            : '';
    expect(leaf('/terms/doc/1'), 'doc/:id');
    expect(leaf('/terms/accept'), 'accept');
    expect(leaf('/compliance/quotations/1'), ':id');
    expect(leaf('/compliance/invoices/1'), 'invoices/:id');
  });
}
