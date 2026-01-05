# Lemmatizer Cache Optimization Benchmarks

## Baseline (Before Optimization)

**Date**: 2025-12-20
**Build**: 0.0.507
**Database**: en:sujato
**Caches**: Cleaned with `make clean-lemmatizer` and `make clean-db`

### Build Results
- **Elapsed Time**: 90.86s
- **Suttas**: 4,167
- **Segments**: 148,496
- **Uncompressed Size**: 22.4 MB
- **Compressed Size**: 4.8 MB (79% compression)

### Lemmatizer Cache Analysis
- **Total Entries**: 20,922
- **Identity Mappings** (word == lemma): 16,894 (80.7%)
- **Non-Identity Mappings**: 4,028 (19.3%)
- **Cache File Size**: 457 KB
- **Potential Savings**: ~370 KB (80.7% of entries)

## After Optimization

**Date**: 2025-12-20
**Build**: 0.0.507
**Database**: en:sujato
**Caches**: Cleaned before rebuild, scv-build rebuilt to use updated Lemmatizer

### Build Results
- **Elapsed Time**: 83.94s
- **Suttas**: 4,167
- **Segments**: 148,496
- **Uncompressed Size**: 22.4 MB
- **Compressed Size**: 4.8 MB (79% compression)
- **Lemmatizer Cache Saved**: 3,351 non-identity lemmas (skipped 10,057 identities)

### Performance Improvement
- **Baseline**: 90.86s
- **After Optimization**: 83.94s
- **Improvement**: 6.92s faster (7.6% improvement)

### Cache Reduction
- **Before**: 20,922 entries (457 KB)
- **After**: 3,351 non-identity entries saved
- **Identity Mappings Skipped**: 10,057 (48.1% of en-sujato lemmas)

---

## Optimization Plan

1. Update `Lemmatizer.saveCache()` to skip identity mappings
2. Add cache entry count logging when writing cache
3. Benchmark en-sujato.db creation after changes
4. Compare performance metrics
