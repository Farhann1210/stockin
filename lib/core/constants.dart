const businessesCollection = 'businesses';
const usersCollection = 'users';
const productsCollection = 'products';
const transactionsCollection = 'transactions';
const stockLogsCollection = 'stock_logs';
const membershipPaymentsCollection = 'membership_payments';
const supportRequestsCollection = 'support_requests';
const maxMembershipProofImageBytes = 5 * 1024 * 1024;

class MembershipTier {
  const MembershipTier({
    required this.id,
    required this.price,
    required this.durationMonths,
    required this.durationLabel,
    required this.cashierLimit,
    required this.stockLimit,
  });

  final String id;
  final int price;
  final int durationMonths;
  final String durationLabel;
  final int cashierLimit;
  final int stockLimit;
}

const membershipTiers = <MembershipTier>[
  MembershipTier(
    id: '50k',
    price: 50000,
    durationMonths: 1,
    durationLabel: '1 bulan',
    cashierLimit: 2,
    stockLimit: 2,
  ),
  MembershipTier(
    id: '250k',
    price: 250000,
    durationMonths: 6,
    durationLabel: '6 bulan',
    cashierLimit: 6,
    stockLimit: 6,
  ),
  MembershipTier(
    id: '400k',
    price: 400000,
    durationMonths: 12,
    durationLabel: '1 tahun',
    cashierLimit: 20,
    stockLimit: 20,
  ),
];

MembershipTier? membershipTierForId(String id) {
  for (final tier in membershipTiers) {
    if (tier.id == id) return tier;
  }
  return null;
}

String membershipDurationLabel(String tierId) =>
    membershipTierForId(tierId)?.durationLabel ??
    switch (tierId) {
      '100k' => '6 bulan',
      '200k' => '1 tahun',
      _ => 'durasi tidak diketahui',
    };

DateTime addCalendarMonths(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(
    year,
    month,
    date.day > lastDay ? lastDay : date.day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

int convertStockToPieces({
  required int quantity,
  required String unit,
  required int piecesPerPack,
}) {
  if (quantity < 0) {
    throw ArgumentError.value(quantity, 'quantity', 'Tidak boleh negatif.');
  }
  if (unit != 'pcs' && unit != 'dus') {
    throw ArgumentError.value(unit, 'unit', 'Satuan harus pcs atau dus.');
  }
  if (piecesPerPack < 1 || piecesPerPack > 100000) {
    throw ArgumentError.value(piecesPerPack, 'piecesPerPack');
  }
  final pieces = unit == 'dus' ? quantity * piecesPerPack : quantity;
  if (pieces > 100000000) {
    throw ArgumentError.value(
      quantity,
      'quantity',
      'Jumlah stok terlalu besar.',
    );
  }
  return pieces;
}

const roleOwner = 'owner';
const roleCashier = 'kasir';
const roleStock = 'staf_stok';
const roleAdmin = 'admin';
