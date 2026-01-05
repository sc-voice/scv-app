# German EBT Phrase Search Strategies

## Problem Statement

German morphological complexity makes exact phrase matching ineffective. Query "abhängige entstehen" fails to find sn6.1 which contains related but inflected forms.

See: CLAUDE.md backlog item "Investigate German search for 'abhängig entstehen' not finding sn6.1"

## Current Implementation

### searchKeywords()
Uses SQLite FTS5 MATCH with tokenized keywords
- No lemmatization or stemming
- Case-insensitive but form-sensitive
- See: EbtData.swift:481-491

### searchPhrase()
Filters keyword results to exact substring matches
- Post-filters FTS results
- Case-insensitive substring: `segmentText.lowercased().contains(phrase.lowercased())`
- See: EbtData.swift:726-749, 797

## Recommended Strategies

### 1. Lemma-based Query Expansion ⭐ (Highest ROI)

**Status**: Recommended for immediate implementation

Transform user query into lemma forms with wildcard prefix matching.

**Example**:
- Input: "abhängige entstehen"
- Transform: "abhäng*" AND "entste*"
- FTS MATCH: `abhäng* AND entste*`

**Implementation**:
1. Map German word forms to lemma roots
   - abhängig, abhängige, abhängigen, abhängiger → root "abhäng"
   - entstehen, entsteht, entstanden → root "entste"
2. Use FTS5 prefix queries with `*` wildcards
3. Leverage existing FTS infrastructure without morphological parser

**Constraints**:
- Requires German lemma dictionary (e.g., based on German grammar rules)
- False positives possible with prefix matching (e.g., "abhäng*" matches "abhängigkeit")

**See**: EbtData.swift:461-491 (searchKeywords)

---

### 2. Diacritic Normalization (Quick Win)

**Status**: Easy win, implement alongside lemma expansion

Pre-process queries to match both umlaut and non-umlaut forms.

**Example**:
- Input: "abhängig" also matches "abhaengig"
- Input: "ö" also matches "o"
- Input: "ä" also matches "a"

**Implementation**:
1. Map umlauts: ü→u, ö→o, ä→a
2. Store both forms in FTS index (or pre-process queries)
3. Handle user input variations transparently

**Constraints**:
- Linguistic inaccuracy (ä ≠ a in German)
- Should be fallback only, not primary match

---

### 3. Word Order Flexibility (Moderate Complexity)

**Status**: Implement if lemma expansion insufficient

Allow phrase words in any order within distance threshold.

**Example**:
- Query: "abhängig entstehen"
- Matches: "abhängig entstehen" (exact)
- Matches: "entstehen abhängig" (reversed)
- Matches: "abhängig [word] entstehen" (distance ≤ N words)

**Implementation**:
1. Query segments for all keywords present
2. Check if keywords appear within N-word distance
3. Use FTS5 phrase queries with position information

**Constraints**:
- More complex FTS query logic
- Must define meaningful distance threshold
- May reduce precision vs. phrase search

**See**: EbtData.swift:726-749 (searchPhrase filtering logic)

---

### 4. Compound Word Decomposition (German-specific)

**Status**: Consider if other strategies insufficient

Handle German Komposita (compound words).

**Example**:
- Compound: "abhängigentstehen" (concatenated forms)
- Decompose: "abhängig entstehen" (separate words)

**Implementation**:
1. Build custom SQLite tokenizer recognizing morpheme boundaries
2. Pre-process German compound recognition
3. Split on known German word boundaries

**Constraints**:
- Requires German morphology knowledge
- Custom tokenizer complexity
- May break legitimate compound words

---

### 5. Case/Number Agnostic Matching (Syntactic)

**Status**: Consider for German-specific grammar handling

Query parser recognizes German inflection patterns.

**Example**:
- Nominative: "abhängig" (base)
- Dative: "abhängigen" (matches)
- Genitive feminine: "abhängiger" (matches)

**Implementation**:
1. Build German grammar rules or rules table
2. Normalize query forms to canonical lemma
3. Query with lemma form only

**Constraints**:
- Requires German grammar modeling
- Overlap with strategy #1 (lemma expansion)

---

## Implementation Priority

| Priority | Strategy | Effort | Impact | Why |
|----------|----------|--------|--------|-----|
| 1 | Lemma expansion with FTS wildcards | Low | High | Lowest effort, immediate FTS integration |
| 2 | Diacritic normalization | Very Low | Low | Quick win, handles user input |
| 3 | Word order flexibility | Medium | Medium | If lemma insufficient |
| 4 | Case-agnostic matching | Medium | Medium | Part of lemma expansion |
| 5 | Compound decomposition | High | Low | Complex, German-specific |

## Why Semantic Search Failed

Previous approach using CoreML embeddings (testDEPhraseSearch) identified that:
- All 54 segments in sn12.20 had non-zero cosine similarity
- No clear semantic distinction between matches
- Top match (sn12.20:4.12) didn't indicate actual phrase containment

**Conclusion**: Syntactic search (FTS with morphology) superior to semantic search for exact phrase location.

See: WORK.md (2ca6fcb - Add CoreML embedding test) identified dead end

## Testing Strategy

### Test Case: sn6.1 German search
- Query: "abhängige entstehen" (user input)
- Expected: Find sn6.1 with segment containing "abhängig" + "entstehen"
- Current: Returns 0 results
- After lemma expansion: Should return sn6.1 in top results

### Test Queries (German)
1. "abhängige entstehen" → sn6.1
2. "geistesfrische" → segments with geistesfrische
3. "willensbildung" → sn12.20:4.12
4. Compound words if present in bilara-data

## References

- EbtData.swift:461-491 (searchKeywords with FTS MATCH)
- EbtData.swift:726-749 (searchPhrase with containsPhrase filter)
- EbtSeeker.swift:212-256 (findMatch for quote generation)
- Settings.shared.maxDoc limit applies to all searches

## Next Steps

1. Evaluate lemma expansion feasibility with German EBT vocabulary
2. Implement German word stemming (e.g., suffix-stripping for -en, -ig, -ung)
3. Test against sn6.1 "abhängige entstehen" query
4. Measure precision/recall vs. current approach
5. Document German morphology rules for maintenance
