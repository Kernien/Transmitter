import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/storage/cloud_connection_service.dart';
import '../features/vaults/vaults_controller.dart';
import '../features/vaults/vaults_screen.dart';
import 'vault_session_factory.dart';

class TransmitterApp extends StatelessWidget {
  const TransmitterApp({
    super.key,
    required this.connections,
    required this.vaults,
    required this.sessions,
  });

  final CloudConnectionService connections;
  final VaultsController vaults;
  final VaultSessionFactory sessions;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: connections),
        ChangeNotifierProvider.value(value: vaults),
        Provider.value(value: sessions),
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
        home: const VaultsScreen(),
      ),
    );
  }
}
