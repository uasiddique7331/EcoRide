import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/document_picker_field.dart';
import '../../models/vehicle.dart';
import '../../providers/providers.dart';
import '../../repositories/storage_repository.dart';
import 'account_fields.dart';

/// UC-02: Register as a driver together with exactly one vehicle.
class RegisterDriverScreen extends ConsumerStatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  ConsumerState<RegisterDriverScreen> createState() => _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends ConsumerState<RegisterDriverScreen> {
  final _keys = List.generate(3, (_) => GlobalKey<FormState>());
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _plate = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _capacity = TextEditingController(text: '3');
  String _type = vehicleTypes.first;
  PickedUpload? _cnic;
  PickedUpload? _vehicleDoc;
  int _step = 0;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm, _plate, _make, _model, _color, _capacity]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validate(int i) => _keys[i].currentState?.validate() ?? true;

  void _next() {
    if (!_validate(_step)) return;
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    for (var i = 0; i < 3; i++) {
      if (!_validate(i)) {
        setState(() => _step = i);
        return;
      }
    }
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    ref.read(registrationBusyProvider.notifier).set(true);
    try {
      await ref.read(authRepositoryProvider).registerDriver(
            fullName: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
            cnic: _cnic!,
            vehicleDoc: _vehicleDoc!,
            plate: _plate.text,
            make: _make.text,
            model: _model.text,
            color: _color.text,
            vehicleType: _type,
            capacity: int.parse(_capacity.text.trim()),
          );
      messenger.showSnackBar(const SnackBar(
        content: Text('Registration successful! Your documents are pending admin review.'),
        backgroundColor: AppColors.primaryDark,
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          if (_error!.contains('already exists')) _step = 0;
        });
      }
    } finally {
      ref.read(registrationBusyProvider.notifier).set(false);
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver registration')),
      body: SafeArea(
        child: Column(children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: NoticeBanner(
                message: _error!,
                color: AppColors.danger,
                icon: Icons.error_outline,
                action: _error!.contains('already exists')
                    ? TextButton(onPressed: () => context.go('/login'), child: const Text('Log in'))
                    : null,
              ),
            ),
          Expanded(
            child: Stepper(
              currentStep: _step,
              type: StepperType.vertical,
              onStepTapped: (i) {
                if (i < _step) setState(() => _step = i);
              },
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: _step == 2 ? 'Create driver account' : 'Continue',
                      loading: _loading,
                      onPressed: _next,
                    ),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    ),
                  ],
                ]),
              ),
              steps: [
                Step(
                  title: const Text('Personal details'),
                  isActive: _step >= 0,
                  state: _step > 0 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _keys[0],
                    child: AccountFields(name: _name, email: _email, phone: _phone, password: _password, confirm: _confirm),
                  ),
                ),
                Step(
                  title: const Text('Your vehicle'),
                  subtitle: const Text('One vehicle per driver account'),
                  isActive: _step >= 1,
                  state: _step > 1 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _keys[1],
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AppTextField(
                        controller: _plate,
                        label: 'Registration number',
                        icon: Icons.pin_outlined,
                        validator: Validators.plate,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _make,
                        label: 'Make (e.g. Toyota)',
                        icon: Icons.directions_car_outlined,
                        validator: (v) => Validators.required(v, 'Make'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _model,
                        label: 'Model (e.g. Corolla)',
                        icon: Icons.model_training_outlined,
                        validator: (v) => Validators.required(v, 'Model'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _color,
                        label: 'Colour',
                        icon: Icons.palette_outlined,
                        validator: (v) => Validators.required(v, 'Colour'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      const Text('Vehicle type', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final t in vehicleTypes)
                          ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
                      ]),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _capacity,
                        label: 'Passenger seats (excluding driver)',
                        icon: Icons.event_seat_outlined,
                        keyboardType: TextInputType.number,
                        validator: Validators.capacity,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 1,
                        textInputAction: TextInputAction.done,
                      ),
                    ]),
                  ),
                ),
                Step(
                  title: const Text('Documents'),
                  subtitle: Text('Reviewed by an admin • max ${AppConfig.maxUploadBytes ~/ (1024 * 1024)} MB each'),
                  isActive: _step >= 2,
                  content: Form(
                    key: _keys[2],
                    child: Column(children: [
                      DocumentPickerField(
                        label: 'CNIC / identity document',
                        hint: 'JPG, PNG or PDF',
                        onChanged: (f) => _cnic = f,
                      ),
                      const SizedBox(height: 12),
                      DocumentPickerField(
                        label: 'Vehicle registration card',
                        hint: 'JPG, PNG or PDF',
                        onChanged: (f) => _vehicleDoc = f,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
