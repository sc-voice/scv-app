# Core ML Learning Notes

**Date Started**: 2025-12-08

## Overview

Core ML is Apple's framework for integrating machine learning models into apps.

- Framework name: **Core ML** (not MLCore)
- Runs models on-device for privacy and performance
- Supports iOS, macOS, watchOS, tvOS
- Can convert models from TensorFlow, PyTorch

## Project Goal

Help users develop intuitive understanding of Early Buddhist Texts (EBTs) by finding texts most relevant to their queries, even when queries use different words than the translation being studied.

**Challenge**: Current keyword/phrase search requires exact word matches. Users may search using different vocabulary than specific translations use.

**Opportunity**: Leverage the magnificent structure of the EBTs themselves to enable semantic search that understands meaning beyond exact word matching.

**Potential ML Approach**: Use embeddings or semantic similarity models to match query intent with sutta content, regardless of specific word choices.

## Pilot Study: German (DE) Search Improvement

**Focus**: Improve German search as initial CoreML learning exercise.

**Specific Problem**:
- Search query: "abhängig entstehen" (dependent origination)
- Current results: 0 suttas found
- Expected results: 21 suttas (e.g., sn6.1) should be found

**Why German?**
- German word morphology more complex than English
- Different word forms (abhängig/abhängige/abhängigen, entstehen/entsteht/entstanden)
- Current exact-match search fails to find morphological variations
- Success with DE will inform approach for other languages

**Learning Goals**:
1. Understand how CoreML embeddings handle morphological variations
2. Explore on-device semantic search feasibility
3. Develop patterns applicable to broader EBT semantic search

## Concepts

### Tokenizers

**What**: Convert text into smaller units (tokens) that ML models can process.

**Why Important**: Tokenization is the first step before embeddings. How text gets tokenized directly affects how well the model understands morphological variations.

**Types**:
1. Word tokenizers - Split on whitespace/punctuation (simple but fails on morphology)
2. Subword tokenizers - Split words into meaningful pieces (e.g., "abhängig" → "ab" + "häng" + "ig")
3. Character tokenizers - Split into individual characters (rarely used alone)

**German Challenge**:
- "abhängig entstehen" vs "abhängige Entstehung" vs "abhängiges Entstehen"
- Word tokenizer sees these as completely different
- Subword tokenizer might recognize shared roots
- Question: What tokenization approach best handles German morphology for EBT search?

**Apple's NaturalLanguage Framework**:
- **NLTokenizer**: Segments natural language text into semantic units
- **German Support**: Built-in OS embeddings support 7 languages including German
- **Multilingual Models**: Transformer-based (BERT) embeddings support 27 languages
- **Key Insight**: Apple already provides German tokenization optimized for morphology

See: References #8-11

### Embeddings

**What**: Convert text into dense numerical vectors (embeddings) that capture semantic meaning.

**Apple's Embedding APIs**:

1. **NLEmbedding** (Older, word-level)
   - Non-contextual word embeddings
   - Limited - treats each word independently
   - Not ideal for morphological variations

2. **NLContextualEmbedding** (BERT-based, 2023+)
   - Sentence-based transformer model using BERT architecture
   - Supports 27 languages including German (Latin-script model)
   - 512 dimensions, 256-token sequence length
   - **Key advantage**: Uses subword tokenization internally (WordPiece/BPE)
   - **Handles morphology**: "abhängig" vs "abhängige" share subword components

**Why NLContextualEmbedding solves German morphology**:
- BERT uses subword tokenization (WordPiece)
- "abhängig" and "abhängige" decompose to shared subwords
- Embeddings capture semantic similarity across inflected forms
- Enables finding "abhängige Entstehung" when searching "abhängig entstehen"

See: References #14-15

## Notes

## References

1. Core ML Documentation - https://developer.apple.com/documentation/coreml
2. Core ML Tools Guide - https://apple.github.io/coremltools/docs-guides/source/overview-coremltools.html
3. Machine Learning Overview - https://developer.apple.com/machine-learning/core-ml/
4. Core ML Tools GitHub - https://github.com/apple/coremltools
5. Getting a Core ML Model - https://developer.apple.com/documentation/coreml/getting-a-core-ml-model
6. Classifying Images with Vision and Core ML - https://developer.apple.com/documentation/vision/classifying_images_with_vision_and_core_ml
7. Core ML 3 Framework (WWDC19) - https://developer.apple.com/videos/play/wwdc2019/704/
8. Natural Language Framework - https://developer.apple.com/documentation/naturallanguage
9. NLTokenizer - https://developer.apple.com/documentation/naturallanguage/nltokenizer
10. Tokenizing Natural Language Text - https://developer.apple.com/documentation/naturallanguage/tokenizing-natural-language-text
11. Explore Natural Language Multilingual Models (WWDC23) - https://developer.apple.com/videos/play/wwdc2023/10042/
12. Advances in Natural Language Framework (WWDC19) - https://developer.apple.com/videos/play/wwdc2019/232/
13. Make Apps Smarter with Natural Language (WWDC20) - https://developer.apple.com/videos/play/wwdc2020/10657/
14. NLEmbedding - https://developer.apple.com/documentation/naturallanguage/nlembedding
15. NLContextualEmbedding - https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding

