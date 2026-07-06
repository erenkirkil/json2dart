import 'package:equatable/equatable.dart';

/// Kullanıcının üzerinde çalıştığı tek bir JSON belgesi (sekme / kayıt).
class JsonDocument extends Equatable {
  const JsonDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;

  /// Son değişiklik zamanı (ms since epoch) — kayıt listesini sıralamak için.
  final int updatedAt;

  JsonDocument copyWith({String? title, String? content, int? updatedAt}) {
    return JsonDocument(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'content': content,
    'updatedAt': updatedAt,
  };

  factory JsonDocument.fromJson(Map<String, dynamic> json) => JsonDocument(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Adsız',
    content: json['content'] as String? ?? '',
    updatedAt: json['updatedAt'] as int? ?? 0,
  );

  @override
  List<Object?> get props => [id, title, content, updatedAt];
}
