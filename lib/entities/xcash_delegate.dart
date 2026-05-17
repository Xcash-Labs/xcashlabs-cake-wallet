class XCashDelegate {
  final String delegateName;
  final int fee;
  final BigInt votes;

  XCashDelegate({
    required this.delegateName,
    required this.fee,
    required this.votes,
  });

  String get votesDisplay => (votes ~/ BigInt.from(1000000)).toString();

  factory XCashDelegate.fromJson(Map<String, dynamic> json) {
    return XCashDelegate(
      delegateName: json['delegateName'] as String,
      fee: json['fee'] as int,
      votes: BigInt.parse(json['votes'].toString()),
    );
  }

  static bool isSharedOnlineDelegate(Map<String, dynamic> json) {
    return json['DelegateType'] == 'shared' && json['online'] == true;
  }
}