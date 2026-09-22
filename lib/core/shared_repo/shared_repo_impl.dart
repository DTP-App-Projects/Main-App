import 'package:digital_trade_portal/core/shared_repo/shared_repo.dart';

import '../../../../core/utils/services/remote_services/api_service.dart';

class SharedRepoImpl implements SharedRepo {
  final ApiService? apiService;

  SharedRepoImpl(this.apiService);


}
