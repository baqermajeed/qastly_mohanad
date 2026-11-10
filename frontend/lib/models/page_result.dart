class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.pages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int pages;

  bool get hasNext => page < pages;
  bool get hasPrev => page > 1;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) mapItem,
  ) {
    final raw = json['items'] as List<dynamic>? ?? const [];
    return PageResult<T>(
      items: raw
          .map((e) => mapItem(e as Map<String, dynamic>))
          .toList(growable: false),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
      pages: json['pages'] as int? ?? 0,
    );
  }

  factory PageResult.empty({int page = 1, int pageSize = 20}) {
    return PageResult<T>(
      items: const [],
      total: 0,
      page: page,
      pageSize: pageSize,
      pages: 0,
    );
  }

  PageResult<T> appended(PageResult<T> next) {
    return PageResult<T>(
      items: [...items, ...next.items],
      total: next.total,
      page: next.page,
      pageSize: next.pageSize,
      pages: next.pages,
    );
  }
}
