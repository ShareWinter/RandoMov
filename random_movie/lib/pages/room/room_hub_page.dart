import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:random_movie/config/app_theme.dart';
import 'package:random_movie/providers/providers.dart';
import 'package:random_movie/widgets/common/common_widgets.dart';

/// Room hub page — user card + action grid
class RoomHubPage extends StatelessWidget {
  const RoomHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('房间')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.spacingMedium),

            // User card
            _buildUserCard(context),

            const SizedBox(height: AppTheme.spacingLarge),

            // Section title
            Text(
              '选择一种方式开始抽片',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),

            const SizedBox(height: AppTheme.spacingMedium),

            // 2x2 Grid
            Row(
              children: [
                Expanded(
                  child: _HubCard(
                    icon: Icons.casino_outlined,
                    title: '我一个人',
                    subtitle: '从片库随机抽取',
                    accentColor: AppTheme.accent,
                    onTap: () => context.push('/room/solo-draw'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: _HubCard(
                    icon: Icons.add_circle_outline,
                    title: '创建房间',
                    subtitle: '邀请好友一起选片',
                    accentColor: const Color(0xFF5C7CFA),
                    onTap: () => _createRoom(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Row(
              children: [
                Expanded(
                  child: _HubCard(
                    icon: Icons.login_rounded,
                    title: '加入房间',
                    subtitle: '输入房间码参与',
                    accentColor: const Color(0xFF51CF66),
                    onTap: () => _joinRoom(context),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: _HubCard(
                    icon: Icons.history_rounded,
                    title: '抽奖历史',
                    subtitle: '查看过往记录',
                    accentColor: const Color(0xFFFCC419),
                    onTap: () => context.push('/room/draw-history'),
                  ),
                ),
              ],
            ),

            // Bottom spacing
            SizedBox(
              height:
                  MediaQuery.of(context).padding.bottom +
                  AppTheme.spacingXLarge,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== User Card ====================

  Widget _buildUserCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final user = userProvider.user;
        if (user == null) return const SizedBox.shrink();

        return SoftContainer(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            children: [
              // Avatar circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name.characters.first : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              // Name + ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${user.id.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () => _showEditNameDialog(context, user.name),
                tooltip: '修改用户名',
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== Dialogs ====================

  void _showEditNameDialog(BuildContext context, String currentName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: MediaQuery.of(ctx).viewInsets,
        child: MediaQuery.removeViewInsets(
          context: ctx,
          removeBottom: true,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF222240) : Colors.white,
            elevation: 24,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              side: BorderSide(
                color: isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x14000000),
                width: 1,
              ),
            ),
            title: Text(
              '修改用户名',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textPrimaryDarkOnLight,
              ),
            ),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '输入新的用户名',
                counterText: '',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppTheme.textSecondary
                      : AppTheme.textSecondaryDarkOnLight,
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryDarkOnLight,
              ),
              maxLength: 20,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.textSecondary
                        : AppTheme.textSecondaryDarkOnLight,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) return;
                  Navigator.of(ctx).pop();
                  context.read<UserProvider>().updateUserName(newName);
                },
                style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
                child: const Text(
                  '确认',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createRoom(BuildContext context) async {
    final userProvider = context.read<UserProvider>();
    final roomProvider = context.read<RoomProvider>();
    final user = userProvider.user;
    if (user == null) return;

    final code = await roomProvider.createAndJoinRoom(user.id, user.name);
    if (code != null && context.mounted) {
      context.push('/room/detail/$code');
    } else if (roomProvider.error != null && context.mounted) {
      AppToast.error(context, roomProvider.error!);
      roomProvider.clearError();
    }
  }

  void _joinRoom(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: MediaQuery.of(ctx).viewInsets,
        child: MediaQuery.removeViewInsets(
          context: ctx,
          removeBottom: true,
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF222240) : Colors.white,
            elevation: 24,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              side: BorderSide(
                color: isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x14000000),
                width: 1,
              ),
            ),
            title: Text(
              '加入房间',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textPrimaryDarkOnLight,
              ),
            ),
            content: TextField(
              controller: codeController,
              decoration: InputDecoration(
                hintText: '输入6位房间码',
                counterText: '',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppTheme.textSecondary
                      : AppTheme.textSecondaryDarkOnLight,
                ),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimaryDarkOnLight,
              ),
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.textSecondary
                        : AppTheme.textSecondaryDarkOnLight,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final code = codeController.text.trim().toUpperCase();

                  // Client-side format validation (server generates 6-char A-Z0-9)
                  if (code.isEmpty) return;
                  if (code.length != 6 ||
                      !RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
                    Navigator.of(ctx).pop();
                    if (context.mounted) {
                      AppToast.error(context, '房间码为6位字母数字组合');
                    }
                    return;
                  }

                  Navigator.of(ctx).pop();

                  final userProvider = context.read<UserProvider>();
                  final roomProvider = context.read<RoomProvider>();
                  final user = userProvider.user;
                  if (user == null) return;

                  final success = await roomProvider.joinRoom(
                    code,
                    user.id,
                    user.name,
                  );
                  if (success && context.mounted) {
                    context.push('/room/detail/$code');
                  } else if (roomProvider.error != null && context.mounted) {
                    AppToast.error(context, roomProvider.error!);
                    roomProvider.clearError();
                  }
                },
                style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
                child: const Text(
                  '加入',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hub action card with scale animation
class _HubCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_HubCard> createState() => _HubCardState();
}

class _HubCardState extends State<_HubCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: AspectRatio(
          aspectRatio: 1.05,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(
                    alpha: isDark ? 0.15 : 0.08,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SoftContainer(
              borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon circle
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(
                        alpha: isDark ? 0.2 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSmall),
                  // Title
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Subtitle
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
