import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:digital_trade_portal/core/shared_repo/shared_repo_impl.dart';
import 'package:digital_trade_portal/features/auth/data/repos/auth_repo_impl.dart';
import 'api_service.dart';
//dependency Injection

final getIt = GetIt.instance;

void setup() {
  getIt.registerSingleton<ApiService>(ApiService(Dio()));
  getIt.registerSingleton<AuthRepoImpl>(AuthRepoImpl(getIt.get<ApiService>()));
  getIt.registerSingleton<SharedRepoImpl>(SharedRepoImpl(getIt.get<ApiService>()));
}
