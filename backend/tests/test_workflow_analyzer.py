"""
Tests for WorkflowAnalyzer — verifies that garak's actual stdout patterns
are parsed into workflow graph nodes, edges, and traces.
"""
import os
import sys

import pytest

# Add backend root to path so we can import modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.workflow_analyzer import WorkflowAnalyzer
from models.schemas import WorkflowNodeType, WorkflowEdgeType


SCAN_ID = "test-scan-001"


@pytest.fixture
def analyzer():
    """Fresh WorkflowAnalyzer for each test."""
    return WorkflowAnalyzer()


# ---------------------------------------------------------------------------
# Probe progress lines
# ---------------------------------------------------------------------------

class TestProbeProgress:
    """Test that probe progress lines create PROBE nodes."""

    def test_probe_progress_creates_node(self, analyzer):
        event = analyzer.process_garak_output(
            SCAN_ID,
            "probes.encoding.InjectBase64:  42%|████▏     | 5/12 [00:55<01:13, 10.55s/it]"
        )
        assert event is not None
        assert event["type"] == "probe_progress"
        assert event["probe_name"] == "encoding.InjectBase64"
        assert event["percent"] == 42

        wf = analyzer.get_workflow_graph(SCAN_ID)
        assert len(wf.nodes) == 1
        assert wf.nodes[0].node_type == WorkflowNodeType.PROBE
        assert wf.nodes[0].name == "encoding.InjectBase64"

    def test_probe_progress_100_percent(self, analyzer):
        event = analyzer.process_garak_output(
            SCAN_ID,
            "probes.encoding.InjectBase64: 100%|██████████| 12/12 [00:55<00:00, 4.58s/it]"
        )
        assert event is not None
        assert event["percent"] == 100

    def test_duplicate_probe_progress_no_extra_node(self, analyzer):
        """Multiple progress lines for same probe should not create duplicate nodes."""
        analyzer.process_garak_output(
            SCAN_ID,
            "probes.encoding.InjectBase64:  10%|█         | 1/12"
        )
        analyzer.process_garak_output(
            SCAN_ID,
            "probes.encoding.InjectBase64:  50%|█████     | 6/12"
        )

        wf = analyzer.get_workflow_graph(SCAN_ID)
        probe_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.PROBE]
        assert len(probe_nodes) == 1
        # Progress should be updated to latest
        assert probe_nodes[0].metadata["progress"] == 50

    def test_multiple_probes_create_separate_nodes(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64:  10%|█ | 1/12"
        )
        analyzer.process_garak_output(
            SCAN_ID, "probes.dan.DanJailbreak:   5%|▌ | 1/20"
        )

        wf = analyzer.get_workflow_graph(SCAN_ID)
        probe_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.PROBE]
        assert len(probe_nodes) == 2
        names = {n.name for n in probe_nodes}
        assert names == {"encoding.InjectBase64", "dan.DanJailbreak"}

    def test_probe_creates_trace(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64:  10%|█ | 1/12"
        )
        wf = analyzer.get_workflow_graph(SCAN_ID)
        assert len(wf.traces) == 1
        assert wf.traces[0].probe_name == "encoding.InjectBase64"


# ---------------------------------------------------------------------------
# Model turn lines (atkgen)
# ---------------------------------------------------------------------------

class TestModelTurn:
    """Test that 'turn XX: waiting for [model]' lines create LLM_RESPONSE nodes."""

    def test_model_turn_creates_llm_node(self, analyzer):
        # First create the probe context
        analyzer.process_garak_output(
            SCAN_ID, "probes.atkgen.Tox:  10%|█ | 1/25"
        )
        event = analyzer.process_garak_output(
            SCAN_ID,
            "turn 01: waiting for [llama3.2:3]:  10%|█         | 1/10"
        )
        assert event is not None
        assert event["type"] == "model_turn"
        assert event["model_name"] == "llama3.2:3"
        assert event["turn"] == 1

        wf = analyzer.get_workflow_graph(SCAN_ID)
        llm_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.LLM_RESPONSE]
        assert len(llm_nodes) == 1
        assert "llama3.2:3" in llm_nodes[0].name

    def test_model_turn_creates_edge_from_probe(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.atkgen.Tox:  10%|█ | 1/25"
        )
        analyzer.process_garak_output(
            SCAN_ID, "turn 01: waiting for [llama3.2:3]:  10%|█ | 1/10"
        )

        wf = analyzer.get_workflow_graph(SCAN_ID)
        assert len(wf.edges) == 1
        assert wf.edges[0].edge_type == WorkflowEdgeType.PROMPT
        assert "probe_" in wf.edges[0].source_id
        assert "llm_" in wf.edges[0].target_id

    def test_model_turn_updates_statistics(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.atkgen.Tox:  10%|█ | 1/25"
        )
        analyzer.process_garak_output(
            SCAN_ID, "turn 01: waiting for [llama3.2:3]:  10%|█ | 1/10"
        )
        wf = analyzer.get_workflow_graph(SCAN_ID)
        assert wf.statistics["total_responses"] == 1
        assert wf.statistics["total_interactions"] == 1


# ---------------------------------------------------------------------------
# Generator turn lines (atkgen red teaming)
# ---------------------------------------------------------------------------

class TestGeneratorTurn:
    """Test that 'turn XX: red teaming [generator]' lines create GENERATOR nodes."""

    def test_generator_turn_creates_node(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.atkgen.Tox:  10%|█ | 1/25"
        )
        event = analyzer.process_garak_output(
            SCAN_ID,
            "turn 02: red teaming [attackgene]:  20%|██        | 2/10"
        )
        assert event is not None
        assert event["type"] == "generator_turn"
        assert event["generator_name"] == "attackgene"
        assert event["turn"] == 2

        wf = analyzer.get_workflow_graph(SCAN_ID)
        gen_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.GENERATOR]
        assert len(gen_nodes) == 1

    def test_generator_turn_creates_chain_edge(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.atkgen.Tox:  10%|█ | 1/25"
        )
        analyzer.process_garak_output(
            SCAN_ID, "turn 02: red teaming [attackgene]:  20%|██ | 2/10"
        )

        wf = analyzer.get_workflow_graph(SCAN_ID)
        chain_edges = [e for e in wf.edges if e.edge_type == WorkflowEdgeType.CHAIN]
        assert len(chain_edges) == 1


# ---------------------------------------------------------------------------
# Probe result lines (PASS / FAIL)
# ---------------------------------------------------------------------------

class TestProbeResult:
    """Test that result lines create DETECTOR nodes and optionally VULNERABILITY nodes."""

    def test_pass_result_creates_detector_node(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 100%|██████| 12/12"
        )
        event = analyzer.process_garak_output(
            SCAN_ID,
            "encoding.InjectBase64  encoding.InjectBase64Detector: PASS  ok on   12/  12"
        )
        assert event is not None
        assert event["type"] == "probe_result"
        assert event["result"] == "PASS"
        assert event["passed"] == 12
        assert event["total"] == 12

        wf = analyzer.get_workflow_graph(SCAN_ID)
        det_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.DETECTOR]
        assert len(det_nodes) == 1
        assert det_nodes[0].metadata["result"] == "PASS"

    def test_pass_result_no_vulnerability_node(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 100%|██████| 12/12"
        )
        analyzer.process_garak_output(
            SCAN_ID,
            "encoding.InjectBase64  encoding.InjectBase64Detector: PASS  ok on  12/12"
        )

        wf = analyzer.get_workflow_graph(SCAN_ID)
        vuln_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.VULNERABILITY]
        assert len(vuln_nodes) == 0

    def test_fail_result_creates_vulnerability_node(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.dan.DanJailbreak:  100%|██████| 20/20"
        )
        event = analyzer.process_garak_output(
            SCAN_ID,
            "dan.DanJailbreak  dan.DanDetector: FAIL  ok on  15/ 20"
        )
        assert event["result"] == "FAIL"
        assert event["passed"] == 15
        assert event["total"] == 20

        wf = analyzer.get_workflow_graph(SCAN_ID)
        vuln_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.VULNERABILITY]
        assert len(vuln_nodes) == 1
        assert vuln_nodes[0].metadata["failed"] == 5
        assert wf.statistics["vulnerabilities_found"] == 1

    def test_fail_creates_vulnerability_finding_in_trace(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.dan.DanJailbreak: 100%|██████| 20/20"
        )
        analyzer.process_garak_output(
            SCAN_ID, "dan.DanJailbreak  dan.DanDetector: FAIL  ok on  15/ 20"
        )

        wf = analyzer.get_workflow_graph(SCAN_ID)
        trace = wf.traces[0]
        assert len(trace.vulnerability_findings) == 1
        assert trace.vulnerability_findings[0].probe_name == "dan.DanJailbreak"

    def test_result_marks_probe_completed(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 100%|██████| 12/12"
        )
        analyzer.process_garak_output(
            SCAN_ID,
            "encoding.InjectBase64  encoding.InjectBase64Detector: PASS  ok on  12/12"
        )

        wf = analyzer.get_workflow_graph(SCAN_ID)
        probe_node = [n for n in wf.nodes if n.node_type == WorkflowNodeType.PROBE][0]
        assert probe_node.metadata["status"] == "completed"

    def test_result_creates_detection_edge(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 100%|██████| 12/12"
        )
        analyzer.process_garak_output(
            SCAN_ID,
            "encoding.InjectBase64  encoding.InjectBase64Detector: PASS  ok on  12/12"
        )

        wf = analyzer.get_workflow_graph(SCAN_ID)
        det_edges = [e for e in wf.edges if e.edge_type == WorkflowEdgeType.DETECTION]
        assert len(det_edges) == 1
        assert "probe_" in det_edges[0].source_id
        assert "det_" in det_edges[0].target_id

    def test_result_without_prior_progress(self, analyzer):
        """Result line for a probe we never saw progress for should still work."""
        event = analyzer.process_garak_output(
            SCAN_ID,
            "encoding.InjectBase64  encoding.InjectBase64Detector: PASS  ok on  12/12"
        )
        assert event is not None
        assert event["type"] == "probe_result"

        wf = analyzer.get_workflow_graph(SCAN_ID)
        # Should have created probe node + detector node
        probe_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.PROBE]
        det_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.DETECTOR]
        assert len(probe_nodes) == 1
        assert len(det_nodes) == 1


# ---------------------------------------------------------------------------
# Full atkgen flow
# ---------------------------------------------------------------------------

class TestAtkgenFlow:
    """Test a realistic atkgen probe output sequence."""

    def test_full_atkgen_flow(self, analyzer):
        lines = [
            "probes.atkgen.Tox:  10%|█         | 1/25 [00:14<04:50, 17.09s/it]",
            "turn 01: waiting for [llama3.2:3]:  10%|█         | 1/10",
            "turn 02: red teaming [attackgene]:  20%|██        | 2/10",
            "turn 03: waiting for [llama3.2:3]:  30%|███       | 3/10",
            "turn 04: red teaming [attackgene]:  40%|████      | 4/10",
            "probes.atkgen.Tox:  50%|█████     | 12/25",
            "probes.atkgen.Tox: 100%|██████████| 25/25 [02:14<00:00, 5.37s/it]",
            "atkgen.Tox  toxicity.ToxicityDetector: PASS  ok on  29/ 29",
        ]

        for line in lines:
            analyzer.process_garak_output(SCAN_ID, line)

        wf = analyzer.get_workflow_graph(SCAN_ID)

        # 1 probe + 2 LLM + 2 generator + 1 detector = 6 nodes
        assert len(wf.nodes) == 6
        probe_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.PROBE]
        llm_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.LLM_RESPONSE]
        gen_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.GENERATOR]
        det_nodes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.DETECTOR]

        assert len(probe_nodes) == 1
        assert len(llm_nodes) == 2
        assert len(gen_nodes) == 2
        assert len(det_nodes) == 1

        # Probe should be completed
        assert probe_nodes[0].metadata["status"] == "completed"

        # Statistics
        assert wf.statistics["probes_executed"] == 1
        assert wf.statistics["total_responses"] == 2
        assert wf.statistics["total_prompts"] == 2
        assert wf.statistics["vulnerabilities_found"] == 0


# ---------------------------------------------------------------------------
# Multi-probe scan
# ---------------------------------------------------------------------------

class TestMultiProbeScan:
    """Test a scan with multiple probes."""

    def test_multiple_probes_with_mixed_results(self, analyzer):
        lines = [
            "probes.encoding.InjectBase64: 100%|██████████| 12/12",
            "encoding.InjectBase64  encoding.InjectBase64Detector: PASS  ok on  12/ 12",
            "probes.dan.DanJailbreak: 100%|██████████| 20/20",
            "dan.DanJailbreak  dan.DanDetector: FAIL  ok on  15/ 20",
        ]
        for line in lines:
            analyzer.process_garak_output(SCAN_ID, line)

        wf = analyzer.get_workflow_graph(SCAN_ID)
        assert wf.statistics["probes_executed"] == 2
        assert wf.statistics["vulnerabilities_found"] == 1

        # 2 probe + 2 detector + 1 vulnerability = 5 nodes
        assert len(wf.nodes) == 5
        assert len(wf.traces) == 2


# ---------------------------------------------------------------------------
# Timeline
# ---------------------------------------------------------------------------

class TestTimeline:
    """Test timeline generation."""

    def test_timeline_returns_sorted_events(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 100%|██████| 12/12"
        )
        analyzer.process_garak_output(
            SCAN_ID,
            "encoding.InjectBase64  encoding.InjectBase64Detector: PASS  ok on  12/12"
        )

        timeline = analyzer.get_workflow_timeline(SCAN_ID)
        assert len(timeline) == 2
        assert timeline[0].timestamp <= timeline[1].timestamp

    def test_timeline_empty_for_unknown_scan(self, analyzer):
        timeline = analyzer.get_workflow_timeline("nonexistent")
        assert timeline == []


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

class TestEdgeCases:
    """Edge cases and non-matching lines."""

    def test_empty_line_returns_none(self, analyzer):
        assert analyzer.process_garak_output(SCAN_ID, "") is None
        assert analyzer.process_garak_output(SCAN_ID, "   ") is None

    def test_unmatched_line_returns_none(self, analyzer):
        assert analyzer.process_garak_output(SCAN_ID, "some random output") is None

    def test_clear_workflow(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 50%|█████| 6/12"
        )
        assert analyzer.get_workflow_graph(SCAN_ID) is not None

        analyzer.clear_workflow(SCAN_ID)
        assert analyzer.get_workflow_graph(SCAN_ID) is None

    def test_clear_nonexistent_workflow(self, analyzer):
        """clear_workflow for unknown scan should not raise."""
        analyzer.clear_workflow("nonexistent")

    def test_export_json(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 50%|█████| 6/12"
        )
        export = analyzer.export_workflow(SCAN_ID, "json")
        assert '"scan_id"' in export
        assert SCAN_ID in export

    def test_export_mermaid(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 50%|█████| 6/12"
        )
        export = analyzer.export_workflow(SCAN_ID, "mermaid")
        assert "graph TD" in export

    def test_export_unknown_format_raises(self, analyzer):
        analyzer.process_garak_output(
            SCAN_ID, "probes.encoding.InjectBase64: 50%|█████| 6/12"
        )
        with pytest.raises(ValueError, match="Unsupported"):
            analyzer.export_workflow(SCAN_ID, "pdf")

    def test_export_nonexistent_scan_returns_empty(self, analyzer):
        assert analyzer.export_workflow("nonexistent") == ""


# ---------------------------------------------------------------------------
# build_from_report_entries (JSONL fallback for completed scans)
# ---------------------------------------------------------------------------

class TestBuildFromReport:
    """Test building workflow from JSONL report entries."""

    REPORT_ENTRIES = [
        {
            "entry_type": "config",
            "plugins.target_type": "ollama",
            "plugins.target_name": "llama3.2:3b",
            "transient.starttime_iso": "2025-01-01T00:00:00",
        },
        {
            "entry_type": "attempt",
            "probe_classname": "dan.DanJailbreak",
            "status": 2,
            "goal": "Jailbreak the model",
        },
        {
            "entry_type": "attempt",
            "probe_classname": "dan.DanJailbreak",
            "status": 1,
            "goal": "Jailbreak the model",
        },
        {
            "entry_type": "attempt",
            "probe_classname": "encoding.InjectBase64",
            "status": 2,
            "goal": "Inject encoded content",
        },
        {
            "entry_type": "eval",
            "probe": "dan.DanJailbreak",
            "detector": "dan.DanDetector",
            "passed": 1,
            "total": 2,
        },
        {
            "entry_type": "eval",
            "probe": "encoding.InjectBase64",
            "detector": "encoding.InjectBase64Detector",
            "passed": 1,
            "total": 1,
        },
    ]

    def test_builds_workflow_from_entries(self, analyzer):
        wf = analyzer.build_from_report_entries(SCAN_ID, self.REPORT_ENTRIES)
        assert wf is not None
        assert wf.scan_id == SCAN_ID

    def test_creates_probe_nodes(self, analyzer):
        wf = analyzer.build_from_report_entries(SCAN_ID, self.REPORT_ENTRIES)
        probes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.PROBE]
        assert len(probes) == 2
        names = {n.name for n in probes}
        assert names == {"dan.DanJailbreak", "encoding.InjectBase64"}

    def test_creates_detector_nodes_from_eval(self, analyzer):
        wf = analyzer.build_from_report_entries(SCAN_ID, self.REPORT_ENTRIES)
        detectors = [n for n in wf.nodes if n.node_type == WorkflowNodeType.DETECTOR]
        assert len(detectors) == 2
        names = {n.name for n in detectors}
        assert names == {"dan.DanDetector", "encoding.InjectBase64Detector"}

    def test_creates_vulnerability_for_fail(self, analyzer):
        wf = analyzer.build_from_report_entries(SCAN_ID, self.REPORT_ENTRIES)
        vulns = [n for n in wf.nodes if n.node_type == WorkflowNodeType.VULNERABILITY]
        # dan.DanJailbreak FAIL (1/2), encoding passes (1/1)
        assert len(vulns) == 1
        assert "dan.DanJailbreak" in vulns[0].name

    def test_no_vulnerability_for_pass(self, analyzer):
        """All-passing entries should produce no vulnerability nodes."""
        entries = [
            {"entry_type": "config", "plugins.target_name": "test"},
            {"entry_type": "attempt", "probe_classname": "a.B", "status": 2},
            {"entry_type": "eval", "probe": "a.B", "detector": "a.D", "passed": 1, "total": 1},
        ]
        wf = analyzer.build_from_report_entries(SCAN_ID, entries)
        vulns = [n for n in wf.nodes if n.node_type == WorkflowNodeType.VULNERABILITY]
        assert len(vulns) == 0

    def test_stores_target_model_in_layout_hints(self, analyzer):
        wf = analyzer.build_from_report_entries(SCAN_ID, self.REPORT_ENTRIES)
        assert wf.layout_hints.get("target_model") == "llama3.2:3b"

    def test_creates_detection_edges(self, analyzer):
        wf = analyzer.build_from_report_entries(SCAN_ID, self.REPORT_ENTRIES)
        det_edges = [e for e in wf.edges if e.edge_type == WorkflowEdgeType.DETECTION]
        # 2 probe→detector edges + 1 detector→vulnerability edge = 3
        assert len(det_edges) == 3

    def test_returns_none_for_empty_entries(self, analyzer):
        wf = analyzer.build_from_report_entries(SCAN_ID, [])
        assert wf is None

    def test_returns_none_for_no_useful_data(self, analyzer):
        """Config-only entries produce no nodes → returns None."""
        entries = [{"entry_type": "config", "plugins.target_name": "test"}]
        wf = analyzer.build_from_report_entries(SCAN_ID, entries)
        assert wf is None

    def test_attempts_without_eval_still_create_probe_nodes(self, analyzer):
        """If there are attempts but no eval entries, probes should still appear."""
        entries = [
            {"entry_type": "attempt", "probe_classname": "a.Probe1", "status": 2, "goal": "Test"},
            {"entry_type": "attempt", "probe_classname": "a.Probe1", "status": 1, "goal": "Test"},
        ]
        wf = analyzer.build_from_report_entries(SCAN_ID, entries)
        assert wf is not None
        probes = [n for n in wf.nodes if n.node_type == WorkflowNodeType.PROBE]
        assert len(probes) == 1
        assert probes[0].metadata["passed"] == 1
        assert probes[0].metadata["failed"] == 1

    def test_graph_is_cached_after_build(self, analyzer):
        """After build, get_workflow_graph should return the same object."""
        wf = analyzer.build_from_report_entries(SCAN_ID, self.REPORT_ENTRIES)
        assert analyzer.get_workflow_graph(SCAN_ID) is wf

    def test_statistics_populated(self, analyzer):
        wf = analyzer.build_from_report_entries(SCAN_ID, self.REPORT_ENTRIES)
        assert wf.statistics["probes_executed"] == 2
        assert wf.statistics["vulnerabilities_found"] == 1

    def test_eval_with_total_evaluated_field(self, analyzer):
        """garak JSONL uses 'total_evaluated' instead of 'total' in eval entries."""
        entries = [
            {"entry_type": "attempt", "probe_classname": "ansiescape.AnsiEscaped", "status": 2},
            {"entry_type": "attempt", "probe_classname": "ansiescape.AnsiEscaped", "status": 1},
            {
                "entry_type": "eval",
                "probe": "ansiescape.AnsiEscaped",
                "detector": "ansiescape.Escaped",
                "passed": 128,
                "fails": 127,
                "total_evaluated": 255,
            },
        ]
        wf = analyzer.build_from_report_entries(SCAN_ID, entries)
        assert wf is not None
        # Should create detector node and edges from the eval entry
        detectors = [n for n in wf.nodes if n.node_type == WorkflowNodeType.DETECTOR]
        assert len(detectors) == 1
        assert detectors[0].name == "ansiescape.Escaped"
        # FAIL since passed(128) < total(255)
        det_edges = [e for e in wf.edges if e.edge_type == WorkflowEdgeType.DETECTION]
        assert len(det_edges) >= 1
        vulns = [n for n in wf.nodes if n.node_type == WorkflowNodeType.VULNERABILITY]
        assert len(vulns) == 1
