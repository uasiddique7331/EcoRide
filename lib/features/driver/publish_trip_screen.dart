import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/routing_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/location_field.dart';
import '../../core/widgets/route_map.dart';
import '../../models/place_point.dart';
import '../../providers/providers.dart';
import '../../services/fare_calculator.dart';

/// UC-04: publish a trip. The route/fare is previewed before publishing.
class PublishTripScreen extends ConsumerStatefulWidget {
  const PublishTripScreen({super.key});
  @override
  ConsumerState<PublishTripScreen> createState() => _PublishTripScreenState();
}

class _PublishTripScreenState extends ConsumerState<PublishTripScreen> {
  PlacePoint? _from;
  PlacePoint? _to;
  late DateTime _when = DateTime.now().add(const Duration(hours: 1));
  int _seats = 1;
  RouteInfo? _route;
  String? _error;
  bool _calculating = false;
  bool _publishing = false;

  void _invalidate() => _route = null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _when, firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 90)));
    if (d != null) setState(() {
      _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute);
      _invalidate();
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t != null) setState(() {
      _when = DateTime(_when.year, _when.month, _when.day, t.hour, t.minute);
      _invalidate();
    });
  }

  Future<void> _preview() async {
    if (_from == null || _to == null) {
      setState(() => _error = 'Choose both a starting location and a destination.');
      return;
    }
    if (!_when.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      setState(() => _error = 'Departure must be at least 5 minutes in the future.');
      return;
    }
    setState(() {
      _error = null;
      _calculating = true;
    });
    final r = await ref.read(routingServiceProvider).route(_from!.latLng, _to!.latLng);
    if (!mounted) return;
    setState(() {
      _calculating = false;
      if (r.distanceKm < 0.5) {
        _error = 'Start and destination are too close together.';
      } else {
        _route = r;
      }
    });
  }

  Future<void> _publish() async {
    final driver = ref.read(currentUserProvider);
    final vehicle = ref.read(myVehicleProvider).value;
    if (driver == null || vehicle == null) {
      setState(() => _error = 'A registered vehicle is required to publish a trip.'); // A2
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final ok = await runAction(
      context,
      () => ref.read(tripRepositoryProvider).publish(
            driver: driver,
            vehicle: vehicle,
            origin: _from!,
            destination: _to!,
            departure: _when,
            seats: _seats,
            route: _route!,
          ),
    );
    if (mounted) setState(() => _publishing = false);
    if (ok) {
      ref.read(driverTabProvider.notifier).set(1);
      router.go('/driver');
      messenger.showSnackBar(const SnackBar(content: Text('Trip published! Passengers can now find it.'), backgroundColor: AppColors.primaryDark));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(myVehicleProvider).value;
    final user = ref.watch(currentUserProvider);
    final maxSeats = vehicle?.capacity ?? 1;
    if (_seats > maxSeats) _seats = maxSeats;
    final r = _route;

    return Scaffold(
      appBar: AppBar(title: const Text('Publish a trip')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        if (user != null && !user.isVerified)
          const NoticeBanner(message: 'Your documents must be approved by an administrator before you can publish trips.', icon: Icons.hourglass_top_rounded),
        if (_error != null) NoticeBanner(message: _error!, color: AppColors.danger, icon: Icons.error_outline),
        SectionCard(
          child: Column(children: [
            LocationField(label: 'Starting location', icon: Icons.trip_origin, allowGps: true, value: _from, onChanged: (p) => setState(() {
                  _from = p;
                  _invalidate();
                })),
            const SizedBox(height: 12),
            LocationField(label: 'Destination', icon: Icons.location_on_outlined, value: _to, onChanged: (p) => setState(() {
                  _to = p;
                  _invalidate();
                })),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: InkWell(borderRadius: BorderRadius.circular(14), onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event_outlined)), child: Text(Fmt.date(_when))))),
              const SizedBox(width: 12),
              Expanded(child: InkWell(borderRadius: BorderRadius.circular(14), onTap: _pickTime, child: InputDecorator(decoration: const InputDecoration(labelText: 'Time', prefixIcon: Icon(Icons.schedule_outlined)), child: Text(Fmt.time(_when))))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.event_seat_outlined, color: AppColors.muted),
              const SizedBox(width: 10),
              Expanded(child: Text('Available seats (max $maxSeats)', style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton.filledTonal(onPressed: _seats > 1 ? () => setState(() => _seats--) : null, icon: const Icon(Icons.remove)),
              SizedBox(width: 34, child: Center(child: Text('$_seats', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
              IconButton.filledTonal(onPressed: _seats < maxSeats ? () => setState(() => _seats++) : null, icon: const Icon(Icons.add)),
            ]),
            const SizedBox(height: 16),
            PrimaryButton(label: r == null ? 'Calculate route & fare' : 'Recalculate', icon: Icons.calculate_outlined, loading: _calculating, onPressed: _preview),
          ]),
        ),
        if (r != null) ...[
          RouteMap(route: r.points, origin: _from!.latLng, destination: _to!.latLng),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Fare preview',
            child: Column(children: [
              InfoRow(icon: Icons.route_outlined, label: 'Distance', value: Fmt.km(r.distanceKm) + (r.isEstimate ? ' (estimate)' : '')),
              InfoRow(icon: Icons.payments_outlined, label: 'Total fare', value: Fmt.pkr(FareCalculator.totalFare(r.distanceKm)), bold: true, valueColor: AppColors.primaryDark),
              if (r.isEstimate)
                const NoticeBanner(message: 'The road route service was unreachable, so distance is estimated from the straight line. Retry for the exact road distance.'),
              const NoticeBanner(color: AppColors.info, message: 'The total is split equally among accepted passengers. Passengers pay you directly.'),
            ]),
          ),
          PrimaryButton(label: 'Publish trip', icon: Icons.check_circle_outline, loading: _publishing, onPressed: _publish),
        ],
      ]),
    );
  }
}
