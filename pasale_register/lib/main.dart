import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/keys.dart';
import 'screens/activation_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/invoice_ingestor_screen.dart';
import 'services/service_locator.dart';

void main() {
  setupLocator(useFakes: true);
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

    if (storeId != null && storeId.isNotEmpty && deviceId != null && deviceId.isNotEmpty && isActivated) {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    key: AppKeys.navToActivation,
                    onPressed: () => setState(() => _currentIndex = 0),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentIndex == 0 ? Colors.blue : Colors.grey,
                    ),
                    child: const Text('Activation'),
                  ),
                  ElevatedButton(
                    key: AppKeys.navToCatalog,
                    onPressed: _isActivated ? () => setState(() => _currentIndex = 1) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentIndex == 1 ? Colors.blue : Colors.grey,
                    ),
                    child: const Text('Catalog'),
                  ),
                  ElevatedButton(
                    key: AppKeys.navToCheckout,
                    onPressed: _isActivated ? () => setState(() => _currentIndex = 2) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentIndex == 2 ? Colors.blue : Colors.grey,
                    ),
                    child: const Text('Checkout'),
                  ),
                  ElevatedButton(
                    key: AppKeys.navToInvoiceIngestor,
                    onPressed: _isActivated ? () => setState(() => _currentIndex = 3) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentIndex == 3 ? Colors.blue : Colors.grey,
                    ),
                    child: const Text('Ingestor'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _currentIndex == 0
                  ? ActivationScreen(onActivated: _onActivated)
                  : _currentIndex == 1
                      ? const CatalogScreen()
                      : _currentIndex == 2
                          ? const CheckoutScreen()
                          : const InvoiceIngestorScreen(),
            ),
          ],
        ),
      ),
    );
  }
}
