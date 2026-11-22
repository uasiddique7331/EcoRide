import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../models/vehicle.dart';
import '../../providers/providers.dart';

/// FR-22 .. FR-28: view and update the driver's single vehicle.
class VehicleScreen extends ConsumerWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(myVehicleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My vehicle')),
      body: AsyncView<Vehicle?>(
        value: v,
        onRetry: () => ref.invalidate(myVehicleProvider),
        data: (vehicle) => vehicle == null
            ? const EmptyState(icon: Icons.directions_car_outlined, title: 'No vehicle registered')
            : _Editor(vehicle: vehicle),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.vehicle});
  final Vehicle vehicle;
  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _form = GlobalKey<FormState>();
  late final _color = TextEditingController(text: widget.vehicle.color);
  late final _capacity = TextEditingController(text: '${widget.vehicle.capacity}');
  late String _type = vehicleTypes.contains(widget.vehicle.type) ? widget.vehicle.type : 'Other';
  bool _loading = false;

  @override
  void dispose() {
    _color.dispose();
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    await runAction(
      context,
      () => ref.read(userRepositoryProvider).updateVehicle(
            driverUid: widget.vehicle.ownerId,
            color: _color.text,
            type: _type,
            capacity: int.parse(_capacity.text.trim()),
          ),
      success: 'Vehicle updated.',
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    return ListView(padding: const EdgeInsets.all(16), children: [
      SectionCard(
        title: 'Registered vehicle',
        child: Column(children: [
          InfoRow(icon: Icons.pin_outlined, label: 'Plate', value: v.registrationNumber),
          InfoRow(icon: Icons.directions_car_outlined, label: 'Make', value: v.make),
          InfoRow(icon: Icons.model_training_outlined, label: 'Model', value: v.model),
          InfoRow(icon: Icons.person_outline, label: 'Owner', value: v.ownerName),
          const SizedBox(height: 4),
          const NoticeBanner(message: 'Plate, make and model are locked after registration. One vehicle per driver account.'),
        ]),
      ),
      Form(
        key: _form,
        child: SectionCard(
          title: 'Editable details',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppTextField(controller: _color, label: 'Colour', icon: Icons.palette_outlined, validator: (x) => Validators.required(x, 'Colour')),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              for (final t in vehicleTypes) ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
            ]),
            const SizedBox(height: 14),
            AppTextField(
              controller: _capacity,
              label: 'Passenger seats',
              icon: Icons.event_seat_outlined,
              keyboardType: TextInputType.number,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (x) => Validators.capacity(x, max: AppConfig.maxVehicleCapacity),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Save changes', loading: _loading, onPressed: _save),
          ]),
        ),
      ),
    ]);
  }
}
