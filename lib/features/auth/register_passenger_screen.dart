import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_picker_field.dart';
import '../../providers/providers.dart';
import '../../repositories/storage_repository.dart';
import 'account_fields.dart';

/// UC-01: Register as a passenger.
class RegisterPassengerScreen extends ConsumerStatefulWidget {
  const RegisterPassengerScreen({super.key});

  @override
  ConsumerState<RegisterPassengerScreen> createState() => _RegisterPassengerScreenState();
}

class _RegisterPassengerScreenState extends ConsumerState<RegisterPassengerScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  PickedUpload? _cnic;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return; // A1, A2, A4
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(registrationBusyProvider.notifier).set(true);
    try {
      await ref.read(authRepositoryProvider).registerPassenger(
            fullName: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
            cnic: _cnic!,
          );
      messenger.showSnackBar(const SnackBar(
        content: Text('Registration successful! Your CNIC is pending admin review.'),
        backgroundColor: AppColors.primaryDark,
      ));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e)); // A3, A5, A6
    } finally {
      ref.read(registrationBusyProvider.notifier).set(false);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passenger registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_error != null) ...[
                NoticeBanner(
                  message: _error!,
                  color: AppColors.danger,
                  icon: Icons.error_outline,
                  action: _error!.contains('already exists')
                      ? TextButton(onPressed: () => context.go('/login'), child: const Text('Log in'))
                      : null,
                ),
              ],
              AccountFields(name: _name, email: _email, phone: _phone, password: _password, confirm: _confirm),
              const SizedBox(height: 24),
              Text('Identity verification', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Upload a clear photo or PDF of your CNIC. An administrator will review it.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              DocumentPickerField(
                label: 'CNIC / identity document',
                hint: 'JPG, PNG or PDF • max 5 MB',
                onChanged: (f) => _cnic = f,
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Create passenger account', loading: _loading, onPressed: _submit),
            ]),
          ),
        ),
      ),
    );
  }
}
