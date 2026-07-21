import 'package:flutter/material.dart';

import '../models/user_role.dart';

class AppKeys {
  // --- Landing / role ---
  static const Key landingScreen = Key('landingScreen');
  static const Key roleToggleBar = Key('roleToggleBar');
  static const Key continueAsRoleButton = Key('continueAsRoleButton');
  static Key roleOption(UserRole role) => Key('roleOption_${role.name}');
  static const Key languagePicker = Key('languagePicker');
  static Key languageOption(String code) => Key('languageOption_$code');
  static const Key languageSettingsTile = Key('languageSettingsTile');

  // --- OTP / Facebook auth ---
  static const Key otpAuthScreen = Key('otpAuthScreen');
  static const Key phoneInput = Key('phoneInput');
  static const Key otpInput = Key('otpInput');
  static const Key sendOtpButton = Key('sendOtpButton');
  static const Key verifyOtpButton = Key('verifyOtpButton');
  static const Key facebookSignInButton = Key('facebookSignInButton');

  // --- Training ---
  static const Key trainingScreen = Key('trainingScreen');
  static const Key trainingConsentCheckbox = Key('trainingConsentCheckbox');
  static const Key startTrainingButton = Key('startTrainingButton');
  static const Key skipTrainingButton = Key('skipTrainingButton');
  static const Key finishTrainingButton = Key('finishTrainingButton');

  // --- Activation / store setup ---
  static const Key storeNameInput = Key('storeNameInput');
  static const Key activateStoreButton = Key('activateStoreButton');
  static const Key storeIdInput = Key('storeIdInput');
  static const Key deviceIdInput = Key('deviceIdInput');
  static const Key deviceMetadataInput = Key('deviceMetadataInput');
  static const Key registerDeviceButton = Key('registerDeviceButton');
  static const Key statusText = Key('statusText');

  // --- Catalog / products ---
  static const Key productSearchInput = Key('productSearchInput');
  static const Key addProductButton = Key('addProductButton');
  static const Key productNameInput = Key('productNameInput');
  static const Key productBarcodeInput = Key('productBarcodeInput');
  static const Key productSellingPriceInput = Key('productSellingPriceInput');
  static const Key productCostPriceInput = Key('productCostPriceInput');
  static const Key productMarkupInput = Key('productMarkupInput');
  static const Key saveProductButton = Key('saveProductButton');

  // --- Checkout / cart ---
  static const Key scanBarcodeButton = Key('scanBarcodeButton');
  static const Key incrementQtyButton = Key('incrementQtyButton');
  static const Key decrementQtyButton = Key('decrementQtyButton');
  static const Key paidCreditToggle = Key('paidCreditToggle');
  static const Key checkoutButton = Key('checkoutButton');
  static const Key shareReceiptButton = Key('shareReceiptButton');
  static const Key customerPhoneInput = Key('customerPhoneInput');
  static const Key cartStatus = Key('cartStatus');
  static const Key paidCreditStatus = Key('paidCreditStatus');
  static const Key doneScanningButton = Key('doneScanningButton');
  static const Key markPaidButton = Key('markPaidButton');
  static const Key markCreditButton = Key('markCreditButton');

  // --- Invoice ingestor ---
  static const Key costPriceInput = Key('costPriceInput');
  static const Key markupInput = Key('markupInput');
  static const Key saveInvoiceProductButton = Key('saveInvoiceProductButton');
  static const Key captureInvoiceButton = Key('captureInvoiceButton');
  static const Key searchBarcodeResult = Key('searchBarcodeResult');

  // --- Camera scope ---
  static const Key navToCameraScope = Key('navToCameraScope');
  static const Key cameraScopeTier = Key('cameraScopeTier');
  static const Key saveCameraScopeButton = Key('saveCameraScopeButton');

  // --- Unknown product registration ---
  static const Key registerUnknownProductDialog =
      Key('registerUnknownProductDialog');
  static const Key registerProductNameInput = Key('registerProductNameInput');
  static const Key registerProductPriceInput = Key('registerProductPriceInput');
  static const Key registerProductCostInput = Key('registerProductCostInput');
  static const Key registerProductSaveButton = Key('registerProductSaveButton');
  static const Key registerProductSkipButton = Key('registerProductSkipButton');
  static const Key registerProductPhotoButton = Key('registerProductPhotoButton');
  static const Key registerProductPhotoPreview =
      Key('registerProductPhotoPreview');
  static const Key registerProductNotesInput = Key('registerProductNotesInput');
  static const Key registerProductBarcodeInput =
      Key('registerProductBarcodeInput');
  static const Key registerProductScanBarcodeButton =
      Key('registerProductScanBarcodeButton');
  static const Key addOpenItemButton = Key('addOpenItemButton');
  static const Key catalogProductTile = Key('catalogProductTile');

  // Manual invoice
  static const Key manualInvoiceScreen = Key('manualInvoiceScreen');
  static const Key manualInvoiceDateField = Key('manualInvoiceDateField');
  static const Key manualInvoiceTotalInput = Key('manualInvoiceTotalInput');
  static const Key manualInvoicePhoneInput = Key('manualInvoicePhoneInput');
  static const Key manualInvoiceNotesInput = Key('manualInvoiceNotesInput');
  static const Key manualInvoicePaidCreditToggle =
      Key('manualInvoicePaidCreditToggle');
  static const Key manualInvoiceSendButton = Key('manualInvoiceSendButton');
  static const Key invoicesListScreen = Key('invoicesListScreen');
  static const Key invoiceTotalsBar = Key('invoiceTotalsBar');
  static const Key customerSearchInput = Key('customerSearchInput');
  static const Key creditCustomerNameInput = Key('creditCustomerNameInput');
  static const Key creditCustomerPhoneInput = Key('creditCustomerPhoneInput');
  static const Key creditCustomerEmailInput = Key('creditCustomerEmailInput');
  static const Key creditCustomerConfirmButton =
      Key('creditCustomerConfirmButton');

  // Scanner mode
  static const Key scanModeBarcode = Key('scanModeBarcode');
  static const Key scanModePriceTag = Key('scanModePriceTag');

  // --- Navigation (legacy horizontal nav + shells) ---
  static const Key navToActivation = Key('navToActivation');
  static const Key navToCatalog = Key('navToCatalog');
  static const Key navToCheckout = Key('navToCheckout');
  static const Key navToInvoiceIngestor = Key('navToInvoiceIngestor');
  static const Key navToDashboard = Key('navToDashboard');
  static const Key navToVendors = Key('navToVendors');
  static const Key navToCustomers = Key('navToCustomers');
  static const Key navToScanner = Key('navToScanner');

  // --- Profile menu ---
  static const Key profileMenuButton = Key('profileMenuButton');
  static Key menuAction(String name) => Key('menuAction_$name');
  static const Key logoutButton = Key('logoutButton');

  // --- Help chat ---
  static const Key helpChatButton = Key('helpChatButton');
  static const Key helpChatSheet = Key('helpChatSheet');
  static const Key helpChatInput = Key('helpChatInput');
  static const Key helpChatSend = Key('helpChatSend');
  static const Key helpChatMic = Key('helpChatMic');

  // --- Role homes ---
  static const Key storeOwnerShell = Key('storeOwnerShell');
  static const Key vendorShell = Key('vendorShell');
  static const Key buyerShell = Key('buyerShell');
  static const Key dashboardScreen = Key('dashboardScreen');
  static const Key customersScreen = Key('customersScreen');
  static const Key vendorsScreen = Key('vendorsScreen');
  static const Key premiumScreen = Key('premiumScreen');
  static const Key settingsScreen = Key('settingsScreen');
  static const Key profileScreen = Key('profileScreen');
}
