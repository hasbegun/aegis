#!/usr/bin/env python3
"""
Test script to verify enhanced DAN probe with mitigation recommendations.
"""

from garak.probes.dan import DAN_Jailbreak
from garak.attempt import Attempt, ATTEMPT_COMPLETE

print("=" * 70)
print("Testing Enhanced DAN_Jailbreak Probe")
print("=" * 70)

# Create a probe instance
probe = DAN_Jailbreak()
print(f"\n✅ Probe created: {probe.__class__.__name__}")

# Create a test attempt
attempt = Attempt(
    prompt="Test jailbreak prompt",
    probe_classname="dan.DAN_Jailbreak"
)
attempt.status = ATTEMPT_COMPLETE

# Simulate a failed detection (vulnerability found)
attempt.detector_results = {
    "dan.DANJailbreak": [1.0]  # Score > 0 means detection (failure)
}

print(f"✅ Test attempt created with simulated jailbreak detection")

# Call the prestore hook
enhanced_attempt = probe._attempt_prestore_hook(attempt, seq=0)

print(f"\n✅ Prestore hook executed successfully!")
print("\n" + "=" * 70)
print("Enhanced Attempt Fields:")
print("=" * 70)

print(f"\n📅 Timestamp: {enhanced_attempt.timestamp}")
print(f"⚠️  Severity: {enhanced_attempt.severity}")
print(f"🎯 Attack Technique: {enhanced_attempt.attack_technique}")
print(f"🏷️  CWE IDs: {enhanced_attempt.cwe_ids}")
print(f"🏷️  OWASP Categories: {enhanced_attempt.owasp_categories}")

print(f"\n📝 Vulnerability Explanation:")
print(f"   {enhanced_attempt.vulnerability_explanation[:150]}...")

print(f"\n🛡️  Mitigation Recommendations ({len(enhanced_attempt.mitigation_recommendations)} total):")
for i, rec in enumerate(enhanced_attempt.mitigation_recommendations[:3], 1):
    print(f"   {i}. {rec[:80]}...")

print(f"\n📚 References ({len(enhanced_attempt.references)} total):")
for ref in enhanced_attempt.references[:2]:
    print(f"   - {ref['title']}")
    print(f"     {ref['url']}")

print(f"\n🔄 Reproduction Steps ({len(enhanced_attempt.reproduction_steps)} total):")
for step in enhanced_attempt.reproduction_steps[:3]:
    print(f"   {step}")

# Test serialization to JSONL
print("\n" + "=" * 70)
print("Testing JSONL Serialization:")
print("=" * 70)

data = enhanced_attempt.as_dict()
required_fields = [
    'vulnerability_explanation',
    'mitigation_recommendations',
    'severity',
    'cwe_ids',
    'owasp_categories',
    'attack_technique',
    'reproduction_steps',
    'timestamp',
    'references'
]

all_present = all(field in data for field in required_fields)
print(f"\n✅ All enhanced fields present in JSONL: {all_present}")

if all_present:
    print("\n✨ SUCCESS! The enhanced probe is working correctly!")
    print("\nYou can now run a real scan with:")
    print("  python -m garak --target_type ollama --target_name <model> --probes dan.DAN_Jailbreak")
    print("\nThe JSONL report will include all mitigation recommendations!")
else:
    print("\n❌ ERROR: Some fields are missing from serialization")
    missing = [f for f in required_fields if f not in data]
    print(f"Missing fields: {missing}")

print("\n" + "=" * 70)
