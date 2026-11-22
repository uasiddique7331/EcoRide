import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../theme/app_theme.dart';
import 'common.dart';

StatusChip docStatusChip(DocStatus s) => StatusChip(
      label: s.label,
      color: AppColors.forDoc(s),
      icon: switch (s) {
        DocStatus.pending => Icons.hourglass_top_rounded,
        DocStatus.approved => Icons.verified_rounded,
        DocStatus.rejected => Icons.cancel_rounded,
      },
    );

StatusChip bookingStatusChip(BookingStatus s) => StatusChip(label: s.label, color: AppColors.forBooking(s));

StatusChip tripStatusChip(TripStatus s) => StatusChip(label: s.label, color: AppColors.forTrip(s));

StatusChip accountStatusChip(AccountStatus s) => StatusChip(label: s.label, color: AppColors.forAccount(s));
