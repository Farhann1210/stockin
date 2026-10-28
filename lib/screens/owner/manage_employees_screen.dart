import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/business_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../common.dart';

class ManageEmployeesScreen extends StatelessWidget {
  const ManageEmployeesScreen({
    super.key,
    required this.business,
    required this.owner,
  });

  final BusinessModel business;
  final UserModel owner;

  Future<void> _add(BuildContext context, String role) async {
    if (business.membershipStatus != 'active') {
      showAppMessage(context, 'Membership belum aktif.', error: true);
      return;
    }
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(role == roleCashier ? 'Tambah Kasir' : 'Tambah Staf Stok'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nama wajib diisi.'
                    : null,
              ),
              TextFormField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || !value.contains('@')
                    ? 'Email tidak valid.'
                    : null,
              ),
              TextFormField(
                controller: password,
                decoration: const InputDecoration(
                  labelText: 'Kata sandi sementara',
                ),
                obscureText: true,
                validator: (value) => value == null || value.length < 6
                    ? 'Minimal 6 karakter.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Buat Akun'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) {
      name.dispose();
      email.dispose();
      password.dispose();
      return;
    }

    try {
      final auth = AuthService();
      final credential = await auth.createEmployeeAuthUser(
        email: email.text,
        password: password.text,
      );
      final employeeUid = credential.user!.uid;
      try {
        await UserService().addEmployee(
          uid: employeeUid,
          businessId: business.id,
          name: name.text,
          role: role,
        );
      } catch (_) {
        await auth.deleteEmployeeAuthUser(employeeUid);
        rethrow;
      }
      if (context.mounted) {
        showAppMessage(context, 'Akun karyawan berhasil dibuat.');
      }
    } on FirebaseAuthException catch (error) {
      if (context.mounted) {
        showAppMessage(
          context,
          error.code == 'email-already-in-use'
              ? 'Email sudah digunakan.'
              : error.message ?? 'Gagal membuat akun.',
          error: true,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, error.toString(), error: true);
      }
    } finally {
      name.dispose();
      email.dispose();
      password.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kelola Karyawan')),
    floatingActionButton: PopupMenuButton<String>(
      tooltip: 'Tambah karyawan',
      icon: const Icon(Icons.person_add_alt_1),
      onSelected: (role) => _add(context, role),
      itemBuilder: (context) => const [
        PopupMenuItem(value: roleCashier, child: Text('Tambah Kasir')),
        PopupMenuItem(value: roleStock, child: Text('Tambah Staf Stok')),
      ],
    ),
    body: StreamBuilder<List<UserModel>>(
      stream: UserService().watchEmployees(business.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Gagal memuat karyawan: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final employees = snapshot.data!;
        if (employees.isEmpty) {
          return const Center(child: Text('Belum ada karyawan.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            return Card(
              child: SwitchListTile(
                title: Text(employee.name),
                subtitle: Text(
                  employee.role == roleCashier ? 'Kasir' : 'Manajemen Stok',
                ),
                value: employee.isActive,
                onChanged: (value) async {
                  try {
                    await UserService().setEmployeeActive(
                      employee: employee,
                      isActive: value,
                    );
                  } catch (error) {
                    if (context.mounted) {
                      showAppMessage(context, error.toString(), error: true);
                    }
                  }
                },
              ),
            );
          },
        );
      },
    ),
  );
}
