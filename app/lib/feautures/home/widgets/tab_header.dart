import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: AppText.headlineSm(Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
