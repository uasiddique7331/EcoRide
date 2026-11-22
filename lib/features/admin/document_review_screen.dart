import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launcher.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../providers/providers.dart';

/// UC-12: view a document and approve or reject it.
class DocumentReviewScreen extends ConsumerStatefulWidget {
  const DocumentReviewScreen({super.key, required this.documentId});
  final String documentId;
  @override
  ConsumerState<DocumentReviewScreen> createState() => _State();
}

class _State extends ConsumerState<DocumentReviewScreen> {
  Future<String>? _url;
  String? _loadedPath;
  bool _busy = false;

  Future<void> _review(bool approve) async {
    final doc = ref.read(documentProvider(widget.documentId)).value;
    final admin = ref.read(currentUserProvider);
    if (doc == null || admin == null) return;
    String? reason;
    if (!approve) {
      reason = await promptText(context, title: 'Reject document', hint: 'Reason shown to the user', confirmLabel: 'Reject');
      if (reason == null || !mounted) return;
    } else {
      final ok = await confirmDialog(context, title: 'Approve document?', message: '${doc.type.label} of ${doc.ownerName} will be marked as approved.', confirmLabel: 'Approve');
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    await runAction(
      context,
      () => ref.read(adminRepositoryProvider).reviewDocument(document: doc, admin: admin, approve: approve, rejectionReason: reason),
      success: approve ? 'Document approved.' : 'Document rejected.',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(documentProvider(widget.documentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review document')),
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(documentProvider(widget.documentId)),
        data: (d) {
          if (d == null) return const EmptyState(icon: Icons.search_off, title: 'Document not found');
          if (_loadedPath != d.storagePath) {
            _loadedPath = d.storagePath;
            _url = ref.read(storageRepositoryProvider).downloadUrl(d.storagePath);
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            SectionCard(
              title: d.type.label,
              trailing: docStatusChip(d.status),
              child: Column(children: [
                InfoRow(icon: Icons.person_outline, label: 'Owner', value: '${d.ownerName} (${d.ownerRole.label})'),
                InfoRow(icon: Icons.mail_outline, label: 'Email', value: d.ownerEmail),
                InfoRow(icon: Icons.attach_file, label: 'File', value: '${d.fileName} • ${Fmt.fileSize(d.fileSize)}'),
                InfoRow(icon: Icons.upload_outlined, label: 'Uploaded', value: Fmt.dateTime(d.uploadedAt)),
                if (d.reviewedByName != null) InfoRow(icon: Icons.verified_user_outlined, label: 'Reviewed by', value: '${d.reviewedByName} • ${Fmt.dateTime(d.reviewedAt)}'),
                if ((d.rejectionReason ?? '').isNotEmpty) InfoRow(icon: Icons.report_gmailerrorred_outlined, label: 'Reason', value: d.rejectionReason!, valueColor: AppColors.danger),
              ]),
            ),
            FutureBuilder<String>(
              future: _url,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 220, child: LoadingView());
                if (snap.hasError) return ErrorState(error: snap.error!, onRetry: () => setState(() => _loadedPath = null)); // A2
                final url = snap.data!;
                if (d.isPdf) {
                  return SectionCard(
                    child: Column(children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 56, color: AppColors.danger),
                      const SizedBox(height: 8),
                      FilledButton.icon(onPressed: () => openUrl(context, url), icon: const Icon(Icons.open_in_new), label: const Text('Open PDF')),
                    ]),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    child: Image.network(url, fit: BoxFit.contain, loadingBuilder: (c, w, p) => p == null ? w : const SizedBox(height: 220, child: LoadingView()), errorBuilder: (c, e, s) => ErrorState(error: friendlyError(e))),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (d.status == DocStatus.pending || d.status != DocStatus.approved)
              Row(children: [
                Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)), onPressed: _busy || d.status == DocStatus.rejected ? null : () => _review(false), child: const Text('Reject'))),
                const SizedBox(width: 12),
                Expanded(child: PrimaryButton(label: 'Approve', loading: _busy, onPressed: () => _review(true))),
              ]),
          ]);
        },
      ),
    );
  }
}
