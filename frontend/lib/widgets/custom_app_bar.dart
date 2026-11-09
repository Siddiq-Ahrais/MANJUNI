import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onMenuPressed;
  final Widget? trailingExtra;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onSearchPressed,
    this.onNotificationPressed,
    this.onMenuPressed,
    this.trailingExtra,
  });

  static const Color primaryGreen = Color(0xFF164E2E);

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: primaryGreen,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                onPressed: onMenuPressed ?? () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Color(0xDDFFFFFF),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      ValueListenableBuilder<bool?>(
                        valueListenable: ApiService.isConnectedNotifier,
                        builder: (context, isConn, _) {
                          return Text(
                            isConn == true
                                ? 'Warung Maju Jaya \u2022 Online'
                                : 'Warung Maju Jaya \u2022 Mode Offline',
                            style: const TextStyle(
                              color: Color(0xDDFFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                  ],
                ),
              ),
              if (trailingExtra != null) ...[
                trailingExtra!,
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white, size: 24),
                onPressed: onSearchPressed ?? () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onNotificationPressed ?? () {},
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF69F0AE),
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryGreen, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
