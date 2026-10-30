import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_result.dart';
import '../../../data/models/compliance/legal.dart';
import '../../../data/repositories/compliance_repository.dart';

/// The organization's compliance profile, read once per organization from
/// `GET /signatories` — the only payload that carries `activity_type` (the
/// bootstrap does not). Drives the marketer entry points and the
/// registration lock on the organization screen.
class OrgComplianceCubit extends Cubit<RegistrationData?> {
  final ComplianceRepository _repo;

  OrgComplianceCubit(this._repo) : super(null);

  bool get isMarketer => state?.activityType == 'marketer';

  Future<void> load() async {
    final result = await _repo.signatories();
    if (isClosed) return;
    if (result case Ok(:final data)) emit(data.organization);
  }

  void reset() => emit(null);
}
