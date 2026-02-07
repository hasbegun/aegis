import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

/// A banner that appears at the top of the screen when offline
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      offset: isOffline ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isOffline ? 1.0 : 0.0,
        child: Material(
          color: Colors.red.shade700,
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'No internet connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      ref.read(connectivityProvider.notifier).refresh();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Retry'),
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

/// A wrapper widget that adds an offline banner to any screen
class OfflineBannerWrapper extends StatelessWidget {
  final Widget child;

  const OfflineBannerWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}

/// A scaffold that includes the offline banner
class OfflineAwareScaffold extends ConsumerWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;

  const OfflineAwareScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          // Offline banner
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isOffline ? null : 0,
            child: isOffline
                ? Material(
                    color: Colors.red.shade700,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'No internet connection',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(connectivityProvider.notifier)
                                  .refresh();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Main body
          Expanded(child: body ?? const SizedBox.shrink()),
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}

/// Shows a snackbar when connectivity changes
class ConnectivitySnackbarListener extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivitySnackbarListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ConnectivitySnackbarListener> createState() =>
      _ConnectivitySnackbarListenerState();
}

class _ConnectivitySnackbarListenerState
    extends ConsumerState<ConnectivitySnackbarListener> {
  ConnectivityStatus? _previousStatus;

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityStatus>(connectivityProvider, (previous, next) {
      // Skip initial state or unknown
      if (previous == null || previous == ConnectivityStatus.unknown) {
        _previousStatus = next;
        return;
      }

      // Show snackbar on status change
      if (next != _previousStatus) {
        _previousStatus = next;

        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.hideCurrentSnackBar();

          if (next == ConnectivityStatus.offline) {
            messenger.showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('You are offline'),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (next == ConnectivityStatus.online) {
            messenger.showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.wifi, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Back online'),
                  ],
                ),
                backgroundColor: Colors.green.shade700,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    });

    return widget.child;
  }
}
