import 'package:flutter/material.dart';

class AppKeys {
  static const Key storeNameInput = Key('storeNameInput');
  static const Key activateStoreButton = Key('activateStoreButton');
  static const Key productSearchInput = Key('productSearchInput');
  static const Key addProductButton = Key('addProductButton');
  static const Key scanBarcodeButton = Key('scanBarcodeButton');
  static const Key incrementQtyButton = Key('incrementQtyButton');
  static const Key decrementQtyButton = Key('decrementQtyButton');
  static const Key paidCreditToggle = Key('paidCreditToggle');
  static const Key checkoutButton = Key('checkoutButton');
  static const Key shareReceiptButton = Key('shareReceiptButton');
  static const Key costPriceInput = Key('costPriceInput');
  static const Key markupInput = Key('markupInput');
  static const Key saveInvoiceProductButton = Key('saveInvoiceProductButton');

  // Navigation Keys for routing/testing
  static const Key navToActivation = Key('navToActivation');
  static const Key navToCatalog = Key('navToCatalog');
  static const Key navToCheckout = Key('navToCheckout');
  static const Key navToInvoiceIngestor = Key('navToInvoiceIngestor');

  // Additional keys for input/output verification
  static const Key storeIdInput = Key('storeIdInput');
  static const Key deviceIdInput = Key('deviceIdInput');
  static const Key deviceMetadataInput = Key('deviceMetadataInput');
  static const Key registerDeviceButton = Key('registerDeviceButton');
  static const Key statusText = Key('statusText');

  static const Key productNameInput = Key('productNameInput');
  static const Key productBarcodeInput = Key('productBarcodeInput');
  static const Key productSellingPriceInput = Key('productSellingPriceInput');
  static const Key productCostPriceInput = Key('productCostPriceInput');
  static const Key productMarkupInput = Key('productMarkupInput');
  static const Key saveProductButton = Key('saveProductButton');

  static const Key customerPhoneInput = Key('customerPhoneInput');
  static const Key captureInvoiceButton = Key('captureInvoiceButton');
  static const Key searchBarcodeResult = Key('searchBarcodeResult');
  
  static const Key cartStatus = Key('cartStatus');
  static const Key paidCreditStatus = Key('paidCreditStatus');
  static const Key doneScanningButton = Key('doneScanningButton');

  static const Key navToCameraScope = Key('navToCameraScope');
  static const Key cameraScopeTier = Key('cameraScopeTier');
  static const Key saveCameraScopeButton = Key('saveCameraScopeButton');

  static const Key registerUnknownProductDialog =
      Key('registerUnknownProductDialog');
  static const Key registerProductNameInput = Key('registerProductNameInput');
  static const Key registerProductPriceInput = Key('registerProductPriceInput');
  static const Key registerProductCostInput = Key('registerProductCostInput');
  static const Key registerProductSaveButton = Key('registerProductSaveButton');
  static const Key registerProductSkipButton = Key('registerProductSkipButton');
}
