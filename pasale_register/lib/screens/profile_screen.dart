import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/keys.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/camera_service.dart';
import '../services/service_locator.dart';
import '../services/session_service.dart';
import '../theme/pasale_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _session = SessionService();
  final _nameController = TextEditingController();
  final _extraPhoneController = TextEditingController();
  final _primaryPhoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _auth = AuthService();

  AppSession? _snap;
  bool _loading = true;
  bool _otpSent = false;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _session.load();
    if (!mounted) return;
    setState(() {
      _snap = s;
      _nameController.text = s.displayName ?? '';
      _primaryPhoneController.text = s.phone ?? '';
      _loading = false;
    });
  }

  Future<void> _saveName() async {
    await _session.setDisplayName(_nameController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
    await _load();
  }

  Future<void> _addExtraPhone() async {
    final p = _extraPhoneController.text.trim();
    if (p.isEmpty) return;
    final list = List<String>.from(_snap?.extraPhones ?? []);
    if (!list.contains(p) && p != _snap?.phone) {
      list.add(p);
      await _session.setExtraPhones(list);
      _extraPhoneController.clear();
      await _load();
    }
  }

  Future<void> _removeExtra(String phone) async {
    final list = List<String>.from(_snap?.extraPhones ?? [])..remove(phone);
    await _session.setExtraPhones(list);
    await _load();
  }

  Future<void> _sendPrimaryOtp() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final r = await _auth.sendOtp(_primaryPhoneController.text);
      setState(() {
        _otpSent = true;
        _status = r.message;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _status = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _verifyPrimaryChange() async {
    final role = _snap?.role ?? UserRole.storeOwner;
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      await _auth.verifyOtp(otp: _otpController.text, role: role);
      final phone = _auth.pendingPhone ?? _primaryPhoneController.text.trim();
      await _session.setPrimaryPhone(phone);
      setState(() {
        _otpSent = false;
        _otpController.clear();
        _busy = false;
        _status = 'Primary phone updated to $phone';
      });
      await _load();
    } catch (e) {
      setState(() {
        _status = '$e';
        _busy = false;
      });
    }
  }

  Future<void> _uploadPan() async {
    // Reuse product photo capture path as document scan (still).
    try {
      await locator<CameraService>().prepareProductPhotoSession();
      final path = await locator<CameraService>().captureProductPhoto();
      if (path == null || path.isEmpty) return;
      await _session.setPanDocumentPath(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PAN document saved')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PAN upload failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _extraPhoneController.dispose();
    _primaryPhoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final s = _snap!;
    final theme = Theme.of(context);

    return ListView(
      key: AppKeys.profileScreen,
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: _avatar(s)),
        const SizedBox(height: 12),
        Text(
          s.displayName?.isNotEmpty == true ? s.displayName! : (s.role?.label ?? 'Profile'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (s.authProvider != null)
          Text(
            _providerLabel(s.authProvider!),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        const SizedBox(height: 20),

        _section('Account'),
        _outlinedTile('Role', s.role?.label ?? '—'),
        if (s.email != null && s.email!.isNotEmpty)
          _outlinedTile('Email', s.email!),
        if (s.storeName != null)
          _outlinedTile('Store', '${s.storeName} (${s.storeId})'),

        const SizedBox(height: 16),
        _section('Display name'),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _saveName, child: const Text('Save name')),

        // Business profile: PAN + multi-phone
        if (s.isBusinessRole) ...[
          const SizedBox(height: 20),
          _section('PAN document (14-day window)'),
          _panCard(s),
          const SizedBox(height: 20),
          _section('Primary phone (OTP to change)'),
          TextField(
            controller: _primaryPhoneController,
            decoration: const InputDecoration(
              labelText: 'Primary mobile',
              hintText: '98XXXXXXXX',
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
            ],
          ),
          const SizedBox(height: 8),
          if (!_otpSent)
            OutlinedButton(
              onPressed: _busy ? null : _sendPrimaryOtp,
              child: Text(_busy ? 'Sending…' : 'Send OTP to verify change'),
            )
          else ...[
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'OTP',
                hintText: 'Demo: 123456 if offline',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _verifyPrimaryChange,
              child: const Text('Verify & set primary'),
            ),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_status, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          _section('Additional phone numbers'),
          ...s.extraPhones.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(p),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _removeExtra(p),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _extraPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Add phone',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _addExtraPhone,
                child: const Text('Add'),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 16),
          _outlinedTile('Phone', s.phone ?? '—'),
        ],
      ],
    );
  }

  Widget _avatar(AppSession s) {
    final url = s.photoUrl;
    final hasNet = url != null &&
        (url.startsWith('http://') || url.startsWith('https://'));
    final hasFile = url != null && File(url).existsSync();

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: PasaleTheme.ink, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasNet
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
              return _initials(s);
            })
          : hasFile
              ? Image.file(File(url), fit: BoxFit.cover)
              : _initials(s),
    );
  }

  Widget _initials(AppSession s) {
    final letter = (s.displayName?.isNotEmpty == true
            ? s.displayName!
            : (s.role?.label ?? '?'))
        .characters
        .first
        .toUpperCase();
    return Center(
      child: Text(
        letter,
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _panCard(AppSession s) {
    final days = s.panDaysRemaining;
    final overdue = s.panOverdue;
    String subtitle;
    if (s.panUploaded) {
      subtitle = 'Uploaded${s.panUploadedAt != null ? ' · ${s.panUploadedAt!.toLocal().toString().split('.').first}' : ''}';
    } else if (days == null) {
      subtitle = 'Upload within 14 days of signup';
    } else if (overdue) {
      subtitle = 'Overdue — please upload PAN now';
    } else {
      subtitle = '$days day(s) left to upload';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.panUploaded ? 'PAN on file' : 'PAN required',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: overdue ? const Color(0xFFFF6B6B) : PasaleTheme.mute,
                fontSize: 13,
              ),
            ),
            if (s.panPath != null && File(s.panPath!).existsSync()) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(s.panPath!),
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _uploadPan,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(s.panUploaded ? 'Replace PAN photo' : 'Upload PAN photo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: PasaleTheme.mute,
        ),
      ),
    );
  }

  Widget _outlinedTile(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 12, color: PasaleTheme.mute)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'phone':
        return 'Phone (Firebase OTP)';
      case 'facebook':
        return 'Facebook profile';
      case 'demoPhone':
        return 'Phone (demo OTP)';
      case 'demoFacebook':
        return 'Facebook (demo)';
      default:
        return provider;
    }
  }
}
