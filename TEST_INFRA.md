# E2E Test Infra: Pasale Register

## Test Philosophy
- **Opaque-box, requirement-driven**: Test the system's behavior via external APIs, integration tests, and UI interactions without depending on the internal class design.
- **Methodology**: Category-Partition + Boundary Value Analysis (BVA) + Pairwise Combinatorial Testing + Real-World Workload Testing.

## Feature Inventory
| # | Feature | Source (Requirement) | Tier 1 | Tier 2 | Tier 3 |
|---|---------|---------------------|:------:|:------:|:------:|
| 1 | Device Activation & Tracking | R1 (Firebase & Devices) | 5 | 5 | ✓ |
| 2 | Firestore Product Catalog & Seeding | R2 (Catalog & Seeding) | 5 | 5 | ✓ |
| 3 | Cart Management & Calculations | R3 (Cart & Checkout Flow) | 5 | 5 | ✓ |
| 4 | Paid/Credit & Receipt Sharing | R3 (Cart & Checkout Flow) | 5 | 5 | ✓ |
| 5 | Barcode Scanner & Matching | R3 (Continuous camera active in split-screen, vibration/beep feedback, done button) | 5 | 5 | ✓ |
| 6 | Vendor Invoice Ingestor & Markup | R4 (Vendor Invoice) | 5 | 5 | ✓ |

## Test Architecture
- **Unit and Widget Tests**:
  - Command: `flutter test test/`
  - Runs tests under the `test/` directory verifying cart math, formatting, quantity bounds.
- **Integration / E2E Tests**:
  - Command: `flutter test integration_test/app_test.dart`
  - Uses Flutter `integration_test` package to simulate tap events, text entry, and mock scanner actions.
- **Seeding Script Verification**:
  - Command: `python scripts/seed_db.py --dry-run` or similar check.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Standard Checkout | F2, F3, F4 | Medium |
| 2 | New Item Scan & Register | F2, F3, F5 | High |
| 3 | Bulk Restock via Vendor Ingestor | F2, F6 | Medium |
| 4 | Store Activation & Multi-Device Login | F1 | High |
| 5 | Complex Cart (Varying quantities, Paid/Credit Toggle, Receipt Share) | F3, F4 | High |

## Coverage Thresholds
- **Tier 1 (Feature Coverage)**: ≥5 test cases per feature (Total: 30 test cases)
- **Tier 2 (Boundary & Corner Cases)**: ≥5 test cases per feature (Total: 30 test cases)
- **Tier 3 (Cross-Feature Combinations)**: ≥6 test cases covering major feature interactions
- **Tier 4 (Real-World Application Scenarios)**: ≥5 complete workflow scenarios
- **Total Minimum**: 71 test cases
