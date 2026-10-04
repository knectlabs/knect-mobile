import 'package:flutter_test/flutter_test.dart';
import 'package:knect_mobile/features/payroll/data/payslip_repository.dart';
import 'package:knect_mobile/features/payroll/presentation/payslip_format.dart';

void main() {
  test('parses a payslip summary keeping decimal-string amounts verbatim', () {
    final summary = PayslipSummary.fromJson({
      'payrollEmployeeId': 'pe-1',
      'period': {
        'id': 'period-1',
        'name': 'October 2026',
        'startDate': '2026-10-01',
        'endDate': '2026-10-31',
        'finalizedAt': '2026-11-01T02:00:00.000Z',
      },
      'grossSalary': '8500000.00',
      'totalDeduction': '500000.00',
      'netSalary': '8000000.00',
    });

    expect(summary.payrollEmployeeId, 'pe-1');
    expect(summary.periodId, 'period-1');
    expect(summary.periodName, 'October 2026');
    expect(summary.startDate, '2026-10-01');
    expect(summary.endDate, '2026-10-31');
    expect(summary.finalizedAt, isNotNull);
    expect(summary.grossSalary, '8500000.00');
    expect(summary.totalDeduction, '500000.00');
    expect(summary.netSalary, '8000000.00');
  });

  test('parses a finalized payslip and groups earnings/deductions', () {
    final payslip = Payslip.fromJson({
      'id': 'pe-1',
      'payrollPeriodId': 'period-1',
      'employee': {'id': 'emp-1', 'name': 'Rina', 'code': 'EMP-001'},
      'basicSalary': '8000000.00',
      'totalAllowance': '500000.00',
      'overtimeAmount': '0.00',
      'grossSalary': '8500000.00',
      'totalDeduction': '500000.00',
      'taxAmount': '0.00',
      'netSalary': '8000000.00',
      'status': 'FINALIZED',
      'lines': [
        {
          'id': 'l1',
          'componentType': 'EARNING',
          'code': 'BASIC',
          'name': 'Basic Salary',
          'quantity': '1',
          'rate': '8000000.00',
          'amount': '8000000.00',
        },
        {
          'id': 'l2',
          'componentType': 'DEDUCTION',
          'code': 'LATE',
          'name': 'Late deduction',
          'quantity': '2',
          'rate': '250000.00',
          'amount': '500000.00',
        },
      ],
    });

    expect(payslip.status, 'FINALIZED');
    expect(payslip.employeeName, 'Rina');
    expect(payslip.employeeCode, 'EMP-001');
    expect(payslip.netSalary, '8000000.00');
    expect(payslip.lines, hasLength(2));
    expect(payslip.earnings, hasLength(1));
    expect(payslip.earnings.single.name, 'Basic Salary');
    expect(payslip.deductions, hasLength(1));
    expect(payslip.deductions.single.amount, '500000.00');
  });

  group('formatIdr', () {
    test('groups thousands and drops zero cents', () {
      expect(formatIdr('8000000.00'), 'Rp 8.000.000');
    });

    test('keeps non-zero cents', () {
      expect(formatIdr('1234567.50'), 'Rp 1.234.567,50');
    });

    test('handles values without a decimal part', () {
      expect(formatIdr('500000'), 'Rp 500.000');
    });

    test('falls back to raw input for non-numeric values', () {
      expect(formatIdr('N/A'), 'N/A');
      expect(formatIdr(null), '');
    });
  });

  group('isPositiveAmount', () {
    test('true for amounts greater than zero', () {
      expect(isPositiveAmount('150000.00'), isTrue);
    });

    test('false for zero, empty, negative, or null', () {
      expect(isPositiveAmount('0.00'), isFalse);
      expect(isPositiveAmount('0'), isFalse);
      expect(isPositiveAmount(''), isFalse);
      expect(isPositiveAmount('-100.00'), isFalse);
      expect(isPositiveAmount(null), isFalse);
    });
  });
}
