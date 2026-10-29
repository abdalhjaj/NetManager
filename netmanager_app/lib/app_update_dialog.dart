import 'package:flutter/material.dart';

import 'app_update_service.dart';
import 'app_update_downloader.dart';

Future<void> showNetManagerUpdateDialog(
  BuildContext context,
  AppUpdateInfo update,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _NetManagerUpdateDialog(update: update);
    },
  );
}

class _NetManagerUpdateDialog extends StatefulWidget {
  final AppUpdateInfo update;

  const _NetManagerUpdateDialog({required this.update});

  @override
  State<_NetManagerUpdateDialog> createState() =>
      _NetManagerUpdateDialogState();
}

class _NetManagerUpdateDialogState extends State<_NetManagerUpdateDialog> {
  bool downloading = false;
  double progress = 0;
  String? errorMessage;

  Future<void> startDownload() async {
    if (downloading) return;

    setState(() {
      downloading = true;
      progress = 0;
      errorMessage = null;
    });

    try {
      await AppUpdateDownloader.downloadAndInstall(
        apkUrl: widget.update.apkUrl,
        versionCode: widget.update.versionCode,
        expectedSha256: widget.update.apkSha256,
        onProgress: (value) {
          if (!mounted) return;

          setState(() {
            progress = value.clamp(0.0, 1.0);
          });
        },
      );

      if (!mounted) return;

      // Android سيتولى عرض شاشة تأكيد التثبيت.
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'فشل تنزيل أو تثبيت التحديث: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          downloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;

    return PopScope(
      canPop: !downloading && !update.isMandatory,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.green),
            SizedBox(width: 10),
            Expanded(child: Text('تحديث جديد لـ NetManager')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإصدار الجديد: ${update.versionName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              update.releaseNotes.isEmpty
                  ? 'يتوفر إصدار جديد من التطبيق.'
                  : update.releaseNotes,
            ),
            if (update.isMandatory) ...[
              const SizedBox(height: 12),
              const Text(
                'هذا التحديث مطلوب للاستمرار باستخدام التطبيق.',
                style: TextStyle(color: Colors.red),
              ),
            ],
            if (downloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'جاري تنزيل التحديث: ${(progress * 100).toStringAsFixed(0)}%',
                ),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          if (!downloading && !update.isMandatory)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لاحقًا'),
            ),
          FilledButton.icon(
            onPressed: downloading ? null : startDownload,
            icon: Icon(downloading ? Icons.hourglass_top : Icons.download),
            label: Text(downloading ? 'جاري التنزيل' : 'تحديث الآن'),
          ),
        ],
      ),
    );
  }
}
