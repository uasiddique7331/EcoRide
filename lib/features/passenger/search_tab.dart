import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/services/geo_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/location_field.dart';
import '../../models/place_point.dart';
import '../../providers/providers.dart';
import '../../services/ride_matcher.dart';

/// UC-05 steps 1-7: collect and validate the passenger's search criteria.
class PassengerSearchTab extends ConsumerStatefulWidget {
  const PassengerSearchTab({super.key});

  @override
  ConsumerState<PassengerSearchTab> createState() => _PassengerSearchTabState();
}

class _PassengerSearchTabState extends ConsumerState<PassengerSearchTab> {
  PlacePoint? _pickup;
  PlacePoint? _dropoff;
  late DateTime _when = _defaultTime();
  int _seats = 1;
  String? _pickupError;
  String? _dropError;
  String? _timeError;

  static DateTime _defaultTime() {
    final t = DateTime.now().add(const Duration(minutes: 30));
    return DateTime(t.year, t.month, t.day, t.hour, (t.minute ~/ 5) * 5);
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _when.isBefore(today) ? today : _when,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t != null) setState(() => _when = DateTime(_when.year, _when.month, _when.day, t.hour, t.minute));
  }

  void _search() {
    // FR-60: validate before searching
    setState(() {
      _pickupError = _pickup == null ? 'Choose your pickup location' : null;
      _dropError = _dropoff == null ? 'Choose your drop-off location' : null;
      _timeError = _when.isBefore(DateTime.now().subtract(const Duration(minutes: 5)))
          ? 'Departure time must be in the future'
          : null;
      if (_pickup != null && _dropoff != null && GeoUtils.haversineKm(_pickup!.latLng, _dropoff!.latLng) < 0.3) {
        _dropError = 'Drop-off is too close to your pickup';
      }
    });
    if (_pickupError != null || _dropError != null || _timeError != null) return;
    context.push('/passenger/results',
        extra: RideQuery(pickup: _pickup!, dropoff: _dropoff!, desiredTime: _when, seats: _seats));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final t = Theme.of(context);
    final firstName = (user?.fullName ?? '').split(' ').first;

    return Scaffold(
      appBar: AppBar(title: const Text('Find a ride')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text('Hi${firstName.isEmpty ? '' : ', $firstName'} 👋', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Where are you headed today?', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          if (user != null && !user.isVerified)
            const NoticeBanner(
              message: 'Your CNIC is awaiting administrator approval. You can search rides now; booking opens once you are verified.',
              icon: Icons.hourglass_top_rounded,
            ),
          SectionCard(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              LocationField(
                label: 'Pickup location',
                icon: Icons.trip_origin,
                allowGps: true,
                value: _pickup,
                errorText: _pickupError,
                onChanged: (p) => setState(() {
                  _pickup = p;
                  _pickupError = null;
                }),
              ),
              const SizedBox(height: 12),
              LocationField(
                label: 'Drop-off location',
                icon: Icons.location_on_outlined,
                value: _dropoff,
                errorText: _dropError,
                onChanged: (p) => setState(() {
                  _dropoff = p;
                  _dropError = null;
                }),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(labelText: 'Date', prefixIcon: const Icon(Icons.event_outlined), errorText: _timeError),
                      child: Text(Fmt.date(_when)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.schedule_outlined)),
                      child: Text(Fmt.time(_when)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.event_seat_outlined, color: AppColors.muted),
                const SizedBox(width: 10),
                const Expanded(child: Text('Seats needed', style: TextStyle(fontWeight: FontWeight.w600))),
                IconButton.filledTonal(
                  onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(width: 36, child: Center(child: Text('$_seats', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))),
                IconButton.filledTonal(
                  onPressed: _seats < AppConfig.maxSeatsPerBooking ? () => setState(() => _seats++) : null,
                  icon: const Icon(Icons.add),
                ),
              ]),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Search rides', icon: Icons.search_rounded, onPressed: _search),
            ]),
          ),
          const SizedBox(height: 4),
          SectionCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('How matching works', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _tip(Icons.radar_rounded, 'Rides starting within ${AppConfig.searchRadiusKm.round()} km of your pickup'),
              _tip(Icons.alt_route_rounded, 'Driver route passes your drop-off, in the same direction'),
              _tip(Icons.schedule_rounded, 'Departure within ±${AppConfig.timeWindowMinutes} minutes of your time'),
              _tip(Icons.payments_outlined, 'Fare PKR ${AppConfig.farePerKm}/km, split equally among accepted riders'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _tip(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ]),
      );
}
