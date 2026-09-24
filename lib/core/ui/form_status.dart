import 'package:flutter/foundation.dart';

enum FormStatus { idle, submitting, success, failure }

/// Shared shape for every submit-a-form screen: one status, one localized
/// message, and the server's `bag` mapped onto field slots.
@immutable
class SubmitState {
  final FormStatus status;

  /// Already localized. Never a raw server key.
  final String? message;

  /// `400 validation_error` → `{field: [messages]}`.
  final Map<String, List<String>> bag;

  const SubmitState({
    this.status = FormStatus.idle,
    this.message,
    this.bag = const {},
  });

  bool get isSubmitting => status == FormStatus.submitting;
  bool get isSuccess => status == FormStatus.success;

  String? fieldError(String field) {
    final messages = bag[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  SubmitState copyWith({
    FormStatus? status,
    String? message,
    Map<String, List<String>>? bag,
    bool clearMessage = false,
  }) =>
      SubmitState(
        status: status ?? this.status,
        message: clearMessage ? null : (message ?? this.message),
        bag: bag ?? this.bag,
      );
}
