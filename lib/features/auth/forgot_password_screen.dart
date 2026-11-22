import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../providers/providers.dart';

/// FR-06: password recovery through Firebase Authentication.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _sent
              ? Column(children: [
                  const SizedBox(height: 32),
                  const Icon(Icons.mark_email_read_outlined, size: 72, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text('Check your inbox', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('If an account exists for ${_email.text.trim()}, a password reset link has been sent.', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  OutlinedButton(onPressed: () => context.pop(), child: const Text('Back to login')),
                ])
              : Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Enter your registered email and we'll send you a link to set a new password."),
                    const SizedBox(height: 20),
                    if (_error != null) NoticeBanner(message: _error!, color: AppColors.danger, icon: Icons.error_outline),
                    AppTextField(
                      controller: _email,
                      label: 'Email',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(label: 'Send reset link', loading: _loading, onPressed: _submit),
                  ]),
                ),
        ),
      ),
    );
  }
}
