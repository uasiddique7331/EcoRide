import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return; // UC-03 A3
    FocusScope.of(context).unfocus();
    ref.read(authNoticeProvider.notifier).set(null);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _password.text);
      // The router redirects to the role dashboard (FR-07).
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(authNoticeProvider);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome back', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              const Text('Log in to continue your journey.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 24),
              if (notice != null) NoticeBanner(message: notice, color: AppColors.danger, icon: Icons.block_rounded),
              if (_error != null) NoticeBanner(message: _error!, color: AppColors.danger, icon: Icons.error_outline),
              AppTextField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?')),
              ),
              const SizedBox(height: 8),
              PrimaryButton(label: 'Log in', loading: _loading, onPressed: _submit),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Don't have an account?"),
                TextButton(onPressed: () => context.push('/register'), child: const Text('Register')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
