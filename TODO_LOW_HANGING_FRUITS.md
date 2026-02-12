# Aegis UI - Low Hanging Fruits TODO

## Overview
Features that require minimal effort but add significant value to the Aegis UI.

---

## TODO List

### 1. [x] Probe Tag Filtering (OWASP LLM Top 10)
- **Priority**: High
- **Effort**: 2-3 hours
- **Impact**: High
- **Location**: Probe selection screen
- **Description**: Add dropdown to filter probes by OWASP LLM Top 10 tags (`owasp:llm01` through `owasp:llm10`)
- **CLI Flag**: `--probe_tags`
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Added `probe_tags` field
  - `backend/services/garak_wrapper.py` - Added `--probe_tags` CLI handling
  - `frontend/lib/models/scan_config.dart` - Added `probeTags` field
  - `frontend/lib/providers/scan_config_provider.dart` - Added `setProbeTags()` method
  - `frontend/lib/screens/configuration/probe_selection_screen.dart` - Added filter chips UI

---

### 2. [x] Add Missing Generator Types (Groq, Mistral, Azure, Bedrock)
- **Priority**: High
- **Effort**: 1-2 hours
- **Impact**: High
- **Location**: Model selection screen
- **Description**: Add Groq, Mistral, Azure OpenAI, and AWS Bedrock to generator dropdown with their models
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Added GROQ, MISTRAL, AZURE, BEDROCK to GeneratorType enum
  - `backend/api/routes/models.py` - Added model lists for all 4 generators
  - `frontend/lib/config/constants.dart` - Added generator constants + display names
  - `frontend/lib/screens/configuration/model_selection_screen.dart` - Updated `_needsApiKey()`

---

### 3. [x] System Prompt Override
- **Priority**: Medium
- **Effort**: 1 hour
- **Impact**: Medium
- **Location**: Advanced config screen
- **Description**: Add text area for custom `system_prompt` to test specific persona/instructions
- **CLI Flag**: `--system_prompt`
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Added `system_prompt` field
  - `backend/services/garak_wrapper.py` - Added `--system_prompt` CLI handling
  - `frontend/lib/models/scan_config.dart` - Added `systemPrompt` field
  - `frontend/lib/providers/scan_config_provider.dart` - Added `setSystemPrompt()` method
  - `frontend/lib/screens/configuration/advanced_config_screen.dart` - Added multiline text field

---

### 4. [x] Config Export to JSON
- **Priority**: Medium
- **Effort**: 1-2 hours
- **Impact**: Medium
- **Location**: Advanced config screen (AppBar)
- **Description**: "Export Config" button that downloads current scan settings as JSON file
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `frontend/lib/services/export_service.dart` - Added `exportConfig()` and `shareConfig()` methods
  - `frontend/lib/screens/configuration/advanced_config_screen.dart` - Added export button in AppBar

---

### 5. [x] Extended Detectors Toggle
- **Priority**: Low
- **Effort**: 30 minutes
- **Impact**: Low
- **Location**: Advanced config screen
- **Description**: Add toggle for `--extended_detectors` (true/false) - run all detectors vs primary only
- **CLI Flag**: `--extended_detectors`
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Added `extended_detectors` field
  - `backend/services/garak_wrapper.py` - Added `--extended_detectors` CLI handling
  - `frontend/lib/models/scan_config.dart` - Added `extendedDetectors` field
  - `frontend/lib/providers/scan_config_provider.dart` - Added `setExtendedDetectors()` method
  - `frontend/lib/screens/configuration/advanced_config_screen.dart` - Added SwitchListTile toggle

---

### 6. [x] Deprefix Option
- **Priority**: Low
- **Effort**: 30 minutes
- **Impact**: Low
- **Location**: Advanced config screen
- **Description**: Add toggle for `--deprefix` (remove prompt from generator output)
- **CLI Flag**: `--deprefix`
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Added `deprefix` field
  - `backend/services/garak_wrapper.py` - Added `--deprefix` CLI handling
  - `frontend/lib/models/scan_config.dart` - Added `deprefix` field
  - `frontend/lib/providers/scan_config_provider.dart` - Added `setDeprefix()` method
  - `frontend/lib/screens/configuration/advanced_config_screen.dart` - Added SwitchListTile toggle

---

### 7. [x] Verbose Mode Toggle
- **Priority**: Low
- **Effort**: 30 minutes
- **Impact**: Low
- **Location**: Advanced config screen
- **Description**: Add verbosity control slider/dropdown (-v, -vv, -vvv)
- **CLI Flag**: `-v` / `-vv` / `-vvv`
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Added `verbose` field (int 0-3)
  - `backend/services/garak_wrapper.py` - Added `-v` flag handling
  - `frontend/lib/models/scan_config.dart` - Added `verbose` field
  - `frontend/lib/providers/scan_config_provider.dart` - Added `setVerbose()` method
  - `frontend/lib/screens/configuration/advanced_config_screen.dart` - Added SegmentedButton UI

---

### 8. [x] Skip Unknown Plugins Toggle
- **Priority**: Low
- **Effort**: 30 minutes
- **Impact**: Low
- **Location**: Advanced config screen
- **Description**: Add toggle for `--skip_unknown` to prevent scan failures on missing plugins
- **CLI Flag**: `--skip_unknown`
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Added `skip_unknown` field
  - `backend/services/garak_wrapper.py` - Added `--skip_unknown` CLI handling
  - `frontend/lib/models/scan_config.dart` - Added `skipUnknown` field
  - `frontend/lib/providers/scan_config_provider.dart` - Added `setSkipUnknown()` method
  - `frontend/lib/screens/configuration/advanced_config_screen.dart` - Added SwitchListTile toggle

---

### 9. [x] Buff Options: Include Original Prompt
- **Priority**: Low
- **Effort**: 30 minutes
- **Impact**: Low
- **Location**: Advanced config screen (buff section)
- **Description**: Add toggle for `buffs_include_original_prompt` to include original alongside buffed prompts
- **CLI Flag**: `--buffs_include_original_prompt`
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Added `buffs_include_original_prompt` field
  - `backend/services/garak_wrapper.py` - Added `--buffs_include_original_prompt` CLI handling
  - `frontend/lib/models/scan_config.dart` - Added `buffsIncludeOriginalPrompt` field
  - `frontend/lib/providers/scan_config_provider.dart` - Added `setBuffsIncludeOriginalPrompt()` method
  - `frontend/lib/screens/configuration/advanced_config_screen.dart` - Added SwitchListTile toggle in Buffs section

---

### 10. [x] Increase Max Generations Limit
- **Priority**: Low
- **Effort**: 15 minutes
- **Impact**: Low
- **Location**: Validation constants
- **Description**: Increase max generations from 100 to 500 for power users
- **Status**: ✅ Completed (2026-01-12)
- **Files Modified**:
  - `backend/models/schemas.py` - Changed `le=100` to `le=500`
  - `backend/api/routes/config.py` - Updated validation range to 1-500
  - `frontend/lib/config/constants.dart` - Changed `maxGenerations` from 100 to 500

---

## Completed

### 1. Probe Tag Filtering (OWASP LLM Top 10) - ✅ 2026-01-12
Added OWASP LLM Top 10 filter chips to probe selection screen. Users can now filter scans to only run probes tagged with specific OWASP categories (LLM01-LLM10).

### 2. Add Missing Generator Types (Groq, Mistral, Azure, Bedrock) - ✅ 2026-01-12
Added 4 new LLM provider integrations: Groq (fast inference), Mistral AI, Azure OpenAI, and AWS Bedrock. Each includes model lists, API key requirements, and proper display names.

### 3. System Prompt Override - ✅ 2026-01-12
Added multiline text field in Advanced Config screen for custom system prompts. Passed to garak via `--system_prompt` CLI flag.

### 4. Config Export to JSON - ✅ 2026-01-12
Added export button in Advanced Config screen AppBar. Uses `share_plus` to trigger native share dialog with the JSON config file.

### 5. Extended Detectors Toggle - ✅ 2026-01-12
Added SwitchListTile in Advanced Config screen. When enabled, passes `--extended_detectors` flag to garak to run all detectors instead of primary only.

### 6. Deprefix Option - ✅ 2026-01-12
Added SwitchListTile in Advanced Config screen. When enabled, passes `--deprefix` flag to garak to remove the prompt from generator output before analysis.

### 7. Verbose Mode Toggle - ✅ 2026-01-12
Added SegmentedButton in Advanced Config screen with 4 levels: Off, -v, -vv, -vvv. Provides control over garak output verbosity for debugging.

### 8. Skip Unknown Plugins Toggle - ✅ 2026-01-12
Added SwitchListTile in Advanced Config screen. When enabled, passes `--skip_unknown` flag to garak to continue scans even when some plugins are missing.

### 9. Buff Options: Include Original Prompt - ✅ 2026-01-12
Added SwitchListTile in Buffs section of Advanced Config screen. When enabled, passes `--buffs_include_original_prompt` flag to garak to test the original prompt alongside the buffed versions.

### 10. Increase Max Generations Limit - ✅ 2026-01-12
Increased max generations limit from 100 to 500 for power users who need more thorough testing. Updated validation in backend schema, config route, and frontend constants.

---

## Implementation Notes

### OWASP LLM Top 10 Tags Reference
| Tag | Description |
|-----|-------------|
| `owasp:llm01` | Prompt Injection |
| `owasp:llm02` | Insecure Output Handling |
| `owasp:llm03` | Training Data Poisoning |
| `owasp:llm04` | Model Denial of Service |
| `owasp:llm05` | Supply Chain Vulnerabilities |
| `owasp:llm06` | Sensitive Information Disclosure |
| `owasp:llm07` | Insecure Plugin Design |
| `owasp:llm08` | Excessive Agency |
| `owasp:llm09` | Overreliance |
| `owasp:llm10` | Model Theft |

### Generator API Keys Required
| Generator | Environment Variable |
|-----------|---------------------|
| Groq | `GROQ_API_KEY` |
| Mistral | `MISTRAL_API_KEY` |
| Azure | `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_ENDPOINT` |
| Bedrock | AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) |

---

*Last Updated: 2026-01-12*
