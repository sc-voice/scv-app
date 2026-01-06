# EBT Translations

**Last updated:** 2026-01-06

## Overview

This document describes the Buddhist scripture translations available in SC-Voice, including both translations in the local data repository and those included in the app databases.

The `ebt-translations.sh` script lists all available translations grouped by language and author, showing:
1. File counts for each translator
2. Apple AVSpeechSynthesizer language support status
3. Database inclusion status
4. Language-specific author rankings by file count

Run the script with:
```bash
/Users/visakha/dev/scv-app/scripts/ebt-translations.sh
```

## Column Descriptions

| Column | Description |
|--------|-------------|
| **Count** | Number of JSON translation files for this language/author pair |
| **Apple** | ✅ if Apple AVSpeechSynthesizer supports text-to-speech for this language; blank otherwise |
| **Lang** | 2-3 letter language code (e.g., `en`, `de`, `fr`) |
| **DB** | ✅ if this author is included in the app's databases (from db-manifest.json); blank otherwise |
| **Order** | Ranking of this author by file count within the language (1=most files, 2=second most, etc.); blank if not in databases |
| **Author** | Translator or author identifier (e.g., `sujato`, `sabbamitta`) |

## Example Output

```
Translation JSON Files by Language/Author (sorted by count):
===========================================================

    4304  ✅ en   ✅ 1 sujato
    4060  ✅ de   ✅ 1 sabbamitta
     904  ✅ ru   ✅ 1 sv
     427  ✅ en   ✅ 2 brahmali
     337  ✅ ru   ✅ 2 narinyanievmenenko
     313  ✅ lt   ✅ 1 piyadassi
     277  ✅ fr   ✅ 1 sekha
```

## Inclusion Criteria

We welcome translations of Buddhist scriptures from qualified translators. If you would like your translation included in SC-Voice, please let us know by opening an issue in the project repository.

## Including New Translations

To add a translator to the app's databases:

1. Verify translation files exist in `local/ebt-data/translation/{lang}/{author}/sutta/` or `vinaya/`
2. Add entry to `scv-core/Sources/Resources/db-manifest.json`:
   - `language`: Language code
   - `author`: Author identifier (matches directory name)
   - `authorName`: Full translator name
   - `files.total`: Count of JSON files
   - `json`: Metadata with translator name and type
3. Run `make content` to rebuild databases from manifest
4. Run `ebt-translations.sh` to verify inclusion

See also: `scv-build/README.md` for comprehensive database building documentation.
