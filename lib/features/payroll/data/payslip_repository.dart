import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// One finalized payroll period in the employee's payslip list. Amounts stay as
/// decimal strings (e.g. `"8000000.00"`); the client never does payroll math.
class PayslipSummary {
  PayslipSummary.fromJson(Json json)
      : payrollEmployeeId = json.str('payrollEmployeeId'),
        periodId = json.obj('period').str('id'),
        periodName = json.obj('period').str('name'),
        startDate = json.obj('period').str('startDate'),
        endDate = json.obj('period').str('endDate'),
        finalizedAt = json.obj('period').timeOrNull('finalizedAt'),
        grossSalary = json.str('grossSalary'),
        totalDeduction = json.str('totalDeduction'),
        netSalary = json.str('netSalary');

  final String payrollEmployeeId;
  final String periodId;
  final String periodName;
  final String startDate;
  final String endDate;
  final DateTime? finalizedAt;
  final String grossSalary;
  final String totalDeduction;
  final String netSalary;
}

/// A single earning or deduction line on a payslip. Amounts are decimal
/// strings; grouping into earnings/deductions happens in the UI.
class PayslipLine {
  PayslipLine.fromJson(Json json)
      : id = json.str('id'),
        componentType = json.str('componentType'),
        code = json.str('code'),
        name = json.str('name'),
        quantity = json.strOrNull('quantity'),
        rate = json.strOrNull('rate'),
        amount = json.str('amount');

  final String id;

  /// `"EARNING"` or `"DEDUCTION"`.
  final String componentType;
  final String code;
  final String name;
  final String? quantity;
  final String? rate;
  final String amount;

  bool get isEarning => componentType == 'EARNING';
  bool get isDeduction => componentType == 'DEDUCTION';
}

/// The full finalized payslip for one period. All amounts are decimal strings.
class Payslip {
  Payslip.fromJson(Json json)
      : id = json.str('id'),
        payrollPeriodId = json.str('payrollPeriodId'),
        employeeName = json.obj('employee').str('name'),
        employeeCode = json.obj('employee').strOrNull('code'),
        basicSalary = json.str('basicSalary'),
        totalAllowance = json.str('totalAllowance'),
        overtimeAmount = json.str('overtimeAmount'),
        grossSalary = json.str('grossSalary'),
        totalDeduction = json.str('totalDeduction'),
        taxAmount = json.str('taxAmount'),
        netSalary = json.str('netSalary'),
        status = json.str('status'),
        lines =
            json.list('lines').map(PayslipLine.fromJson).toList(growable: false);

  final String id;
  final String payrollPeriodId;
  final String employeeName;
  final String? employeeCode;
  final String basicSalary;
  final String totalAllowance;
  final String overtimeAmount;
  final String grossSalary;
  final String totalDeduction;
  final String taxAmount;
  final String netSalary;
  final String status;
  final List<PayslipLine> lines;

  List<PayslipLine> get earnings =>
      lines.where((line) => line.isEarning).toList(growable: false);

  List<PayslipLine> get deductions =>
      lines.where((line) => line.isDeduction).toList(growable: false);
}

/// Read-only access to the employee's own finalized payslips (PRD §5.13).
class PayslipRepository {
  PayslipRepository(this._api);

  final ApiClient _api;

  Future<List<PayslipSummary>> list() async =>
      dataList(await _api.dio.get('/payroll/me/payslips'))
          .map(PayslipSummary.fromJson)
          .toList();

  Future<Payslip> detail(String periodId) async =>
      Payslip.fromJson(data(await _api.dio.get('/payroll/me/payslips/$periodId')));
}
