import 'package:fit_align/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class Camerapermission extends StatefulWidget {
  const Camerapermission({super.key});

  @override
  State<Camerapermission> createState() => _CamerapermissionState();
}

class _CamerapermissionState extends State<Camerapermission> {
  bool _isLoading = false;
  String _errorMessage = '';

  ColorScheme get cs => Theme.of(context).colorScheme;

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CameraScreen()));
        }
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _errorMessage = 'Camera permission is permanently denied. Please enable it in settings.';
          _isLoading = false;
        });
        _showDialog(
          title: 'Enable Camera Access',
          message: 'Camera permission is permanently denied. Please enable it in your device settings to use this feature.',
          actionLabel: 'Open Settings',
          onAction: openAppSettings,
        );
      } else {
        setState(() {
          _errorMessage = 'Camera permission is required to use this feature. Please allow access in settings.';
          _isLoading = false;
        });
        _showDialog(
          title: 'Permission Required',
          message: 'Camera access is required to analyze your exercise form. Please grant permission to continue.',
          actionLabel: 'Try Again',
          onAction: _requestPermissions,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error requesting permission: $e';
        _isLoading = false;
      });
    }
  }

  void _showDialog({
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
        content: Text(message, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(actionLabel == null ? 'I Understand' : 'Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          if (actionLabel != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onAction?.call();
              },
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }

  Widget _permissionTile(IconData icon, String title, String status, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurface, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title, style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withAlpha(90)),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text('Camera Permission', style: TextStyle(color: cs.onSurface, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary.withAlpha(90), width: 1.5),
              ),
              child: Icon(Icons.camera_alt_rounded, color: cs.primary, size: 38),
            ),
            const SizedBox(height: 24),
            Text(
              'Allow Camera Access',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'Camera access is required to analyze your form and provide real-time feedback during exercises. Please grant camera permission to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                children: [
                  _permissionTile(Icons.camera_alt_outlined, 'Camera Access', 'Required', cs.secondary),
                  Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                  _permissionTile(Icons.mic_none_rounded, 'Microphone Access', 'Not Required', cs.primary),
                  Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
                  _permissionTile(Icons.sd_storage_outlined, 'Storage Access', 'Not Required', cs.primary),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.secondary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.secondary.withAlpha(90)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: cs.secondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage, style: TextStyle(color: cs.secondary, fontSize: 13))),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _requestPermissions,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary))
                    : const Text('Allow Camera Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showDialog(
                title: 'Camera Access Required',
                message: 'Without camera access, we cannot analyze your form and provide feedback. You can continue later from settings.',
              ),
              child: Text('Not Now', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
            ),
            TextButton(
              onPressed: openAppSettings,
              child: Text(
                'You can change this later in settings.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, decoration: TextDecoration.underline),
              ),
            ),
            Text('Your privacy is important to us.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}