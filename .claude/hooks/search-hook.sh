#!/bin/bash

# Claude Code Hook: Recursive String Search
# Usage: ./search_hook.sh "search_string" [directory]
# Output format: file_path: line number : 5 characters before and after match

# Default values
SEARCH_STRING=""
SEARCH_DIR="."
CASE_INSENSITIVE=""

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS] SEARCH_STRING [DIRECTORY]"
    echo ""
    echo "Options:"
    echo "  -i    Case insensitive search"
    echo "  -h    Show this help"
    echo ""
    echo "Output format: file_path: line number : 5 characters before and after match"
    echo ""
    echo "Examples:"
    echo "  $0 'TODO' ."
    echo "  $0 -i 'error' /path/to/project"
    exit 1
}

# Parse arguments
while getopts "ih" opt; do
    case $opt in
        i)
            CASE_INSENSITIVE="true"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done

shift $((OPTIND-1))

# Get search string and directory
SEARCH_STRING="$1"
if [ -n "$2" ]; then
    SEARCH_DIR="$2"
fi

# Validate inputs
if [ -z "$SEARCH_STRING" ]; then
    echo "Error: Search string is required"
    usage
fi

if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Directory '$SEARCH_DIR' does not exist"
    exit 1
fi

# Define directories to skip
SKIP_DIRS=".git|.svn|.hg|node_modules|__pycache__|.pytest_cache|venv|.venv|env|build|dist|target|.idea|.vscode|.vs"

# Define explicit files to skip (add file names here)
SKIP_EXPLICIT_FILES="package-lock.json|yarn.lock|Cargo.lock|composer.lock|Pipfile.lock|poetry.lock|go.sum|go.mod|uv.lock"

# Define file extensions to skip (add extensions here without dots)
SKIP_FILES_EXTENSIONS="jpg|jpeg|png|gif|bmp|svg|ico|webp|pdf|doc|docx|xls|xlsx|ppt|pptx|zip|tar|gz|rar|7z|exe|dll|so|dylib|bin|dat|db|sqlite|mp3|mp4|avi|mov|mkv|wav|flac"

# Define text file extensions
TEXT_EXTENSIONS="txt|py|js|jsx|ts|tsx|html|css|scss|sass|less|json|xml|yaml|yml|md|rst|java|cpp|c|h|hpp|go|rs|php|rb|sh|bash|zsh|fish|ps1|bat|cmd|sql|r|scala|swift|kt|dart|vue|svelte|pl|pm|lua|vim|conf|config|ini|toml|properties|env|dockerfile|gitignore|gitattributes|editorconfig|log|csv|makefile|cmake|gradle|maven|sbt|lock|mod|sum"

# Function to check if file should be searched
should_search_file() {
    local file="$1"
    
    # Skip if file is not readable
    [ ! -r "$file" ] && return 1
    
    # Check if filename is in explicit skip list
    local filename=$(basename "$file")
    if echo "$filename" | grep -qE "^($SKIP_EXPLICIT_FILES)$"; then
        return 1
    fi
    
    # Get file extension
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    # Check if extension is in skip list
    if echo "$ext" | grep -qE "^($SKIP_FILES_EXTENSIONS)$"; then
        return 1
    fi
    
    # Skip if file is too large (>10MB)
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    [ "$size" -gt 10485760 ] && return 1
    
    # Check if extension is in our list
    if echo "$ext" | grep -qE "^($TEXT_EXTENSIONS)$"; then
        return 0
    fi
    
    # For files without extension, check if they're text
    if [ "$ext" = "$(basename "$file")" ]; then
        # Use file command if available
        if command -v file >/dev/null 2>&1; then
            file_type=$(file -b "$file" 2>/dev/null)
            if echo "$file_type" | grep -qi "text\|ascii\|empty"; then
                return 0
            fi
        else
            # Fallback: check if file contains mostly printable characters
            if head -c 1024 "$file" 2>/dev/null | LC_ALL=C grep -q '[[:print:]]'; then
                # Check if it's not binary (contains null bytes)
                if ! head -c 1024 "$file" 2>/dev/null | LC_ALL=C grep -q '\000'; then
                    return 0
                fi
            fi
        fi
    fi
    
    return 1
}

# Function to extract context around match
get_context() {
    local line="$1"
    local search_term="$2"
    local case_insensitive="$3"
    
    # Make search case insensitive if needed
    local search_line="$line"
    local search_pattern="$search_term"
    
    if [ "$case_insensitive" = "true" ]; then
        search_line=$(echo "$line" | tr '[:upper:]' '[:lower:]')
        search_pattern=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')
    fi
    
    # Find the position of the match
    local before="${search_line%%$search_pattern*}"
    local match_pos=${#before}
    
    # If no match found, return empty
    if [ ${#before} -eq ${#search_line} ]; then
        return 1
    fi
    
    # Calculate context positions
    local context_start=$((match_pos - 5))
    local context_end=$((match_pos + ${#search_term} + 5))
    
    # Adjust start position
    if [ $context_start -lt 0 ]; then
        context_start=0
    fi
    
    # Adjust end position
    if [ $context_end -gt ${#line} ]; then
        context_end=${#line}
    fi
    
    # Extract the context
    local context="${line:$context_start:$((context_end - context_start))}"
    
    echo "$context"
}

# Function to search in a single file
search_in_file() {
    local file="$1"
    local line_num=0
    local found_matches=0
    
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # Check if line contains the search string
        local match_found=false
        if [ "$CASE_INSENSITIVE" = "true" ]; then
            # Case insensitive comparison
            local line_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
            local search_lower=$(echo "$SEARCH_STRING" | tr '[:upper:]' '[:lower:]')
            if [[ "$line_lower" == *"$search_lower"* ]]; then
                match_found=true
            fi
        else
            # Case sensitive comparison
            if [[ "$line" == *"$SEARCH_STRING"* ]]; then
                match_found=true
            fi
        fi
        
        if [ "$match_found" = true ]; then
            found_matches=1
            # Get context around the match
            local context=$(get_context "$line" "$SEARCH_STRING" "$CASE_INSENSITIVE")
            
            # Output in the requested format: file_path: line number : context
            echo "$file: $line_num : $context"
        fi
    done < "$file"
    
    return $found_matches
}

# Main search function
search_files() {
    local total_found=0
    
    # Use find to get all files, excluding skip directories
    find "$SEARCH_DIR" -type f | grep -vE "/($SKIP_DIRS)/" | while read -r file; do
        # Skip hidden files unless we're specifically looking in hidden dirs
        if [[ "$(basename "$file")" == .* ]] && [[ "$SEARCH_DIR" != */.* ]]; then
            continue
        fi
        
        # Check if we should search this file
        if should_search_file "$file"; then
            # Search in the file
            if search_in_file "$file"; then
                total_found=1
            fi
        fi
    done | {
        local found_any=0
        while read -r line; do
            echo "$line"
            found_any=1
        done
        
        if [ $found_any -eq 0 ]; then
            echo "No matches found."
            exit 1
        fi
    }
}

# Run the search
search_files