/// App persona selected on the landing page.
enum UserRole {
  storeOwner,
  vendor,
  buyer,
}

extension UserRoleX on UserRole {
  String get storageValue => name;

  String get label {
    switch (this) {
      case UserRole.storeOwner:
        return 'Store Owner';
      case UserRole.vendor:
        return 'Vendor';
      case UserRole.buyer:
        return 'Buyer';
    }
  }

  String get shortLabel {
    switch (this) {
      case UserRole.storeOwner:
        return 'Store';
      case UserRole.vendor:
        return 'Vendor';
      case UserRole.buyer:
        return 'Buyer';
    }
  }

  static UserRole? fromStorage(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    // Back-compat aliases
    switch (value.toLowerCase()) {
      case 'store_owner':
      case 'storeowner':
      case 'owner':
        return UserRole.storeOwner;
      case 'vendor':
        return UserRole.vendor;
      case 'buyer':
      case 'customer':
        return UserRole.buyer;
      default:
        return null;
    }
  }
}
