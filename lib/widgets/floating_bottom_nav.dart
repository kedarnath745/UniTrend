import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class FloatingBottomNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int>? onDoubleTap;

  const FloatingBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.onDoubleTap,
  });

  static const _items = [
    (Icons.radar_outlined, Icons.radar, 'Radar'),
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.search_outlined, Icons.search, 'Search'),
    (Icons.trending_up_outlined, Icons.trending_up, 'Trending'),
    (Icons.bookmark_border_outlined, Icons.bookmark, 'Bookmarks'),
  ];

  @override
  State<FloatingBottomNav> createState() => _FloatingBottomNavState();
}

class _FloatingBottomNavState extends State<FloatingBottomNav> {
  int? _lastTapIndex;
  DateTime? _lastTapTime;

  void _handleTap(int i) {
    final now = DateTime.now();
    final isDoubleTap = _lastTapIndex == i &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 350);

    _lastTapIndex = i;
    _lastTapTime = now;

    if (isDoubleTap && i == widget.selectedIndex) {
      HapticFeedback.mediumImpact();
      widget.onDoubleTap?.call(i);
    } else {
      HapticFeedback.lightImpact();
      widget.onTap(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF12121A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(FloatingBottomNav._items.length, (i) {
                final item = FloatingBottomNav._items[i];
                final selected = i == widget.selectedIndex;
                return InkWell(
                  onTap: () => _handleTap(i),
                  borderRadius: BorderRadius.circular(12),
                  splashColor: Colors.white.withValues(alpha: 0.1),
                  highlightColor: Colors.transparent,
                  child: SizedBox(
                    width: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              item.$2,
                              size: 18,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            item.$1,
                            size: 22,
                            color: Colors.white38,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color:
                                selected ? Colors.white : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
