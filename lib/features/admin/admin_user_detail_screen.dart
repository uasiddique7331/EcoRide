import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/app_user.dart';
import '../../models/enums.dart';
import '../../providers/providers.dart';

/// UC-13: view a user and restrict / deactivate / re-activate the account.
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});
  final String userId;
  @override
  ConsumerState<AdminUserDetailScreen> createState() => _State();
}

class _State extends ConsumerState<AdminUserDetailScreen> {
  bool _busy = false;

  Future<void> _set(AppUser u, AccountStatus status) async {
    final admin = ref.read(currentUserProvider);
    if (admin == null) return;
    String? reason;
    if (status != AccountStatus.active) {
      reason = await promptText(context, title: '${status == AccountStatus.restricted ? 'Restrict' : 'Deactivate'} account', hint: 'Reason', confirmLabel: 'Confirm');
      if (reason == null || !mounted) return;
    }
    setState(() => _busy = true);
    await runAction(context, () => ref.read(adminRepositoryProvider).setAccountStatus(target: u, admin: admin, status: status, reason: reason), success: 'Account is now ${status.label.toLowerCase()}.');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userByIdProvider(widget.userId));
    return Scaffold(
      appBar: AppBar(title: const Text('User')),
      body: AsyncView<AppUser?>(
        value: async,
        onRetry: () => ref.invalidate(userByIdProvider(widget.userId)),
        data: (u) {
          if (u == null) return const EmptyState(icon: Icons.person_off_outlined, title: 'User not found');
          final docs = ref.watch(documentsByOwnerProvider(u.uid)).value ?? const [];
          final vehicle = u.isDriver ? ref.watch(vehicleByOwnerProvider(u.uid)).value : null;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            SectionCard(
              title: u.fullName,
              trailing: accountStatusChip(u.status),
              child: Column(children: [
                InfoRow(icon: Icons.badge_outlined, label: 'Role', value: u.role.label),
                InfoRow(icon: Icons.mail_outline, label: 'Email', value: u.email),
                InfoRow(icon: Icons.phone_outlined, label: 'Mobile', value: u.phone),
                InfoRow(icon: Icons.verified_outlined, label: 'Verified', value: u.isVerified ? 'Yes' : 'No'),
                InfoRow(icon: Icons.event_outlined, label: 'Joined', value: Fmt.date(u.createdAt)),
              ]),
            ),
            if (vehicle != null)
              SectionCard(title: 'Vehicle', child: Column(children: [
                InfoRow(icon: Icons.directions_car_outlined, label: 'Vehicle', value: vehicle.summary),
                InfoRow(icon: Icons.event_seat_outlined, label: 'Capacity', value: '${vehicle.capacity} seats'),
                InfoRow(icon: Icons.person_outline, label: 'Owner', value: vehicle.ownerName),
              ])),
            SectionCard(
              title: 'Documents',
              child: docs.isEmpty
                  ? const Text('No documents.')
                  : Column(children: [
                      for (final d in docs)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(d.type.label),
                          trailing: docStatusChip(d.status),
                          onTap: () => context.push('/admin/document/${d.id}'),
                        ),
                    ]),
            ),
            if (!u.isAdmin) ...[
              if (u.status != AccountStatus.active) PrimaryButton(label: 'Re-activate account', loading: _busy, onPressed: () => _set(u, AccountStatus.active)),
              if (u.status == AccountStatus.active) ...[
                OutlinedButton.icon(onPressed: _busy ? null : () => _set(u, AccountStatus.restricted), icon: const Icon(Icons.block), label: const Text('Restrict account')),
                const SizedBox(height: 10),
                OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)), onPressed: _busy ? null : () => _set(u, AccountStatus.deactivated), icon: const Icon(Icons.person_off_outlined), label: const Text('Deactivate account')),
              ],
            ],
          ]);
        },
      ),
    );
  }
}
