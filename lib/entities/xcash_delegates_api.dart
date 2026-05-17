import 'dart:convert';

import 'package:cake_wallet/entities/xcash_delegate.dart';
import 'package:http/http.dart' as http;

class XCashDelegatesApi {
  static const String delegatesUrl =
      'https://api.xcashseeds.us/v2/xcash/dpops/unauthorized/delegates/registered/';

  Future<List<XCashDelegate>> getSharedOnlineDelegates() async {
    final response = await http.get(Uri.parse(delegatesUrl));

    if (response.statusCode != 200) {
      throw Exception('Failed to load delegates');
    }

    final data = jsonDecode(response.body) as List<dynamic>;

    final delegates = data
        .whereType<Map<String, dynamic>>()
        .where(XCashDelegate.isSharedOnlineDelegate)
        .map(XCashDelegate.fromJson)
        .toList();

    delegates.sort((a, b) => b.votes.compareTo(a.votes));

    return delegates;
  }
}