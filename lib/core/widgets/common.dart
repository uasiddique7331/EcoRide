import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../utils/app_exception.dart';

/// Primary action button with built-in loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: color == null ? null : FilledButton.styleFrom(backgroundColor: color),
      child: loading
          ? const SizedBox(
              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}

/// Colored pill for statuses (document / booking / trip / account).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: t.colorScheme.primaryContainer.withValues(alpha: 0.5), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: t.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Something went wrong',
      message: friendlyError(error),
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(140, 44)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Renders an [AsyncValue] with consistent loading / error / retry UI.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(error: e, onRetry: onRetry),
      );
}

/// White rounded card with soft border; used everywhere for grouping.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title, this.padding = const EdgeInsets.all(16), this.onTap, this.trailing});

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isLight = t.brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : t.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title != null) ...[
                Row(children: [
                  Expanded(child: Text(title!, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                  if (trailing != null) trailing!,
                ]),
                const SizedBox(height: 12),
              ],
              child,
            ]),
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value, this.valueColor, this.bold = false});

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        SizedBox(width: 104, child: Text(label, style: t.textTheme.bodyMedium?.copyWith(color: AppColors.muted))),
        Expanded(
          child: Text(value,
              style: t.textTheme.bodyMedium
                  ?.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: valueColor)),
        ),
      ]),
    );
  }
}

/// Inline coloured banner (info / warning / error).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.message, this.color = AppColors.warning, this.icon = Icons.info_outline, this.action});

  final String message;
  final Color color;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.35))),
        if (action != null) action!,
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, this.size = 44});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: t.colorScheme.primaryContainer,
      child: Text(initials, style: TextStyle(fontWeight: FontWeight.w800, color: t.colorScheme.onPrimaryContainer, fontSize: size * 0.36)),
    );
  }
}

// --- helpers -----------------------------------------------------------------

void showSnack(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.danger : AppColors.primaryDark,
    duration: Duration(seconds: error ? 5 : 3),
  ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
        FilledButton(
          style: FilledButton.styleFrom(
              minimumSize: const Size(100, 44), backgroundColor: destructive ? AppColors.danger : null),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Asks for free text (e.g. rejection / cancellation reason). Null = dismissed.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = 'Submit',
  bool requireText = true,
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final res = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          validator: (v) => requireText && (v == null || v.trim().isEmpty) ? 'A reason is required' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return res;
}

/// Runs [action], showing a success snack on completion or the friendly
/// error on failure. Returns true on success.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) showSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
    return false;
  }
}
