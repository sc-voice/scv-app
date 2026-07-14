# EBT Translations

**Last updated:** 2026-07-14

## Overview

This document describes the Buddhist scripture translations available in SC-Voice, including both translations in the local data repository and those included in the app databases.

The `ebt-translations.sh` script lists all available translations grouped by language and author, showing:
1. File counts for each translator
2. Apple AVSpeechSynthesizer language support status
3. Database inclusion status
4. Language-specific author rankings by file count

Run the script with:
```bash
/Users/visakha/dev/scv-next/scripts/ebt-translations.sh
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

## Current Translations


| Count | Apple | Lang | DB | Order | Author |
|-------|-------|------|----|----|--------|
|     4310 | ✅ | en | ✅ | 1 | sujato |
|     4168 | ✅ | de | ✅ | 1 | sabbamitta |
|     1094 | ✅ | ru | ✅ | 1 | sv |
|      861 |    | sr |    | 1 | brankokovacevic |
|      574 | ✅ | ru |    | 2 | o |
|      427 | ✅ | en | ✅ | 2 | brahmali |
|      337 | ✅ | ru | ✅ | 3 | narinyanievmenenko |
|      313 |    | lt |    | 1 | piyadassi |
|      277 | ✅ | fr | ✅ | 1 | sekha |
|      276 | ✅ | cs |    | 1 | ashinsarana |
|      263 | ✅ | it |    | 1 | giovannizappa |
|      193 | ✅ | pt | ✅ | 1 | laera-quaresma |
|      100 | ✅ | en | ✅ | 3 | kelly |
|       73 | ✅ | en | ✅ | 4 | soma |
|       73 | ✅ | de | ✅ | 2 | sonjabuege |
|       72 | ✅ | tr |    | 1 | dogensisapa |
|       60 |    | jpn |    | 1 | kaz |
|       58 | ✅ | pl | ✅ | 1 | hardao |
|       53 | ✅ | fr | ✅ | 2 | noeismet |
|       37 | ✅ | fr |    | 3 | christelle |
|       31 | ✅ | es | ✅ | 1 | font |
|       30 | ✅ | en |    | 5 | suddhaso |
|       26 | ✅ | vi |    | 1 | phantuananh |
|       26 |    | et |    | 1 | thitanana |
|       18 |    | ka |    | 1 | luka |
|       10 | ✅ | pl |    | 2 | marcinow |
|        9 |    | gu |    | 1 | trush |
|        9 | ✅ | es |    | 2 | maggatr |
|        8 | ✅ | ru |    | 4 | syrkin |
|        7 | ✅ | hi |    | 1 | trush |
|        6 | ✅ | ru |    | 5 | khantibalo |
|        4 | ✅ | tr |    | 2 | fulyakoksoy |
|        4 |    | my |    | 1 | my-team |
|        2 | ✅ | th |    | 2 | jayasaro |
|        2 | ✅ | th |    | 1 | dhiranandi |
|        2 |    | my |    | 2 | myteam |
|        2 |    | lo |    | 1 | jayasaro |
|        2 |    | gsw |    | 1 | flavio |
|        2 | ✅ | en |    | 6 | kovilo |
|        1 | ✅ | ru |    | 6 | team |
|        1 | ✅ | fr |    | 4 | wijayaratna |
|        1 | ✅ | fi |    | 1 | mudito |
|        1 |    | et |    | 2 | mgvali |

**Total:**    14460 files

## Inclusion Criteria

We welcome translations of Buddhist scriptures from qualified translators. If you would like your translation included in SC-Voice, please let us know by opening an issue in the project repository.

Note that there are limits to what can be included since each language and author increases the application size. New languages must be supported by Apple AVSpeechSynthesizer and we would also greatly appreciate help with UI localization.

## Developers Notes

### Including New Translations

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
