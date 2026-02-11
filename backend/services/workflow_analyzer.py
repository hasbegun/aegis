"""
Workflow Analyzer Service
Parses Garak output to build workflow graphs showing probe-LLM interactions
"""
import re
import time
import json
from typing import Dict, List, Optional, Any, Set
from uuid import uuid4

from models.schemas import (
    WorkflowGraph,
    WorkflowNode,
    WorkflowEdge,
    WorkflowTrace,
    WorkflowNodeType,
    WorkflowEdgeType,
    VulnerabilityFinding,
    WorkflowTimelineEvent
)


class WorkflowAnalyzer:
    """Analyzes Garak output to build workflow graphs"""

    def __init__(self):
        # Store active workflows by scan_id
        self.active_workflows: Dict[str, WorkflowGraph] = {}
        # Track which probes we've already created nodes for
        self._seen_probes: Dict[str, Set[str]] = {}
        # Track current probe per scan for linking edges
        self._current_probe: Dict[str, str] = {}

        # Pattern matchers for actual garak CLI output
        self.patterns = {
            # probes.atkgen.Tox:  32%|███▏      | 8/25 [02:14<04:50, 17.09s/it]
            'probe_progress': re.compile(
                r'probes\.(\S+?):\s+(\d+)%'
            ),
            # turn 01: waiting for [llama3.2:3]:  10%|█         | 1/10
            'model_turn': re.compile(
                r'turn\s+(\d+):\s+waiting for \[([^\]]+)\]'
            ),
            # turn 02: red teaming [attackgene]:  20%|██        | 2/10
            'generator_turn': re.compile(
                r'turn\s+(\d+):\s+red teaming \[([^\]]+)\]'
            ),
            # atkgen.Tox  toxicity.ToxicityDetector: PASS  ok on  29/29
            'probe_result': re.compile(
                r'([\w\.]+)\s+([\w\.]+):\s+(PASS|FAIL)\s+ok on\s+(\d+)\s*/\s*(\d+)'
            ),
            # 1 3/51 [00:52<13:08, 16.44s/it]  (overall probe counter)
            'overall_progress': re.compile(
                r'^\s*\d+\s+(\d+)/(\d+)\s+\['
            ),
        }

    def get_or_create_workflow(self, scan_id: str) -> WorkflowGraph:
        """Get existing workflow or create new one"""
        if scan_id not in self.active_workflows:
            self.active_workflows[scan_id] = WorkflowGraph(
                scan_id=scan_id,
                nodes=[],
                edges=[],
                traces=[],
                statistics={
                    'total_interactions': 0,
                    'total_prompts': 0,
                    'total_responses': 0,
                    'vulnerabilities_found': 0,
                    'probes_executed': 0
                },
                layout_hints={}
            )
            self._seen_probes[scan_id] = set()
        return self.active_workflows[scan_id]

    def process_garak_output(self, scan_id: str, output_line: str) -> Optional[Dict[str, Any]]:
        """
        Process a single line of Garak output and update workflow graph

        Args:
            scan_id: Scan identifier
            output_line: Single line from Garak output

        Returns:
            Dictionary with parsed event data or None
        """
        workflow = self.get_or_create_workflow(scan_id)
        line = output_line.strip()

        if not line:
            return None

        timestamp = time.time()
        event = None

        # Check for probe progress (first seen = probe start)
        if match := self.patterns['probe_progress'].search(line):
            probe_name = match.group(1)
            percent = int(match.group(2))
            event = self._handle_probe_progress(workflow, scan_id, probe_name, percent, timestamp)

        # Check for model turn (waiting for model response)
        elif match := self.patterns['model_turn'].search(line):
            turn_num = int(match.group(1))
            model_name = match.group(2)
            event = self._handle_model_turn(workflow, scan_id, model_name, turn_num, timestamp)

        # Check for generator turn (red teaming)
        elif match := self.patterns['generator_turn'].search(line):
            turn_num = int(match.group(1))
            generator_name = match.group(2)
            event = self._handle_generator_turn(workflow, scan_id, generator_name, turn_num, timestamp)

        # Check for probe result (PASS/FAIL with detector)
        elif match := self.patterns['probe_result'].search(line):
            probe_name = match.group(1)
            detector_name = match.group(2)
            result = match.group(3)
            passed = int(match.group(4))
            total = int(match.group(5))
            event = self._handle_probe_result(
                workflow, scan_id, probe_name, detector_name,
                result, passed, total, timestamp
            )

        return event

    def _ensure_probe_node(self, workflow: WorkflowGraph, scan_id: str,
                           probe_name: str, timestamp: float) -> str:
        """Create a probe node if not already seen. Returns node_id."""
        if probe_name in self._seen_probes.get(scan_id, set()):
            # Find existing node_id
            for node in workflow.nodes:
                if node.node_type == WorkflowNodeType.PROBE and node.name == probe_name:
                    return node.node_id
            # Shouldn't happen, but generate a new one
            return f"probe_{probe_name.replace('.', '_')}"

        node_id = f"probe_{probe_name.replace('.', '_')}"
        node = WorkflowNode(
            node_id=node_id,
            node_type=WorkflowNodeType.PROBE,
            name=probe_name,
            description=f"Security probe: {probe_name}",
            metadata={'status': 'running'},
            timestamp=timestamp
        )
        workflow.nodes.append(node)
        self._seen_probes.setdefault(scan_id, set()).add(probe_name)
        workflow.statistics['probes_executed'] = workflow.statistics.get('probes_executed', 0) + 1

        # Create a new trace for this probe
        trace = WorkflowTrace(
            trace_id=str(uuid4()),
            scan_id=scan_id,
            probe_name=probe_name,
            nodes=[node],
            edges=[],
            vulnerability_findings=[],
            statistics={}
        )
        workflow.traces.append(trace)

        return node_id

    def _get_trace_for_probe(self, workflow: WorkflowGraph,
                             probe_name: str) -> Optional[WorkflowTrace]:
        """Find the trace for a given probe."""
        for trace in workflow.traces:
            if trace.probe_name == probe_name:
                return trace
        return None

    def _handle_probe_progress(self, workflow: WorkflowGraph, scan_id: str,
                               probe_name: str, percent: int,
                               timestamp: float) -> Dict:
        """Handle probe progress line — creates probe node on first sight."""
        node_id = self._ensure_probe_node(workflow, scan_id, probe_name, timestamp)
        self._current_probe[scan_id] = probe_name

        # Update progress in the probe node metadata
        for node in workflow.nodes:
            if node.node_id == node_id:
                node.metadata['progress'] = percent
                break

        return {
            'type': 'probe_progress',
            'probe_name': probe_name,
            'percent': percent,
            'node_id': node_id,
        }

    def _handle_model_turn(self, workflow: WorkflowGraph, scan_id: str,
                           model_name: str, turn_num: int,
                           timestamp: float) -> Dict:
        """Handle model interaction turn (waiting for LLM response)."""
        current_probe = self._current_probe.get(scan_id)
        node_id = f"llm_{model_name.replace('.', '_').replace(':', '_')}_{len(workflow.nodes)}"

        node = WorkflowNode(
            node_id=node_id,
            node_type=WorkflowNodeType.LLM_RESPONSE,
            name=f"{model_name} (turn {turn_num})",
            description=f"Waiting for response from {model_name}",
            metadata={'model': model_name, 'turn': turn_num},
            timestamp=timestamp
        )
        workflow.nodes.append(node)
        workflow.statistics['total_responses'] = workflow.statistics.get('total_responses', 0) + 1
        workflow.statistics['total_interactions'] = workflow.statistics.get('total_interactions', 0) + 1

        # Link from current probe to this LLM node
        if current_probe:
            trace = self._get_trace_for_probe(workflow, current_probe)
            if trace:
                trace.nodes.append(node)
                probe_node_id = f"probe_{current_probe.replace('.', '_')}"
                edge = WorkflowEdge(
                    edge_id=str(uuid4()),
                    source_id=probe_node_id,
                    target_id=node_id,
                    edge_type=WorkflowEdgeType.PROMPT,
                    content_preview=f"Turn {turn_num}: querying {model_name}",
                    full_content="",
                    metadata={'turn': turn_num}
                )
                workflow.edges.append(edge)
                trace.edges.append(edge)

        return {
            'type': 'model_turn',
            'model_name': model_name,
            'turn': turn_num,
            'node_id': node_id,
        }

    def _handle_generator_turn(self, workflow: WorkflowGraph, scan_id: str,
                               generator_name: str, turn_num: int,
                               timestamp: float) -> Dict:
        """Handle generator turn (red teaming / attack generation)."""
        current_probe = self._current_probe.get(scan_id)
        node_id = f"gen_{generator_name.replace('.', '_')}_{len(workflow.nodes)}"

        node = WorkflowNode(
            node_id=node_id,
            node_type=WorkflowNodeType.GENERATOR,
            name=f"{generator_name} (turn {turn_num})",
            description=f"Red teaming attack generation",
            metadata={'generator': generator_name, 'turn': turn_num},
            timestamp=timestamp
        )
        workflow.nodes.append(node)
        workflow.statistics['total_prompts'] = workflow.statistics.get('total_prompts', 0) + 1
        workflow.statistics['total_interactions'] = workflow.statistics.get('total_interactions', 0) + 1

        # Link from current probe to this generator node
        if current_probe:
            trace = self._get_trace_for_probe(workflow, current_probe)
            if trace:
                trace.nodes.append(node)
                probe_node_id = f"probe_{current_probe.replace('.', '_')}"
                edge = WorkflowEdge(
                    edge_id=str(uuid4()),
                    source_id=probe_node_id,
                    target_id=node_id,
                    edge_type=WorkflowEdgeType.CHAIN,
                    content_preview=f"Turn {turn_num}: generating attack",
                    full_content="",
                    metadata={'turn': turn_num}
                )
                workflow.edges.append(edge)
                trace.edges.append(edge)

        return {
            'type': 'generator_turn',
            'generator_name': generator_name,
            'turn': turn_num,
            'node_id': node_id,
        }

    def _handle_probe_result(self, workflow: WorkflowGraph, scan_id: str,
                             probe_name: str, detector_name: str,
                             result: str, passed: int, total: int,
                             timestamp: float) -> Dict:
        """Handle probe result line (PASS/FAIL with detector)."""
        # Ensure the probe node exists (in case we missed progress lines)
        self._ensure_probe_node(workflow, scan_id, probe_name, timestamp)

        # Create detector node
        det_node_id = f"det_{detector_name.replace('.', '_')}_{len(workflow.nodes)}"
        det_node = WorkflowNode(
            node_id=det_node_id,
            node_type=WorkflowNodeType.DETECTOR,
            name=detector_name,
            description=f"Detector: {detector_name}",
            metadata={
                'result': result,
                'passed': passed,
                'total': total,
                'failed': total - passed,
            },
            timestamp=timestamp
        )
        workflow.nodes.append(det_node)

        # Mark probe node as completed
        probe_node_id = f"probe_{probe_name.replace('.', '_')}"
        for node in workflow.nodes:
            if node.node_id == probe_node_id:
                node.metadata['status'] = 'completed'
                node.metadata['completed_at'] = timestamp
                break

        # Get or create trace, add detector node
        trace = self._get_trace_for_probe(workflow, probe_name)
        if trace:
            trace.nodes.append(det_node)

            # Edge from probe to detector
            edge = WorkflowEdge(
                edge_id=str(uuid4()),
                source_id=probe_node_id,
                target_id=det_node_id,
                edge_type=WorkflowEdgeType.DETECTION,
                content_preview=f"{result}: {passed}/{total} ok",
                full_content=f"{probe_name} {detector_name}: {result} ok on {passed}/{total}",
                metadata={'result': result, 'passed': passed, 'total': total}
            )
            workflow.edges.append(edge)
            trace.edges.append(edge)

        # Handle FAIL — create vulnerability node
        if result == "FAIL":
            failed_count = total - passed
            vuln_node_id = f"vuln_{probe_name.replace('.', '_')}_{len(workflow.nodes)}"
            vuln_node = WorkflowNode(
                node_id=vuln_node_id,
                node_type=WorkflowNodeType.VULNERABILITY,
                name=f"Vulnerability: {probe_name}",
                description=f"{failed_count}/{total} tests failed for {probe_name}",
                metadata={
                    'severity': 'high' if failed_count > total // 2 else 'medium',
                    'failed': failed_count,
                    'total': total,
                },
                timestamp=timestamp
            )
            workflow.nodes.append(vuln_node)
            workflow.statistics['vulnerabilities_found'] = (
                workflow.statistics.get('vulnerabilities_found', 0) + 1
            )

            # Edge from detector to vulnerability
            vuln_edge = WorkflowEdge(
                edge_id=str(uuid4()),
                source_id=det_node_id,
                target_id=vuln_node_id,
                edge_type=WorkflowEdgeType.DETECTION,
                content_preview=f"{failed_count} failures detected",
                full_content=f"{failed_count}/{total} tests failed",
                metadata={'failed': failed_count, 'total': total}
            )
            workflow.edges.append(vuln_edge)

            if trace:
                trace.nodes.append(vuln_node)
                trace.edges.append(vuln_edge)

                finding = VulnerabilityFinding(
                    vulnerability_type=f"{probe_name} failure",
                    severity='high' if failed_count > total // 2 else 'medium',
                    probe_name=probe_name,
                    node_path=[probe_node_id, det_node_id, vuln_node_id],
                    evidence=f"{detector_name}: FAIL ok on {passed}/{total}"
                )
                trace.vulnerability_findings.append(finding)

        return {
            'type': 'probe_result',
            'probe_name': probe_name,
            'detector_name': detector_name,
            'result': result,
            'passed': passed,
            'total': total,
        }

    def build_from_report_entries(self, scan_id: str,
                                  entries: List[dict]) -> Optional[WorkflowGraph]:
        """Build a workflow graph from parsed JSONL report entries.

        This is the fallback for completed scans where we no longer have
        real-time stdout data.  It creates the same node/edge structure
        from the report's attempt and eval records.
        """
        if not entries:
            return None

        timestamp = time.time()
        workflow = self.get_or_create_workflow(scan_id)

        # Collect per-probe attempt counts
        probe_counts: Dict[str, Dict[str, int]] = {}
        probe_goals: Dict[str, str] = {}
        target_model: Optional[str] = None

        for entry in entries:
            etype = entry.get("entry_type")

            if etype == "config":
                target_model = entry.get("plugins.target_name")

            elif etype == "attempt":
                probe = entry.get("probe_classname", "unknown")
                if probe not in probe_counts:
                    probe_counts[probe] = {"passed": 0, "failed": 0}
                status = entry.get("status")
                if status == 2:
                    probe_counts[probe]["passed"] += 1
                elif status == 1:
                    probe_counts[probe]["failed"] += 1
                goal = entry.get("goal")
                if goal and probe not in probe_goals:
                    probe_goals[probe] = goal

            elif etype == "eval":
                probe = entry.get("probe")
                detector = entry.get("detector")
                passed = entry.get("passed", 0)
                total = entry.get("total", 0)
                if probe and detector and total > 0:
                    result = "PASS" if passed == total else "FAIL"
                    self._handle_probe_result(
                        workflow, scan_id, probe, detector,
                        result, passed, total, timestamp
                    )

        # For probes that had attempts but no eval entry, create probe nodes
        for probe_name in probe_counts:
            if probe_name not in self._seen_probes.get(scan_id, set()):
                self._ensure_probe_node(workflow, scan_id, probe_name, timestamp)
                # Mark completed since this is from a finished report
                node_id = f"probe_{probe_name.replace('.', '_')}"
                for node in workflow.nodes:
                    if node.node_id == node_id:
                        node.metadata['status'] = 'completed'
                        counts = probe_counts[probe_name]
                        node.metadata['passed'] = counts['passed']
                        node.metadata['failed'] = counts['failed']
                        node.metadata['total'] = counts['passed'] + counts['failed']
                        if probe_name in probe_goals:
                            node.description = probe_goals[probe_name]
                        break

        # Store target model in layout hints for the frontend
        if target_model:
            workflow.layout_hints['target_model'] = target_model

        if not workflow.nodes:
            # No useful data extracted
            self.clear_workflow(scan_id)
            return None

        return workflow

    def get_workflow_graph(self, scan_id: str) -> Optional[WorkflowGraph]:
        """Get workflow graph for a scan"""
        return self.active_workflows.get(scan_id)

    def get_workflow_timeline(self, scan_id: str) -> List[WorkflowTimelineEvent]:
        """Get chronological timeline of workflow events"""
        workflow = self.active_workflows.get(scan_id)
        if not workflow:
            return []

        events = []
        for i, node in enumerate(sorted(workflow.nodes, key=lambda n: n.timestamp)):
            event = WorkflowTimelineEvent(
                event_id=f"event_{i}",
                event_type=node.node_type.value,
                timestamp=node.timestamp,
                title=node.name,
                description=node.description,
                node_id=node.node_id,
                metadata=node.metadata
            )

            # Add prompt/response if available from edges
            for edge in workflow.edges:
                if edge.target_id == node.node_id:
                    if edge.edge_type == WorkflowEdgeType.PROMPT:
                        event.prompt = edge.full_content
                    elif edge.edge_type == WorkflowEdgeType.RESPONSE:
                        event.response = edge.full_content

            # Add duration if available
            if 'latency_ms' in node.metadata:
                event.duration_ms = node.metadata['latency_ms']

            events.append(event)

        return events

    def export_workflow(self, scan_id: str, format: str = "json") -> str:
        """Export workflow in specified format"""
        workflow = self.active_workflows.get(scan_id)
        if not workflow:
            return ""

        if format == "json":
            return workflow.model_dump_json(indent=2)

        elif format == "mermaid":
            return self._export_mermaid(workflow)

        else:
            raise ValueError(f"Unsupported export format: {format}")

    def _export_mermaid(self, workflow: WorkflowGraph) -> str:
        """Export workflow as Mermaid diagram"""
        lines = ["graph TD"]

        # Add nodes
        for node in workflow.nodes:
            node_label = node.name.replace('"', "'")
            shape = self._get_mermaid_shape(node.node_type)
            lines.append(f'  {node.node_id}{shape[0]}"{node_label}"{shape[1]}')

        # Add edges
        for edge in workflow.edges:
            edge_label = edge.edge_type.value
            lines.append(f'  {edge.source_id} -->|{edge_label}| {edge.target_id}')

        return "\n".join(lines)

    def _get_mermaid_shape(self, node_type: WorkflowNodeType) -> tuple:
        """Get Mermaid shape brackets for node type"""
        shapes = {
            WorkflowNodeType.PROBE: ('[', ']'),
            WorkflowNodeType.GENERATOR: ('(', ')'),
            WorkflowNodeType.DETECTOR: ('{', '}'),
            WorkflowNodeType.LLM_RESPONSE: ('([', '])'),
            WorkflowNodeType.VULNERABILITY: ('[[', ']]'),
        }
        return shapes.get(node_type, ('[', ']'))

    def clear_workflow(self, scan_id: str):
        """Clear workflow data for a scan"""
        if scan_id in self.active_workflows:
            del self.active_workflows[scan_id]
        self._seen_probes.pop(scan_id, None)
        self._current_probe.pop(scan_id, None)


# Global instance
workflow_analyzer = WorkflowAnalyzer()
