# Deep Technical Analysis Report — Pasale Register Code Review (Modules 5–8)

**Target Scope**:
5. Multi-store access
6. Device sharing for store/vendor access
7. Vendors
8. Online/offline access & Security Rules

---

## 1. Executive Summary & Core Findings

A comprehensive static analysis and security audit was conducted on the Pasale Register Flutter application and Firebase backend policy configurations (`firestore.rules`, `storage.rules`, models, screens, and services). Multiple critical security flaws, permission defects, offline sync race conditions, and tenant isolation breaches were identified:

1. **Vendor Portal Broken by Missing Rules**: `firestore.rules` lacks match rules for `stores/{storeId}/vendor_invoices/{id}` and collection group queries for `vendors`. Vendors attempting to view assigned stores or send invoices encounter immediate `PERMISSION_DENIED` failures in production.
2. **Passcode Join Vulnerability & Rule Mismatch**: Store setup passcode joining sends `{memberUids: ...}` but Firestore rules require `request.resource.data.passcode` to match existing passcode during store updates, causing join attempts to fail while exposing store update privileges.
3. **Insecure Storage Rules**: `storage.rules` permits unauthenticated read and write access (`allow read, write: if true;`) to product photos and invoice images across all store buckets, allowing remote anonymous image overwrites and storage quota exhaustion.
4. **Business Master Catalog Disconnect**: Co-members of a store added via `memberUids` are not automatically registered in `businesses/{businessId}/members`, leading to Firestore rule rejection when fetching master business catalog items.
5. **Offline Credit Synchronization Race Condition**: Customer credit balances are calculated via client-side read-modify-write (`prevCredit + delta`) instead of atomic server increments (`FieldValue.increment`), resulting in lost credit updates and corrupted balances during offline sync.

---

## 2. Detailed Module Breakdown

### Module 5: Multi-Store Access
- **Files Inspected**: `lib/models/store.dart`, `lib/models/user_role.dart`, `lib/screens/store_setup_screen.dart`, `lib/screens/store_owner_shell.dart`, `lib/widgets/store_switcher.dart`, `lib/services/firestore_service.dart`, `lib/services/real_firestore_service.dart`, `firestore.rules`.

#### Findings & Evidence Chain:
1. **Passcode Join Rule Mismatch (`PERMISSION_DENIED` on Join)**
   - *Observation*: In `lib/services/real_firestore_service.dart` (`joinStore`, lines 343–346):
     ```dart
     await ref.update({
       'memberUids': FieldValue.arrayUnion([uid]),
     });
     ```
     In `firestore.rules` (lines 177–181):
     ```javascript
     allow update: if isStoreOwner(storeId)
       || isStoreMember(storeId)
       || isLegacyClaim(storeId)
       || isDemoReclaim(storeId)
       || (isSignedIn()
           && resource.data.keys().hasAny(['passcode'])
           && request.resource.data.keys().hasAny(['passcode'])
           && request.resource.data.passcode == resource.data.passcode
           && request.resource.data.ownerUid == resource.data.ownerUid);
     ```
   - *Logic Chain*: A new user calling `joinStore` is neither an owner nor a member yet (`isStoreMember` returns false). To qualify under the passcode rule, `request.resource.data` MUST contain `passcode` and `ownerUid`. However, `joinStore` performs a partial update containing ONLY `memberUids`. Thus, `request.resource.data.keys().hasAny(['passcode'])` evaluates to `false`, and Firestore denies the update with `permission-denied`.
   - *Impact*: Users cannot join existing stores using valid passcodes in production.

2. **Tenant Privilege Escalation in Passcode Rule**
   - *Observation*: If a malicious client crafts an update payload containing the correct `passcode`, `ownerUid`, and arbitrary modified fields (e.g. changing `name`, `ownerUid`, `planTier`), the security rule line 180 checks `request.resource.data.passcode == resource.data.passcode` and `request.resource.data.ownerUid == resource.data.ownerUid`, but DOES NOT restrict which fields in `request.resource.data` can be modified.
   - *Impact*: Any user who knows a store's passcode can modify store attributes or elevate their privileges prior to becoming a validated member.

3. **Legacy / Synthetic Demo Reclaim Access Leaks**
   - *Observation*: `firestore.rules` lines 49–86 definition of `isLegacyUnclaimed` and `isSyntheticDemoOwner` allows any authenticated user to list or update stores where `ownerUid` matches `demo_phone_.*` or `fb_demo_.*` or where `memberUids` is absent.
   - *Impact*: Attackers can claim ownership of unclaimed or legacy demo stores by setting `ownerUid` to their own UID.

4. **Co-Member Master Business Catalog Read Lockout**
   - *Observation*: In `real_firestore_service.dart` (`streamCatalog` lines 610–618), the app fetches shared business catalog products from `businesses/{businessId}/catalog`. In `firestore.rules` lines 119–122:
     ```javascript
     match /catalog/{productId} {
       allow read: if isBusinessMember(businessId) || isBusinessOwner(businessId);
     }
     ```
     However, `joinStore` adds the user UID to `stores/{storeId}.memberUids`, but NEVER writes a corresponding document to `businesses/{businessId}/members/{uid}`.
   - *Impact*: Invited store co-members receive `PERMISSION_DENIED` when streaming shared catalog products.

---

### Module 6: Device Sharing for Store/Vendor Access
- **Files Inspected**: `lib/models/device.dart`, `lib/services/device_context_service.dart`, `lib/services/real_firestore_service.dart`, `firestore.rules`.

#### Findings & Evidence Chain:
1. **Unrestricted Device Document Tampering**
   - *Observation*: In `firestore.rules` (lines 188–190):
     ```javascript
     match /devices/{deviceId} {
       allow read, write: if canAccessStore(storeId);
     }
     ```
     `real_firestore_service.dart` (`registerDevice` lines 354–377) uses client-supplied `deviceId` without hardware token verification.
   - *Logic Chain*: Any member of a store can overwrite any other device's document under `stores/{storeId}/devices/{deviceId}`. A compromised or malicious device can fake its `lastActive` timestamp, alter geolocation metadata, or delete other registered devices.
   - *Impact*: Audit log spoofing, loss of device tracking integrity, and inability to revoke unauthorized device access.

2. **Lack of Active Device Access Revocation**
   - *Observation*: Neither security rules nor application code check whether a `deviceId` remains active or approved before allowing store access. `canAccessStore` checks user membership, ignoring device registration status entirely.
   - *Impact*: Disabling or removing a device entry from `stores/{storeId}/devices` has no security effect; the physical device continues to have full read/write access.

---

### Module 7: Vendors
- **Files Inspected**: `lib/models/vendor.dart`, `lib/models/vendor_invoice.dart`, `lib/screens/vendors_manage_screen.dart`, `lib/screens/vendor_stores_screen.dart`, `lib/screens/vendor_shell.dart`, `lib/services/real_firestore_service.dart`, `firestore.rules`.

#### Findings & Evidence Chain:
1. **Missing Security Rules for Vendor Invoices (`/vendor_invoices`)**
   - *Observation*: In `real_firestore_service.dart` (lines 1073–1105), vendor invoices are created and queried under path `stores/{storeId}/vendor_invoices/{id}`.
   - *Security Rules Verification*: Inspecting `firestore.rules` (lines 136–253): There is a rule for `match /vendors/{vendorId}` (line 248), but **NO MATCH RULE FOR `/vendor_invoices/{invoiceId}` EXISTS**.
   - *Impact*: By default Firestore denies access to undefined paths. When vendors execute `saveVendorInvoice` or call `streamVendorInvoices`, Firebase rejects the operation with `PERMISSION_DENIED`.

2. **Collection Group Query & Vendor Store Lookup Failure**
   - *Observation*: `real_firestore_service.dart` (`streamStoresForVendor` lines 1047–1069) performs a collection group query:
     ```dart
     _firestore.collectionGroup('vendors').where('salespersonPhones', arrayContains: vendorPhone)
     ```
     It then attempts to fetch each parent store doc via `_firestore.collection('stores').doc(storeId).get()`.
   - *Security Rules Verification*:
     1. `firestore.rules` lacks a `match /{path=**}/vendors/{vendorId}` collection group rule.
     2. `canAccessStore(storeId)` requires the caller UID to be in `stores/{storeId}.memberUids` or `ownerUid`. Vendor accounts (logged in via phone/auth) are NOT listed in `memberUids` of client stores.
   - *Impact*: `streamStoresForVendor` fails with `PERMISSION_DENIED`, leaving the Vendor app interface (`VendorStoresScreen`) completely blank with error messages.

3. **Un-normalized Phone Matching for Vendor Assignment**
   - *Observation*: In `vendors_manage_screen.dart` (lines 186–189), store owners enter phone numbers as raw strings (e.g., `9800000000`). However, `AuthService` normalizes user phones to E.164 (e.g., `+9779800000000`).
   - *Impact*: Query `arrayContains: vendorPhone` fails to match because string representation differs (`9800000000` vs `+9779800000000`), breaking vendor-to-store linking even if rules are resolved.

---

### Module 8: Online/Offline Access & Security Rules
- **Files Inspected**: `firestore.rules`, `storage.rules`, `lib/services/real_firestore_service.dart`, `lib/services/session_service.dart`, `lib/services/auth_service.dart`.

#### Findings & Evidence Chain:
1. **Unauthenticated Public Storage Read/Write Vulnerability**
   - *Observation*: In `storage.rules` (lines 5–18):
     ```javascript
     match /stores/{storeId}/products/{fileName} {
       allow read: if true;
       allow write: if true && request.resource.size < 8 * 1024 * 1024 && request.resource.contentType.matches('image/.*');
     }
     match /stores/{storeId}/invoices/{fileName} {
       allow read: if true;
       allow write: if true && request.resource.size < 12 * 1024 * 1024 && request.resource.contentType.matches('image/.*');
     }
     ```
   - *Impact*: `allow write: if true` permits any unauthenticated user on the internet to upload, overwrite, or delete product images and invoice scans for ANY store ID without authentication or authorization.

2. **Global Un-Scoped `/products` Security Flaw**
   - *Observation*: In `firestore.rules` (lines 125–134):
     ```javascript
     match /products/{productId} {
       allow read: if isSignedIn();
       allow create, update: if isSignedIn()
         && isNonEmptyString(request.resource.data.name)
         ...
     }
     ```
   - *Impact*: Any authenticated user (including basic buyers or trial users) can modify or corrupt global catalog product names, barcodes, and prices across the platform.

3. **Offline Customer Credit Synchronization Race Condition**
   - *Observation*: In `real_firestore_service.dart` (`saveInvoice` lines 780–795, `saveDeposit` lines 881–896):
     ```dart
     final prevCredit = (prev?['creditBalance'] as num?)?.toDouble() ?? 0;
     ref.set({'creditBalance': prevCredit + delta}, SetOptions(merge: true));
     ```
   - *Logic Chain*: When transactions occur offline, multiple local updates recalculate `creditBalance` based on stale cached `prevCredit`. Upon regaining connectivity, Firestore writes the absolute calculated `creditBalance` value instead of performing an atomic delta update (`FieldValue.increment(delta)`).
   - *Impact*: Concurrent or offline credit transactions overwrite each other, leading to inaccurate customer ledger balances and loss of financial data integrity.

---

## 3. Summary Matrix of Findings

| Module | Category | Issue Description | Severity | Target File & Lines |
| :--- | :--- | :--- | :--- | :--- |
| **5. Multi-Store** | Security / Bug | `joinStore` payload omits passcode/ownerUid required by rules; join fails with `PERMISSION_DENIED` | High | `firestore.rules:177-181`, `real_firestore_service.dart:343` |
| **5. Multi-Store** | Access Control | Passcode update rule allows arbitrary field modifications during store join | High | `firestore.rules:177-181` |
| **5. Multi-Store** | Access Control | Co-members missing from `businesses/{id}/members` are blocked from master business catalog | Medium | `real_firestore_service.dart:336`, `firestore.rules:119` |
| **6. Device Sharing** | Security | Store members can tamper with/overwrite any device record under `stores/{id}/devices` | Medium | `firestore.rules:188-190`, `real_firestore_service.dart:354` |
| **7. Vendors** | Bug / Rules | Missing security rule for `stores/{id}/vendor_invoices` causes total vendor invoice failure | High | `firestore.rules:248-253` |
| **7. Vendors** | Bug / Rules | Collection group query for `vendors` blocked; vendors denied access to client store info | High | `real_firestore_service.dart:1047`, `firestore.rules` |
| **7. Vendors** | Logic Bug | Phone numbers not normalized when linking vendors, breaking array queries | Medium | `vendors_manage_screen.dart:187` |
| **8. Security / Offline**| Security | `storage.rules` allows global unauthenticated read/write to product & invoice images | Critical | `storage.rules:6-17` |
| **8. Security / Offline**| Security | Global `/products/{id}` rules permit any signed-in user to mutate global catalog | High | `firestore.rules:125-134` |
| **8. Security / Offline**| Data Integrity | Client-side read-modify-write for customer `creditBalance` causes offline sync overwrites | High | `real_firestore_service.dart:786, 887` |

