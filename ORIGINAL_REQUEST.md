# Original User Request

## Initial Request — 2026-07-07T17:38:44+05:45

A Flutter mobile application serving as a digital cash register for local mom-and-pop shops in Nepal, integrated with Firebase. It features device activation tracking, Firestore-backed product catalog (seeded with scraped marketplace data), barcode scanning, manual entry with quantity control, receipt sharing, and a vendor invoice photo ingestion feature with markup calculations.

Working directory: c:/Users/aerok/Pasale Register
Integrity mode: development

## Requirements

### R1. Flutter App & Firebase Integration
- Setup Firebase in the Flutter project (using Firestore, and optionally Firebase Auth or Device ID tracking).
- Track shop registration (stores) and the count/list of devices (phones) where the register is activated for each store.

### R2. Firestore-Backed Product Catalog
- Store product catalog in Firestore (name, barcode, selling price, cost price, markup).
- Implement a script (Dart or Python) to seed the database with initial product prices scraped from leading online marketplaces in Nepal (Bhatbhateni Online or Daraz).

### R3. Checkout, Scanning & Cart Management
- Camera-based barcode scanner that checks scanned codes against the Firestore catalog.
- If unrecognized, prompt the storekeeper to register the product on-the-fly (updates Firestore).
- Trigger a beep and vibration on successful scan.
- Add products manually, edit quantity with "+" and "-" buttons, and calculate total.
- Toggle between "Paid" and "Credit". Share text receipt via native SMS/WhatsApp using customer's phone number.

### R4. Vendor Invoice & Price Markup Ingestor
- Camera interface to capture a photo of a vendor's invoice.
- Input fields to record the vendor's cost price and a store-specific markup percentage.
- Automatically calculate the selling price: `Selling Price = Cost Price * (1 + Markup / 100)`.
- Save the photo (e.g., to Firebase Storage or local cache) and save/update the calculated selling price of the item in Firestore.

### R5. Automated Testing
- Include unit/widget tests to cover cart calculations, quantity updates, and bill formatting logic.

## Acceptance Criteria

### Firebase & Devices
- [ ] Active devices and stores are tracked in Firestore.
- [ ] Product catalog is stored in Firestore.
- [ ] Scraper script successfully fetches/seeds sample products from Daraz or Bhatbhateni Online into Firestore.

### Cart & Checkout Flow
- [ ] Items scanned/entered display correct prices from Firestore.
- [ ] Unrecognized barcode brings up a registration dialog, saving new item details to Firestore.
- [ ] Successful scan triggers vibration and beep.
- [ ] Cart quantities can be modified using +/- buttons and direct numeric typing.
- [ ] Order can be toggled between "Paid" and "Credit".

### Vendor Invoice
- [ ] Storekeeper can take a photo of a vendor invoice.
- [ ] Storekeeper can input cost price and markup percentage, correctly calculating selling price and updating Firestore.

### Verification & Testing
- [ ] Run `flutter test` successfully verifies calculations, quantity editing, and formatting.

## Follow-up — 2026-07-08T05:40:42Z

The user has requested the following UI updates. Incorporate these specifications:
1. Split-screen layout: When scanning with the camera, the view should show a split-screen (or swipeable layout) so that scanned items are listed in one part of the screen while the camera stays active.
2. Camera control: The barcode scanner camera must remain active continuously and only turn off when the storekeeper explicitly taps the "Done Scanning / OK" button.

