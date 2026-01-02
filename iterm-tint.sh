#!/bin/bash
# iterm-tint - Dynamic iTerm2 tab colors based on working directory
# https://github.com/michaelkoss/iterm-tint

# Clamp a percentage value to 0-100, returning default if non-numeric
# Usage: result=$(_itint_clamp_percent "$value" "$default")
_itint_clamp_percent() {
    local value="$1"
    local default="$2"
    if ! [ "$value" -eq "$value" ] 2>/dev/null; then
        echo "$default"
        return
    fi
    if [ "$value" -lt 0 ]; then
        echo 0
    elif [ "$value" -gt 100 ]; then
        echo 100
    else
        echo "$value"
    fi
}

# Capture initial environment values before any config loading (preserves user overrides)
# These are captured once on script load and used as base defaults on every config reload
: "${_ITINT_ENV_SATURATION:=${ITINT_DEFAULT_SATURATION:-50}}"
: "${_ITINT_ENV_LIGHTNESS:=${ITINT_DEFAULT_LIGHTNESS:-50}}"
: "${_ITINT_ENV_HASH_MODE:=${ITINT_HASH_MODE:-absolute_path}}"
: "${_ITINT_ENV_SUBMODULE_MODE:=${ITINT_SUBMODULE_MODE:-parent}}"

# Track config file mtime to avoid unnecessary reloads
_ITINT_CONFIG_MTIME=""

# Load configuration from ~/.itint
# Parses the config file safely without eval and sets defaults for any missing settings
# Also parses the [overrides] section for path-specific color overrides
_itint_load_config() {
    local config_file="$HOME/.itint"

    # Check if config file has changed (mtime-based caching)
    local mtime
    mtime=$(stat -f %m "$config_file" 2>/dev/null || echo 0)
    if [[ "$mtime" == "$_ITINT_CONFIG_MTIME" ]]; then
        return  # Config unchanged, skip reload
    fi
    _ITINT_CONFIG_MTIME=$mtime

    # Reset to base defaults (preserves environment variable overrides)
    # Uses captured environment values, falling back to hardcoded defaults
    ITINT_DEFAULT_SATURATION=$_ITINT_ENV_SATURATION
    ITINT_DEFAULT_LIGHTNESS=$_ITINT_ENV_LIGHTNESS
    ITINT_HASH_MODE=$_ITINT_ENV_HASH_MODE
    # ITINT_FOCUS_MODE is reserved for future use (primary_pane support not yet implemented)
    ITINT_SUBMODULE_MODE=$_ITINT_ENV_SUBMODULE_MODE

    # Clear any existing overrides
    _ITINT_OVERRIDES=""

    # Parse config file if it exists (safely, without eval)
    if [ -f "$config_file" ]; then
        local line key value
        local in_overrides=0
        local line_count=0
        local max_lines=200  # Safety limit to prevent DoS from large files

        while IFS= read -r line || [ -n "$line" ]; do
            # Safety limit on number of lines processed
            line_count=$((line_count + 1))
            [ "$line_count" -gt "$max_lines" ] && break
            # Check for [overrides] section header (exact match only)
            case "$line" in
                "[overrides]")
                    in_overrides=1
                    continue
                    ;;
                "["*"]"*)
                    # Another section started, stop parsing overrides
                    in_overrides=0
                    continue
                    ;;
            esac

            # Skip comments and empty lines
            case "$line" in
                "#"*|"") continue ;;
            esac

            if [ "$in_overrides" -eq 1 ]; then
                # Parse override line: <path> <hue> [saturation lightness]
                _itint_parse_override_line "$line"
            else
                # Parse ITINT_ variable assignment
                # Split on first equals sign only (preserves values containing '=')
                key="${line%%=*}"
                value="${line#*=}"
                # Skip lines that don't match assignment pattern
                [ "$key" = "$line" ] && continue
                [ -z "$key" ] && continue
                # Validate key format (must be ITINT_ followed by uppercase letters/underscores)
                case "$key" in
                    ITINT_[A-Z_]*) ;;
                    *) continue ;;
                esac
                # Strip matching pairs of quotes from value if present
                case "$value" in
                    \"*\") value="${value#\"}"; value="${value%\"}" ;;
                    \'*\') value="${value#\'}"; value="${value%\'}" ;;
                esac
                # Validate and set known configuration variables
                case "$key" in
                    ITINT_DEFAULT_SATURATION|ITINT_DEFAULT_LIGHTNESS)
                        # Only accept numeric values
                        if [ "$value" -eq "$value" ] 2>/dev/null; then
                            export "$key=$value"
                        fi
                        ;;
                    ITINT_HASH_MODE)
                        # Only accept known modes
                        case "$value" in
                            absolute_path|folder_name_only)
                                export "$key=$value"
                                ;;
                        esac
                        ;;
                    ITINT_SUBMODULE_MODE)
                        # Only accept known modes
                        case "$value" in
                            parent|unique)
                                export "$key=$value"
                                ;;
                        esac
                        ;;
                esac
            fi
        done < "$config_file"
    fi

    # Validate and clamp saturation/lightness (0-100)
    ITINT_DEFAULT_SATURATION=$(_itint_clamp_percent "$ITINT_DEFAULT_SATURATION" 50)
    ITINT_DEFAULT_LIGHTNESS=$(_itint_clamp_percent "$ITINT_DEFAULT_LIGHTNESS" 50)

    # Validate hash mode
    case "$ITINT_HASH_MODE" in
        absolute_path|folder_name_only) ;;
        *) ITINT_HASH_MODE=absolute_path ;;
    esac

    # Validate submodule mode
    case "$ITINT_SUBMODULE_MODE" in
        parent|unique) ;;
        *) ITINT_SUBMODULE_MODE=parent ;;
    esac
}

# Parse a single override line and add to _ITINT_OVERRIDES
# Format: <path> <hue> [saturation lightness]
# Stores as: path|hue|sat|light (newline-separated entries)
# Supports paths with spaces by parsing numeric values from the end
#
# Limitations:
# - Paths with multiple consecutive spaces are not supported (spaces collapse)
# - HSL values must be provided as either hue-only OR all three (hue sat light),
#   never just two. Two trailing numbers is ambiguous and treated as hue-only.
_itint_parse_override_line() {
    local line="$1"
    local override_path hue sat light
    local words word_count

    # Skip empty lines and comments
    case "$line" in
        ""|\#*) return ;;
    esac

    # Parse from the end: last 1-3 fields may be hue/sat/light (numeric)
    # This allows paths with spaces like "~/My Projects 120 50 50"
    # Strategy: split into array, check last fields for numeric values

    # Use read -a (bash) or read -A (zsh) to split into array
    # Initialize array first to ensure clean state
    words=()
    # shellcheck disable=SC2162
    if [ -n "$ZSH_VERSION" ]; then
        words=("${(@s: :)line}")
    else
        read -r -a words <<< "$line"
    fi
    word_count=${#words[@]}

    # Need at least 2 words (path and hue)
    [ "$word_count" -lt 2 ] && return

    # Check last 3 words for numeric pattern: hue [sat light]
    # Note: zsh arrays are 1-based, bash arrays are 0-based
    local last1 last2 last3
    if [ -n "$ZSH_VERSION" ]; then
        last1="${words[$word_count]}"
        last2="${words[$((word_count - 1))]}"
        [ "$word_count" -ge 3 ] && last3="${words[$((word_count - 2))]}"
    else
        last1="${words[$((word_count - 1))]}"
        last2="${words[$((word_count - 2))]}"
        [ "$word_count" -ge 3 ] && last3="${words[$((word_count - 3))]}"
    fi

    # Determine how many trailing numeric values we have
    local num_count=0
    if [ "$last1" -eq "$last1" ] 2>/dev/null; then
        num_count=1
        if [ "$last2" -eq "$last2" ] 2>/dev/null; then
            num_count=2
            if [ "$word_count" -ge 3 ] && [ "$last3" -eq "$last3" ] 2>/dev/null; then
                num_count=3
            fi
        fi
    fi

    # Must have at least 1 numeric (hue)
    [ "$num_count" -eq 0 ] && return

    # Extract values based on count
    # num_count=1: hue only
    # num_count=2: could be "path hue" with 2-word path, or invalid (need 1 or 3 nums)
    # num_count=3: hue sat light
    #
    # Helper function to reconstruct path from array elements
    # This handles paths with multiple spaces correctly
    local path_end_idx idx
    local path_words=()

    case "$num_count" in
        1)
            hue="$last1"
            sat=""
            light=""
            # Path is words[0..word_count-2] (bash) or words[1..word_count-1] (zsh)
            path_end_idx=$((word_count - 1))
            ;;
        3)
            hue="$last3"
            sat="$last2"
            light="$last1"
            # Path is words[0..word_count-4] (bash) or words[1..word_count-3] (zsh)
            path_end_idx=$((word_count - 3))
            ;;
        *)
            # 2 trailing numbers is ambiguous - treat as hue-only with numeric path component
            # (e.g., "~/project2 120" where "project2" isn't the hue)
            hue="$last1"
            sat=""
            light=""
            path_end_idx=$((word_count - 1))
            ;;
    esac

    # Reconstruct path from array (handles paths with spaces correctly)
    if [ -n "$ZSH_VERSION" ]; then
        # zsh: 1-based indexing
        for ((idx=1; idx<=path_end_idx; idx++)); do
            path_words+=("${words[$idx]}")
        done
    else
        # bash: 0-based indexing
        for ((idx=0; idx<path_end_idx; idx++)); do
            path_words+=("${words[$idx]}")
        done
    fi
    override_path="${path_words[*]}"

    # Must have at least path and hue
    [ -z "$override_path" ] && return
    [ -z "$hue" ] && return

    # Validate hue is numeric (0-360)
    if ! [ "$hue" -eq "$hue" ] 2>/dev/null; then
        return
    fi
    if [ "$hue" -lt 0 ] || [ "$hue" -gt 360 ]; then
        return
    fi

    # Expand tilde to home directory
    case "$override_path" in
        "~"/*) override_path="$HOME${override_path#\~}" ;;
        "~") override_path="$HOME" ;;
    esac

    # Handle saturation and lightness
    # Must have both or neither (hue-only or full HSL)
    if [ -n "$sat" ] && [ -n "$light" ]; then
        # Validate both are numeric
        if ! [ "$sat" -eq "$sat" ] 2>/dev/null || ! [ "$light" -eq "$light" ] 2>/dev/null; then
            # Invalid, use defaults
            sat=""
            light=""
        else
            # Clamp to valid range
            [ "$sat" -lt 0 ] && sat=0
            [ "$sat" -gt 100 ] && sat=100
            [ "$light" -lt 0 ] && light=0
            [ "$light" -gt 100 ] && light=100
        fi
    else
        # Partial HSL not supported, clear both
        sat=""
        light=""
    fi

    # Append to overrides (format: path|hue|sat|light)
    # Empty sat/light means use defaults
    if [ -n "$_ITINT_OVERRIDES" ]; then
        _ITINT_OVERRIDES="${_ITINT_OVERRIDES}
${override_path}|${hue}|${sat}|${light}"
    else
        _ITINT_OVERRIDES="${override_path}|${hue}|${sat}|${light}"
    fi
}

# Find the best matching override for a given path
# Returns: "hue|sat|light" or empty string if no match
# Uses longest prefix match (most specific path wins)
_itint_find_override() {
    local target_path="$1"
    local best_match=""
    local best_len=0

    [ -z "$_ITINT_OVERRIDES" ] && return

    # Iterate through overrides
    local override_entry override_path hue sat light path_len

    # Process each line
    while IFS= read -r override_entry; do
        [ -z "$override_entry" ] && continue

        # Parse: path|hue|sat|light
        IFS='|' read -r override_path hue sat light <<< "$override_entry"

        # Check if target_path starts with override_path (prefix match)
        case "$target_path" in
            "$override_path"|"$override_path"/*)
                # Calculate path length for "most specific wins"
                path_len=${#override_path}
                if [ "$path_len" -gt "$best_len" ]; then
                    best_len="$path_len"
                    best_match="$hue|$sat|$light"
                fi
                ;;
        esac
    done <<< "$_ITINT_OVERRIDES"

    echo "$best_match"
}

# DJB2 hash algorithm - converts a string to a hue value (0-360)
# Algorithm: hash = ((hash << 5) + hash) + byte for each byte
# Initial value: 5381
_itint_path_to_hue() {
    local input_path="$1"
    local hash=5381
    local i=0 len char byte

    # Get string length
    len=${#input_path}

    # Process each character
    while [ "$i" -lt "$len" ]; do
        # Extract character (0-based indexing works in both bash and zsh)
        char="${input_path:$i:1}"

        # Get ASCII value using printf
        # printf '%d' "'X" gives ASCII value of X
        byte=$(printf '%d' "'$char" 2>/dev/null) || byte=0

        # DJB2: hash = hash * 33 + byte
        hash=$(( ((hash << 5) + hash) + byte ))
        # Keep hash within reasonable bounds to avoid overflow
        hash=$(( hash & 0x7FFFFFFF ))

        i=$((i + 1))
    done

    # Return hue as hash mod 360
    echo $(( hash % 360 ))
}

# HSL to RGB conversion - converts HSL values to RGB (0-255)
# Input: H (0-360), S (0-100), L (0-100)
# Output: "R G B" where each is 0-255
_itint_hsl_to_rgb() {
    local h="$1" s="$2" l="$3"
    local c x m r g b
    local h_sector

    # Scale factor for integer arithmetic (avoid floating point)
    local scale=10000

    # Normalize: S and L from 0-100 to 0-scale
    s=$(( s * scale / 100 ))
    l=$(( l * scale / 100 ))

    # Chroma: C = (1 - |2L - 1|) * S
    # |2L - 1| where L is in [0, scale] means |2L - scale|
    local two_l_minus_1=$(( 2 * l - scale ))
    if [ "$two_l_minus_1" -lt 0 ]; then
        two_l_minus_1=$(( -two_l_minus_1 ))
    fi
    c=$(( (scale - two_l_minus_1) * s / scale ))

    # Determine hue sector (0-5) and position within sector
    # H is 0-360, each sector is 60 degrees
    h_sector=$(( h / 60 ))
    local h_in_sector=$(( h % 60 ))

    # X = C * (1 - |H' * 6 mod 2 - 1|)
    # H' * 6 mod 2 = (h / 60) mod 2 + (h % 60) / 60
    # Simplified: position = h % 120, then |position - 60| / 60
    local pos=$(( h % 120 ))
    local pos_diff=$(( pos - 60 ))
    if [ "$pos_diff" -lt 0 ]; then
        pos_diff=$(( -pos_diff ))
    fi
    # X = C * (1 - pos_diff/60) = C * (60 - pos_diff) / 60
    x=$(( c * (60 - pos_diff) / 60 ))

    # Match value: m = L - C/2
    m=$(( l - c / 2 ))

    # Map to RGB based on hue sector
    case "$h_sector" in
        0) r=$c; g=$x; b=0 ;;
        1) r=$x; g=$c; b=0 ;;
        2) r=0; g=$c; b=$x ;;
        3) r=0; g=$x; b=$c ;;
        4) r=$x; g=0; b=$c ;;
        *) r=$c; g=0; b=$x ;;  # sector 5 or edge case
    esac

    # Add match value and scale to 0-255
    r=$(( (r + m) * 255 / scale ))
    g=$(( (g + m) * 255 / scale ))
    b=$(( (b + m) * 255 / scale ))

    # Clamp to valid range (handles rounding edge cases)
    [ "$r" -lt 0 ] && r=0; [ "$r" -gt 255 ] && r=255
    [ "$g" -lt 0 ] && g=0; [ "$g" -gt 255 ] && g=255
    [ "$b" -lt 0 ] && b=0; [ "$b" -gt 255 ] && b=255

    echo "$r $g $b"
}

# Set iTerm2 tab color using escape codes
# Input: R G B lightness (0-255 for RGB, 0-100 for lightness)
# Only outputs escape codes if running in iTerm2
# Sets both background and foreground (text) color for optimal contrast
_itint_set_tab_color() {
    local r="$1" g="$2" b="$3"
    # Default to 50 if lightness not provided (backwards compatibility)
    local lightness="${4:-50}"
    # Validate lightness is numeric; default to 50 if not
    if ! [[ "$lightness" =~ ^[0-9]+$ ]]; then
        lightness=50
    fi

    # Silently do nothing if not in iTerm2 or not a TTY
    [ "$TERM_PROGRAM" != "iTerm.app" ] && return 0
    [ ! -t 1 ] && return 0

    # Set background color (one escape per channel)
    printf '\033]6;1;bg;red;brightness;%d\a' "$r"
    printf '\033]6;1;bg;green;brightness;%d\a' "$g"
    printf '\033]6;1;bg;blue;brightness;%d\a' "$b"

    # Set foreground (text) color based on lightness for contrast
    # L >= 55%: black text, L < 55%: white text
    local fg_val
    if [ "$lightness" -ge 55 ]; then
        fg_val=0    # Black
    else
        fg_val=255  # White
    fi
    printf '\033]6;1;fg;red;brightness;%d\a' "$fg_val"
    printf '\033]6;1;fg;green;brightness;%d\a' "$fg_val"
    printf '\033]6;1;fg;blue;brightness;%d\a' "$fg_val"
}

# Find git root directory by searching upward
# Input: starting directory path
# Output: git root path (empty string if not in a git repo)
# Stops at ~ or / to prevent runaway searches
# Respects ITINT_SUBMODULE_MODE: 'unique' returns submodule root, 'parent' continues to parent repo
_itint_find_git_root() {
    local dir="$1"
    local home_dir="$HOME"
    local prev_dir=""

    # Traverse upward until we find .git or hit boundaries
    while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "$prev_dir" ]; do
        prev_dir="$dir"
        # Check for .git in current directory
        if [ -e "$dir/.git" ]; then
            # Found something - is it a directory (regular repo) or file (submodule/worktree)?
            if [ -d "$dir/.git" ]; then
                # Regular git repository
                echo "$dir"
                return 0
            else
                # .git is a file - could be submodule or worktree
                # Worktrees have: gitdir: /path/to/.git/worktrees/<name>
                # Submodules have: gitdir: ../.git/modules/<name>
                local gitdir_line
                gitdir_line=$(head -1 "$dir/.git" 2>/dev/null)
                # Check for worktree pattern using case for shell compatibility
                case "$gitdir_line" in
                    *"/worktrees/"*)
                        # This is a worktree - treat it as a real repo root
                        echo "$dir"
                        return 0
                        ;;
                esac
                # Check if it's a submodule (points to .git/modules/) vs separate-git-dir
                case "$gitdir_line" in
                    *"/.git/modules/"*)
                        # This is a submodule
                        if [ "$ITINT_SUBMODULE_MODE" = "unique" ]; then
                            # Return submodule root for unique color
                            echo "$dir"
                            return 0
                        fi
                        # For 'parent' mode, continue searching upward for real repo
                        ;;
                    *)
                        # Not a submodule (e.g., git --separate-git-dir) - treat as repo root
                        echo "$dir"
                        return 0
                        ;;
                esac
            fi
        fi

        # Stop at home directory boundary
        if [ "$dir" = "$home_dir" ]; then
            break
        fi

        # Move up one directory
        dir="${dir%/*}"
        # Handle root case (dir becomes empty when at /)
        [ -z "$dir" ] && dir="/"
    done

    # Not in a git repository
    echo ""
    return 1
}

# Main update function - determines color for current directory and sets tab color
# Called by shell hooks on directory change
_itint_update() {
    local hue saturation lightness
    local override

    # Reload configuration on every update to pick up changes immediately
    _itint_load_config

    # Check for path override first (highest priority)
    # Overrides match against the current directory, not git root
    override=$(_itint_find_override "$PWD")

    if [ -n "$override" ]; then
        # Parse override: hue|sat|light (sat/light may be empty)
        local o_hue o_sat o_light
        IFS='|' read -r o_hue o_sat o_light <<< "$override"

        hue="$o_hue"
        # Use override values if provided, otherwise use defaults
        saturation="${o_sat:-${ITINT_DEFAULT_SATURATION:-50}}"
        lightness="${o_light:-${ITINT_DEFAULT_LIGHTNESS:-50}}"
    else
        # No override - determine path to hash
        local hash_path
        local git_root

        git_root=$(_itint_find_git_root "$PWD")

        if [ -n "$git_root" ]; then
            # Inside a git repo - use git root for hashing
            hash_path="$git_root"
        else
            # Not in git - use current directory
            hash_path="$PWD"
        fi

        # Apply hash mode: folder_name_only uses just the folder name, not full path
        if [ "$ITINT_HASH_MODE" = "folder_name_only" ]; then
            hash_path="${hash_path##*/}"
            # Handle edge case where path is "/" (results in empty string)
            [ -z "$hash_path" ] && hash_path="/"
        fi

        # Generate hue from path
        hue=$(_itint_path_to_hue "$hash_path")

        # Validate hue output
        if [ -z "$hue" ] || ! [ "$hue" -eq "$hue" ] 2>/dev/null; then
            return 1
        fi

        # Use saturation and lightness from configuration
        saturation="${ITINT_DEFAULT_SATURATION:-50}"
        lightness="${ITINT_DEFAULT_LIGHTNESS:-50}"
    fi

    # Convert to RGB
    local rgb r g b
    rgb=$(_itint_hsl_to_rgb "$hue" "$saturation" "$lightness")

    # Validate rgb output
    if [ -z "$rgb" ]; then
        return 1
    fi

    # Parse RGB values (explicitly set IFS for zsh compatibility)
    IFS=' ' read -r r g b <<< "$rgb"

    # Set tab color (pass lightness for foreground contrast calculation)
    _itint_set_tab_color "$r" "$g" "$b" "$lightness"
}

# Guard against duplicate sourcing
if [ -z "$_ITINT_INITIALIZED" ]; then
    _ITINT_INITIALIZED=1

    # Load configuration from ~/.itint
    _itint_load_config

    # Determine script directory for sourcing shell-specific hooks
    # Uses shell-specific methods to correctly resolve the sourced script's location
    if [ -n "$ZSH_VERSION" ]; then
        # Zsh: %N gives the name of the sourced file, :a makes it absolute, :h gets directory
        # ${0:a:h} doesn't work when sourced (resolves to shell name), so we use %N
        _ITINT_DIR="${${(%):-%N}:a:h}"
    elif [ -n "$BASH_VERSION" ]; then
        # Bash: resolve via dirname and cd/pwd for absolute path
        _ITINT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        # Fallback for other shells (unlikely to work, but provides a path)
        _ITINT_DIR="$(dirname "$0")"
    fi

    # Source shell-specific hook registration
    # Zsh: uses chpwd hook (fires on directory change)
    # Bash: uses PROMPT_COMMAND (fires before each prompt, tracks last dir)
    # Falls back to inline hook registration if external files are missing (backward compatibility)
    if [ -n "$ZSH_VERSION" ]; then
        if [ -f "$_ITINT_DIR/shells/zsh.sh" ] && [ -r "$_ITINT_DIR/shells/zsh.sh" ]; then
            source "$_ITINT_DIR/shells/zsh.sh"
        else
            echo "iterm-tint: warning: shells/zsh.sh not found at $_ITINT_DIR - reinstall may be required" >&2
            # Inline fallback: register chpwd hook directly
            if [[ ! " ${chpwd_functions[*]} " =~ " _itint_update " ]]; then
                chpwd_functions+=(_itint_update)
            fi
        fi
    elif [ -n "$BASH_VERSION" ]; then
        if [ -f "$_ITINT_DIR/shells/bash.sh" ] && [ -r "$_ITINT_DIR/shells/bash.sh" ]; then
            source "$_ITINT_DIR/shells/bash.sh"
        else
            echo "iterm-tint: warning: shells/bash.sh not found at $_ITINT_DIR - reinstall may be required" >&2
            # Inline fallback: register PROMPT_COMMAND hook directly
            _itint_prompt_command() {
                if [ "$PWD" != "$_ITINT_LAST_DIR" ]; then
                    _itint_update
                    _ITINT_LAST_DIR="$PWD"
                fi
            }
            if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" =~ "declare -a" ]]; then
                PROMPT_COMMAND=("_itint_prompt_command" "${PROMPT_COMMAND[@]}")
            else
                PROMPT_COMMAND="_itint_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
            fi
        fi
    fi

    # Clean up directory variable - no longer needed after sourcing
    unset _ITINT_DIR

    # Set initial tab color for current directory on shell startup
    _itint_update

    # Initialize last dir to prevent redundant update on first prompt
    _ITINT_LAST_DIR="$PWD"
fi
