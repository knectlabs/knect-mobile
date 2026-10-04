import '../../../shared/widgets/state_views.dart';

/// Human label for a performance goal status.
String goalStatusLabel(String status) => switch (status) {
      'DRAFT' => 'Draft',
      'ACTIVE' => 'Active',
      'COMPLETED' => 'Completed',
      'CANCELLED' => 'Cancelled',
      _ => status,
    };

/// Tone for a performance goal status chip.
StatusTone goalStatusTone(String status) => switch (status) {
      'COMPLETED' => StatusTone.success,
      'ACTIVE' => StatusTone.warning,
      'CANCELLED' => StatusTone.danger,
      _ => StatusTone.neutral,
    };

/// Human label for a review type.
String reviewTypeLabel(String type) => switch (type) {
      'SELF' => 'Self review',
      'MANAGER' => 'Manager review',
      'PEER' => 'Peer review',
      'THREE_SIXTY' => '360 review',
      _ => type,
    };

/// Human label for a review status.
String reviewStatusLabel(String status) => switch (status) {
      'PENDING' => 'Pending',
      'SUBMITTED' => 'Submitted',
      _ => status,
    };

/// Tone for a review status chip.
StatusTone reviewStatusTone(String status) => switch (status) {
      'SUBMITTED' => StatusTone.success,
      'PENDING' => StatusTone.warning,
      _ => StatusTone.neutral,
    };

/// Progress label from decimal-string target/current values, e.g. `"3 / 10"`.
/// Falls back to the current value alone, then an em dash. No arithmetic — the
/// client never computes performance values.
String goalProgress({String? currentValue, String? targetValue}) {
  final current = currentValue?.trim();
  final target = targetValue?.trim();
  if (target != null && target.isNotEmpty) {
    return '${_trim(current) ?? '0'} / ${_trim(target)}';
  }
  return _trim(current) ?? '—';
}

/// Rating label from a decimal string, dropping trailing `.00`.
String? ratingLabel(String? rating) => _trim(rating?.trim());

/// Drops a trailing `.00`/`.x0` from a decimal string for display; returns null
/// for null/empty input.
String? _trim(String? value) {
  if (value == null || value.isEmpty) return null;
  if (!value.contains('.')) return value;
  var out = value;
  while (out.endsWith('0')) {
    out = out.substring(0, out.length - 1);
  }
  if (out.endsWith('.')) out = out.substring(0, out.length - 1);
  return out;
}
