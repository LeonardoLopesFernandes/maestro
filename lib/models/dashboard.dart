class DashboardResponse {
  final List<DashboardCount> counts;
  final DashboardData data;

  const DashboardResponse({this.counts = const [], required this.data});

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    final dashboard = json['dashboard'];
    return DashboardResponse(
      counts: (json['data'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DashboardCount.fromJson)
          .toList(),
      data: DashboardData.fromJson(
        dashboard is Map<String, dynamic> ? dashboard : const {},
      ),
    );
  }
}

class DashboardCount {
  final String id;
  final int count;

  const DashboardCount({required this.id, required this.count});

  factory DashboardCount.fromJson(Map<String, dynamic> json) =>
      DashboardCount(
        id: (json['_id'] ?? json['status'] ?? '').toString(),
        count: _toInt(json['count']),
      );
}

class DashboardData {
  final DashboardHeader header;
  final List<DashboardSummaryCard> summaryCards;
  final OrdersInProgress ordersInProgress;
  final List<DashboardStatusCard> statusCards;
  final DashboardTables tables;

  const DashboardData({
    required this.header,
    this.summaryCards = const [],
    required this.ordersInProgress,
    this.statusCards = const [],
    required this.tables,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) =>
      DashboardData(
        header: DashboardHeader.fromJson(
          json['header'] is Map<String, dynamic>
              ? json['header'] as Map<String, dynamic>
              : const {},
        ),
        summaryCards: (json['summaryCards'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DashboardSummaryCard.fromJson)
            .toList(),
        ordersInProgress: OrdersInProgress.fromJson(
          json['ordersInProgress'] is Map<String, dynamic>
              ? json['ordersInProgress'] as Map<String, dynamic>
              : const {},
        ),
        statusCards: (json['statusCards'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DashboardStatusCard.fromJson)
            .toList(),
        tables: DashboardTables.fromJson(
          json['tables'] is Map<String, dynamic>
              ? json['tables'] as Map<String, dynamic>
              : const {},
        ),
      );
}

class DashboardHeader {
  final String date;
  final String updatedAt;
  final String searchPlaceholder;

  const DashboardHeader({
    this.date = '',
    this.updatedAt = '',
    this.searchPlaceholder = '',
  });

  factory DashboardHeader.fromJson(Map<String, dynamic> json) =>
      DashboardHeader(
        date: (json['date'] ?? '').toString(),
        updatedAt: (json['updatedAt'] ?? '').toString(),
        searchPlaceholder: (json['searchPlaceholder'] ?? '').toString(),
      );
}

class DashboardSummaryCard {
  final String id;
  final String value;
  final String description;
  final String goal;
  final String status;
  final String color;

  const DashboardSummaryCard({
    required this.id,
    required this.value,
    required this.description,
    required this.goal,
    required this.status,
    required this.color,
  });

  factory DashboardSummaryCard.fromJson(Map<String, dynamic> json) =>
      DashboardSummaryCard(
        id: (json['id'] ?? '').toString(),
        value: (json['value'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        goal: (json['goal'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        color: (json['color'] ?? '').toString(),
      );
}

class OrdersInProgress {
  final String title;
  final int total;
  final List<OrderProgressItem> items;

  const OrdersInProgress({
    this.title = '',
    this.total = 0,
    this.items = const [],
  });

  factory OrdersInProgress.fromJson(Map<String, dynamic> json) =>
      OrdersInProgress(
        title: (json['title'] ?? '').toString(),
        total: _toInt(json['total']),
        items: (json['items'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(OrderProgressItem.fromJson)
            .toList(),
      );
}

class OrderProgressItem {
  final String label;
  final int value;
  final String color;
  final String percentage;

  const OrderProgressItem({
    required this.label,
    required this.value,
    required this.color,
    required this.percentage,
  });

  factory OrderProgressItem.fromJson(Map<String, dynamic> json) =>
      OrderProgressItem(
        label: (json['label'] ?? '').toString(),
        value: _toInt(json['value']),
        color: (json['color'] ?? '').toString(),
        percentage: (json['percentage'] ?? '').toString(),
      );
}

class DashboardStatusCard {
  final String title;
  final String value;
  final String status;
  final String code;

  const DashboardStatusCard({
    required this.title,
    required this.value,
    required this.status,
    required this.code,
  });

  factory DashboardStatusCard.fromJson(Map<String, dynamic> json) =>
      DashboardStatusCard(
        title: (json['title'] ?? '').toString(),
        value: (json['value'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        code: (json['code'] ?? '').toString(),
      );
}

class DashboardTables {
  final DashboardTable expiring;
  final DashboardTable overdue;
  final DashboardTable withdrawal;

  const DashboardTables({
    this.expiring = const DashboardTable(),
    this.overdue = const DashboardTable(),
    this.withdrawal = const DashboardTable(),
  });

  factory DashboardTables.fromJson(Map<String, dynamic> json) =>
      DashboardTables(
        expiring: DashboardTable.fromJson(
          json['expiring'] is Map<String, dynamic>
              ? json['expiring'] as Map<String, dynamic>
              : const {},
        ),
        overdue: DashboardTable.fromJson(
          json['overdue'] is Map<String, dynamic>
              ? json['overdue'] as Map<String, dynamic>
              : const {},
        ),
        withdrawal: DashboardTable.fromJson(
          json['withdrawal'] is Map<String, dynamic>
              ? json['withdrawal'] as Map<String, dynamic>
              : const {},
        ),
      );
}

class DashboardTable {
  final String title;
  final String variant;
  final String infoText;
  final String emptyTitle;
  final String emptyDescription;
  final List<String> columns;
  final List<dynamic> rows;

  const DashboardTable({
    this.title = '',
    this.variant = '',
    this.infoText = '',
    this.emptyTitle = '',
    this.emptyDescription = '',
    this.columns = const [],
    this.rows = const [],
  });

  factory DashboardTable.fromJson(Map<String, dynamic> json) =>
      DashboardTable(
        title: (json['title'] ?? '').toString(),
        variant: (json['variant'] ?? '').toString(),
        infoText: (json['infoText'] ?? '').toString(),
        emptyTitle: (json['emptyTitle'] ?? '').toString(),
        emptyDescription: (json['emptyDescription'] ?? '').toString(),
        columns: (json['columns'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        rows: json['rows'] is List ? json['rows'] as List : const [],
      );
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
