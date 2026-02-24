import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_amount_format.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/utils/proxy_socket/abstract.dart';
import 'package:cw_core/utils/proxy_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

enum ConnectionStatus { connected, disconnected, connecting, failed }

String jsonrpcparams(List<Object> params) {
  final _params = params.map((val) => '"${val.toString()}"').join(',');
  return '[$_params]';
}

String jsonrpc(
    {required String method, required List<Object> params, required int id, double version = 2.0}) {
  return '{"jsonrpc": "$version", "method": "$method", "id": "$id",  "params": ${json.encode(params)}}\n';
}

class SocketTask {
  SocketTask({required this.isSubscription, this.completer, this.subject});

  final Completer<dynamic>? completer;
  final BehaviorSubject<dynamic>? subject;
  final bool isSubscription;
}

class ElectrumClient {
  ElectrumClient()
      : _id = 0,
        _tasks = {},
        _errors = {},
        unterminatedString = '',
        _isolateId = 0,
        _isolateTasks = {},
        _isolateErrors = {},
        isolateUnterminatedString = '';

  static const connectionTimeout = Duration(seconds: 30); // increased for slower nodes/Tor
  static const aliveTimerDuration =
      Duration(seconds: 20); // aligns better with Fulcrum's 2s polling of bitcoind

  bool get isConnected => socket != null && socket?.isClosed == false;
  ProxySocket? socket;
  ProxySocket? isolateSocket;
  void Function(ConnectionStatus)? onConnectionStatusChange;
  int _id;
  final Map<String, SocketTask> _tasks;
  Map<String, SocketTask> get tasks => _tasks;
  final Map<String, String> _errors;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  Timer? _aliveTimer;
  String unterminatedString;

  // Separate state management for isolate socket
  int _isolateId;
  final Map<String, SocketTask> _isolateTasks;
  final Map<String, String> _isolateErrors;
  String isolateUnterminatedString;
  Timer? _isolateAliveTimer;

  Uri? uri;
  bool? useSSL;

  Future<void> connectToUri(Uri uri, {bool? useSSL, bool? isolateRequest}) async {
    this.uri = uri;
    if (useSSL != null) {
      this.useSSL = useSSL;
    }
    // Use isolateConnect if this is an isolate request
    if (isolateRequest == true) {
      await isolateConnect(host: uri.host, port: uri.port);
    } else {
      await connect(host: uri.host, port: uri.port);
    }
  }

  Future<void> isolateConnect({required String host, required int port}) async {
    // _setConnectionStatus(ConnectionStatus.connecting);

    // Reset internal state to ensure clean connection
    // _resetInternalState();

    // try {
    //   await socket?.close();
    // } catch (_) {}
    // socket = null;

    final ssl = !(useSSL == false || (useSSL == null && uri.toString().contains("btc-electrum")));
    try {
      isolateSocket = await ProxyWrapper()
          .getSocksSocket(ssl, host, port, connectionTimeout: connectionTimeout);
    } catch (e) {
      printV("isolate connect: $e");
      if (e is HandshakeException) {
        useSSL = !(useSSL ?? false);
      }

      // The TCP stack should be deferred to, here (this is not a primary connection)
      // if (_connectionStatus != ConnectionStatus.connecting) {
      //   _setConnectionStatus(ConnectionStatus.failed);
      // }

      return;
    }

    if (isolateSocket == null) {
      // if (_connectionStatus != ConnectionStatus.connecting) {
      //   _setConnectionStatus(ConnectionStatus.failed);
      // }

      return;
    }

    // use ping to determine actual connection status since we could've just not timed out yet:
    // _setConnectionStatus(ConnectionStatus.connected);
    isolateSocket!.listen(
      (Uint8List event) {
        try {
          final msg = utf8.decode(event.toList());
          final messagesList = msg.split("\n");
          for (var message in messagesList) {
            // For some reason, the existing code will serve up garbage whitespace
            // Skip empty messages or messages with only whitespace/control chars
            message = message.trim();
            if (message.isEmpty || message.replaceAll(RegExp(r'[\s\x00-\x1F\x7F]'), '').isEmpty) {
              continue;
            }
            _parseIsolate(message);
          }
        } catch (e) {
          printV("isolateSocket.listen: $e");
        }
      },
      onError: (Object error) {
        printV("Isolate error: $error");
        _isolateAliveTimer?.cancel();
        _isolateAliveTimer = null;
        isolateUnterminatedString = '';
        _failAllPendingIsolateTasks(error.toString());
        // Socket will be destroyed in closeIsolateBatch()
      },
      onDone: () {
        printV("Isolate socket: Close on done");
        _isolateAliveTimer?.cancel();
        _isolateAliveTimer = null;
        isolateUnterminatedString = '';
        _failAllPendingIsolateTasks("Isolate connection closed");
        // Socket will be destroyed in closeIsolateBatch()
      },
      cancelOnError: false,
    );

    isolateKeepAlive();
  }

  Future<void> connect({required String host, required int port}) async {
    _setConnectionStatus(ConnectionStatus.connecting);

    // Reset internal state to ensure clean connection
    _resetInternalState();

    try {
      await socket?.close();
    } catch (_) {}
    socket = null;

    final ssl = !(useSSL == false || (useSSL == null && uri.toString().contains("btc-electrum")));
    try {
      socket = await ProxyWrapper()
          .getSocksSocket(ssl, host, port, connectionTimeout: connectionTimeout);
    } catch (e) {
      printV("connect: $e");
      if (e is HandshakeException) {
        useSSL = !(useSSL ?? false);
      }

      if (_connectionStatus != ConnectionStatus.connecting) {
        _setConnectionStatus(ConnectionStatus.failed);
      }

      return;
    }

    if (socket == null) {
      if (_connectionStatus != ConnectionStatus.connecting) {
        _setConnectionStatus(ConnectionStatus.failed);
      }

      return;
    }

    // use ping to determine actual connection status since we could've just not timed out yet:
    // _setConnectionStatus(ConnectionStatus.connected);
    socket!.listen(
      (Uint8List event) {
        try {
          final msg = utf8.decode(event.toList());
          final messagesList = msg.split("\n");
          for (var message in messagesList) {
            // For some reason, the existing code will serve up garbage whitespace
            // Skip empty messages or messages with only whitespace/control chars
            message = message.trim();
            if (message.isEmpty || message.replaceAll(RegExp(r'[\s\x00-\x1F\x7F]'), '').isEmpty) {
              continue;
            }
            _parseResponse(message);
          }
        } catch (e) {
          printV("socket.listen: $e");
        }
      },
      onError: (Object error) {
        final errorMsg = error.toString();
        printV(errorMsg);
        unterminatedString = '';
        socket?.destroy();
        socket = null;
        _setConnectionStatus(ConnectionStatus.disconnected);
        _failAllPendingTasks(errorMsg);
      },
      onDone: () {
        printV("SOCKET CLOSED");
        unterminatedString = '';
        try {
          _setConnectionStatus(ConnectionStatus.disconnected);
          socket?.destroy();
          socket = null;
          _failAllPendingTasks("Connection closed");
        } catch (e) {
          printV("onDone: $e");
        }
      },
      cancelOnError: true,
    );

    keepAlive();
  }

  void _parseIsolate(String message) {
    try {
      final decoded = json.decode(message);

      if (decoded is List) {
        printV(
            "Isolate batch response (first 500 chars): ${message.substring(0, message.length > 500 ? 500 : message.length)}");
        _batchHandleIsolateResponse(decoded);
      } else if (decoded is Map<String, dynamic>) {
        printV(message);
        _handleIsolateResponse(decoded);
      }
    } on FormatException catch (e) {
      developer.log(
          "!!!!! Isolate Node communication possibly broke !!!!!: FormatException in _parseIsolate: $e");
      final msg = e.message.toLowerCase();

      if (e.source is String) {
        isolateUnterminatedString += e.source as String;
      }

      if (msg.contains("not a subtype of type")) {
        isolateUnterminatedString += e.source as String;
        return;
      }

      if (isJSONStringCorrect(isolateUnterminatedString)) {
        final decoded = json.decode(isolateUnterminatedString);

        if (decoded is List) {
          printV(
              "Isolate batch response (first 500 chars): ${isolateUnterminatedString.substring(0, isolateUnterminatedString.length > 500 ? 500 : isolateUnterminatedString.length)}");
          _batchHandleIsolateResponse(decoded);
        } else if (decoded is Map<String, dynamic>) {
          printV(isolateUnterminatedString);
          _handleIsolateResponse(decoded);
        }
        isolateUnterminatedString = '';
      }
    } on TypeError catch (e) {
      if (!e.toString().contains('Map<String, Object>') &&
          !e.toString().contains('Map<String, dynamic>')) {
        return;
      }

      isolateUnterminatedString += message;

      if (isJSONStringCorrect(isolateUnterminatedString)) {
        final decoded = json.decode(isolateUnterminatedString);

        if (decoded is List) {
          printV(
              "Isolate batch response (first 500 chars): ${isolateUnterminatedString.substring(0, isolateUnterminatedString.length > 500 ? 500 : isolateUnterminatedString.length)}");
          _batchHandleIsolateResponse(decoded);
        } else if (decoded is Map<String, dynamic>) {
          printV(isolateUnterminatedString);
          printV("handle isolateResponse: $decoded");
          _handleIsolateResponse(decoded);
          printV("handle isolateResponse: $decoded");
        }
        isolateUnterminatedString = '';
      }
    } catch (e) {
      printV("!!!!! ISOLATE NODE COMMUNICATION REALLY BROKE !!!!!: Exception in _parseIsolate: $e");
    }
  }

  void _parseResponse(String message) {
    try {
      final decoded = json.decode(message);
      // KB: TODO: verify if this functionality is working as intended
      // Check if it's a batch response (array) or single response (map)

      if (decoded is List) {
        printV(
            "Batch response (first 500 chars): ${message.substring(0, message.length > 500 ? 500 : message.length)}");
        _batchHandleResponse(decoded);
      } else if (decoded is Map<String, dynamic>) {
        printV(message);
        _handleResponse(decoded);
      }
    } on FormatException catch (e) {
      // Just so we notice issues identifying batches versus single responses
      developer.log(
          "!!!!! Node communication possibly broke !!!!!: FormatException in _parseResponse: $e");
      final msg = e.message.toLowerCase();
      printV("The failure reason: $msg");

      if (e.source is String) {
        unterminatedString += e.source as String;
      }

      if (msg.contains("not a subtype of type")) {
        unterminatedString += e.source as String;
        return;
      }

      if (isJSONStringCorrect(unterminatedString)) {
        final decoded = json.decode(unterminatedString);

        if (decoded is List) {
          printV(
              "Batch response (first 500 chars): ${unterminatedString.substring(0, unterminatedString.length > 500 ? 500 : unterminatedString.length)}");
          _batchHandleResponse(decoded);
        } else if (decoded is Map<String, dynamic>) {
          printV(unterminatedString);
          _handleResponse(decoded);
        }
        unterminatedString = '';
      }
    } on TypeError catch (e) {
      if (!e.toString().contains('Map<String, Object>') &&
          !e.toString().contains('Map<String, dynamic>')) {
        return;
      }

      unterminatedString += message;

      if (isJSONStringCorrect(unterminatedString)) {
        final decoded = json.decode(unterminatedString);

        if (decoded is List) {
          printV(
              "Batch response (first 500 chars): ${unterminatedString.substring(0, unterminatedString.length > 500 ? 500 : unterminatedString.length)}");
          _batchHandleResponse(decoded);
        } else if (decoded is Map<String, dynamic>) {
          printV(unterminatedString);
          _handleResponse(decoded);
        }
        unterminatedString = '';
      }
    } catch (e) {
      // Just so we notice issues identifying batches versus single responses
      printV("!!!!! NODE COMMUNICATION REALLY BROKE !!!!!: Exception in _parseResponse: $e");
    }
  }

  // TODO: verify batchHandleResponse works with transactions
  void _batchHandleResponse(List<dynamic> batchResponse) {
    printV("Handling batch response with ${batchResponse.length} items");
    // Match the batch response to the correct task by finding the first ID in the response
    if (_tasks.isNotEmpty && batchResponse.isNotEmpty) {
      // Get the first ID from the batch response
      int? firstResponseId;
      if (batchResponse.first is Map<String, dynamic>) {
        firstResponseId = batchResponse.first['id'] as int?;
      }

      if (firstResponseId != null) {
        // Find the task that matches this batch (registered with the first ID)
        final taskId = firstResponseId.toString();
        if (_tasks.containsKey(taskId)) {
          _finish(taskId, batchResponse);
        } else {
          printV("WARNING: No task found for batch response starting with ID $firstResponseId");
        }
      }
    }
  }

  void _batchHandleIsolateResponse(List<dynamic> batchResponse) {
    printV("Handling isolate batch response with ${batchResponse.length} items");
    // Match the batch response to the correct task by finding the first ID in the response
    if (_isolateTasks.isNotEmpty && batchResponse.isNotEmpty) {
      // Get the first ID from the batch response
      int? firstResponseId;
      if (batchResponse.first is Map<String, dynamic>) {
        firstResponseId = batchResponse.first['id'] as int?;
      }

      if (firstResponseId != null) {
        // Find the task that matches this batch (registered with the first ID)
        final taskId = firstResponseId.toString();
        if (_isolateTasks.containsKey(taskId)) {
          _finishIsolate(taskId, batchResponse);
        } else {
          printV("WARNING: No task found for batch response starting with ID $firstResponseId");
        }
      }
    }
  }

  void keepAlive() {
    _aliveTimer?.cancel();
    _aliveTimer = Timer.periodic(aliveTimerDuration, (_) async => ping());
  }

  void isolateKeepAlive() {
    _isolateAliveTimer?.cancel();
    _isolateAliveTimer = Timer.periodic(aliveTimerDuration, (_) async => await isolatePing());
  }

  Future<void> ping() async {
    try {
      await callWithTimeout(method: 'server.ping');
      _setConnectionStatus(ConnectionStatus.connected);
    } catch (_) {
      _setConnectionStatus(ConnectionStatus.disconnected);
    }
  }

  Future<void> isolatePing() async {
    if (isolateSocket == null) return;
    try {
      _isolateId += 1;
      final id = _isolateId;
      final completer = Completer<dynamic>();
      _registryIsolateTask(id, completer);
      isolateSocket!.write(jsonrpc(method: 'server.ping', id: id, params: []));

      await completer.future.timeout(Duration(seconds: 5));
    } catch (e) {
      printV("isolatePing error: $e");
    }
  }

  Future<List<String>> version() =>
      call(method: 'server.version', params: ["", "1.4"]).then((dynamic result) {
        if (result is List) {
          return result.map((dynamic val) => val.toString()).toList();
        }

        return [];
      });

  // Will need to write a batch version of this method
  Future<Map<String, dynamic>> getBalance(String scriptHash, {bool throwOnError = false}) async {
    try {
      final result = await call(method: 'blockchain.scripthash.get_balance', params: [scriptHash]);
      if (result is Map<String, dynamic>) {
        return result;
      }

      if (throwOnError) {
        throw Exception('Invalid response format for getBalance');
      }

      return <String, dynamic>{};
    } catch (e) {
      if (throwOnError) {
        rethrow;
      }
      return <String, dynamic>{};
    }
  }

  // This function is designed for when we invoke multiple of the same method with different scriptHashes
  // It takes responsibility for also re-ordering the results deterministically
  // It will never get invoked when a connection does not exist
  // Future<Map<String, Map<String, dynamic>>> batchGetData(
  Future<dynamic> batchGetData(List<String> scriptHashes, String method) async {
    if (scriptHashes.isEmpty) {
      return {};
    }

    try {
      // Increment _id first to get base ID for this batch
      _id += 1;
      final baseId = _id;

      // Build batch request payload with unique IDs
      final List<Map<String, dynamic>> batchRequest = [];
      for (int i = 0; i < scriptHashes.length; i++) {
        batchRequest.add({
          'jsonrpc': '2.0',
          'id': baseId + i,
          'method': method,
          'params': [scriptHashes[i]],
        });
      }

      // Update _id to account for all batch items
      _id = baseId + scriptHashes.length - 1;

      final batchRequestJson = json.encode(batchRequest);
      // printV('batchGetData: Batch request JSON: $batchRequestJson');
      // printV(
      //     'batchGetData: substring last 100 characters: ${batchRequestJson.substring(batchRequestJson.length - 100)}');
      // Send batch request
      // if (!isConnected) {
      //   throw Exception('Not connected to Electrum server');
      // }

      final completer = Completer<dynamic>();
      final requestId = baseId;
      _registryTask(requestId, completer);

      // Write the batch request directly to socket
      socket!.write(batchRequestJson + '\n');
      printV('batchGetData: Batch request sent with ID: $requestId');

      final response = await completer.future;
      // printV('batchGetData: Server response received: $response');
      // printV(
      //     'batchGetData: substring last 100 characters of response: ${response.toString().substring(response.toString().length - 100)}');
      // Response is to be handled by method that invokes this method (so not in here)
      final jsonSortedList = response as List<dynamic>;
      // Sort by id field
      jsonSortedList.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          final aId = a['id'] as int? ?? 0;
          final bId = b['id'] as int? ?? 0;
          return aId.compareTo(bId);
        }
        return 0;
      });

      return jsonSortedList;
    } catch (e) {
      printV('batchGetData error: $e');
      return {};
    }
  }

  Future<dynamic> isolateGetData(List<String> scriptHashes, String method) async {
    if (scriptHashes.isEmpty) {
      return {};
    }

    try {
      // Increment _isolateId first to get base ID for this batch
      _isolateId += 1;
      final baseId = _isolateId;

      // Build batch request payload with unique IDs
      final List<Map<String, dynamic>> batchRequest = [];
      for (int i = 0; i < scriptHashes.length; i++) {
        // Add height parameters for get_history calls (BCH Electrum protocol)
        final params = method == 'blockchain.scripthash.get_history'
            ? [scriptHashes[i], 930000, -1]
            : [scriptHashes[i]];

        batchRequest.add({
          'jsonrpc': '2.0',
          'id': baseId + i,
          'method': method,
          'params': params,
        });
      }

      // Update _isolateId to account for all batch items
      _isolateId = baseId + scriptHashes.length - 1;

      final batchRequestJson = json.encode(batchRequest);
      printV('isolateGetData: Batch request JSON: $batchRequestJson');
      printV(
          'isolateGetData: substring last 100 characters: ${batchRequestJson.substring(batchRequestJson.length - 100)}');

      // Send batch request via isolate socket
      // if (isolateSocket == null) {
      //   throw Exception('Isolate socket not connected');
      // }

      final completer = Completer<dynamic>();
      final requestId = baseId;
      _registryIsolateTask(requestId, completer);

      // Write the batch request directly to isolate socket
      isolateSocket!.write(batchRequestJson + '\n');
      printV('isolateGetData: Batch request sent with ID: $requestId');

      final response = await completer.future.timeout(
        Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Isolate batch request timed out after 60 seconds');
        },
      );

      printV(
          'isolateGetData: substring last 100 characters of response: ${response.toString().substring(response.toString().length - 100)}');

      // Response is already decoded by _batchHandleIsolateResponse

      final jsonSortedList = response as List<dynamic>;
      printV("Batch response came back");
      // Sort by id field
      // return jsonSortedList;
      jsonSortedList.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          final aId = a['id'] as int? ?? 0;
          final bId = b['id'] as int? ?? 0;
          return aId.compareTo(bId);
        }
        return 0;
      });

      // Doge: [{jsonrpc: 2.0, result: {confirmed: 4387611546, unconfirmed: 0}, id: 1}, {jsonrpc: 2.0, result: {confirmed: 0, unconfirmed: 0}, id: 2}, {jsonrpc: 2.0, result: {confirmed: 0, unconfirmed: 0}, id: 3}, {jsonrpc: 2.0, result: {confirmed: 0, unconfirmed: 0}, id: 4}, {jsonrpc: 2.0, result: {confirmed: 0, unconfirmed: 0}, id: 5}, {jsonrpc: 2.0, result: {confirmed: 0, unconfirmed: 0}, id: 6}, {jsonrpc: 2.0, result: {confirmed: 0, unconfirmed: 0}, id: 7}, {jsonrpc: 2.0, result: {confirmed: 0, unconfirmed: 0}, id: 8}

      return jsonSortedList;
    } catch (e) {
      printV('isolateGetData error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getHistory(String scriptHash) => call(
        method: 'blockchain.scripthash.get_history',
        params: [scriptHash],
      ).then((dynamic result) {
        if (result is List) {
          return result.map((dynamic val) {
            if (val is Map<String, dynamic>) {
              return val;
            }

            return <String, dynamic>{};
          }).toList();
        }

        return [];
      });

  Future<Map<String, List<Map<String, dynamic>>>> batchGetHistory(List<String> scriptHashes) async {
    if (scriptHashes.isEmpty) {
      return {};
    }

    try {
      // Build batch request payload
      // https://electrum-cash-protocol.readthedocs.io/en/latest/protocol-methods.html
      // blockchain.scripthash.get_history(scripthash, from_height=0, to_height=-1)
      final List<Map<String, dynamic>> batchRequest = [];
      for (int i = 0; i < scriptHashes.length; i++) {
        batchRequest.add({
          'jsonrpc': '2.0',
          'id': i + 1,
          'method': 'blockchain.scripthash.get_history',
          'params': [scriptHashes[i], 930000, -1],
        });
      }

      final batchRequestJson = json.encode(batchRequest);
      printV('batchGetHistory: Batch request JSON: $batchRequestJson');

      // Send batch request
      if (!isConnected) {
        throw Exception('Not connected to Electrum server');
      }

      final completer = Completer<dynamic>();
      _id += 1;
      final requestId = _id;
      _registryTask(requestId, completer);

      // Write the batch request directly to socket
      socket!.write(batchRequestJson + '\n');
      printV('batchGetHistory: Batch request sent with ID: $requestId');

      final response = await completer.future;

      // Response is already decoded by _batchHandleResponse
      final jsonSortedList = response as List<dynamic>;
      // Sort by id field
      jsonSortedList.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          final aId = a['id'] as int? ?? 0;
          final bId = b['id'] as int? ?? 0;
          return aId.compareTo(bId);
        }
        return 0;
      });

      // Map results back to scriptHashes
      final Map<String, List<Map<String, dynamic>>> resultMap = {};
      for (int i = 0; i < scriptHashes.length && i < jsonSortedList.length; i++) {
        final item = jsonSortedList[i];
        if (item is Map<String, dynamic>) {
          final result = item['result'];
          if (result is List) {
            resultMap[scriptHashes[i]] = result.map((dynamic val) {
              if (val is Map<String, dynamic>) {
                return val;
              }
              return <String, dynamic>{};
            }).toList();
          } else {
            resultMap[scriptHashes[i]] = [];
          }
        }
      }

      return resultMap;
    } catch (e) {
      printV('batchGetHistory error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>?> getListUnspent(String scriptHash) async {
    printV("KB: Here?");
    final result = await call(method: 'blockchain.scripthash.listunspent', params: [scriptHash]);

    if (result is List) {
      return result.map((dynamic val) {
        if (val is Map<String, dynamic>) {
          return val;
        }

        return <String, dynamic>{};
      }).toList();
    }

    return null;
  }

  Future<dynamic> batchGetListUnspent(List<String> scriptHashes) async {}

  Future<List<Map<String, dynamic>>> getMempool(String scriptHash) =>
      call(method: 'blockchain.scripthash.get_mempool', params: [scriptHash])
          .then((dynamic result) {
        if (result is List) {
          return result.map((dynamic val) {
            if (val is Map<String, dynamic>) {
              return val;
            }

            return <String, dynamic>{};
          }).toList();
        }

        return [];
      });

  Future<dynamic> getTransaction({required String hash, required bool verbose}) async {
    try {
      final result = await callWithTimeout(
          method: 'blockchain.transaction.get', params: [hash, verbose], timeout: 10000);
      return result;
    } on RequestFailedTimeoutException catch (_) {
      return <String, dynamic>{};
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> getTransactionVerbose({required String hash}) =>
      getTransaction(hash: hash, verbose: true).then((dynamic result) {
        if (result is Map<String, dynamic>) {
          return result;
        }

        return <String, dynamic>{};
      });

  Future<String> getTransactionHex({required String hash}) =>
      getTransaction(hash: hash, verbose: false).then((dynamic result) {
        if (result is String) {
          return result;
        }

        return '';
      });

  Future<String> broadcastTransaction(
          {required String transactionRaw,
          BasedUtxoNetwork? network,
          Function(int)? idCallback}) async =>
      call(
              method: 'blockchain.transaction.broadcast',
              params: [transactionRaw],
              idCallback: idCallback)
          .then((dynamic result) {
        if (result is String) {
          return result;
        }

        return '';
      });

  Future<Map<String, dynamic>> getMerkle({required String hash, required int height}) async =>
      await call(method: 'blockchain.transaction.get_merkle', params: [hash, height])
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> getHeader({required int height}) async =>
      await call(method: 'blockchain.block.get_header', params: [height]) as Map<String, dynamic>;

  BehaviorSubject<Object>? tweaksSubscribe({required int height, required int count}) {
    return subscribe<Object>(
      id: 'blockchain.tweaks.subscribe',
      method: 'blockchain.tweaks.subscribe',
      params: [height, count, false],
    );
  }

  Future<dynamic> getTweaks({required int height}) async =>
      await callWithTimeout(method: 'blockchain.tweaks.subscribe', params: [height, 1, false]);

  Future<double> estimatefee({required int p}) =>
      call(method: 'blockchain.estimatefee', params: [p]).then((dynamic result) {
        if (result is double) {
          return result;
        }

        if (result is String) {
          return double.parse(result);
        }

        return 0;
      });

  Future<List<List<int>>> feeHistogram() =>
      call(method: 'mempool.get_fee_histogram').then((dynamic result) {
        if (result is List) {
          // return result.map((dynamic e) {
          //   if (e is List) {
          //     return e.map((dynamic ee) => ee is int ? ee : null).toList();
          //   }

          //   return null;
          // }).toList();
          final histogram = <List<int>>[];
          for (final e in result) {
            if (e is List) {
              final eee = <int>[];
              for (final ee in e) {
                if (ee is int) {
                  eee.add(ee);
                }
              }
              histogram.add(eee);
            }
          }
          return histogram;
        }

        return [];
      });

  Future<List<int>> feeRates({BasedUtxoNetwork? network}) async {
    try {
      final topDoubleString = await estimatefee(p: 1);
      final middleDoubleString = await estimatefee(p: 5);
      final bottomDoubleString = await estimatefee(p: 10);
      final top = (stringDoubleToBitcoinAmount(topDoubleString.toString()) / 1000).round();
      final middle = (stringDoubleToBitcoinAmount(middleDoubleString.toString()) / 1000).round();
      final bottom = (stringDoubleToBitcoinAmount(bottomDoubleString.toString()) / 1000).round();

      return [bottom, middle, top];
    } catch (_) {
      return [];
    }
  }

  // https://electrumx.readthedocs.io/en/latest/protocol-methods.html#blockchain-headers-subscribe
  // example response:
  // {
  //   "height": 520481,
  //   "hex": "00000020890208a0ae3a3892aa047c5468725846577cfcd9b512b50000000000000000005dc2b02f2d297a9064ee103036c14d678f9afc7e3d9409cf53fd58b82e938e8ecbeca05a2d2103188ce804c4"
  // }

  Future<int?> getCurrentBlockChainTip() async {
    try {
      final result = await callWithTimeout(method: 'blockchain.headers.subscribe');
      if (result is Map<String, dynamic>) {
        return result["height"] as int;
      }
      return null;
    } on RequestFailedTimeoutException catch (_) {
      return null;
    } catch (e) {
      printV("getCurrentBlockChainTip: ${e.toString()}");
      return null;
    }
  }

  BehaviorSubject<Object>? chainTipSubscribe() {
    _id += 1;
    return subscribe<Object>(
        id: 'blockchain.headers.subscribe', method: 'blockchain.headers.subscribe');
  }

  BehaviorSubject<Object>? scripthashUpdate(String scripthash) {
    _id += 1;
    return subscribe<Object>(
        id: 'blockchain.scripthash.subscribe:$scripthash',
        method: 'blockchain.scripthash.subscribe',
        params: [scripthash]);
  }

  BehaviorSubject<T>? subscribe<T>(
      {required String id, required String method, List<Object> params = const []}) {
    try {
      if (socket == null) {
        return null;
      }
      final subscription = BehaviorSubject<T>();
      _regisrySubscription(id, subscription);
      socket!.write(jsonrpc(method: method, id: _id, params: params));

      return subscription;
    } catch (e) {
      printV("subscribe $e");
      return null;
    }
  }

  Future<dynamic> call(
      {required String method, List<Object> params = const [], Function(int)? idCallback}) async {
    if (!isConnected) return null;
    printV("call $method");
    final completer = Completer<dynamic>();
    _id += 1;
    final id = _id;
    idCallback?.call(id);
    _registryTask(id, completer);
    socket!.write(jsonrpc(method: method, id: id, params: params));

    return completer.future;
  }

  Future<dynamic> callWithTimeout(
      {required String method, List<Object> params = const [], int timeout = 5000}) async {
    try {
      if (!isConnected) return null;

      final completer = Completer<dynamic>();
      _id += 1;
      final id = _id;
      _registryTask(id, completer);
      socket!.write(jsonrpc(method: method, id: id, params: params));
      Timer(Duration(milliseconds: timeout), () {
        if (!completer.isCompleted) {
          completer.completeError(RequestFailedTimeoutException(method, id));
        }
      });

      return completer.future;
    } catch (e) {
      printV("callWithTimeout $e");
      rethrow;
    }
  }

  Future<void> close() async {
    _aliveTimer?.cancel();
    try {
      await socket?.close();
      socket = null;
    } catch (_) {}
    onConnectionStatusChange = null;
    // Reset internal state when closing
    _resetInternalStateCompletely();
  }

  Future<void> closeIsolateBatch() async {
    _isolateAliveTimer?.cancel();
    _isolateAliveTimer = null;

    // Complete any pending tasks with timeout error before clearing
    for (final task in _isolateTasks.values) {
      if (task.completer != null && !task.completer!.isCompleted) {
        task.completer!.completeError(Exception('Socket closed before response received'));
      }
    }

    try {
      await isolateSocket?.close();
      isolateSocket = null;
    } catch (e) {
      printV(e.toString());
    }

    // Reset isolate-specific state
    _isolateId = 0;
    _isolateTasks.clear();
    _isolateErrors.clear();
    isolateUnterminatedString = '';
  }

  void _resetInternalState() {
    // Only clears errors and unterminated string, leaves tasks or reset ID
    // This preserves active subscriptions while clearing error state
    _errors.clear();
    unterminatedString = '';
  }

  void _resetInternalStateCompletely() {
    _id = 0;
    _tasks.clear();
    _errors.clear();
    unterminatedString = '';
  }

  void _registryTask(int id, Completer<dynamic> completer) =>
      _tasks[id.toString()] = SocketTask(completer: completer, isSubscription: false);

  void _regisrySubscription(String id, BehaviorSubject<dynamic> subject) =>
      _tasks[id] = SocketTask(subject: subject, isSubscription: true);

  void _registryIsolateTask(int id, Completer<dynamic> completer) =>
      _isolateTasks[id.toString()] = SocketTask(completer: completer, isSubscription: false);

  void _finish(String id, Object? data) {
    if (_tasks[id] == null) {
      return;
    }

    if (!(_tasks[id]?.completer?.isCompleted ?? false)) {
      _tasks[id]?.completer!.complete(data);
    }

    if (!(_tasks[id]?.isSubscription ?? false)) {
      _tasks.remove(id);
    } else {
      _tasks[id]?.subject?.add(data);
    }
  }

  void _finishIsolate(String id, Object? data) {
    if (_isolateTasks[id] == null) {
      return;
    }

    if (!(_isolateTasks[id]?.completer?.isCompleted ?? false)) {
      _isolateTasks[id]?.completer!.complete(data);
    }

    if (!(_isolateTasks[id]?.isSubscription ?? false)) {
      _isolateTasks.remove(id);
    } else {
      _isolateTasks[id]?.subject?.add(data);
    }
  }

  void _failAllPendingTasks(String errorMessage) {
    _tasks.forEach((id, task) {
      if (!(task.completer?.isCompleted ?? true)) {
        task.completer!.completeError(Exception(errorMessage));
      }
    });
    _tasks.clear();
  }

  void _failAllPendingIsolateTasks(String errorMessage) {
    _isolateTasks.forEach((id, task) {
      if (!(task.completer?.isCompleted ?? true)) {
        task.completer!.completeError(Exception(errorMessage));
      }
    });
    _isolateTasks.clear();
  }

  void _methodHandler({required String method, required Map<String, dynamic> request}) {
    switch (method) {
      case 'blockchain.headers.subscribe':
        final params = request['params'] as List<dynamic>;
        final id = 'blockchain.headers.subscribe';

        _tasks[id]?.subject?.add(params.last);
        break;
      case 'blockchain.scripthash.subscribe':
        final params = request['params'] as List<dynamic>;
        final scripthash = params.first as String?;
        final id = 'blockchain.scripthash.subscribe:$scripthash';

        _tasks[id]?.subject?.add(params.last);
        break;
      case 'blockchain.headers.subscribe':
        final params = request['params'] as List<dynamic>;
        _tasks[method]?.subject?.add(params.last);
        break;
      case 'blockchain.tweaks.subscribe':
        final params = request['params'] as List<dynamic>;
        _tasks[_tasks.keys.first]?.subject?.add(params.last);
        break;
      default:
        break;
    }
  }

  void _setConnectionStatus(ConnectionStatus status) {
    onConnectionStatusChange?.call(status);
    _connectionStatus = status;
    if (!isConnected) {
      try {
        socket?.destroy();
      } catch (_) {}
      socket = null;
    }
  }

  void _handleResponse(Map<String, dynamic> response) {
    final method = response['method'];
    final id = response['id'] as String?;
    final result = response['result'];
    // Only log non-null results to reduce noise from unused addresses
    if (result != null) {
      printV("method: $method, id: $id, result: $result");
    }
    try {
      final error = response['error'] as Map<String, dynamic>?;
      if (error != null) {
        final errorMessage = error['message'] as String?;
        printV(errorMessage);
        if (errorMessage != null) {
          _errors[id!] = errorMessage;
        }
      }
    } catch (_) {}

    try {
      final error = response['error'] as String?;
      if (error != null) {
        _errors[id!] = error;
      }
    } catch (_) {}

    if (method is String) {
      _methodHandler(method: method, request: response);
      return;
    }

    if (id != null) {
      _finish(id, result);
    }
  }

  void _handleIsolateResponse(Map<String, dynamic> response) {
    final method = response['method'];
    final id = response['id'] as String?;
    final result = response['result'];
    // Only log non-null results to reduce noise from unused addresses
    if (result != null) {
      printV("isolate method: $method, id: $id, result: $result");
    }
    try {
      final error = response['error'] as Map<String, dynamic>?;
      if (error != null) {
        final errorMessage = error['message'] as String?;
        printV(errorMessage);
        if (errorMessage != null) {
          _isolateErrors[id!] = errorMessage;
        }
      }
    } catch (_) {}

    try {
      final error = response['error'] as String?;
      if (error != null) {
        _isolateErrors[id!] = error;
      }
    } catch (_) {}

    if (method is String) {
      // Isolate socket doesn't handle method subscriptions
      return;
    }

    if (id != null) {
      _finishIsolate(id, result);
    }
  }

  String getErrorMessage(int id) => _errors[id.toString()] ?? '';

  bool get isInternalStateConsistent => _errors.isEmpty;
}

// FIXME: move me
bool isJSONStringCorrect(String source) {
  try {
    json.decode(source);
    return true;
  } catch (_) {
    return false;
  }
}

class RequestFailedTimeoutException implements Exception {
  RequestFailedTimeoutException(this.method, this.id);

  final String method;
  final int id;
}
