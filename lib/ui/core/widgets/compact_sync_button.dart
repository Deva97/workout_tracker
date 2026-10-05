import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/services/google_drive_service.dart';
import '../theme/app_colors.dart';

/// Small compact Sync button featuring rotating sync arrows and status colors
class CompactSyncButton extends StatefulWidget {
  final SyncState? syncState;
  final ValueListenable<SyncState>? syncStateListenable;
  final VoidCallback? onPressed;

  const CompactSyncButton({
    this.syncState,
    this.syncStateListenable,
    this.onPressed,
    super.key,
  });

  @override
  State<CompactSyncButton> createState() => _CompactSyncButtonState();
}

class _CompactSyncButtonState extends State<CompactSyncButton> with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  ValueListenable<SyncState>? _activeListenable;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _initListenable();
    _checkAnimationState(_getCurrentState());
  }

  void _initListenable() {
    if (widget.syncState == null) {
      _activeListenable = widget.syncStateListenable ?? GoogleDriveService().syncStateNotifier;
      _activeListenable?.addListener(_onListenableChanged);
    }
  }

  void _onListenableChanged() {
    if (mounted) {
      _checkAnimationState(_getCurrentState());
      setState(() {});
    }
  }

  SyncState _getCurrentState() {
    if (widget.syncState != null) {
      return widget.syncState!;
    }
    return _activeListenable?.value ?? SyncState.synced;
  }

  void _checkAnimationState(SyncState state) {
    if (state == SyncState.syncing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }
  }

  @override
  void didUpdateWidget(covariant CompactSyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.syncState != widget.syncState ||
        oldWidget.syncStateListenable != widget.syncStateListenable) {
      oldWidget.syncStateListenable?.removeListener(_onListenableChanged);
      _activeListenable?.removeListener(_onListenableChanged);
      _activeListenable = null;
      _initListenable();
    }
    _checkAnimationState(_getCurrentState());
  }

  @override
  void dispose() {
    _activeListenable?.removeListener(_onListenableChanged);
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final result = await GoogleDriveService().manualSyncToExcel();
    if (!mounted) return;
    if (result == SyncState.synced) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Synced with Google Drive Excel!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Sync failed. Changes saved locally in cache.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _getCurrentState();
    final (label, color, icon) = switch (state) {
      SyncState.synced => ('Synced', AppColors.success, Icons.cloud_done_rounded),
      SyncState.syncing => ('Syncing...', AppColors.primary, Icons.sync_rounded),
      SyncState.error => ('Sync', AppColors.warning, Icons.cloud_upload_rounded),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: state == SyncState.syncing ? null : _handleTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _rotationController,
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
