import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

Future<UserModel?> showAccountSwitcher(
  BuildContext context, {
  required UserModel owner,
}) => showDialog<UserModel>(
  context: context,
  builder: (_) => _AccountSwitcherDialog(owner: owner),
);

class _AccountSwitcherDialog extends StatelessWidget {
  const _AccountSwitcherDialog({required this.owner});

  final UserModel owner;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ganti Peran / Akun Pengguna'),
    content: SizedBox(
      width: 440,
      height: MediaQuery.sizeOf(context).height * 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pilih akun untuk menguji fitur Owner, Kasir, atau Staf Stok:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          _AccountTile(
            name: owner.name,
            role: 'Owner / Pemilik',
            selected: true,
            onTap: () => Navigator.pop(context, owner),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: StreamBuilder<List<UserModel>>(
              stream: UserService().watchEmployees(owner.businessId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat akun: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final employees = snapshot.data!
                    .where(
                      (employee) =>
                          employee.role == roleCashier ||
                          employee.role == roleStock,
                    )
                    .toList();
                if (employees.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Belum ada akun kasir atau staf stok.'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: employees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    return _AccountTile(
                      name: employee.name,
                      role: employee.role == roleCashier
                          ? 'Kasir (POS)'
                          : 'Staf Manajemen Stok',
                      selected: false,
                      enabled: employee.isActive && !employee.isBanned,
                      onTap: () => Navigator.pop(context, employee),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.name,
    required this.role,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String name;
  final String role;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? colorScheme.primaryContainer : null,
      child: ListTile(
        enabled: enabled,
        title: Text(name),
        subtitle: Text(
          enabled ? role : '$role · Nonaktif',
          style: TextStyle(color: colorScheme.primary),
        ),
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
