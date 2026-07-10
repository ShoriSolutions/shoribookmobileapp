/// Mirrors the DB's business_role enum (OWNER/ADMIN/STAFF). Kept as a
/// plain enum (not int) since the DB value is the canonical string and
/// round-trips exactly.
enum BusinessRole {
  owner('OWNER'),
  admin('ADMIN'),
  staff('STAFF');

  final String value;
  const BusinessRole(this.value);

  static BusinessRole fromString(String value) => BusinessRole.values
      .firstWhere((r) => r.value == value, orElse: () => BusinessRole.staff);

  /// OWNER(2) > ADMIN(1) > STAFF(0) — mirrors the web's ROLE_ORDER used
  /// for minRole nav-item visibility checks.
  int get rank {
    switch (this) {
      case BusinessRole.owner:
        return 2;
      case BusinessRole.admin:
        return 1;
      case BusinessRole.staff:
        return 0;
    }
  }

  bool atLeast(BusinessRole minRole) => rank >= minRole.rank;
}
