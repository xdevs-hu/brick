import 'dart:convert';
import 'package:brick_rest/src/rest_request.dart';
import 'package:meta/meta.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:brick_rest/rest_exception.dart';
import 'package:brick_rest/src/rest_model.dart';
import 'package:brick_rest/src/rest_model_dictionary.dart';
import 'package:brick_core/core.dart';

/// Retrieves from an HTTP endpoint
class RestProvider implements Provider<RestModel> {
  /// A fully-qualified URL
  final String baseEndpoint;

  /// The glue between app models and generated adapters.
  @override
  final RestModelDictionary modelDictionary;

  /// Headers supplied for every [get], [delete], and [upsert] call.
  Map<String, String>? defaultHeaders;

  /// All requests pass through this client.
  http.Client client;

  @protected
  final Logger logger;

  RestProvider(
    this.baseEndpoint, {
    required this.modelDictionary,
    http.Client? client,
  })  : client = client ?? http.Client(),
        logger = Logger('RestProvider');

  /// Sends a DELETE request method to the endpoint
  @override
  Future<http.Response?> delete<TModel extends RestModel>(instance, {query, repository}) async {
    final adapter = modelDictionary.adapterFor[TModel]!;
    final fromAdapter =
        adapter.restRequest != null ? adapter.restRequest!(query, instance).delete : null;
    final request = (query?.providerArgs['request'] as RestRequest?) ?? fromAdapter;

    final url = request?.url;
    if (url == null) return null;

    final resp = await _brickRequestToHttpRequest(
      request!,
      QueryAction.delete,
      query: query,
    );

    if (statusCodeIsSuccessful(resp.statusCode)) {
      return resp;
    } else {
      logger.warning('#delete: url=$url statusCode=${resp.statusCode} body=${resp.body}');
      throw RestException(resp);
    }
  }

  @override
  Future<bool> exists<TModel extends RestModel>({query, repository}) async {
    final adapter = modelDictionary.adapterFor[TModel]!;
    final fromAdapter = adapter.restRequest != null ? adapter.restRequest!(query, null).get : null;
    final request = (query?.providerArgs['request'] as RestRequest?) ?? fromAdapter;

    final url = request?.url;
    if (url == null) return false;

    final resp = await _brickRequestToHttpRequest(
      request!,
      QueryAction.get,
      query: query,
    );
    return statusCodeIsSuccessful(resp.statusCode);
  }

  /// [Query]'s `providerArgs` can extend the [get] functionality:
  /// * `'request'` (`RestRequest`) Specifies configurable information about the request like HTTP method or top level key
  /// (however, when defined, `['request'].topLevelKey` is prioritized). Note that when no key is defined, the first value is returned
  /// regardless of the first key (in the example, `{"id"...}`).
  @override
  Future<List<TModel>> get<TModel extends RestModel>({query, repository}) async {
    final adapter = modelDictionary.adapterFor[TModel]!;
    final fromAdapter = adapter.restRequest != null ? adapter.restRequest!(query, null).get : null;
    final request = (query?.providerArgs['request'] as RestRequest?) ?? fromAdapter;

    final url = request?.url;
    if (url == null) return <TModel>[];

    final resp = await _brickRequestToHttpRequest(
      request!,
      QueryAction.get,
      query: query,
    );

    if (statusCodeIsSuccessful(resp.statusCode)) {
      final topLevelKey = request.topLevelKey;
      final parsed = convertJsonFromGet(resp.body, topLevelKey);
      final body = parsed is Iterable ? parsed : [parsed];
      final results = body
          .where((msg) => msg != null)
          .map((msg) {
            return adapter.fromRest(msg, provider: this, repository: repository);
          })
          .toList()
          .cast<Future<TModel>>();

      return await Future.wait<TModel>(results);
    } else {
      logger.warning('#get: url=$url statusCode=${resp.statusCode} body=${resp.body}');
      throw RestException(resp);
    }
  }

  /// [Query]'s `providerArgs` can extend the [upsert] functionality:
  /// * `'request'` (`RestRequest`) Specifies configurable information about the request like HTTP method or top level key
  @override
  Future<http.Response?> upsert<TModel extends RestModel>(instance, {query, repository}) async {
    final adapter = modelDictionary.adapterFor[TModel]!;
    final body = await adapter.toRest(instance, provider: this, repository: repository);
    final fromAdapter =
        adapter.restRequest != null ? adapter.restRequest!(query, instance).upsert : null;
    final request = (query?.providerArgs['request'] as RestRequest?) ?? fromAdapter;

    final url = request?.url;
    if (url == null) return null;

    final combinedBody = <String, dynamic>{};

    final topLevelKey = request?.topLevelKey;
    if (topLevelKey != null) {
      combinedBody.addAll({topLevelKey: body});
    } else {
      combinedBody.addAll(body);
    }

    final resp = await _brickRequestToHttpRequest(
      request!,
      QueryAction.upsert,
      body: combinedBody,
      query: query,
    );

    logger.finest('#upsert: url=$url statusCode=${resp.statusCode} body=${resp.body}');

    if (statusCodeIsSuccessful(resp.statusCode)) {
      return resp;
    } else {
      logger.warning('#upsert: url=$url statusCode=${resp.statusCode} body=${resp.body}');
      throw RestException(resp);
    }
  }

  /// Expand a query into HTTP headers
  @protected
  Map<String, String> headersForQuery(Query? query, Map<String, String>? requestHeaders) {
    if ((query == null || query.providerArgs['request']?.headers == null) &&
        requestHeaders == null &&
        defaultHeaders != null) {
      return defaultHeaders!;
    }

    return {}
      ..addAll({'Content-Type': 'application/json'})
      ..addAll(defaultHeaders ?? <String, String>{})
      ..addAll(requestHeaders ?? <String, String>{})
      ..addAll(query?.providerArgs['request']?.headers ?? <String, String>{});
  }

  /// If a [key] is defined from the adapter and it is not null in the response, use it to narrow the response.
  /// Otherwise, if there is only one top level key, use it to narrow the response.
  /// Otherwise, return the payload.
  @visibleForOverriding
  dynamic convertJsonFromGet(String json, String? key) {
    final decoded = jsonDecode(json);
    if (key != null && decoded[key] != null) {
      return decoded[key];
    } else if (decoded is Map) {
      if (decoded.keys.length == 1) {
        return decoded.values.first;
      }
    }

    return decoded;
  }

  /// Sends serialized model data to an endpoint
  Future<http.Response> _brickRequestToHttpRequest(
    RestRequest request,
    QueryAction operation, {
    Query? query,
    Map<String, dynamic>? body,
  }) async {
    final combinedBody = body ?? {};
    final url = Uri.parse([baseEndpoint, request.url!].join(''));
    final method =
        (query?.providerArgs ?? {})['request']?.method ?? request.method ?? operation.httpMethod;
    final headers = headersForQuery(query, request.headers);

    logger.fine('$method $url');
    final methodLog = 'method=$method url=$url headers=$headers';
    if (operation == QueryAction.upsert) {
      logger.finer('$methodLog body=$body');
    } else {
      logger.finest(methodLog);
    }

    // if supplementalTopLevelData is specified it, insert alongside normal payload
    final topLevelData = (query?.providerArgs ?? {})['request']?.supplementalTopLevelData ??
        request.supplementalTopLevelData;
    if (topLevelData != null) {
      combinedBody.addAll(topLevelData);
    }

    final serializedBody = body == null && combinedBody.isEmpty ? null : jsonEncode(combinedBody);

    switch (method) {
      case 'DELETE':
        return await client.delete(url, headers: headers);
      case 'GET':
        return await client.get(url, headers: headers);
      case 'PATCH':
        return await client.patch(url, body: serializedBody, headers: headers);
      case 'POST':
        return await client.post(url, body: serializedBody, headers: headers);
      case 'PUT':
        return await client.put(url, body: serializedBody, headers: headers);
      default:
        throw StateError(
          "Request method $method is unhandled; use providerArgs['request'] or RestRequest#method",
        );
    }
  }

  static bool statusCodeIsSuccessful(int? statusCode) =>
      statusCode != null && 200 <= statusCode && statusCode < 300;
}

extension on QueryAction {
  String get httpMethod {
    switch (this) {
      case QueryAction.subscribe:
      case QueryAction.get:
        return 'GET';
      case QueryAction.insert:
      case QueryAction.update:
      case QueryAction.upsert:
        return 'POST';
      case QueryAction.delete:
        return 'DELETE';
    }
  }
}
