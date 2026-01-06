#!/bin/bash

# List translation JSON file counts grouped by language and author, sorted by count descending
# Marks those included in our databases with a checkmark

script_dir="$(dirname "$0")"
# Get absolute path before cd
manifest_file="$(cd "$script_dir" && pwd)/../scv-core/Sources/Resources/db-manifest.json"

cd "$(dirname "$0")/../local/ebt-data/translation" || exit 1

# Extract included databases to temp file
included_list=$(mktemp)
order_map=$(mktemp)
if [ -f "$manifest_file" ]; then
    jq -r '.databases[] | "\(.language):\(.author)"' "$manifest_file" 2>/dev/null > "$included_list"
fi

# Build language-based author order map (sorted by file count descending per language)
# This uses all translations available locally, not just those in manifest
declare -a order_entries
for lang_dir in */; do
    lang="${lang_dir%/}"

    for author_dir in "$lang_dir"*/; do
        if [ -d "$author_dir" ]; then
            author="${author_dir%/}"
            author="${author#$lang_dir}"
            author="${author%/}"
            count=$(find "$author_dir" -type f -name "*.json" | wc -l)
            if [ "$count" -gt 0 ] && [ "$author" != "site" ] && [ "$author" != "blurb" ]; then
                order_entries+=("$count|$lang|$author")
            fi
        fi
    done
done

# Sort by language, then by count descending
IFS=$'\n' sorted_order=($(sort -t'|' -k2,2 -k1,1nr <<<"${order_entries[*]}"))

# Build order map
for entry in "${sorted_order[@]}"; do
    IFS='|' read -r count lang author <<< "$entry"
    if [ "$prev_lang" != "$lang" ]; then
        order_num=1
        prev_lang="$lang"
    fi
    echo "$lang:$author $order_num" >> "$order_map"
    ((order_num++))
done

echo "Translation JSON Files by Language/Author (sorted by count):"
echo "==========================================================="
echo ""

# Collect all lang/author/count combinations
declare -a entries
for lang_dir in */; do
    lang="${lang_dir%/}"

    for author_dir in "$lang_dir"*/; do
        if [ -d "$author_dir" ]; then
            author="${author_dir%/}"
            author="${author#$lang_dir}"
            author="${author%/}"
            count=$(find "$author_dir" -type f -name "*.json" | wc -l)
            if [ "$count" -gt 0 ] && [ "$author" != "site" ] && [ "$author" != "blurb" ]; then
                entries+=("$count|$lang|$author")
            fi
        fi
    done
done

# Sort by count descending
IFS=$'\n' sorted=($(sort -t'|' -k1 -rn <<<"${entries[*]}"))

# Languages supported by AVSpeechSynthesizer
apple_langs="cs de en es et fi fr hu id it ja ko lt nl no pl pt ru th tr vi zh"

# Display sorted results
for entry in "${sorted[@]}"; do
    IFS='|' read -r count lang author <<< "$entry"

    # Check if in database
    db_mark="  "
    if grep -q "^$lang:$author$" "$included_list"; then
        db_mark="✅"
    fi

    # Check if Apple supports language
    apple_mark="  "
    if echo "$apple_langs" | grep -qw "$lang"; then
        apple_mark="✅"
    fi

    # Get author order for this language
    order="  "
    if [ -f "$order_map" ]; then
        order_line=$(grep "^$lang:$author " "$order_map")
        if [ -n "$order_line" ]; then
            order=$(echo "$order_line" | awk '{print $2}')
        fi
    fi

    printf "%-5s  %s %-3s  %s %s %-25s\n" "$count" "$apple_mark" "$lang" "$db_mark" "$order" "$author"
done

rm -f "$included_list" "$order_map"

echo ""
echo "==========================================================="
echo "Total translation JSON files:"
find . -type f -name "*.json" | wc -l
