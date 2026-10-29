import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateDownloader {
  static Future<void> downloadAndInstall({
    required String apkUrl,
    required int versionCode,
    required String expectedSha256,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('التحديث المباشر متاح على Android فقط');
    }

    final uri = Uri.tryParse(apkUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('رابط التحديث غير صالح');
    }

    final expectedHash = expectedSha256.trim().toLowerCase();

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash)) {
      throw const FormatException('بصمة SHA-256 غير صالحة');
    }

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/netmanager_update_$versionCode.apk';

    final file = File(filePath);

    try {
      final dio = Dio();

      await dio.download(
        apkUrl,
        filePath,
        deleteOnError: true,
        options: Options(
          followRedirects: false,
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('لم يكتمل تنزيل ملف التحديث');
      }

      // حساب SHA-256 بطريقة تدفق البيانات دون تحميل APK
      // بالكامل في ذاكرة الهاتف.
      final actualHash = (await sha256.bind(file.openRead()).first).toString();

      if (actualHash != expectedHash) {
        throw Exception('فشل التحقق من سلامة التحديث: بصمة APK غير مطابقة');
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        throw Exception('تعذر فتح مثبت Android: ${result.message}');
      }
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }
}
