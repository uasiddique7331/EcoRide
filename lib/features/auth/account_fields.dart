import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';

/// Shared personal-information fields for both registration forms (FR-01, FR-03).
class AccountFields extends StatelessWidget {
  const AccountFields({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirm,
  });

  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController password;
  final TextEditingController confirm;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppTextField(
        controller: name,
        label: 'Full name',
        icon: Icons.person_outline_rounded,
        validator: Validators.fullName,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: email,
        label: 'Email',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        validator: Validators.email,
        autofillHints: const [AutofillHints.email],
      ),
      const SizedBox(height: 14),
      AppTextField(
        controller: phone,
        label: 'Mobile number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: Validators.phone,
        maxLength: 16,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]'))],
        autofillHints: const [AutofillHints.telephoneNumber],
      ),
      const SizedBox(height: 14),
      PasswordField(controller: password, validator: Validators.password),
      const SizedBox(height: 14),
      PasswordField(
        controller: confirm,
        label: 'Confirm password',
        validator: Validators.confirmPassword(() => password.text),
        textInputAction: TextInputAction.done,
      ),
    ]);
  }
}
