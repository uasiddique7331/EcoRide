import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common.dart';

Future<void> openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, 'Could not open the file.', error: true);
}

Future<void> callNumber(BuildContext context, String phone) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
  if (!ok && context.mounted) showSnack(context, 'Could not open the phone app.', error: true);
}
