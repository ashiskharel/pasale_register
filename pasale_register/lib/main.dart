import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/keys.dart';
import 'screens/activation_screen.dart';
import 'screens/camera_scope_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/invoice_ingestor_screen.dart';
import 'services/service_locator.dart';

/// Set to `false` for device builds with real ML Kit camera + Firestore.
const bool kUseFakeServices = true;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupLocator(useFakes: kUseFakeServices);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasale Register',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

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
      // Step 2: load camera scope for this store (barcode/QR free default).
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
    // Apply scope right after activation.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
