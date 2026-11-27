/// Fixed inventory allocation math:
/// - Physical Store (POS) has access to **100%** of actual unreserved physical stock.
/// - Online Store (Customer App) can display and sell up to **75%** of physical stock.
/// - The remaining **25%** (`physicalReserve`) is strictly reserved for walk-in POS sales.
class InventoryAllocation {
  const InventoryAllocation._();

  /// Fixed 25% physical-only walk-in reserve rate (75% online cap / 100% POS access).
  static const double physicalReserveRate = 0.25;

  /// Fixed 30% physical low-stock alert rate relative to original stock.
  static const double lowStockAlertRate = 0.30;

  /// Calculates the 25% physical-only reserve from [totalStock].
  /// Rounds up (`ceil()`) so the physical store is always protected on odd quantities.
  /// Returns `0` when [totalStock] <= 0.
  static int calculatePhysicalReserve(int totalStock) {
    if (totalStock <= 0) return 0;
    return (totalStock * physicalReserveRate).ceil();
  }

  /// Calculates the 30% low-stock trigger quantity from [originalStock].
  static int calculateLowStockTrigger(int originalStock) {
    if (originalStock <= 0) return 0;
    return (originalStock * lowStockAlertRate).ceil();
  }

  /// Resolves the effective physical reserve for a product or variant.
  ///
  /// Uses [storedPhysicalReserve] when present (`>= 0`), or falls back to
  /// `calculatePhysicalReserve(totalStock)` for legacy documents that do not
  /// yet persist `physicalReserve`.
  static int resolvePhysicalReserve({
    required int totalStock,
    int? storedPhysicalReserve,
  }) {
    if (storedPhysicalReserve != null && storedPhysicalReserve >= 0) {
      return storedPhysicalReserve;
    }
    return calculatePhysicalReserve(totalStock);
  }

  /// Calculates unreserved physical stock (`max(0, totalStock - reservedStock)`).
  static int calculatePosAvailable({
    required int totalStock,
    int reservedStock = 0,
  }) {
    final int safeTotal = totalStock < 0 ? 0 : totalStock;
    final int safeReserved = reservedStock < 0 ? 0 : reservedStock;
    final int avail = safeTotal - safeReserved;
    return avail > 0 ? avail : 0;
  }

  /// Dynamically calculates online available stock:
  /// `max(0, availableStock - physicalReserve)` where
  /// `availableStock = max(0, totalStock - reservedStock)`.
  ///
  /// Online orders can never dip into `physicalReserve`. Once unreserved
  /// physical stock drops to or below `physicalReserve`, this returns `0`
  /// (Out of Stock online).
  static int calculateOnlineAvailable({
    required int totalStock,
    required int physicalReserve,
    int reservedStock = 0,
  }) {
    final int avail = calculatePosAvailable(
      totalStock: totalStock,
      reservedStock: reservedStock,
    );
    final int safeReserve = physicalReserve < 0 ? 0 : physicalReserve;
    final int online = avail - safeReserve;
    return online > 0 ? online : 0;
  }
}
