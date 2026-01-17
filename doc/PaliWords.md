# PaliWords

Extracts and counts Pali words (with diacritics) from Buddhist scripture translations.

## Overview

PaliWords is a tool for analyzing Pali vocabulary usage across translations. It identifies words containing Pali-specific diacritics (āīūḍḷṁṅṇṭñ etc.) and builds frequency distributions across entire languages or individual suttas.

## Architecture

### CountMethod Enum

Two counting strategies available:

1. **`.exhaustive`** (legacy)
   - Extracts Pali words from pli field
   - Matches them in doc field using regex word boundaries
   - Also captures morphological variants (case/form differences)
   - Slower but comprehensive
   - Used by tests for validation

2. **`.diacritic`** (default, fast)
   - Scans doc text for words containing Pali diacritics
   - No Pali source loading
   - No regex matching
   - ~100x faster than exhaustive
   - Used for production language-wide analysis

### PaliWords Class

```swift
public class PaliWords {
  public init(lang: String, method: CountMethod = .diacritic)
  public func countPaliWords(suttaRef: SuttaRef) async

  public var paliWords: Int           // Total occurrences
  public var paliDict: [String: Int]  // Pali words by count
  public var docPaliDict: [String: Int]  // Found words in translation
}
```

## CLI Usage

### Single Sutta Analysis

Count Pali words in a single sutta:

```bash
swift run pali-words --count-sutta-pali mn44/en/sujato
```

Output: JSON file at `local/build/pali-en-mn44.json`

Example output:
```json
{
  "sutta": "mn44",
  "lang": "en",
  "author": "sujato",
  "pali_dict_count": 463,
  "unique_pali_words_found": 3,
  "total_pali_word_occurrences": 13,
  "pali_words": {
    "rājagaha": 1,
    "visākha": 7,
    "dhammadinnā": 5
  }
}
```

### Language-Wide Analysis

Extract Pali word frequencies across all suttas in a language:

```bash
swift run pali-words --count-doc-pali en
```

Output: JSONL file at `scv-build/Sources/Resources/pali-en.json`

Each line is a single word entry, sorted by descending frequency:
```jsonl
{"sāvatthī":1848}
{"ānanda":1406}
{"saṅgha":1133}
{"sāriputta":931}
{"rājagaha":478}
...
```

### Progress Logging

Each sutta processed is logged via `cc.ok1()`:

```
✅pali-words-main:pali_words:0.064s+0.039 125 pli-tv-bi-pm [1/427]
✅pali-words-main:pali_words:0.085s+0.005 125 pli-tv-bi-vb-as1-7 [2/427]
```

Shows: sutta UID, elapsed time, progress counter `[N/total]`

## Implementation Details

### Diacritic Detection

Pali diacritics checked: `āīūḍḷṁṅṇṭñĀĪŪḌḶṀṄṆṬÑ`

These are characters not used in European languages (EN, DE, FR, ES, PT, RU), making them reliable Pali indicators.

### Language-Specific Deny Lists

Words excluded from counting because they appear in both Pali and the target language:

- **en**: "me", "a", "i"
- **de**: "de", "es"
- **pt**: "de", "a"

### Morphological Variants

When exhaustive method finds a diacritical word not in paliDict, it adds it as a morphological variant (e.g., locative vs nominative forms). Example:

- Base: "dhamma" (1000x)
- Variant: "dhamme" (500x, locative)

Both are tracked separately in output.

## Performance

Using `.diacritic` method (default):

- Per sutta: ~0.03-0.04s
- 427 suttas per author: ~15-20s
- 4 authors (~1700 suttas total): ~1-2 minutes
- No Pali source loading required

## Output Files

### Single Sutta
- Location: `local/build/pali-{lang}-{uid}.json`
- Format: JSON object with metadata and pali_words dict
- Includes paliDict count, unique words found, total occurrences

### Language-Wide
- Location: `scv-build/Sources/Resources/pali-{lang}.json`
- Format: JSONL (one JSON object per line)
- Each line: `{"word": count}`
- Lines sorted by count (descending)
- Git-tracked resource file

## Testing

Tests use `.exhaustive` method and verify:
- paliDict population from Pali source
- Word matching in translations
- Morphological variant detection
- Deny list filtering

```bash
make test-core  # Includes PaliWordsTests
```

Current test data: `mn44/en/sujato` and `mn44/de/sabbamitta`

## Future Enhancements

1. Parallel author processing (currently serial)
2. Language-specific diacritic rules
3. Export to other formats (CSV, TSV)
4. Filtering by word frequency threshold
5. Incremental updates (process new suttas only)
