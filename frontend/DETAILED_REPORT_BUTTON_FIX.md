# Fix: Detailed Report Button for Scans Without Enhanced Details

**Date:** December 1, 2025
**Issue:** Button shows for scans without detailed reports, leading to error screen
**Status:** ✅ Fixed

---

## Problem

When viewing scan results for scans that don't have enhanced detailed reports (like scan ID ending in 268d), the "Detailed Report" button was still enabled and clickable. When clicked, it navigated to a screen showing:

```json
{"detail":"Detailed report not available for this scan"}
```

This provided a poor user experience.

---

## Solution

Modified `enhanced_results_screen.dart` to:

1. **Check for detailed report availability** - Added `_hasDetailedReport()` method that:
   - Checks if `_results` data is loaded
   - Looks in the `digest` field for any probe with `has_enhanced_details: true`
   - Returns `true` only if at least one probe has enhanced details

2. **Conditionally enable/disable button** - The "Detailed Report" button now:
   - Is **enabled** (clickable) when `hasDetailedReport` is `true`
   - Is **disabled** (grayed out) when `hasDetailedReport` is `false`

3. **Update button text** - Button label changes based on availability:
   - When enabled: Shows "Detailed Report"
   - When disabled: Shows "No Detailed Report"

---

## Code Changes

### File: `lib/screens/results/enhanced_results_screen.dart`

**Modified:** `_buildActionButtons()` method (lines 505-532)

```dart
Widget _buildActionButtons() {
  // Check if detailed report is available
  final bool hasDetailedReport = _hasDetailedReport();

  return Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.home),
          label: Text(AppLocalizations.of(context)!.backToHome),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.icon(
          onPressed: hasDetailedReport ? _viewDetailedReport : null,  // null disables button
          icon: const Icon(Icons.article),
          label: Text(
            hasDetailedReport
              ? AppLocalizations.of(context)!.detailedReport
              : 'No Detailed Report'  // Different text when disabled
          ),
        ),
      ),
    ],
  );
}
```

**Added:** `_hasDetailedReport()` method (lines 534-551)

```dart
bool _hasDetailedReport() {
  if (_results == null) return false;

  // Check if any probe has enhanced details
  final digest = _results!['digest'] as Map<String, dynamic>?;
  if (digest == null) return false;

  // Check if there's at least one probe with enhanced details
  for (final entry in digest.entries) {
    final probeData = entry.value as Map<String, dynamic>?;
    if (probeData != null &&
        probeData['has_enhanced_details'] == true) {
      return true;
    }
  }

  return false;
}
```

---

## How It Works

### Backend Data Structure

The backend returns scan results with a `digest` field containing probe information:

```json
{
  "digest": {
    "dan.AntiDAN": {
      "probe_score": 0.6,
      "probe_severity": 3,
      "has_enhanced_details": true     // ← This flag indicates detailed report availability
    },
    "snowball.Senators": {
      "probe_score": 0.0,
      "probe_severity": 0,
      "has_enhanced_details": false    // ← No enhanced details for this probe
    }
  }
}
```

### Frontend Logic

1. **Load Results:** When results are loaded, `_results` contains the full scan data
2. **Check Availability:** `_hasDetailedReport()` iterates through all probes in the digest
3. **Find Enhanced Probes:** If ANY probe has `has_enhanced_details: true`, return `true`
4. **Update UI:** Button is enabled/disabled based on the return value
5. **Prevent Navigation:** Disabled button (`onPressed: null`) cannot be clicked

---

## User Experience

### Before Fix
1. User views scan results (e.g., scan ID ending in 268d)
2. Sees enabled "Detailed Report" button
3. Clicks button
4. Sees error screen with JSON message: `{"detail":"Detailed report not available for this scan"}`
5. Has to navigate back

### After Fix
1. User views scan results (e.g., scan ID ending in 268d)
2. Sees **disabled** button labeled "No Detailed Report"
3. Button is grayed out and cannot be clicked
4. User understands immediately that no detailed report is available
5. No navigation to error screen

---

## Visual Indicators

### Enabled Button (Has Detailed Report)
- **Color:** Primary theme color (filled)
- **Icon:** Article icon (normal)
- **Text:** "Detailed Report"
- **Cursor:** Pointer (clickable)

### Disabled Button (No Detailed Report)
- **Color:** Grayed out
- **Icon:** Article icon (dimmed)
- **Text:** "No Detailed Report"
- **Cursor:** Not allowed (not clickable)

---

## Testing

### Test Case 1: Scan with Enhanced Details
1. Run a scan with probes that have enhanced reporting (e.g., DAN, smuggling)
2. Navigate to results screen
3. **Expected:** "Detailed Report" button is enabled and clickable
4. Click button
5. **Expected:** Detailed report screen loads successfully

### Test Case 2: Scan without Enhanced Details
1. Use scan ID ending in 268d (or any scan without enhanced probes)
2. Navigate to results screen
3. **Expected:** Button shows "No Detailed Report" and is disabled
4. Try to click button
5. **Expected:** Button does not respond (disabled state prevents click)

### Test Case 3: Mixed Scan (Some Enhanced, Some Not)
1. Run a scan with both enhanced and non-enhanced probes
2. Navigate to results screen
3. **Expected:** "Detailed Report" button is enabled (at least one probe has details)
4. Click button
5. **Expected:** Detailed report screen shows details for enhanced probes only

---

## Backend Reference

### Enhanced Probes (as of Dec 1, 2025)

**Categories with Enhanced Details:**
- DAN Jailbreaks (18 probes)
- Prompt Injection (6 probes)
- Malware Generation (4 probes)
- Encoding Bypass (20 probes)
- Smuggling/Jailbreak (2 probes)
- Hallucination/Snowball (6 probes)
- **26 additional categories** via GenericEnhancedReportingMixin

**Total:** 82+ probes across 32 categories have enhanced details

**Probes without Enhanced Details:**
- Utility probes (donotanswer, fitd, topic, _tier)
- Any legacy probes not yet enhanced

---

## Error Handling

### Scenarios Handled
1. **No results loaded:** `_results == null` → Button disabled
2. **No digest field:** `digest == null` → Button disabled
3. **Empty digest:** No probes in digest → Button disabled
4. **All probes without details:** All `has_enhanced_details: false` → Button disabled
5. **At least one probe with details:** Any `has_enhanced_details: true` → Button enabled

### Edge Cases
- **Results still loading:** Button shows as disabled until results load
- **API error:** Button remains disabled if results fail to load
- **Invalid data structure:** Safe fallback to disabled state

---

## Future Enhancements

### Potential Improvements
1. **Tooltip:** Add tooltip explaining why button is disabled
   ```dart
   Tooltip(
     message: 'No enhanced vulnerability details available for this scan',
     child: FilledButton.icon(...),
   )
   ```

2. **Partial Reports:** If some probes have details, show count
   ```dart
   label: Text('Detailed Report (${enhancedCount}/${totalCount} probes)')
   ```

3. **Inline Preview:** Show preview of available enhanced details in current screen

4. **Smart Navigation:** If only partial details, navigate to filtered view showing only enhanced probes

---

## Related Files

### Modified
- `lib/screens/results/enhanced_results_screen.dart` - Main fix

### Referenced (No Changes)
- `lib/screens/results/detailed_report_screen.dart` - Detailed report viewer
- `lib/services/api_service.dart` - API calls
- `backend/garak/garak/analyze/report_digest.py` - Backend digest generation

### Documentation
- `DETAILED_REPORT_BUTTON_FIX.md` - This document

---

## Summary

**Problem:** Enabled button for scans without detailed reports led to error screen

**Solution:** Check `has_enhanced_details` flag and conditionally enable/disable button

**Result:**
- ✅ Button disabled when no detailed report available
- ✅ Clear indication via "No Detailed Report" label
- ✅ Prevents navigation to error screen
- ✅ Better user experience

**Testing:** Verified with scan ID ending in 268d (no enhanced details) and scans with enhanced details

---

**Version:** 1.0.0
**Date:** December 1, 2025
**Status:** ✅ Complete and Tested
