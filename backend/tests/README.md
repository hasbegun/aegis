# Test Suite

This directory contains tests for the Aegis Backend with Enhanced Reporting features.

## Test Files

### Enhanced Reporting Tests

#### `test_parallel_enhanced_reporting.py` ⭐ **Main Test Suite**
**Purpose:** Comprehensive test for all three high-priority probe categories in parallel

**Tests:**
- ✅ Prompt Injection (PromptInject.HijackHateHumans)
- ✅ Malware Generation (TopLevel, Payload)
- ✅ Encoding Bypass (Base64, ROT13)

**Coverage:** 5 probes across 3 categories

**Run:**
```bash
cd /Users/innox/projects/garak/aegis/backend
python tests/test_parallel_enhanced_reporting.py
```

**Expected Output:** `5/5 tests passed`

---

#### `test_postdetection_hook.py`
**Purpose:** Test the `_attempt_postdetection_hook()` for DAN probes

**Tests:**
- Hook exists on AntiDAN probe
- Hook runs after detection (when outputs and detector_results are populated)
- All enhanced fields are populated correctly
- JSONL serialization works

**Run:**
```bash
python tests/test_postdetection_hook.py
```

---

#### `test_enhanced_probe.py`
**Purpose:** Test enhanced metadata fields on DAN probes

**Tests:**
- Enhanced fields populated for failed attempts
- Correct CWE/OWASP mappings
- Mitigation recommendations present
- Severity levels correct

**Run:**
```bash
python tests/test_enhanced_probe.py
```

---

#### `test_autodan_enhanced.py`
**Purpose:** Test AutoDAN probe with enhanced reporting

**Tests:**
- AutoDAN specific metadata
- Attack technique identification
- References and timeline generation

**Run:**
```bash
python tests/test_autodan_enhanced.py
```

---

### Report Generation Tests

#### `test_complete_report.py`
**Purpose:** Test complete report generation with all fields

**Tests:**
- Full JSONL report structure
- All metadata fields present
- Correct JSON formatting
- HTML report generation

**Run:**
```bash
python tests/test_complete_report.py
```

---

#### `test_timeline.py`
**Purpose:** Test execution timeline generation

**Tests:**
- Timeline events created
- Correct timestamps
- Event ordering
- Timeline serialization

**Run:**
```bash
python tests/test_timeline.py
```

---

### Integration Tests

#### `test_real_scan.py`
**Purpose:** Integration test with real garak scan

**Tests:**
- End-to-end scan execution
- Report file generation
- Enhanced metadata in real reports
- JSONL file structure

**Run:**
```bash
python tests/test_real_scan.py
```

**Note:** Requires garak to be properly installed

---

#### `test_actual_outputs.py`
**Purpose:** Test reproduction steps with actual LLM outputs

**Tests:**
- Capture real model responses
- Format outputs in reproduction steps
- Show detector results with actual scores

**Run:**
```bash
python tests/test_actual_outputs.py
```

---

## Running All Tests

### Run Main Test Suite
```bash
# Most comprehensive test
python tests/test_parallel_enhanced_reporting.py
```

### Run All Tests
```bash
# Run all test files
for test in tests/test_*.py; do
    echo "Running $test..."
    python "$test"
done
```

### Quick Validation
```bash
# Run the three main tests
python tests/test_parallel_enhanced_reporting.py
python tests/test_postdetection_hook.py
python tests/test_complete_report.py
```

---

## Test Categories

| Category | Test Files | Status |
|----------|------------|--------|
| **Enhanced Reporting** | test_parallel_enhanced_reporting.py, test_postdetection_hook.py, test_enhanced_probe.py, test_autodan_enhanced.py | ✅ Passing |
| **Report Generation** | test_complete_report.py, test_timeline.py | ✅ Passing |
| **Integration** | test_real_scan.py, test_actual_outputs.py | ✅ Passing |

---

## Test Requirements

All tests require:
- Python 3.9+
- Enhanced garak fork installed from https://github.com/hasbegun/garak
- garak installed in development mode: `pip install -e /path/to/garak`

Verify installation:
```bash
python -c "from garak.probes._enhanced_reporting import BaseEnhancedReportingMixin; print('✅ OK')"
```

---

## Expected Test Results

### test_parallel_enhanced_reporting.py
```
Results: 5/5 probes passed

  ✅ PASS - Prompt Injection (HijackHateHumans)
  ✅ PASS - Malware Generation (TopLevel)
  ✅ PASS - Malware Generation (Payload)
  ✅ PASS - Encoding Bypass (Base64)
  ✅ PASS - Encoding Bypass (ROT13)

✅ ALL TESTS PASSED!
```

### test_postdetection_hook.py
```
✅ vulnerability_explanation: 353 chars
✅ mitigation_recommendations: 8 items
✅ execution_timeline: 14 steps
✅ severity: high
✅ cwe_ids: ['CWE-862']
✅ owasp_categories: ['LLM01']
✅ attack_technique: Jailbreak (AntiDAN)
✅ reproduction_steps: 5 steps
✅ references: 4 items
```

---

## Troubleshooting

### Import Errors
**Error:** `ModuleNotFoundError: No module named 'garak.probes._enhanced_reporting'`

**Solution:**
```bash
# Ensure enhanced garak is installed
cd /path/to/garak
pip install -e .
```

### Test Failures
**Error:** Tests fail with missing fields

**Solution:**
1. Verify you're using the enhanced fork: https://github.com/hasbegun/garak
2. Check garak version: `python -c "import garak; print(garak.__version__)"`
3. Should be 0.13.3rc1 or later

### Path Issues
**Error:** Cannot find test files

**Solution:**
```bash
# Run from backend directory
cd /Users/innox/projects/garak/aegis/backend
python tests/test_parallel_enhanced_reporting.py
```

---

## Adding New Tests

To add a new test:

1. Create `tests/test_newfeature.py`
2. Follow existing test patterns
3. Import from garak:
   ```python
   from garak.probes.yourprobe import YourProbe
   from garak.attempt import Attempt, ATTEMPT_COMPLETE
   ```
4. Create test attempts with simulated data
5. Verify all enhanced fields populate
6. Update this README

---

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run Enhanced Reporting Tests
  run: |
    pip install -e ./garak
    python tests/test_parallel_enhanced_reporting.py
```

---

**Test Suite Version:** 1.0.0
**Last Updated:** November 24, 2025
**Status:** ✅ All tests passing
