import 'package:flutter/material.dart';

class ReaderBottomBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSettingsPressed;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;

  const ReaderBottomBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSettingsPressed,
    this.onPreviousPressed,
    this.onNextPressed,
  });

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
              if (onPreviousPressed != null)
                _buildNavButton(
                  icon: Icons.chevron_left,
                  onPressed: onPreviousPressed,
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onNextPressed != null)
                _buildNavButton(
                  icon: Icons.chevron_right,
                  onPressed: onNextPressed,
                ),
              _buildSettingsButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onPressed,
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(
      icon: const Icon(Icons.settings, color: Colors.white),
      onPressed: onSettingsPressed,
    );
  }
}
