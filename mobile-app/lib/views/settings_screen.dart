import 'package:flutter/material.dart';
import '../widgets/custom_appbar.dart';
import '../utils/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: const CustomAppBar(
        title: 'Settings',
        subtitle: 'FloodWatch preferences',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _tile(Icons.notifications_active_outlined, 'Notifications',
              'Severe & high risk alerts', true),
          const Divider(height: 32),
          _tile(Icons.shield_outlined, 'Privacy', 'Data & permissions', false),
          const Divider(height: 32),
          _tile(Icons.info_outline, 'About', 'Version 1.0.0', false),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, bool hasSwitch) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withOpacity(.15),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Text(subtitle),
        trailing: hasSwitch
            ? Switch(value: true, onChanged: (_) {})
            : const Icon(Icons.arrow_forward_ios_rounded, size: 18),
      ),
    );
  }
}
