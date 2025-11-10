import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageName;

  const FullScreenImageViewer({super.key, required this.imageName});

  Future<bool> _confirmOpenSettings(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin Diperlukan'),
        content: const Text(
          'Aplikasi perlu akses foto/penyimpanan untuk menyimpan gambar.\n'
          'Buka pengaturan untuk memberikan izin?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
            ),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _saveImageToGallery(BuildContext context) async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      try {
        final ByteData byteData = await rootBundle.load(
          'assets/images/$imageName.jpg',
        );
        final Uint8List uint8List = byteData.buffer.asUint8List();

        await Gal.putImageBytes(uint8List);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gambar berhasil disimpan!',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: const Color(0xFFFFC107),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menyimpan gambar: $e')));
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (!context.mounted) return;
      final shouldOpen = await _confirmOpenSettings(context);
      if (shouldOpen) {
        await openAppSettings();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin tetap ditolak.')));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan ditolak.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () => _saveImageToGallery(context),
            tooltip: 'Simpan ke Galeri',
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: imageName,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.asset(
              'assets/images/$imageName.jpg',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
