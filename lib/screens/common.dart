import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatRupiah(num amount) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(amount);

String formatMembershipEndDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

Future<void> confirmSignOut(
  BuildContext context,
  Future<void> Function() signOut,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keluar dari Stokin?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
  if (accepted == true) await signOut();
}
