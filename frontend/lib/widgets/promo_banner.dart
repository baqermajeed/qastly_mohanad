import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/assets.dart';
import '../core/theme.dart';

class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                AppAssets.banner,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.minusCircle,
                  width: 17,
                  height: 17,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // في RTL: start = اليمين، حتى يتطابق يمين الكونتينرين
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _FrostedText(
                  text: 'مرحبا بك في نظام قسطلي💸',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                SizedBox(height: 8),
                _FrostedText(
                  text: 'أضف زبائنك وخطط أقساطهم، ومستحقاتك تُصرف نقداً يوم 1',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  lineHeight: 1.4,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -26,
            child: Center(
              child: SvgPicture.asset(
                AppAssets.bannerIndicators,
                width: 59,
                height: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedText extends StatelessWidget {
  const _FrostedText({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
    this.lineHeight,
  });

  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double? lineHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.right,
            softWrap: false,
            style: AppTheme.text(
              color: AppTheme.basic,
              fontSize: fontSize,
              fontWeight: fontWeight,
              height: lineHeight,
            ),
          ),
        ),
      ),
    );
  }
}
