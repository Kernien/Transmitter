import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/files/file_transfer_service.dart';
import '../core/share/incoming_share.dart';
import '../core/share/outgoing_share.dart';
import '../core/storage/cloud_connection_service.dart';
import '../features/share_target/incoming_share_listener.dart';
import '../features/vaults/vaults_controller.dart';
import '../features/vaults/vaults_screen.dart';
import 'vault_session_factory.dart';

class TransmitterApp extends StatelessWidget {
  const TransmitterApp({
    super.key,
    required this.connections,
    required this.vaults,
    required this.sessions,
    required this.files,
    required this.incomingShares,
    required this.shareSender,
  });

  final CloudConnectionService connections;
  final VaultsController vaults;
  final VaultSessionFactory sessions;
  final FileTransferService files;
  final IncomingShareSource incomingShares;
  final ShareSender shareSender;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connections),
        ChangeNotifierProvider.value(value: vaults),
        Provider.value(value: sessions),
        Provider<FileTransferService>.value(value: files),
        Provider<IncomingShareSource>.value(value: incomingShares),
        Provider<ShareSender>.value(value: shareSender),
      ],
      child: MaterialApp(
        title: 'Transmitter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const IncomingShareListener(child: VaultsScreen()),
      ),
    );
  }
}
