import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LibraryMetadata {
  const LibraryMetadata({
    required this.path,
    this.title,
    this.author,
    this.thumbnailUrl,
    this.source,
  });

  final String path;
  final String? title;
  final String? author;
  final String? thumbnailUrl;
  final String? source;

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'author': author,
        'thumbnailUrl': thumbnailUrl,
        'source': source,
      };

  factory LibraryMetadata.fromJson(Map<String, dynamic> json) {
    return LibraryMetadata(
      path: json['path'] as String,
      title: json['title'] as String?,
      author: json['author'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      source: json['source'] as String?,
    );
  }
}

class LibraryMetadataService {
  static const _key = 'library_metadata_v1';

  Future<Map<String, LibraryMetadata>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, LibraryMetadata>{};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final result = <String, LibraryMetadata>{};
      for (final item in list) {
        final meta = LibraryMetadata.fromJson(item as Map<String, dynamic>);
        result[meta.path] = meta;
      }
      return result;
    } catch (_) {
      return <String, LibraryMetadata>{};
    }
  }

  Future<void> saveAll(Map<String, LibraryMetadata> map) async {
    final prefs = await SharedPreferences.getInstance();
    final list = map.values.map((e) => e.toJson()).toList();
    await prefs.setString(_key, jsonEncode(list));
  }
}
