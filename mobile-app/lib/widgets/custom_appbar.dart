import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const CustomAppBar({super.key, required this.title, this.subtitle, this.actions});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      centerTitle: false,
      titleSpacing: 12,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
      actions: actions,
      backgroundColor: Colors.white,
      elevation: 0.8,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
