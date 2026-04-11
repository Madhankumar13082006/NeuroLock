import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/contacts_provider.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsStreamProvider);
    final fs = ref.watch(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Trusted Contacts')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Contact'),
        onPressed: () => _showAddSheet(context, fs),
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_outline_rounded,
                        size: 48, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Text('No trusted contacts',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text(
                      'Add someone to approve your unlock requests\nvia WhatsApp',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      (data['name'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(data['name'] ?? '',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500)),
                  subtitle: Text(data['phone'] ?? '',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.danger),
                    onPressed: () => fs.deleteContact(docs[i].id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, fs) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add Trusted Contact',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 6),
            const Text('They will receive unlock requests via WhatsApp',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon:
                    Icon(Icons.person_rounded, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'WhatsApp Number (e.g. +919876543210)',
                prefixIcon:
                    Icon(Icons.phone_rounded, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    phoneCtrl.text.trim().isEmpty) return;
                await fs.addContact(
                    nameCtrl.text.trim(), phoneCtrl.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add Contact'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
