class Recipient {
  Recipient({
    required this.address,
    required this.pools,
    required this.amount,
    required this.feeIncluded,
    required this.replyTo,
    required this.subject,
    required this.memo,
    required this.maxAmountPerNote,
  });

  factory Recipient.fromJson(final Map<String, dynamic> json) {
    return Recipient(
      address: json['address'] as String?,
      pools: json['pools'] as int,
      amount: json['amount'] as int,
      feeIncluded: json['feeIncluded'] as bool,
      replyTo: json['replyTo'] as bool,
      subject: json['subject'] as String?,
      memo: json['memo'] as String?,
      maxAmountPerNote: json['maxAmountPerNote'] as int,
    );
  }

  String? address;
  int pools;
  int amount;
  bool feeIncluded;
  bool replyTo;
  String? subject;
  String? memo;
  int maxAmountPerNote;

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'pools': pools,
      'amount': amount,
      'feeIncluded': feeIncluded,
      'replyTo': replyTo,
      'subject': subject,
      'memo': memo,
      'maxAmountPerNote': maxAmountPerNote,
    };
  }
}

class FeeT {
  FeeT({required this.fee, required this.minFee, required this.maxFee, required this.scheme});

  factory FeeT.fromJson(final Map<String, dynamic> json) {
    return FeeT(
      fee: json['fee'] as int,
      minFee: json['minFee'] as int,
      maxFee: json['maxFee'] as int,
      scheme: json['scheme'] as int,
    );
  }

  int fee;
  int minFee;
  int maxFee;
  int scheme;

  Map<String, dynamic> toJson() {
    return {'fee': fee, 'minFee': minFee, 'maxFee': maxFee, 'scheme': scheme};
  }
}

class ShieldedTx {
  ShieldedTx({
    required this.id,
    this.txId,
    required this.height,
    required this.timestamp,
    this.name,
    required this.value,
    this.address,
    this.memo,
  });

  factory ShieldedTx.fromJson(final Map<String, dynamic> json) {
    return ShieldedTx(
      id: json['id'] as int,
      txId: json['txId'] as String?,
      height: json['height'] as int,
      timestamp: json['timestamp'] as int,
      name: json['name'] as String?,
      value: json['value'] as int,
      address: json['address'] as String?,
      memo: json['memo'] as String?,
    );
  }

  int id;
  String? txId;
  int height;
  int timestamp;
  String? name;
  int value;
  String? address;
  String? memo;

  String? get shortTxId => txId?.substring(0, 8);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'txId': txId,
      'height': height,
      'timestamp': timestamp,
      'name': name,
      'value': value,
      'address': address,
      'memo': memo,
    };
  }
}

class Account {
  Account({
    required this.coin,
    required this.id,
    this.name,
    required this.keyType,
    required this.balance,
    this.address,
    required this.saved,
  });

  factory Account.fromJson(final Map<String, dynamic> json) {
    return Account(
      coin: json['coin'] as int,
      id: json['id'] as int,
      name: json['name'] as String?,
      keyType: json['keyType'] as int,
      balance: json['balance'] as int,
      address: json['address'] as String?,
      saved: json['saved'] as bool,
    );
  }

  int coin;
  int id;
  String? name;
  int keyType;
  int balance;
  String? address;
  bool saved;

  Map<String, dynamic> toJson() {
    return {
      'coin': coin,
      'id': id,
      'name': name,
      'keyType': keyType,
      'balance': balance,
      'address': address,
      'saved': saved,
    };
  }
}

class PaymentURI {
  PaymentURI({required this.address, required this.amount, this.memo});

  factory PaymentURI.fromJson(final Map<String, dynamic> json) {
    return PaymentURI(
      address: json['address'] as String,
      amount: json['amount'] as int,
      memo: json['memo'] as String?,
    );
  }
  String address;
  int amount;
  String? memo;

  Map<String, dynamic> toJson() {
    return {'address': address, 'amount': amount, 'memo': memo};
  }
}

class Backup {
  Backup({
    this.name,
    this.seed,
    required this.index,
    this.sk,
    this.fvk,
    this.uvk,
    this.tsk,
    required this.saved,
  });

  factory Backup.fromJson(final Map<String, dynamic> json) {
    return Backup(
      name: json['name'] as String?,
      seed: json['seed'] as String?,
      index: json['index'] as int,
      sk: json['sk'] as String?,
      fvk: json['fvk'] as String?,
      uvk: json['uvk'] as String?,
      tsk: json['tsk'] as String?,
      saved: json['saved'] as bool,
    );
  }

  final String? name;
  final String? seed;
  final int index;
  final String? sk;
  final String? fvk;
  final String? uvk;
  final String? tsk;
  final bool saved;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'seed': seed,
      'index': index,
      'sk': sk,
      'fvk': fvk,
      'uvk': uvk,
      'tsk': tsk,
      'saved': saved,
    };
  }
}

class Height {
  Height({required this.height, required this.timestamp});

  factory Height.fromJson(final Map<String, dynamic> json) {
    return Height(height: json['height'] as int, timestamp: json['timestamp'] as int);
  }

  final int height;
  final int timestamp;

  Map<String, dynamic> toJson() {
    return {'height': height, 'timestamp': timestamp};
  }
}

class PoolBalance {
  PoolBalance({required this.transparent, required this.sapling, required this.orchard});

  factory PoolBalance.fromJson(final Map<String, dynamic> json) {
    return PoolBalance(
      transparent: json['transparent'] as int,
      sapling: json['sapling'] as int,
      orchard: json['orchard'] as int,
    );
  }

  final int transparent;
  final int sapling;
  final int orchard;

  Map<String, dynamic> toJson() {
    return {'transparent': transparent, 'sapling': sapling, 'orchard': orchard};
  }
}
