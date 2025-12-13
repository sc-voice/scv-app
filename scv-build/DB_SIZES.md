# Database Sizes

## Source Files (en/sujato)
- **Total**: 24M (4,304 files)
- `name/`: 1.4M (name indices)
- `sutta/`: 22M (suttas by collection)
  - AN (Anguttara Nikaya): 6.9M
  - SN (Samyutta Nikaya): 7.8M
  - KN (Khuddaka Nikaya): 3.4M
  - MN (Majjhima Nikaya): 2.6M
  - DN (Digha Nikaya): 1.5M

## SQLite Database (ebt-en-sujato.db)
- **Total**: 37M
- **Tables**:
  - `segments`: 148,496 rows (~12.1 MB data)
  - `segments_fts_content`: 148,496 rows (FTS5 tokenized, ~12.1 MB)
  - `suttas`: 4,167 rows (~0.07 MB)
  - `metadata`: 1 row
  - `segments_fts_data`: 1,848 rows (inverted index, ~12 MB)
  - `segments_fts_docsize`: 148,496 rows (~0.42 MB)
  - `segments_fts_idx`: 1,230 rows
  - `segments_fts_config`: 1 row
- **Overhead**: ~0.5 MB (indices, pages)
