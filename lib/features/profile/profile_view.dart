import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launcher.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_picker_field.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/app_user.dart';
import '../../models/document_record.dart';
import '../../models/enums.dart';
import '../../providers/providers.dart';

/// Profile tab shared by passengers, drivers and administrators
/// (FR-08, FR-13, FR-14, FR-20, FR-05, UC-15).
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const LoadingView();

    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Header(user: user),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Account details',
            trailing: TextButton.icon(
              onPressed: () => _editProfile(context, ref, user),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            child: Column(children: [
              InfoRow(icon: Icons.person_outline, label: 'Name', value: user.fullName),
              InfoRow(icon: Icons.mail_outline, label: 'Email', value: user.email),
              InfoRow(icon: Icons.phone_outlined, label: 'Mobile', value: user.phone),
              InfoRow(icon: Icons.event_outlined, label: 'Member since', value: Fmt.date(user.createdAt)),
            ]),
          ),
          if (!user.isAdmin) _DocumentsCard(user: user),
          if (user.isDriver)
            SectionCard(
              onTap: () => context.push('/driver/vehicle'),
              child: const Row(children: [
                Icon(Icons.directions_car_outlined, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(child: Text('My vehicle', style: TextStyle(fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_right),
              ]),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
            onPressed: () => _logout(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(context, title: 'Log out?', message: 'You will need to log in again to use EcoRide.', confirmLabel: 'Log out');
    if (!ok || !context.mounted) return;
    ref.read(passengerTabProvider.notifier).set(0);
    ref.read(driverTabProvider.notifier).set(0);
    ref.read(adminTabProvider.notifier).set(0);
    await runAction(context, () => ref.read(authRepositoryProvider).signOut());
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref, AppUser user) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditProfileSheet(user: user),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(children: [
      const SizedBox(height: 8),
      Avatar(initials: Fmt.initials(user.fullName), size: 84),
      const SizedBox(height: 12),
      Text(user.fullName, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
        StatusChip(label: user.role.label, color: AppColors.primary, icon: Icons.badge_outlined),
        if (!user.isAdmin)
          user.isVerified
              ? const StatusChip(label: 'Verified', color: AppColors.success, icon: Icons.verified_rounded)
              : const StatusChip(label: 'Not verified yet', color: AppColors.warning, icon: Icons.hourglass_top_rounded),
      ]),
    ]);
  }
}

class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(myDocumentsProvider);
    return SectionCard(
      title: 'Verification documents',
      child: docs.when(
        loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        error: (e, _) => Text(friendlyError(e)),
        data: (list) {
          if (list.isEmpty) return const Text('No documents uploaded.');
          return Column(children: [for (final d in list) _DocTile(doc: d)]);
        },
      ),
    );
  }
}

class _DocTile extends ConsumerStatefulWidget {
  const _DocTile({required this.doc});
  final DocumentRecord doc;

  @override
  ConsumerState<_DocTile> createState() => _DocTileState();
}

class _DocTileState extends ConsumerState<_DocTile> {
  bool _busy = false;

  Future<void> _view() async {
    setState(() => _busy = true);
    try {
      final url = await ref.read(storageRepositoryProvider).downloadUrl(widget.doc.storagePath);
      if (mounted) await openUrl(context, url);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reupload() async {
    final file = await pickDocument(context);
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    await runAction(
      context,
      () => ref.read(documentRepositoryProvider).resubmit(existing: widget.doc, file: file),
      success: 'Document re-submitted for review.',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(d.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.type.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          docStatusChip(d.status),
        ]),
        if (d.status == DocStatus.rejected && (d.rejectionReason ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: NoticeBanner(message: 'Rejected: ${d.rejectionReason}', color: AppColors.danger, icon: Icons.report_gmailerrorred_outlined),
          ),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (_busy)
            const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            TextButton(onPressed: _view, child: const Text('View')),
            if (d.status == DocStatus.rejected) TextButton(onPressed: _reupload, child: const Text('Upload new')),
          ],
        ]),
      ]),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone);
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await runAction(
      context,
      () => ref.read(userRepositoryProvider).updateProfile(
            uid: widget.user.uid,
            fullName: _name.text,
            phone: Validators.normalizePhone(_phone.text),
          ),
      success: 'Profile updated.',
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Email and role cannot be changed.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          AppTextField(controller: _name, label: 'Full name', icon: Icons.person_outline, validator: Validators.fullName, textCapitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          AppTextField(controller: _phone, label: 'Mobile number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: Validators.phone, textInputAction: TextInputAction.done),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Save changes', loading: _loading, onPressed: _save),
        ]),
      ),
    );
  }
}
