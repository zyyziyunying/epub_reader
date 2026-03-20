import 'package:flutter/material.dart';

class ReaderBottomBar extends StatelessWidget {
  final VoidCallback onSettingsPressed;

  const ReaderBottomBar({super.key, required this.onSettingsPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Chapter navigation is temporarily disabled during rebuild.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              _buildSettingsButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
      icon: const Icon(Icons.settings, color: Colors.white),
      onPressed: onSettingsPressed,
    );
  }
}
