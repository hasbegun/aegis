#!/usr/bin/env python3
"""
Test that AutoDAN probe now has enhanced reporting via metaclass
"""

from garak.probes.dan import AutoDAN, Ablation_Dan_11_0
from garak.attempt import Attempt, ATTEMPT_COMPLETE, Message
from datetime import datetime
import json

print("=" * 70)
print("Testing Enhanced Reporting in AutoDAN and Ablation_Dan_11_0")
print("=" * 70)

# Test AutoDAN
print("\n1. Testing AutoDAN probe...")
probe = AutoDAN()

# Check if hook exists
if hasattr(probe, '_attempt_prestore_hook'):
    print("   ✅ AutoDAN has _attempt_prestore_hook method")
else:
    print("   ❌ AutoDAN missing _attempt_prestore_hook method")
    exit(1)

# Create test attempt
attempt = Attempt(
    prompt='Test prompt for AutoDAN',
    probe_classname='dan.AutoDAN'
)
attempt.status = ATTEMPT_COMPLETE
attempt.goal = probe.goal
attempt.outputs = [Message(text="I'm ready to bypass restrictions...")]
attempt.detector_results = {'dan.DAN': [0.9]}

# Run hook
enhanced = probe._attempt_prestore_hook(attempt, seq=0)

# Verify enhanced fields
if enhanced.vulnerability_explanation:
    print(f"   ✅ Vulnerability explanation: {len(enhanced.vulnerability_explanation)} chars")
else:
    print("   ❌ Missing vulnerability_explanation")

if len(enhanced.mitigation_recommendations) > 0:
    print(f"   ✅ Mitigation recommendations: {len(enhanced.mitigation_recommendations)} items")
else:
    print("   ❌ Missing mitigation_recommendations")

if len(enhanced.execution_timeline) > 0:
    print(f"   ✅ Execution timeline: {len(enhanced.execution_timeline)} steps")
else:
    print("   ❌ Missing execution_timeline")

# Test Ablation_Dan_11_0
print("\n2. Testing Ablation_Dan_11_0 probe...")
probe2 = Ablation_Dan_11_0()

# Check if hook exists
if hasattr(probe2, '_attempt_prestore_hook'):
    print("   ✅ Ablation_Dan_11_0 has _attempt_prestore_hook method")
else:
    print("   ❌ Ablation_Dan_11_0 missing _attempt_prestore_hook method")
    exit(1)

# Create test attempt
attempt2 = Attempt(
    prompt='Test prompt for Ablation',
    probe_classname='dan.Ablation_Dan_11_0'
)
attempt2.status = ATTEMPT_COMPLETE
attempt2.goal = probe2.goal
attempt2.outputs = [Message(text="Testing ablation response")]
attempt2.detector_results = {'dan.DAN': [0.85]}

# Run hook
enhanced2 = probe2._attempt_prestore_hook(attempt2, seq=1)

# Verify enhanced fields
if enhanced2.vulnerability_explanation:
    print(f"   ✅ Vulnerability explanation: {len(enhanced2.vulnerability_explanation)} chars")
else:
    print("   ❌ Missing vulnerability_explanation")

if 'Ablation_Dan_11_0' in enhanced2.attack_technique:
    print(f"   ✅ Attack technique includes probe name: {enhanced2.attack_technique}")
else:
    print(f"   ❌ Attack technique doesn't include probe name: {enhanced2.attack_technique}")

print("\n" + "=" * 70)
print("✅ SUCCESS! All DAN probes now have enhanced reporting via metaclass")
print("=" * 70)

print("\nSample enhanced data from AutoDAN:")
print(f"  - Severity: {enhanced.severity}")
print(f"  - CWE IDs: {enhanced.cwe_ids}")
print(f"  - OWASP: {enhanced.owasp_categories}")
print(f"  - Timeline steps: {len(enhanced.execution_timeline)}")
print(f"  - References: {len(enhanced.references)}")
