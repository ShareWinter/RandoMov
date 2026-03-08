import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:random_movie/config/app_theme.dart';

// ==================== Toast ====================

/// Toast type determines icon and color scheme
enum ToastType { success, error, info }

/// Themed floating toast — matches the app's glassmorphism style.
///
/// Usage:
///   AppToast.success(context, '保存成功');
///   AppToast.error(context, '网络异常');
///   AppToast.info(context, '房间码已复制');
class AppToast {
  AppToast._();

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration? duration,
  }) {
    // Capture values synchronously (context may be invalid after frame)
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, iconColor) = _iconFor(type, isDark);
    final textColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryDarkOnLight;
    final bgColor = isDark ? const Color(0xF0222240) : const Color(0xF0FFFFFF);
    final borderColor = isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000);

    // Delay so any dialog pop() animation completes first.
    Future.delayed(const Duration(milliseconds: 500), () {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: AppTheme.spacingSmall),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            side: BorderSide(color: borderColor, width: 1),
          ),
          elevation: 6,
          duration: duration ?? const Duration(seconds: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMedium,
            vertical: AppTheme.spacingSmall + 2,
          ),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    });
  }

  static void success(BuildContext context, String message, {Duration? duration}) =>
      show(context, message, type: ToastType.success, duration: duration);

  static void error(BuildContext context, String message, {Duration? duration}) =>
      show(context, message, type: ToastType.error, duration: duration);

  static void info(BuildContext context, String message, {Duration? duration}) =>
      show(context, message, type: ToastType.info, duration: duration);

  static (IconData, Color) _iconFor(ToastType type, bool isDark) {
    return switch (type) {
      ToastType.success => (Icons.check_circle_rounded, const Color(0xFF4CAF50)),
      ToastType.error   => (Icons.error_rounded, AppTheme.accent),
      ToastType.info    => (
        Icons.info_rounded,
        isDark ? const Color(0xB3FFFFFF) : const Color(0x99101218),
      ),
    };
  }
}

// ==================== Glass Containers ====================

/// iOS 风格毛玻璃容器
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final Color? color;
  final Border? border;
  final bool showBorder;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.blurSigma = 18,
    this.color,
    this.border,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusLarge);
    final effectiveColor = color ?? (brightness == Brightness.dark
        ? const Color(0x26FFFFFF)
        : const Color(0xCCFFFFFF));
    
    final effectiveBorder = showBorder 
        ? (border ?? Border.all(
            color: brightness == Brightness.dark
                ? const Color(0x1AFFFFFF)
                : const Color(0x14000000),
            width: 1,
          ))
        : null;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          padding: padding ?? const EdgeInsets.all(AppTheme.spacingMedium),
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: radius,
            border: effectiveBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// iOS 风格吸顶导航栏装饰
class GlassAppBarDecorator extends StatelessWidget {
  final Widget child;
  final double blurSigma;

  const GlassAppBarDecorator({
    super.key,
    required this.child,
    this.blurSigma = 20,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final appBarHeight = kToolbarHeight;
    final totalHeight = topPadding + appBarHeight;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: totalHeight,
          child: GlassContainer(
            borderRadius: BorderRadius.zero,
            blurSigma: blurSigma,
            padding: EdgeInsets.zero,
            showBorder: false,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x14000000),
                width: 0.5,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
        child,
      ],
    );
  }
}

/// 毛玻璃卡片组件
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = GlassContainer(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      child: child,
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: card,
      );
    }

    return card;
  }
}

/// 主按钮组件
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLarge,
            vertical: AppTheme.spacingMedium,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                ),
              )
            : Row(
                mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: AppTheme.spacingSmall),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// 次按钮组件
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        side: BorderSide(
          color: onSurface.withValues(alpha: 0.25),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: AppTheme.spacingSmall,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: AppTheme.spacingSmall),
          ],
          Text(label),
        ],
      ),
    );
  }
}

/// 空状态组件
class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacingSmall),
              Text(
                subtitle!,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppTheme.spacingLarge),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 加载状态组件
class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              message!,
              style: textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// 错误状态组件
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              message,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacingMedium),
              SecondaryButton(
                label: '重试',
                icon: Icons.refresh,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
