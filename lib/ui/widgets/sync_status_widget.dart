import 'package:flutter/material.dart';
import '../../services/sync_status_service.dart';

/// A minimal sync status icon button for the AppBar.
/// Shows a cloud icon that changes color and icon based on sync state.
/// Spins when syncing. Tap to trigger manual sync.
class SyncStatusWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final bool compact;

  const SyncStatusWidget({
    super.key,
    this.onTap,
    this.compact = false,
  });

  Color _getColor(SyncState state) {
    switch (state) {
      case SyncState.synced:
        return const Color(0xFF00C853);
      case SyncState.syncing:
        return const Color(0xFF448AFF);
      case SyncState.pending:
        return const Color(0xFFFFB74D);
      case SyncState.offline:
        return Colors.grey;
      case SyncState.error:
        return const Color(0xFFFF5252);
    }
  }

  IconData _getIcon(SyncState state) {
    switch (state) {
      case SyncState.synced:
        return Icons.cloud_done_rounded;
      case SyncState.syncing:
        return Icons.sync_rounded;
      case SyncState.pending:
        return Icons.cloud_upload_rounded;
      case SyncState.offline:
        return Icons.cloud_off_rounded;
      case SyncState.error:
        return Icons.error_outline_rounded;
    }
  }

  String _getTooltip(SyncStatusService service) {
    switch (service.state) {
      case SyncState.synced:
        return 'Synced';
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.pending:
        return '${service.pendingCount} pending';
      case SyncState.offline:
        return 'Offline';
      case SyncState.error:
        return 'Sync failed — tap to retry';
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = SyncStatusService();

    return ListenableBuilder(
      listenable: syncStatus,
      builder: (context, child) {
        final color = _getColor(syncStatus.state);
        final icon = _getIcon(syncStatus.state);

        return IconButton(
          onPressed: onTap,
          tooltip: _getTooltip(syncStatus),
          icon: syncStatus.state == SyncState.syncing
              ? _SpinningIcon(icon: icon, color: color)
              : Icon(icon, color: color, size: 22),
        );
      },
    );
  }
}

/// Separate stateful widget ONLY for the spin animation
class _SpinningIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _SpinningIcon({required this.icon, required this.color});

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, color: widget.color, size: 22),
    );
  }
}
