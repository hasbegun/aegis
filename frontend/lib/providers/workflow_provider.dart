import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workflow/workflow_graph.dart';
import '../services/workflow_service.dart';
import 'api_provider.dart';

/// State for workflow data
class WorkflowState {
  final WorkflowGraph? graph;
  final List<Map<String, dynamic>>? timeline;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const WorkflowState({
    this.graph,
    this.timeline,
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  WorkflowState copyWith({
    WorkflowGraph? graph,
    List<Map<String, dynamic>>? timeline,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return WorkflowState(
      graph: graph ?? this.graph,
      timeline: timeline ?? this.timeline,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Check if workflow data exists
  bool get hasData => graph != null;

  /// Check if workflow has vulnerabilities
  bool get hasVulnerabilities => graph?.hasVulnerabilities ?? false;

  /// Check if data is fresh (less than 5 seconds old)
  bool get isFresh {
    if (lastUpdated == null) return false;
    return DateTime.now().difference(lastUpdated!) < const Duration(seconds: 5);
  }
}

/// Notifier for managing workflow state
class WorkflowNotifier extends StateNotifier<WorkflowState> {
  final WorkflowService _service;
  final String _scanId;

  WorkflowNotifier(this._service, this._scanId)
      : super(const WorkflowState());

  /// Load workflow graph
  Future<void> loadWorkflow() async {
    // Skip if data is fresh
    if (state.isFresh && state.hasData) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final graph = await _service.getWorkflowGraph(_scanId);
      state = state.copyWith(
        graph: graph,
        isLoading: false,
        lastUpdated: DateTime.now(),
      );
    } on WorkflowNotFoundException {
      // Not an error — workflow data simply doesn't exist for this scan
      state = state.copyWith(
        isLoading: false,
      );
    } on WorkflowException catch (e) {
      state = state.copyWith(
        error: e.message,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load workflow: $e',
        isLoading: false,
      );
    }
  }

  /// Load workflow timeline
  Future<void> loadTimeline() async {
    try {
      final timeline = await _service.getWorkflowTimeline(_scanId);
      state = state.copyWith(timeline: timeline);
    } on WorkflowNotFoundException {
      // Not an error — no timeline data for this scan
    } on WorkflowException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load timeline: $e');
    }
  }

  /// Export workflow in specified format
  Future<String?> exportWorkflow(String format) async {
    try {
      final data = await _service.exportWorkflow(_scanId, format);
      return data;
    } on WorkflowNotFoundException {
      return null;
    } on WorkflowException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(error: 'Failed to export workflow: $e');
      return null;
    }
  }

  /// Refresh workflow data
  Future<void> refresh() async {
    state = state.copyWith(lastUpdated: null);
    await loadWorkflow();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset state
  void reset() {
    state = const WorkflowState();
  }
}

/// Workflow service provider
final workflowServiceProvider = Provider<WorkflowService>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return WorkflowService(
    baseUrl: apiService.baseUrl,
    connectionTimeout: apiService.connectionTimeout,
    receiveTimeout: apiService.receiveTimeout,
  );
});

/// Workflow provider family (by scan_id)
/// Use this provider to access workflow data for a specific scan
final workflowProvider =
    StateNotifierProvider.family<WorkflowNotifier, WorkflowState, String>(
  (ref, scanId) {
    final service = ref.watch(workflowServiceProvider);
    return WorkflowNotifier(service, scanId);
  },
);

/// Convenience provider to check if workflow exists for a scan
final hasWorkflowProvider = FutureProvider.family<bool, String>((ref, scanId) async {
  final service = ref.watch(workflowServiceProvider);
  return await service.hasWorkflow(scanId);
});
