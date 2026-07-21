# Handoff Report — Explorer 2 (Code Review Modules 5–8)

## 1. Observation

Direct code review and static security analysis was performed across Modules 5–8 in the `pasale_register` project. Key evidence includes:

1. **`firestore.rules` (Lines 177–181)**:
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
   Cross-referenced with `lib/services/real_firestore_service.dart` (lines 343–346):
   ```dart
   await ref.update({
     'memberUids': FieldValue.arrayUnion([uid]),
   });
   ```
   *Observation*: Update payload lacks `passcode` and `ownerUid`, failing rule verification.

2. **`firestore.rules` Subcollections (Lines 248–253)**:
   ```javascript
   match /vendors/{vendorId} {
     allow read: if canAccessStore(storeId);
     allow create, update: if canAccessStore(storeId);
     allow delete: if false;
   }
   ```
   *Observation*: No rule exists for `vendor_invoices` subcollection, nor is there a collection group rule for `vendors` matching `streamStoresForVendor`.

3. **`storage.rules` (Lines 6–17)**:
   ```javascript
   match /stores/{storeId}/products/{fileName} {
     allow read: if true;
     allow write: if true && request.resource.size < 8 * 1024 * 1024 ...
   }
   ```
   *Observation*: Public unauthenticated read/write enabled for all storage buckets.

4. **`real_firestore_service.dart` Customer Credit Sync (Lines 786–795, 887–895)**:
   ```dart
   final prevCredit = (prev?['creditBalance'] as num?)?.toDouble() ?? 0;
   ref.set({'creditBalance': prevCredit + delta}, SetOptions(merge: true));
   ```
   *Observation*: Uses absolute calculated value overwrite instead of atomic `FieldValue.increment(delta)`.

---

## 2. Logic Chain

1. **Passcode Join & Permission Failure**:
   - `joinStore()` issues `ref.update({'memberUids': FieldValue.arrayUnion([uid])})`.
   - Firestore security rules evaluate the request against `allow update`.
   - The user is not yet owner/member (`isStoreMember` is false).
   - The fifth condition requires `request.resource.data.keys().hasAny(['passcode'])`.
   - Because `passcode` is missing from the update map, Firestore evaluates this condition to `false` and throws `PERMISSION_DENIED`.

2. **Vendor Invoicing Breakdown**:
   - Vendor app calls `saveVendorInvoice(invoice, storeId: storeId)`.
   - Target Firestore path is `stores/{storeId}/vendor_invoices/{id}`.
   - `firestore.rules` has no rule block matching `/vendor_invoices/{id}`.
   - Default security stance denies unconfigured subcollections -> `PERMISSION_DENIED` thrown.

3. **Offline Customer Credit Conflict**:
   - Device A creates an invoice offline; reads `prevCredit` (100), calculates `100 + 50 = 150`.
   - Device B receives deposit offline; reads `prevCredit` (100), calculates `100 - 30 = 70`.
   - Upon reconnection, whichever device syncs last overwrites the document field `creditBalance` with its local sum, ignoring the concurrent transaction. Using `FieldValue.increment(delta)` ensures atomic delta calculation regardless of sync order.

---

## 3. Caveats

- Functional runtime testing of real Firebase backend was limited by offline/CODE_ONLY mode; observations are strictly based on code inspection and static analysis of rule logic against service call parameter structures.
- Firebase Auth rules were evaluated assuming standard Security Rules Engine v2 execution behavior.

---

## 4. Conclusion

Modules 5–8 contain significant logic defects and critical security vulnerabilities:
1. Production security rules completely block Vendor Invoicing and Store Passcode Joining due to path omissions and missing payload fields.
2. `storage.rules` contains severe unauthenticated read/write permissions.
3. Offline customer credit synchronization risks balance corruption due to non-atomic client-side arithmetic.

---

## 5. Verification Method

To verify these findings:
1. Inspect `firestore.rules` and `storage.rules` against `lib/services/real_firestore_service.dart`.
2. Deploy `firestore.rules` to a test Firebase project and attempt:
   a. Joining a store via `joinStore` passcode flow.
   b. Streaming vendor stores via `streamStoresForVendor`.
   c. Creating a vendor invoice via `saveVendorInvoice`.
3. Perform anonymous POST requests to Firebase Storage buckets to confirm unauthenticated image write access.
