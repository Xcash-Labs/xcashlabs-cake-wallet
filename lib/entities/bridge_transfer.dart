import 'package:cw_core/hive_type_ids.dart';
import 'package:hive/hive.dart';

class BridgeTransfer extends HiveObject {
  BridgeTransfer({
    required this.id,
    required this.walletId,
    required this.sourceChainId,
    required this.destinationChainId,
    required this.tokenSymbol,
    required this.tokenContract,
    required this.amount,
    required this.recipientAddress,
    required this.sourceTxHash,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.amountRaw,
    this.errorMessage,
    this.statusMessage,
  });

  static const typeId = BRIDGE_TRANSFER_TYPE_ID;
  static const boxName = 'BridgeTransfers';
  static const boxKey = 'bridgeTransfersBoxKey';

  @HiveField(0)
  String id;

  @HiveField(1)
  String walletId;

  @HiveField(2)
  int sourceChainId;

  @HiveField(3)
  int destinationChainId;

  @HiveField(4)
  String tokenSymbol;

  @HiveField(5)
  String tokenContract;

  @HiveField(6)
  String amount;

  @HiveField(7)
  String recipientAddress;

  @HiveField(8)
  String sourceTxHash;

  @HiveField(9)
  String status;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime? updatedAt;

  @HiveField(12)
  DateTime? confirmedAt;

  @HiveField(13)
  String? amountRaw;

  @HiveField(14)
  String? errorMessage;

  @HiveField(15)
  String? statusMessage;

  bool get isActive => status == 'submitted' || status == 'confirming' || status == 'initiated';
}

class BridgeTransferAdapter extends TypeAdapter<BridgeTransfer> {
  @override
  final int typeId = BridgeTransfer.typeId;

  @override
  BridgeTransfer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      try {
        fields[reader.readByte()] = reader.read();
      } catch (_) {}
    }
    return BridgeTransfer(
      id: fields[0] as String? ?? '',
      walletId: fields[1] as String? ?? '',
      sourceChainId: fields[2] as int? ?? 0,
      destinationChainId: fields[3] as int? ?? 0,
      tokenSymbol: fields[4] as String? ?? '',
      tokenContract: fields[5] as String? ?? '',
      amount: fields[6] as String? ?? '',
      recipientAddress: fields[7] as String? ?? '',
      sourceTxHash: fields[8] as String? ?? '',
      status: fields[9] as String? ?? 'submitted',
      createdAt: fields[10] as DateTime? ?? DateTime.now(),
      updatedAt: fields[11] as DateTime?,
      confirmedAt: fields[12] as DateTime?,
      amountRaw: fields[13] as String?,
      errorMessage: fields[14] as String?,
      statusMessage: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BridgeTransfer obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.walletId)
      ..writeByte(2)
      ..write(obj.sourceChainId)
      ..writeByte(3)
      ..write(obj.destinationChainId)
      ..writeByte(4)
      ..write(obj.tokenSymbol)
      ..writeByte(5)
      ..write(obj.tokenContract)
      ..writeByte(6)
      ..write(obj.amount)
      ..writeByte(7)
      ..write(obj.recipientAddress)
      ..writeByte(8)
      ..write(obj.sourceTxHash)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.confirmedAt)
      ..writeByte(13)
      ..write(obj.amountRaw)
      ..writeByte(14)
      ..write(obj.errorMessage)
      ..writeByte(15)
      ..write(obj.statusMessage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BridgeTransferAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
