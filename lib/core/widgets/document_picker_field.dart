import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../repositories/storage_repository.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import 'common.dart';

/// Opens the system file picker and validates type/size (FR-21).
/// Returns null if cancelled; shows an error snack and returns null if invalid.
Future<PickedUpload?> pickDocument(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConfig.allowedUploadExtensions,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final path = f.path;
    if (path == null) {
      if (context.mounted) showSnack(context, 'Could not read the selected file. Please try again.', error: true);
      return null;
    }
    final size = f.size > 0 ? f.size : await File(path).length();
    final error = Validators.upload(fileName: f.name, sizeBytes: size);
    if (error != null) {
      if (context.mounted) showSnack(context, error, error: true);
      return null;
    }
    return PickedUpload(path: path, name: f.name, size: size);
  } catch (_) {
    if (context.mounted) showSnack(context, 'Could not open the file picker. Please try again.', error: true);
    return null;
  }
}

/// Form field for a required document upload with preview, retry and validation.
class DocumentPickerField extends FormField<PickedUpload> {
  DocumentPickerField({
    super.key,
    required String label,
    required String hint,
    required ValueChanged<PickedUpload?> onChanged,
    PickedUpload? initial,
  }) : super(
          initialValue: initial,
          validator: (v) => v == null ? '$label is required' : null,
          builder: (state) {
            final context = state.context;
            final t = Theme.of(context);
            final file = state.value;
            final hasError = state.hasError;
            final color = hasError ? t.colorScheme.error : t.colorScheme.outlineVariant;

            Future<void> choose() async {
              final f = await pickDocument(context);
              if (f != null) {
                state.didChange(f);
                onChanged(f);
              }
            }

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: choose,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.brightness == Brightness.light ? Colors.white : t.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color, width: hasError ? 1.6 : 1),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (file == null ? AppColors.muted : AppColors.success).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        file == null
                            ? Icons.upload_file_rounded
                            : (file.extension == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded),
                        color: file == null ? AppColors.muted : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          file == null ? hint : '${file.name} • ${Fmt.fileSize(file.size)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ]),
                    ),
                    Text(file == null ? 'Choose' : 'Change',
                        style: TextStyle(color: t.colorScheme.primary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(left: 14, top: 6),
                  child: Text(state.errorText!, style: TextStyle(color: t.colorScheme.error, fontSize: 12.5)),
                ),
            ]);
          },
        );
}
