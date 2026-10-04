/// Formats a decimal-string IDR amount (e.g. `"8000000.00"`) for display as
/// `"Rp 8.000.000"`. The API returns money as decimal strings and the client
/// must not perform payroll math, so this only groups digits — no rounding or
/// arithmetic. Cents are dropped when zero and shown with a `,` otherwise.
/// Falls back to the raw input for null/empty/non-numeric values.
String formatIdr(String? amount) {
  final raw = amount?.trim() ?? '';
  if (raw.isEmpty) return raw;

  final negative = raw.startsWith('-');
  final unsigned = negative ? raw.substring(1) : raw;

  final parts = unsigned.split('.');
  final intPart = parts.first;
  final centsPart = parts.length > 1 ? parts[1] : '';

  // Defensive: only group when the integer portion is purely digits.
  if (intPart.isEmpty || !RegExp(r'^\d+$').hasMatch(intPart)) return raw;

  final grouped = _groupThousands(intPart);
  final showCents =
      centsPart.isNotEmpty && int.tryParse(centsPart) != null && int.parse(centsPart) != 0;
  final sign = negative ? '-' : '';
  return showCents ? 'Rp $sign$grouped,$centsPart' : 'Rp $sign$grouped';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  final length = digits.length;
  for (var i = 0; i < length; i++) {
    if (i > 0 && (length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// True when a decimal-string amount is greater than zero, without parsing to
/// a floating-point number (keeps the no-money-math rule). Returns false for
/// null/empty/non-numeric input.
bool isPositiveAmount(String? amount) {
  final raw = amount?.trim() ?? '';
  if (raw.isEmpty || raw.startsWith('-')) return false;
  return RegExp(r'[1-9]').hasMatch(raw);
}
