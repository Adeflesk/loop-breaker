import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class ApiClient {
  static const String _baseUrl = kBackendBaseUrl;

  static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  static Future<Map<String, dynamic>> analyzeEntry(String text) async {
    final response = await http.post(
      _uri('/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_text': text}),
    );

    if (response.statusCode != 200) {
      throw Exception('Analyze failed with status ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> sendFeedback(
    bool success, {
    Map<String, bool>? needsCheck,
  }) async {
    final payload = <String, dynamic>{'success': success};
    if (needsCheck != null) {
      payload['needs_check'] = needsCheck;
    }

    await http.post(
      _uri('/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
  }

  static Future<Map<String, dynamic>> fetchInsight() async {
    try {
      final response = await http.get(_uri('/insight'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Insight fetch error: $e");
    }
    return {"message": "Welcome! Let's break some loops today."};
  }

  static Future<Map<String, dynamic>> fetchStats() async {
    try {
      final response = await http.get(_uri('/stats'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Stats fetch error: $e");
    }
    return {};
  }

  static Future<List<dynamic>> fetchHistory() async {
    try {
      final response = await http.get(_uri('/history'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded;
        }
      }
    } catch (_) {
      // Swallow and fall through to empty list, matching previous behavior.
    }
    return [];
  }

  static Future<bool> resetData() async {
    final response = await http.delete(_uri('/reset'));
    return response.statusCode == 200;
  }
}

