import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class InternetConnection {
  // Singleton pattern
  static final InternetConnection _instance = InternetConnection._internal();
  factory InternetConnection() => _instance;
  InternetConnection._internal();

  // Stream controller to broadcast connection status
  final _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  // Initialize connectivity listening
  void initialize() {
    // Check connectivity initially
    checkConnectivity();

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _connectionStatusController.add(result != ConnectivityResult.none);
    });
  }

  // Check current connectivity
  Future<bool> checkConnectivity() async {
    final ConnectivityResult result = await Connectivity().checkConnectivity();
    final bool isConnected = result != ConnectivityResult.none;
    _connectionStatusController.add(isConnected);
    return isConnected;
  }

  // Dispose method to close the stream controller
  void dispose() {
    _connectionStatusController.close();
  }
}

// Widget to show when there's no internet connection
class OfflineWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const OfflineWidget({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.signal_wifi_off,
            size: 50,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Internet Connection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// Widget wrapper that handles connectivity and shows appropriate UI
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final Widget? loadingWidget;

  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.loadingWidget,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final InternetConnection _internetConnection = InternetConnection();
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _internetConnection.initialize();
    _internetConnection.connectionStatus.listen((isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
    });
  }

  @override
  void dispose() {
    // Note: We don't dispose the InternetConnection here since it's a singleton
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isConnected
        ? widget.child
        : OfflineWidget(
            onRetry: () => _internetConnection.checkConnectivity(),
          );
  }
}
