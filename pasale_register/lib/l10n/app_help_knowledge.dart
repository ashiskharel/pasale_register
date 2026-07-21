/// Local offline knowledge for the Pasale help agent (keyword FAQ + LLM context).
class HelpKnowledgeSection {
  const HelpKnowledgeSection({
    required this.id,
    required this.title,
    required this.keywords,
    required this.body,
  });

  final String id;
  final String title;
  final List<String> keywords;
  final String body;
}

class AppHelpKnowledge {
  AppHelpKnowledge._();

  static const sections = <HelpKnowledgeSection>[
    HelpKnowledgeSection(
      id: 'offline',
      title: 'Offline mode',
      keywords: [
        'offline',
        'no internet',
        'without network',
        'local',
        'no wifi',
        'airplane',
      ],
      body: '''
Scanner (barcode + price-tag OCR), invoice OCR, cart, and a local catalog work without internet (on-device ML Kit / local data).
Language settings and demo OTP also work offline.
Cloud features need network: real phone/Facebook auth, multi-device Firestore sync, live Grok AI answers.
The help "?" button always opens; without network it answers from this built-in guide.''',
    ),
    HelpKnowledgeSection(
      id: 'scanner',
      title: 'Scanner & checkout',
      keywords: [
        'scan',
        'scanner',
        'barcode',
        'price tag',
        'ocr',
        'checkout',
        'cart',
        'paid',
        'credit',
      ],
      body: '''
Store Owner home defaults to Scanner.
• Barcode mode: point at a barcode/QR — known items go to cart; unknown codes open register product.
• Price tag mode: live OCR reads Rs/NPR prices, then opens a prefilled product form (name, price, photo).
• Adjust qty with +/−, enter customer phone for credit, then Paid or Credit checkout.
• "Done Scanning / OK" finishes the scan session.
Works offline with on-device camera ML.''',
    ),
    HelpKnowledgeSection(
      id: 'catalog',
      title: 'Catalog',
      keywords: ['catalog', 'product', 'inventory', 'stock', 'price', 'add product'],
      body: '''
Catalog lists products for the store. Add or edit name, barcode, selling/cost price, markup, notes, and product photo.
Use spare time to fill the catalog; checkout can also register products on the fly when scanning unknown items.''',
    ),
    HelpKnowledgeSection(
      id: 'invoice',
      title: 'Scan invoice',
      keywords: ['invoice', 'bill', 'vendor bill', 'cost', 'markup'],
      body: '''
Scan Invoice (menu): frame a vendor bill, capture + OCR line items, edit name/cost/markup, then save into the catalog.
OCR runs on-device. Review lines carefully before saving.''',
    ),
    HelpKnowledgeSection(
      id: 'roles',
      title: 'Roles',
      keywords: [
        'role',
        'store owner',
        'vendor',
        'buyer',
        'customer',
        'landing',
      ],
      body: '''
On the landing page pick Store Owner, Vendor, or Buyer, then Continue.
• Store Owner: POS scanner, catalog, dashboard, customers, vendors, invoices.
• Vendor: stores list, premium tools (invoices, camera inventory, accounting).
• Buyer: nearby stores / credits (coming soon features).
Switch roles by logging out and choosing again on the landing page.''',
    ),
    HelpKnowledgeSection(
      id: 'language',
      title: 'App language',
      keywords: [
        'language',
        'nepali',
        'hindi',
        'bengali',
        'urdu',
        'english',
        'नेपाली',
        'हिन्दी',
      ],
      body: '''
Choose language on the landing page (under role toggle) or later in Settings → App language.
Supported: English (default), Nepali, Bengali, Hindi, Urdu (RTL).
Preference is saved on the device.''',
    ),
    HelpKnowledgeSection(
      id: 'auth',
      title: 'Sign-in (OTP & Facebook)',
      keywords: ['otp', 'login', 'sign in', 'facebook', 'phone', 'password'],
      body: '''
After choosing a role, sign in with Facebook or phone OTP.
If Firebase Phone is not ready, use Demo OTP (code shown on screen, typically 123456).
You stay signed in until Log Out under Settings or the account menu.''',
    ),
    HelpKnowledgeSection(
      id: 'training_setup',
      title: 'Training & store setup',
      keywords: ['training', 'setup', 'activate', 'store name', 'first time'],
      body: '''
New users see a short training walkthrough (consent required), then store setup for Store Owners (name / activate store).
Complete setup once; later launches go straight to the role home.''',
    ),
    HelpKnowledgeSection(
      id: 'menu_settings',
      title: 'Menu & settings',
      keywords: [
        'menu',
        'settings',
        'profile',
        'logout',
        'log out',
        'notifications',
        'reload',
      ],
      body: '''
Top-right menu (hamburger) opens account options: dashboard, catalog, scan invoice, customers, vendors, profile, settings, reload, log out.
Settings: App language, notifications, reload app data, log out.
Profile: business details, phones, PAN, etc.''',
    ),
    HelpKnowledgeSection(
      id: 'help_chat',
      title: 'This help assistant',
      keywords: ['help', 'assistant', 'chat', 'question', 'voice', 'mic'],
      body: '''
Tap the "?" next to the menu anytime. After 30 seconds idle the "?" flashes to remind you help is available.
Type a question or use the microphone. Answers cover how to use Pasale.
With network + API key, answers use Grok; offline they use this built-in guide.''',
    ),
    HelpKnowledgeSection(
      id: 'dashboard',
      title: 'Dashboard & customers',
      keywords: ['dashboard', 'sales', 'customers', 'vendors', 'report'],
      body: '''
Dashboard shows sales-oriented summary for the store.
Customers and Vendors screens manage contacts and reorder context.
Vendor role focuses on connected stores and premium invoice/camera tools.''',
    ),
  ];

  /// Rank sections by keyword hits in [query]; return best bodies.
  static String answerFromQuery(String query, {int maxSections = 2}) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      return sections.firstWhere((s) => s.id == 'help_chat').body;
    }

    final scored = <({HelpKnowledgeSection s, int score})>[];
    for (final s in sections) {
      var score = 0;
      for (final k in s.keywords) {
        if (q.contains(k.toLowerCase())) score += 2;
      }
      // Title words
      for (final w in s.title.toLowerCase().split(RegExp(r'\W+'))) {
        if (w.length > 2 && q.contains(w)) score += 1;
      }
      if (score > 0) scored.add((s: s, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) {
      return 'I can help with Pasale: scanner, catalog, invoices, roles, '
          'language, sign-in, offline mode, settings, and more. '
          'Try asking e.g. “How do I scan a price tag?” or “How do I change language?”';
    }

    final pick = scored.take(maxSections).map((e) => '**${e.s.title}**\n${e.s.body}');
    return pick.join('\n\n');
  }

  static String fullGuideText() {
    return sections.map((s) => '## ${s.title}\n${s.body}').join('\n\n');
  }

  static String screensForRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('vendor')) {
      return 'Vendor screens: Stores, Premium (invoices, camera inventory, accounting), Profile, Settings. Menu: chat, call stores, notifications, reload, log out.';
    }
    if (r.contains('buyer')) {
      return 'Buyer screens: Shop (nearby stores, credits), Profile, Settings. Menu: notifications, chat, reload, log out.';
    }
    return 'Store Owner screens: Scanner/Checkout, Catalog, Dashboard, Customers, Vendors, Scan invoice, Profile, Settings, Premium camera options. Bottom nav: Scan, Catalog, Dashboard, Customers.';
  }

  static String capabilityStatus({required String backend}) {
    final local =
        'Offline-capable: barcode/QR, price OCR, invoice OCR, cart UI, local language, help FAQ, demo OTP.';
    switch (backend) {
      case 'production':
        return '$local\nBackend: production (Firebase). Cloud auth + Firestore sync need network. Local camera ML still works offline until catalog is only on device cache.';
      case 'realCamera':
        return '$local\nBackend: real camera + local fake catalog — designed for offline/local POS without Firebase.';
      default:
        return '$local\nBackend: fakes (tests/demo) — fully local.';
    }
  }
}
