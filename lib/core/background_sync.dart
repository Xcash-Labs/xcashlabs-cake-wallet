import 'dart:async';
import 'dart:io';

import 'package:cake_wallet/core/key_service.dart';
import 'package:cake_wallet/core/wallet_loading_service.dart';
import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/utils/tor.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cake_wallet/evm/evm.dart';
import 'package:cw_core/wallet_info.dart';

class BackgroundSync {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> _initializeNotifications() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      return await _notificationsPlugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
          false;
    } else if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final enabled = await androidPlugin?.areNotificationsEnabled() ?? false;

      if (enabled) {
        return true;
      }

      return await androidPlugin?.requestNotificationsPermission() ?? false;
    }

    return false;
  }

  Future<void> showNotification(String title, String content) async {
    await _initializeNotifications();
    final hasPermission = await requestPermissions();

    if (!hasPermission) {
      printV('Notification permissions not granted');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'transactions',
      'Transactions',
      channelDescription: 'Channel for notifications about transactions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.hashCode,
      title,
      content,
      notificationDetails,
    );
  }

  Future<void> sync() async {
    final settingsStore = getIt.get<SettingsStore>();
    if (settingsStore.currentBuiltinTor) {
      printV("Starting Tor");
      await ensureTorStarted(context: null);
    }
    printV("Background sync started");
    await _syncWallets();
    printV("Background sync completed");
  }

  Future<void> _syncWallets() async {
    final walletLoadingService = getIt.get<WalletLoadingService>();
    final settingsStore = getIt.get<SettingsStore>();
    final keyService = getIt.get<KeyService>();
    final sharedPreferences = await SharedPreferences.getInstance();

    final List<WalletInfo> moneroWallets = (await WalletInfo.getAll())
        .where((element) => element.type == WalletType.monero)
        .where((element) => !element.isHardwareWallet)
        .toList();

    printV("TRANS_NOTIFY: WalletInfo.getAll() returned ${moneroWallets.length} XCK wallets");

    for (final wallet in moneroWallets) {
      printV(
        "TRANS_NOTIFY: wallet name=${wallet.name} "
        "type=${wallet.type} "
        "hardware=${wallet.isHardwareWallet}",
      );
    }

    for (int i = 0; i < moneroWallets.length; i++) {

      printV(
        "TRANS_NOTIFY: loading wallet index=$i "
        "name=${moneroWallets[i].name} "
        "type=${moneroWallets[i].type} "
        "isHardware=${moneroWallets[i].isHardwareWallet}",
      );

      final wallet = await walletLoadingService.load(moneroWallets[i].type, moneroWallets[i].name,
          isBackground: true);

      int syncedTicks = 0;
      int stuckTicks = 0;
      bool walletSynced = false;
      inner:
      while (true) {
        await Future.delayed(const Duration(seconds: 1));
        final syncStatus = wallet.syncStatus;
        final progress = syncStatus.progress();
        if (syncStatus is ConnectedSyncStatus ||
            syncStatus is AttemptingSyncStatus ||
            syncStatus is NotConnectedSyncStatus) {
          stuckTicks++;
          if (stuckTicks > 30) {
            printV("${wallet.name} sync timed out");
            break inner;
          }
        } else {
          stuckTicks = 0;
        }

        if (syncStatus is NotConnectedSyncStatus) {
          printV("TRANS_NOTIFY: ${wallet.name} NOT CONNECTED");

          final node = settingsStore.getCurrentNode(WalletType.monero);

          printV(
            "TRANS_NOTIFY: selected node for ${wallet.name} "
            "isNull=${node == null} node=$node",
          );

          if (node == null) {
            printV("TRANS_NOTIFY: no XCK node found, stopping wallet sync");
            break inner;
          }

          await wallet.connectToNode(node: node);
          await wallet.startBackgroundSync();

          printV("TRANS_NOTIFY: STARTED SYNC for ${wallet.name}");
          continue inner;
        }

        if (progress > 0.999 || syncStatus is SyncedSyncStatus) {
          syncedTicks++;
          if (syncedTicks > 5) {
            syncedTicks = 0;
            walletSynced = true;
            printV("WALLET $i SYNCED");
            break inner;
          }
        } else {
          syncedTicks = 0;
        }

        if (FeatureFlag.hasDevOptions) {
          if (syncStatus is SyncingSyncStatus) {
            final blocksLeft = syncStatus.blocksLeft;
            printV("$blocksLeft Blocks Left");
          } else if (syncStatus is SyncedSyncStatus) {
            printV("Synced");
          } else if (syncStatus is SyncedTipSyncStatus) {
            printV("Scanned Tip: ${syncStatus.tip}");
          } else if (syncStatus is NotConnectedSyncStatus) {
            printV("Still Not Connected");
          } else if (syncStatus is AttemptingSyncStatus) {
            printV("Attempting Sync");
          } else if (syncStatus is StartingScanSyncStatus) {
            printV("Starting Scan");
          } else if (syncStatus is SyncronizingSyncStatus) {
            printV("Syncronizing");
          } else if (syncStatus is FailedSyncStatus) {
            printV("Failed Sync");
          } else if (syncStatus is ConnectingSyncStatus) {
            printV("Connecting");
          } else {
            printV("Unknown Sync Status ${syncStatus.runtimeType}");
          }
        }
      }

      if (!walletSynced) {
        printV("${wallet.name} STUCK SYNCING - skipping notifications");

        try {
          await wallet.stopBackgroundSync(
            await keyService.getWalletPassword(walletName: wallet.name),
          );
        } catch (e) {
          printV("error stopping stuck wallet sync: $e");
        }

        await wallet.close(shouldCleanup: true);
        continue;
      }

      final txs = wallet.transactionHistory;
      final sortedTxs = txs.transactions.values.toList()..sort((a, b) => a.date.compareTo(b.date));
      
      for (final tx in sortedTxs) {
        final lastTriggerString =
            sharedPreferences.getString(PreferencesKey.backgroundSyncLastTrigger(wallet.name));

        final lastTriggerDate = lastTriggerString != null
            ? DateTime.parse(lastTriggerString)
            : DateTime.fromMillisecondsSinceEpoch(0);

        if (!tx.date.isAfter(lastTriggerDate)) {
          continue;
        }

        await sharedPreferences.setString(
          PreferencesKey.backgroundSyncLastTrigger(wallet.name),
          tx.date.toIso8601String(),
        );

        final action = tx.direction == TransactionDirection.incoming ? "Received" : "Sent";

        if (sharedPreferences.getBool(PreferencesKey.backgroundSyncNotificationsEnabled) ?? false) {

          printV("TRANS_NOTIFY: Showing notification for ${tx.amountFormatted()}");
          await showNotification("$action ${wallet.currency.fullName} in ${wallet.name}", tx.amountFormatted(),);
        }

        printV(
          "TRANS_NOTIFY: ${wallet.currency.fullName} in ${wallet.name}: " "TX: ${tx.date} ${tx.amount} ${tx.direction}",
        );
      }

      try {
        await wallet.stopBackgroundSync(
          await keyService.getWalletPassword(walletName: wallet.name),
        );
      } catch (e) {
        printV("error stopping sync after notifications: $e");
      }

      await wallet.close(shouldCleanup: true);
    }
  }
}
