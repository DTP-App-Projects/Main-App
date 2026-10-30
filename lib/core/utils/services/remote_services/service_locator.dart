import 'dart:async';

import 'package:get_it/get_it.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/bootstrap_repository.dart';
import '../../../../data/repositories/account_repository.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/compliance_repository.dart';
import '../../../../data/repositories/contracts_repository.dart';
import '../../../../data/repositories/fleet_repository.dart';
import '../../../../data/repositories/internal_transfers_repository.dart';
import '../../../../data/repositories/lookups_repository.dart';
import '../../../../data/repositories/orders_repository.dart';
import '../../../../data/repositories/places_repository.dart';
import '../../../../data/repositories/notifications_repository.dart';
import '../../../../data/repositories/onboarding_repository.dart';
import '../../../../data/repositories/organization_repository.dart';
import '../../../../data/repositories/ops_repository.dart';
import '../../../../data/repositories/receivables_repository.dart';
import '../../../../data/repositories/shipments_repository.dart';
import '../../../../data/repositories/shop_repository.dart';
import '../../../../data/repositories/supplier_repository.dart';
import '../../../../data/repositories/uploads_repository.dart';
import '../../../deeplink/deep_link_router.dart';
import '../../../network/api_client.dart';
import '../../../network/device_identity.dart';
import '../../../push/push_service.dart';
import '../../../session/session_cubit.dart';
import '../../../session/session_store.dart';
import '../../../workspace/workspace_cubit.dart';
import '../../../../features/shared/compliance/org_compliance_cubit.dart';
import '../../../../features/shared/compliance/terms/terms_cubit.dart';
import '../../../../features/shared/notifications/presentation/view_models/notifications_cubit.dart';
import '../../roots/app_router.dart';

final getIt = GetIt.instance;

/// Wiring order matters: the session store is the [AuthContext] the Dio
/// interceptors read, so it exists before the client does.
Future<void> setup() async {
  // Before the first request: every call carries `X-Device-Id`.
  await DeviceIdentity.ensure();

  final session = SessionStore();
  await session.restore();
  getIt.registerSingleton<SessionStore>(session);

  final client = ApiClient.create(session);
  getIt.registerSingleton<ApiClient>(client);

  final authRepo = AuthRepository(client);
  final bootstrapRepo = BootstrapRepository(client);
  getIt.registerSingleton<AuthRepository>(authRepo);
  getIt.registerSingleton<BootstrapRepository>(bootstrapRepo);
  getIt.registerSingleton<OnboardingRepository>(OnboardingRepository(client));
  getIt.registerSingleton<OrganizationRepository>(OrganizationRepository(client));
  getIt.registerSingleton<NotificationsRepository>(NotificationsRepository(client));
  getIt.registerSingleton<LookupsRepository>(LookupsRepository(client));
  getIt.registerSingleton<CatalogRepository>(CatalogRepository(client));
  getIt.registerSingleton<OrdersRepository>(OrdersRepository(client));
  getIt.registerSingleton<ShipmentsRepository>(ShipmentsRepository(client));
  getIt.registerSingleton<ReceivablesRepository>(ReceivablesRepository(client));
  getIt.registerSingleton<UploadsRepository>(UploadsRepository(client));
  getIt.registerSingleton<SupplierRepository>(SupplierRepository(client));
  getIt.registerSingleton<ContractsRepository>(ContractsRepository(client));
  getIt.registerSingleton<AccountRepository>(AccountRepository(client));
  getIt.registerSingleton<ShopRepository>(ShopRepository(client));
  getIt.registerSingleton<ComplianceRepository>(ComplianceRepository(client));
  // These two read `organization_id` from the request body / query, so they
  // hold the session to stamp it on every call.
  getIt.registerSingleton<FleetRepository>(FleetRepository(client, session));
  getIt.registerSingleton<InternalTransfersRepository>(
    InternalTransfersRepository(client, session),
  );
  // Nominatim for the branch map, not our backend.
  getIt.registerLazySingleton<PlacesRepository>(PlacesRepository.new);

  final opsRepo = OpsRepository(client);
  getIt.registerSingleton<OpsRepository>(opsRepo);

  final push = PushService(authRepo, bootstrapRepo, session);
  getIt.registerSingleton<PushService>(push);

  final workspace = WorkspaceCubit(session, opsRepo);
  getIt.registerSingleton<WorkspaceCubit>(workspace);

  final sessionCubit = SessionCubit(session, bootstrapRepo, workspace, push);
  getIt.registerSingleton<SessionCubit>(sessionCubit);

  // Session-scoped so the shell can show an unread badge without the list
  // ever having been opened.
  final notifications = NotificationsCubit(getIt<NotificationsRepository>());
  getIt.registerSingleton<NotificationsCubit>(notifications);

  // The badge has to be right before the list is ever opened, and must not
  // survive a logout or an organization switch.
  final terms = TermsCubit(getIt<ComplianceRepository>());
  getIt.registerSingleton<TermsCubit>(terms);
  final orgCompliance = OrgComplianceCubit(getIt<ComplianceRepository>());
  getIt.registerSingleton<OrgComplianceCubit>(orgCompliance);

  sessionCubit.onOrganizationResolved = () {
    unawaited(notifications.load());
    unawaited(_checkTerms(terms));
    unawaited(orgCompliance.load());
  };
  sessionCubit.onContextCleared = () {
    notifications.reset();
    terms.reset();
    orgCompliance.reset();
    _termsShownThisSession = false;
  };

  // Any call that comes back SessionExpired drops the token and routes to
  // login — there is no refresh flow to fall back on.
  client.onSessionExpired = sessionCubit.logout;

  // Registered last: touching AppRouter.router builds the redirect listener,
  // which reads the two cubits above out of the locator.
  getIt.registerSingleton<DeepLinkRouter>(DeepLinkRouter(workspace, AppRouter.router));
  push.deepLinks = getIt<DeepLinkRouter>();
  push.notifications = notifications;

  // The terms gate: a write refused with `409 terms_acceptance_required`
  // opens the terms screen; accepting there replays the write.
  client.onTermsRequired = (_) async =>
      (await AppRouter.router.push<bool>(AppRoutes.termsGate)) ?? false;
}

/// On start and after login: a version in force and not accepted opens the
/// terms screen once. Reads stay open, so it is not a hard redirect — the
/// server's `409` guards every write regardless.
bool _termsShownThisSession = false;

Future<void> _checkTerms(TermsCubit terms) async {
  final status = await terms.load();
  if (status == null || !status.acceptanceRequired || _termsShownThisSession) return;
  if (status.pending.every((d) => !d.canAccept)) return;
  _termsShownThisSession = true;
  unawaited(AppRouter.router.push<bool>(AppRoutes.termsGate));
}
