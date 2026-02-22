# Swift Localization

This document specifies how Swift packages are localized

## Files

Localization files are stored in the `scv-core` module:

  `scv-core/Sources/Resources`

Each language has its own directory. E.g.:

  * `scv-core/Sources/Resources/en.lproj/Localizable.strings`
  * `scv-core/Sources/Resources/pt-PT.lproj/Localizable.strings`


## Localization keys

Localization keys must be sorted alphbetically.
Each key must be preceded by a comment that explains the user context for the given localization key
If parameters are used, an additional comment must specify what the values represent

```
/* Synthesis modal: header title */
"synthesis.title" = "Preparing Audio";

/* Error message when translation not found for language/author combination */
"translation.not.found" = "Translation not found for %@ / %@";

/* Voice synthesis error: voice not responding after timeout (format: voice name, file:line debug info) */
/* Parameters: 1) voice name, 2) error identifier */
"voice.error.not_responding" = "The \"%@\" voice is not responding. Try a different voice or enable background playback. [%@]";

```

## Languages

The languages supported by the application correspond to the following folders:

  `scv-core/Sources/Resources/*.lproj`

The primary language is EN. 
Each EN localization key must have a corresponding localized key/value for all localization language folders.
