#!/bin/bash

# Check if the correct number of arguments is passed
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <init_dep_path> <dep_path>"
    exit 1
fi

# Assign arguments to variables
init_dep_path=$1
dep_path=$2

# Create targ_path by changing the extension of dep_path from .d to .csv
targ_path="${dep_path%.d}.csv"

# Temporary file to store the modified content
temp_file=$(mktemp)
sources_file=$(mktemp)

echo "# -------------------------------" >> "$temp_file"
echo "# Automatically generated file."   >> "$temp_file"
echo "# Do not edit by hand"             >> "$temp_file"
echo "# -------------------------------" >> "$temp_file"

# Initialize variable to store source path
source_path=""
source_metadata_paths=()

# Check if the file contains any colons
if grep -q ':' "$init_dep_path"; then
    contains_colons=0
else
    contains_colons=1
fi

# Prepend lines if there are no colons
if [ $contains_colons -eq 1 ]; then
    while IFS= read -r line; do
        echo "$targ_path : $line" >> "$temp_file"
        if [[ $line == pipelines* ]]; then
            echo "$targ_path : ${line}.json" >> "$temp_file"
            source_metadata_path=$(echo $line | sed -n 's|pipelines/\([^/]*\)/.*|metadata/sources/\1.json|p')
            source_metadata_paths+=("$source_metadata_path")
        fi
        if [[ $line == lookup-tables/* ]]; then
            name=$(basename "${line}" .csv)
            derived_path="derived-data/$name/$name.csv"
            if [ "$derived_path" != "$targ_path" ]; then
                echo "$targ_path : | $derived_path" >> "$temp_file"
            fi
        fi
    done < "$init_dep_path"
else
    while IFS= read -r line; do
        echo "$line" >> "$temp_file"
        if [[ $line == pipelines* ]]; then
            echo "${line}.json" >> "$temp_file"
            source_metadata_path=$(echo $line | sed -n 's|pipelines/\([^/]*\)/.*|metadata/sources/\1.json|p')
            source_metadata_paths+=("$source_metadata_path")
        fi
        if [[ $line == lookup-tables/* ]]; then
            name=$(basename "${line}" .csv)
            derived_path="derived-data/$name/$name.csv"
            if [ "$derived_path" != "$targ_path" ]; then
                echo "| $derived_path" >> "$temp_file"
            fi
        fi
    done < "$init_dep_path"
fi

# Deduplicate source_metadata_paths
source_metadata_paths=($(echo "${source_metadata_paths[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

# Append the sources and tidy-datasets JSON file lines
for path in "${source_metadata_paths[@]}"; do
    echo "$targ_path : $path" >> "$temp_file"
done

tidy_datasets_json="metadata/tidy-datasets/$(basename "${dep_path%.d}").json"
echo "$targ_path : $tidy_datasets_json" >> "$temp_file"

# Remove lines where left-hand-side is identical to right-hand-side, including "|"
awk -F ' : ' '$1 != $2' "$temp_file" | awk -F ' : \\| ' '$1 != $2' > "$dep_path"

# Cleanup
rm -f "$temp_file" "$sources_file"

echo "Process completed. Check $dep_path for results."
