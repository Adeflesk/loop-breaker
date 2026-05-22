import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class ApiClient {
  static const String _baseUrl = kBackendBaseUrl;
  static http.Client? clientOverride;
  static final http.Client _defaultClient = http.Client();
  static const int _defaultTimeoutSeconds = 30;
  static const int _maxRetries = 3;

  // Per-endpoint timeout configuration (seconds)
  static const int _analyzeTimeoutSeconds = 90;        // AI processing
  static const int _historyTimeoutSeconds = 45;        // Potentially large dataset
  static const int _loopPathTimeoutSeconds = 60;       // Data analysis and processing
  static const int _defaultQuickTimeoutSeconds = 30;   // Most endpoints (insight, stats, feedback, etc)

  // Local cache for offline support
  static Map<String, dynamic> _cache = {};
  static Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 30);

  static http.Client get _httpClient => clientOverride ?? _defaultClient;

  static Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  /// Cache management: stores response with timestamp
  static void _setCached(String key, dynamic value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Retrieves cached data if it hasn't expired
  static dynamic _getCached(String key) {
    if (!_cache.containsKey(key)) return null;
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;

    final isExpired = DateTime.now().difference(timestamp) > _cacheExpiry;
    if (isExpired) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      return null;
    }
    return _cache[key];
  }

  /// Clears all cached data
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Wraps an HTTP request with retry logic and exponential backoff.
  /// Retries only on transient errors (5xx, timeouts, connection errors).
  /// Does not retry on client errors (4xx).
  static Future<T> _withRetry<T>(
    Future<T> Function() request, {
    int maxRetries = _maxRetries,
    int timeoutSeconds = _defaultTimeoutSeconds,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await request().timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () => throw TimeoutException('Request timeout'),
        );
      } on TimeoutException {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        await Future.delayed(
          Duration(milliseconds: 100 * (1 << (attempt - 1))), // Exponential backoff
        );
      } on SocketException {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        await Future.delayed(
          Duration(milliseconds: 100 * (1 << (attempt - 1))),
        );
      } on http.ClientException {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        await Future.delayed(
          Duration(milliseconds: 100 * (1 << (attempt - 1))),
        );
      }
    }
  }

  static Future<Map<String, dynamic>> analyzeEntry(String text) async {
    return _withRetry(
      () async {
        final response = await _httpClient.post(
          _uri('/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_text': text}),
        );

        if (response.statusCode != 200) {
          throw Exception('Analyze failed with status ${response.statusCode}');
        }

        return jsonDecode(response.body) as Map<String, dynamic>;
      },
      timeoutSeconds: _analyzeTimeoutSeconds,
    );
  }

  static Future<void> sendFeedback(
    bool success, {
    Map<String, bool>? needsCheck,
    String? chosenVariant,
  }) async {
    final payload = <String, dynamic>{'success': success};
    if (needsCheck != null) {
      payload['needs_check'] = needsCheck;
    }
    if (chosenVariant != null) {
      payload['chosen_variant'] = chosenVariant;
    }

    await _httpClient.post(
      _uri('/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
  }

  static Future<Map<String, dynamic>> fetchInsight() async {
    try {
      return await _withRetry(() async {
        final response = await _httpClient.get(_uri('/insight'));
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        throw Exception('Insight failed with status ${response.statusCode}');
      });
    } catch (e) {
      debugPrint("Insight fetch error: $e");
    }
    return {"message": "Welcome! Let's break some loops today."};
  }

  static Future<Map<String, dynamic>> fetchStats() async {
    try {
      return await _withRetry(() async {
        final response = await _httpClient.get(_uri('/stats'));
        if (response.statusCode == 200) {
          return jsonDecode(response.body) as Map<String, dynamic>;
        }
        throw Exception('Stats failed with status ${response.statusCode}');
      });
    } catch (e) {
      debugPrint("Stats fetch error: $e");
    }
    return {};
  }

  static Future<List<dynamic>> fetchHistory({bool useCache = true}) async {
    const String cacheKey = 'history';

    // Try to use cached data first
    if (useCache) {
      final cached = _getCached(cacheKey);
      if (cached != null && cached is List) {
        return cached;
      }
    }

    try {
      final data = await _withRetry(
        () async {
          final response = await _httpClient.get(_uri('/history'));
          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is List) {
              return decoded;
            }
          }
          throw Exception('History failed with status ${response.statusCode}');
        },
        timeoutSeconds: _historyTimeoutSeconds,
      );

      // Cache successful response
      _setCached(cacheKey, data);
      return data;
    } catch (e) {
      debugPrint("History fetch error: $e");
      // Try to return stale cache on error
      final staleCache = _cache[cacheKey];
      if (staleCache is List) {
        debugPrint("History: returning stale cache");
        return staleCache;
      }
    }
    return [];
  }

  static Future<bool> resetData() async {
    final response = await _httpClient.delete(_uri('/reset'));
    return response.statusCode == 200;
  }

  static Future<void> createThoughtRecord(Map<String, dynamic> data) async {
    return _withRetry(() async {
      final response = await _httpClient.post(
        _uri('/thought-record'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode != 201) {
        throw Exception('Thought record creation failed with status ${response.statusCode}');
      }
    });
  }

  static Future<List<dynamic>> fetchThoughtRecords({int limit = 20, int offset = 0}) async {
    try {
      return await _withRetry(() async {
        final response = await _httpClient.get(
          _uri('/thought-records?limit=$limit&offset=$offset'),
        );
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            return decoded;
          }
        }
        throw Exception('Thought records failed with status ${response.statusCode}');
      });
    } catch (e) {
      debugPrint('Thought records fetch error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> getLoopPath({int days = 30}) async {
    try {
      return await _withRetry(
        () async {
          final response = await _httpClient.get(_uri('/loop-path?days=$days'));
          if (response.statusCode == 200) {
            return jsonDecode(response.body) as Map<String, dynamic>;
          }
          throw Exception('Loop path failed with status ${response.statusCode}');
        },
        timeoutSeconds: _loopPathTimeoutSeconds,
      );
    } catch (e) {
      debugPrint("Loop path fetch error: $e");
    }
    return {"path": [], "analysis": {}};
  }

  static Future<List<dynamic>> fetchJournalEntries({int limit = 50}) async {
    try {
      return await _withRetry(() async {
        final response = await _httpClient.get(_uri('/journal-entries?limit=$limit'));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            return decoded;
          }
        }
        throw Exception('Journal entries failed with status ${response.statusCode}');
      });
    } catch (e) {
      debugPrint('Journal entries fetch error: $e');
    }
    return [];
  }

  static Future<void> recordJournalOutcome(
    String entryId,
    String outcome, {
    String? notes,
  }) async {
    try {
      return await _withRetry(() async {
        final response = await _httpClient.patch(
          _uri('/journal-entries/$entryId/outcome'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'outcome': outcome, 'notes': notes}),
        );
        if (response.statusCode != 200) {
          throw Exception('Journal outcome failed with status ${response.statusCode}');
        }
      });
    } catch (e) {
      debugPrint('Journal outcome error: $e');
    }
  }
}

