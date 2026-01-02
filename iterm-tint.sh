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

# Load configuration from ~/.itint
# Parses the config file safely without eval and sets defaults for any missing settings
_itint_load_config() {
    local config_file="$HOME/.itint"

    # Set defaults first (these are used if config is missing or has errors)
    : "${ITINT_DEFAULT_SATURATION:=50}"
    : "${ITINT_DEFAULT_LIGHTNESS:=50}"
    : "${ITINT_HASH_MODE:=absolute_path}"
    # ITINT_FOCUS_MODE is reserved for future use (primary_pane support not yet implemented)
    : "${ITINT_SUBMODULE_MODE:=parent}"

    # Parse config file if it exists (safely, without eval)
    if [ -f "$config_file" ]; then
        local line key value
        while IFS= read -r line; do
            # Split on first equals sign only (preserves values containing '=')
            key="${line%%=*}"
            value="${line#*=}"
            # Skip empty lines or lines that don't match our pattern
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
        done < <(grep -E '^ITINT_[A-Z_]+=' "$config_file" 2>/dev/null | head -20)
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
# Input: R G B (0-255 each)
# Only outputs escape codes if running in iTerm2
_itint_set_tab_color() {
    local r="$1" g="$2" b="$3"

    # Silently do nothing if not in iTerm2 or not a TTY
    [ "$TERM_PROGRAM" != "iTerm.app" ] && return 0
    [ ! -t 1 ] && return 0

    # Set background color (one escape per channel)
    printf '\033]6;1;bg;red;brightness;%d\a' "$r"
    printf '\033]6;1;bg;green;brightness;%d\a' "$g"
    printf '\033]6;1;bg;blue;brightness;%d\a' "$b"
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
    # Determine what path to hash
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
    local hue
    hue=$(_itint_path_to_hue "$hash_path")

    # Validate hue output
    if [ -z "$hue" ] || ! [ "$hue" -eq "$hue" ] 2>/dev/null; then
        return 1
    fi

    # Use saturation and lightness from configuration
    local saturation="${ITINT_DEFAULT_SATURATION:-50}"
    local lightness="${ITINT_DEFAULT_LIGHTNESS:-50}"

    # Convert to RGB
    local rgb
    rgb=$(_itint_hsl_to_rgb "$hue" "$saturation" "$lightness")

    # Validate rgb output
    if [ -z "$rgb" ]; then
        return 1
    fi

    # Set tab color
    # shellcheck disable=SC2086
    _itint_set_tab_color $rgb
}

# Bash-specific: wrapper for PROMPT_COMMAND that only updates on directory change
_itint_prompt_command() {
    if [ "$PWD" != "$_ITINT_LAST_DIR" ]; then
        _itint_update
        _ITINT_LAST_DIR="$PWD"
    fi
}

# Guard against duplicate sourcing
if [ -z "$_ITINT_INITIALIZED" ]; then
    _ITINT_INITIALIZED=1

    # Load configuration from ~/.itint
    _itint_load_config

    # Register shell hooks based on current shell
    # Zsh: uses chpwd hook (fires on directory change)
    # Bash: uses PROMPT_COMMAND (fires before each prompt, so we track last dir)
    if [ -n "$ZSH_VERSION" ]; then
        # Zsh - add to chpwd hook array (check for duplicates)
        if [[ ! " ${chpwd_functions[*]} " =~ " _itint_update " ]]; then
            chpwd_functions+=(_itint_update)
        fi
    elif [ -n "$BASH_VERSION" ]; then
        # Bash - handle both string and array (bash 5+) PROMPT_COMMAND
        if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" =~ "declare -a" ]]; then
            # PROMPT_COMMAND is an array (bash 5+)
            PROMPT_COMMAND=("_itint_prompt_command" "${PROMPT_COMMAND[@]}")
        else
            # PROMPT_COMMAND is a string or unset
            PROMPT_COMMAND="_itint_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
        fi
    fi

    # Set initial tab color for current directory on shell startup
    _itint_update

    # Initialize last dir to prevent redundant update on first prompt
    _ITINT_LAST_DIR="$PWD"
fi
