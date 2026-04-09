import 'dart:convert';

class PageInfo {
  final int? total;
  final int? page;
  final int? pages;

  PageInfo({this.total, this.page, this.pages});

  PageInfo copyWith({int? total, int? page, int? pages}) => PageInfo(
    total: total ?? this.total,
    page: page ?? this.page,
    pages: pages ?? this.pages,
  );

  factory PageInfo.fromRawJson(String str) =>
      PageInfo.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PageInfo.fromJson(Map<String, dynamic> json) => PageInfo(
    total: int.tryParse(json["total"] ?? ""),
    page: json["page"],
    pages: json["pages"],
  );

  Map<String, dynamic> toJson() => {
    "total": total,
    "page": page,
    "pages": pages,
  };
}
