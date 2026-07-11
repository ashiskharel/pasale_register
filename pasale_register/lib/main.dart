import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bootstrap.dart';
import 'constants/keys.dart';
import 'screens/activation_screen.dart';
import 'screens/camera_scope_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/invoice_ingestor_screen.dart';
import 'services/service_locator.dart';

void main() async {
  final result = await bootstrap();
  debugPrint('Pasale bootstrap: ${result.message}');
  runApp(MyApp(bootstrap: result));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.bootstrap});

  final BootstrapResult? bootstrap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasale Register',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: MainScreen(bootstrap: bootstrap),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.bootstrap});

  final BootstrapResult? bootstrap;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isActivated = false;

  @override
  void initState() {
    super.initState();
    _checkActivation();
  }

  Future<void> _checkActivation() async {
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('storeId');
    final deviceId = prefs.getString('deviceId');
    final isActivated = prefs.getBool('isActivated') ?? false;

    if (storeId != null &&
        storeId.isNotEmpty &&
        deviceId != null &&
        deviceId.isNotEmpty &&
        isActivated) {
      try {
        await loadAndApplyCameraScope(storeId);
      } catch (e) {
        debugPrint('Camera scope load: $e');
      }
      setState(() {
        _isActivated = true;
        _currentIndex = 1;
      });
    } else {
      setState(() {
        _isActivated = false;
        _currentIndex = 0;
      });
    }
  }

  void _onActivated() {
    setState(() {
      _isActivated = true;
      _currentIndex = 1;
    });
    SharedPreferences.getInstance().then((prefs) async {
      final storeId = prefs.getString('storeId');
      if (storeId != null && storeId.isNotEmpty) {
        try {
          await loadAndApplyCameraScope(storeId);
        } catch (e) {
          debugPrint('Camera scope load: $e');
        }
      }
    });
  }

  Widget _bodyForIndex() {
    switch (_currentIndex) {
      case 0:
        return ActivationScreen(onActivated: _onActivated);
      case 1:
        return const CatalogScreen();
      case 2:
        return const CheckoutScreen();
      case 3:
        return const InvoiceIngestorScreen();
      case 4:
        return const CameraScopeScreen();
      default:
        return ActivationScreen(onActivated: _onActivated);
    }
  }

  String get _backendLabel {
    final b = widget.bootstrap;
    if (b == null) return '';
    return switch (b.backend) {
      ServiceBackend.fakes => 'Fakes',
      ServiceBackend.realCamera => 'Real camera · local catalog',
      ServiceBackend.production => 'Firebase · real camera',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.bootstrap != null)
              Material(
                color: widget.bootstrap!.firebaseReady
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        widget.bootstrap!.firebaseReady
                            ? Icons.cloud_done
                            : Icons.camera_alt,
                        size: 18,
                        color: widget.bootstrap!.firebaseReady
                            ? Colors.green.shade800
                            : Colors.orange.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _backendLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.bootstrap!.firebaseReady
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _navBtn(
                      key: AppKeys.navToActivation,
                      label: 'Activation',
                      index: 0,
                      enabled: true,
                    ),
                    _navBtn(
                      key: AppKeys.navToCatalog,
                      label: 'Catalog',
                      index: 1,
                      enabled: _isActivated,
                    ),
                    _navBtn(
                      key: AppKeys.navToCheckout,
                      label: 'Checkout',
                      index: 2,
                      enabled: _isActivated,
                    ),
                    _navBtn(
                      key: AppKeys.navToInvoiceIngestor,
                      label: 'Ingestor',
                      index: 3,
                      enabled: _isActivated,
                    ),
                    _navBtn(
                      key: AppKeys.navToCameraScope,
                      label: 'Cam Scope',
                      index: 4,
                      enabled: _isActivated,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _bodyForIndex()),
          ],
        ),
      ),
    );
  }

  Widget _navBtn({
    required Key key,
    required String label,
    required int index,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ElevatedButton(
        key: key,
        onPressed: enabled ? () => setState(() => _currentIndex = index) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _currentIndex == index ? Colors.blue : Colors.grey,
        ),
        child: Text(label),
      ),
    );
  }
}
