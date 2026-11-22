# EcoRide architecture

```
lib/
  core/        config, theme, router, utils, services (routing, geocoding, GPS), shared widgets
  models/      Firestore-mapped domain models and enums
  repositories Firebase access (auth, users/vehicles, documents, trips, bookings, admin, storage)
  services/    pure business logic: FareCalculator, RideMatcher (unit-tested)
  providers/   Riverpod providers (session, streams, search)
  features/    auth, profile, passenger, driver, admin screens
```

## Firestore data model
| Collection | Doc ID | Key fields |
|---|---|---|
| `users` | uid | role, fullName, email, phone, status (active/restricted/deactivated), isVerified |
| `vehicles` | driver uid (⇒ one per driver) | ownerId, registrationNumber, make, model, color, type, capacity |
| `documents` | `{uid}_{cnic|vehicleRegistration}` | ownerId, storagePath, status, rejectionReason, reviewedBy |
| `trips` | auto | driverId, vehicle{}, origin, destination, departureTime, totalSeats, availableSeats, acceptedPassengers, status, distanceKm, totalFare, routePoints[] |
| `bookings` | `{tripId}_{passengerId}` (⇒ no duplicates) | tripId, driverId, passengerId, seats, status, pickup, dropoff, estimatedShare |
| `adminLogs` | auto | adminId, action, targetType, targetId, details |

Storage: `documents/{uid}/…` — readable only by owner and admins.

## Key design decisions
- **Seat integrity:** accept/cancel run in transactions; rules also bound counters.
- **Share is derived:** `ceil(totalFare / acceptedPassengers)`; recalculated automatically on every accept/cancel.
- **Verification:** a user is `isVerified` when all required docs are approved (set atomically with the review + audit log).
- **No payments:** passengers pay the vehicle owner directly (FR-82/83).

## Requirements traceability
| SRS area | Where |
|---|---|
| FR-01…08 auth/profile | `features/auth/*`, `features/profile/profile_view.dart`, `repositories/auth_repository.dart`, `core/router/app_router.dart` |
| FR-09…21 documents | register screens, `document_picker_field.dart`, `document_repository.dart`, profile re-upload |
| FR-22…28 vehicle | `register_driver_screen.dart`, `vehicle_screen.dart`, `vehicles/{uid}` rule |
| FR-29…36 location | `location_service.dart`, `location_picker_screen.dart`, `location_field.dart` |
| FR-37…45 trips | `publish_trip_screen.dart`, `driver_trip_detail_screen.dart`, `trip_repository.dart` |
| FR-46…60 discovery/matching | `search_tab.dart`, `ride_results_screen.dart`, `services/ride_matcher.dart` |
| FR-61…72 bookings | `booking_repository.dart`, `ride_details_screen.dart`, `booking_detail_screen.dart`, driver requests tab |
| FR-73…83 fare | `services/fare_calculator.dart`, `fare_card.dart` |
| FR-84…99 admin | `features/admin/*`, `admin_repository.dart`, `firestore.rules`, `storage.rules` |
| FR-100…105 feedback/errors | Firestore streams, `app_exception.dart`, `showSnack`, `ErrorState` |
