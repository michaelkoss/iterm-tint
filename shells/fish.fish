# iterm-tint Fish shell integration
# Source this file from ~/.config/fish/config.fish:
#   source ~/.iterm-tint/shells/fish.fish
#
# https://github.com/michaelkoss/iterm-tint

# Capture initial environment values before any config loading (preserves user overrides)
# These are captured once on script load and used as base defaults on every config reload
set -q ITINT_DEFAULT_SATURATION; or set -g ITINT_DEFAULT_SATURATION 50
set -q ITINT_DEFAULT_LIGHTNESS; or set -g ITINT_DEFAULT_LIGHTNESS 50
set -q ITINT_HASH_MODE; or set -g ITINT_HASH_MODE absolute_path
set -q ITINT_SUBMODULE_MODE; or set -g ITINT_SUBMODULE_MODE parent

# Store captured environment values as base defaults
set -g _ITINT_ENV_SATURATION $ITINT_DEFAULT_SATURATION
set -g _ITINT_ENV_LIGHTNESS $ITINT_DEFAULT_LIGHTNESS
set -g _ITINT_ENV_HASH_MODE $ITINT_HASH_MODE
set -g _ITINT_ENV_SUBMODULE_MODE $ITINT_SUBMODULE_MODE

# Track config file mtime to avoid unnecessary reloads
set -g _ITINT_CONFIG_MTIME ""

# Path overrides storage (list of "path|hue|sat|light" entries)
set -g _ITINT_OVERRIDES

# Clamp a value to 0-100, returning default if non-numeric
function _itint_clamp_percent
    set -l value $argv[1]
    set -l default_val $argv[2]

    if not string match -qr '^-?[0-9]+$' -- "$value"
        echo $default_val
        return
    end

    if test $value -lt 0
        echo 0
    else if test $value -gt 100
        echo 100
    else
        echo $value
    end
end

# Parse a single override line and add to _ITINT_OVERRIDES
function _itint_parse_override_line
    set -l line $argv[1]

    # Skip empty lines and comments
    test -z "$line"; and return
    string match -qr '^\s*#' -- "$line"; and return

    # Normalize whitespace (tabs and multiple spaces → single space) and split into words
    set -l normalized_line (string replace -ra '\s+' ' ' -- (string trim -- $line))
    set -l words (string split ' ' -- $normalized_line)
    set -l word_count (count $words)

    # Need at least 2 words (path and hue)
    test $word_count -lt 2; and return

    # Check last 3 words for numeric pattern
    set -l last1 $words[$word_count]
    set -l last2 $words[(math $word_count - 1)]
    set -l last3 ""
    if test $word_count -ge 3
        set last3 $words[(math $word_count - 2)]
    end

    # Count trailing numeric values
    set -l num_count 0
    if string match -qr '^-?[0-9]+$' -- "$last1"
        set num_count 1
        if string match -qr '^-?[0-9]+$' -- "$last2"
            set num_count 2
            if test $word_count -ge 3; and string match -qr '^-?[0-9]+$' -- "$last3"
                set num_count 3
            end
        end
    end

    # Must have at least 1 numeric (hue)
    test $num_count -eq 0; and return

    # Extract values based on count
    set -l hue ""
    set -l sat ""
    set -l light ""
    set -l path_end_idx

    switch $num_count
        case 1
            set hue $last1
            set path_end_idx (math $word_count - 1)
        case 2
            # Two trailing numbers is ambiguous - treat as hue-only with numeric path component
            # (e.g., "~/project2 120" where "project2" isn't the hue)
            set hue $last1
            set path_end_idx (math $word_count - 1)
        case 3
            set hue $last3
            set sat $last2
            set light $last1
            set path_end_idx (math $word_count - 3)
    end

    # Reconstruct path
    set -l override_path (string join ' ' -- $words[1..$path_end_idx])

    # Must have path and hue
    test -z "$override_path"; and return
    test -z "$hue"; and return

    # Validate hue is numeric (0-360)
    if not string match -qr '^[0-9]+$' -- "$hue"
        return
    end
    if test $hue -gt 360
        return
    end

    # Expand tilde (only ~/ prefix or bare ~, not ~username)
    switch "$override_path"
        case '~/*'
            set override_path (string replace -r '^~' "$HOME" -- $override_path)
        case '~'
            set override_path $HOME
    end

    # Handle saturation and lightness
    if test -n "$sat"; and test -n "$light"
        # Validate both are numeric
        if not string match -qr '^-?[0-9]+$' -- "$sat"; or not string match -qr '^-?[0-9]+$' -- "$light"
            set sat ""
            set light ""
        else
            # Clamp to valid range
            test $sat -lt 0; and set sat 0
            test $sat -gt 100; and set sat 100
            test $light -lt 0; and set light 0
            test $light -gt 100; and set light 100
        end
    else
        set sat ""
        set light ""
    end

    # Append to overrides
    set -a _ITINT_OVERRIDES "$override_path|$hue|$sat|$light"
end

# Load configuration from ~/.itint
function _itint_load_config
    set -l config_file "$HOME/.itint"

    # Check if config file has changed (mtime-based caching)
    set -l mtime 0
    if test -f "$config_file"
        set mtime (stat -f %m "$config_file" 2>/dev/null; or echo 0)
    end
    if test "$mtime" = "$_ITINT_CONFIG_MTIME"
        return  # Config unchanged, skip reload
    end
    set -g _ITINT_CONFIG_MTIME $mtime

    # Reset to base defaults (preserves environment variable overrides)
    # Uses captured environment values, falling back to hardcoded defaults
    set -g ITINT_DEFAULT_SATURATION $_ITINT_ENV_SATURATION
    set -g ITINT_DEFAULT_LIGHTNESS $_ITINT_ENV_LIGHTNESS
    set -g ITINT_HASH_MODE $_ITINT_ENV_HASH_MODE
    set -g ITINT_SUBMODULE_MODE $_ITINT_ENV_SUBMODULE_MODE

    # Clear any existing overrides
    set -g _ITINT_OVERRIDES

    if not test -f "$config_file"
        return
    end

    set -l in_overrides 0
    set -l line_count 0
    set -l max_lines 200

    while read -l line
        set line_count (math $line_count + 1)
        test $line_count -gt $max_lines; and break

        # Check for section headers
        if string match -qr '^\[overrides\]' -- "$line"
            set in_overrides 1
            continue
        else if string match -qr '^\[.+\]' -- "$line"
            set in_overrides 0
            continue
        end

        # Skip comments and empty lines
        string match -qr '^\s*#' -- "$line"; and continue
        test -z "$line"; and continue

        if test $in_overrides -eq 1
            _itint_parse_override_line "$line"
        else
            # Parse ITINT_ variable assignment
            if string match -qr '^ITINT_[A-Z_]+=' -- "$line"
                set -l key (string replace -r '=.*' '' -- $line)
                set -l value (string replace -r '^[^=]+=' '' -- $line)

                # Strip quotes
                set value (string trim -c '"' -- $value)
                set value (string trim -c "'" -- $value)

                switch $key
                    case ITINT_DEFAULT_SATURATION ITINT_DEFAULT_LIGHTNESS
                        if string match -qr '^[0-9]+$' -- "$value"
                            set -g $key $value
                        end
                    case ITINT_HASH_MODE
                        switch $value
                            case absolute_path folder_name_only
                                set -g $key $value
                        end
                    case ITINT_SUBMODULE_MODE
                        switch $value
                            case parent unique
                                set -g $key $value
                        end
                end
            end
        end
    end < "$config_file"

    # Validate and clamp values
    set -g ITINT_DEFAULT_SATURATION (_itint_clamp_percent $ITINT_DEFAULT_SATURATION 50)
    set -g ITINT_DEFAULT_LIGHTNESS (_itint_clamp_percent $ITINT_DEFAULT_LIGHTNESS 50)
end

# Find the best matching override for a given path
function _itint_find_override
    set -l target_path $argv[1]
    set -l best_match ""
    set -l best_len 0

    for entry in $_ITINT_OVERRIDES
        test -z "$entry"; and continue

        set -l parts (string split '|' -- $entry)
        set -l override_path $parts[1]
        set -l hue $parts[2]
        set -l sat $parts[3]
        set -l light $parts[4]

        # Check if target_path starts with override_path (prefix match)
        if test "$target_path" = "$override_path"; or string match -q "$override_path/*" -- "$target_path"
            set -l path_len (string length -- $override_path)
            if test $path_len -gt $best_len
                set best_len $path_len
                set best_match "$hue|$sat|$light"
            end
        end
    end

    echo $best_match
end

# DJB2 hash algorithm - converts a string to a hue value (0-360)
function _itint_path_to_hue
    set -l input_path $argv[1]
    set -l hash 5381

    # Process each character
    for i in (seq (string length -- $input_path))
        set -l char (string sub -s $i -l 1 -- $input_path)
        set -l byte (printf '%d' "'$char" 2>/dev/null; or echo 0)

        # DJB2: hash = hash * 33 + byte (use --scale=0 for integer arithmetic)
        set hash (math --scale=0 "(($hash * 32) + $hash) + $byte")
        # Keep hash within reasonable bounds using bitwise AND (matches bash version)
        set hash (math --scale=0 "bitand($hash, 2147483647)")
    end

    # Return hue as hash mod 360
    math --scale=0 "$hash % 360"
end

# HSL to RGB conversion - converts HSL values to RGB (0-255)
function _itint_hsl_to_rgb
    set -l h $argv[1]
    set -l s $argv[2]
    set -l l $argv[3]

    # Scale factor for integer-like arithmetic
    set -l scale 10000

    # Normalize S and L
    set s (math --scale=0 "$s * $scale / 100")
    set l (math --scale=0 "$l * $scale / 100")

    # Chroma
    set -l two_l_minus_1 (math --scale=0 "2 * $l - $scale")
    test $two_l_minus_1 -lt 0; and set two_l_minus_1 (math --scale=0 "- $two_l_minus_1")
    set -l c (math --scale=0 "($scale - $two_l_minus_1) * $s / $scale")

    # Hue sector
    set -l h_sector (math --scale=0 "$h / 60")

    # X calculation
    set -l pos (math --scale=0 "$h % 120")
    set -l pos_diff (math --scale=0 "$pos - 60")
    test $pos_diff -lt 0; and set pos_diff (math --scale=0 "- $pos_diff")
    set -l x (math --scale=0 "$c * (60 - $pos_diff) / 60")

    # Match value
    set -l m (math --scale=0 "$l - $c / 2")

    # Map to RGB based on hue sector
    set -l r 0
    set -l g 0
    set -l b 0

    switch $h_sector
        case 0
            set r $c; set g $x; set b 0
        case 1
            set r $x; set g $c; set b 0
        case 2
            set r 0; set g $c; set b $x
        case 3
            set r 0; set g $x; set b $c
        case 4
            set r $x; set g 0; set b $c
        case '*'
            set r $c; set g 0; set b $x
    end

    # Add match value and scale to 0-255
    set r (math --scale=0 "($r + $m) * 255 / $scale")
    set g (math --scale=0 "($g + $m) * 255 / $scale")
    set b (math --scale=0 "($b + $m) * 255 / $scale")

    # Clamp to valid range
    test $r -lt 0; and set r 0
    test $r -gt 255; and set r 255
    test $g -lt 0; and set g 0
    test $g -gt 255; and set g 255
    test $b -lt 0; and set b 0
    test $b -gt 255; and set b 255

    echo "$r $g $b"
end

# Set iTerm2 tab color using escape codes
function _itint_set_tab_color
    set -l r $argv[1]
    set -l g $argv[2]
    set -l b $argv[3]
    set -l lightness $argv[4]
    test -z "$lightness"; and set lightness 50

    # Silently do nothing if not in iTerm2 or not a TTY
    test "$TERM_PROGRAM" != "iTerm.app"; and return 0
    not isatty stdout; and return 0

    # Set background color
    printf '\033]6;1;bg;red;brightness;%d\a' $r
    printf '\033]6;1;bg;green;brightness;%d\a' $g
    printf '\033]6;1;bg;blue;brightness;%d\a' $b

    # Set foreground color based on lightness
    set -l fg_val 255
    if string match -qr '^[0-9]+$' -- "$lightness"; and test $lightness -ge 55
        set fg_val 0
    end
    printf '\033]6;1;fg;red;brightness;%d\a' $fg_val
    printf '\033]6;1;fg;green;brightness;%d\a' $fg_val
    printf '\033]6;1;fg;blue;brightness;%d\a' $fg_val
end

# Find git root directory by searching upward
function _itint_find_git_root
    set -l dir $argv[1]
    set -l home_dir $HOME
    set -l prev_dir ""

    while test -n "$dir"; and test "$dir" != "/"; and test "$dir" != "$prev_dir"
        set prev_dir $dir

        if test -e "$dir/.git"
            if test -d "$dir/.git"
                echo $dir
                return 0
            else
                # .git is a file - check for worktree or submodule
                set -l gitdir_line (head -1 "$dir/.git" 2>/dev/null)

                # Check for worktree
                if string match -q '*worktrees*' -- "$gitdir_line"
                    echo $dir
                    return 0
                end

                # Check for submodule
                if string match -q '*/.git/modules/*' -- "$gitdir_line"
                    if test "$ITINT_SUBMODULE_MODE" = "unique"
                        echo $dir
                        return 0
                    end
                    # For 'parent' mode, continue searching
                else
                    # Not a submodule - treat as repo root
                    echo $dir
                    return 0
                end
            end
        end

        # Stop at home directory
        if test "$dir" = "$home_dir"
            break
        end

        # Move up one directory
        set dir (string replace -r '/[^/]+$' '' -- $dir)
        test -z "$dir"; and set dir "/"
    end

    # Not in a git repository
    echo ""
    return 1
end

# Main update function - called on directory change
function _itint_update --on-variable PWD
    # Guard against empty PWD
    test -z "$PWD"; and return

    # Reload configuration on every update to pick up changes immediately
    _itint_load_config

    set -l hue
    set -l saturation
    set -l lightness

    # Check for path override first
    set -l override (_itint_find_override $PWD)

    if test -n "$override"
        set -l parts (string split '|' -- $override)
        set hue $parts[1]
        set saturation $parts[2]
        set lightness $parts[3]

        # Use defaults if not specified in override
        test -z "$saturation"; and set saturation $ITINT_DEFAULT_SATURATION
        test -z "$lightness"; and set lightness $ITINT_DEFAULT_LIGHTNESS
    else
        # No override - determine path to hash
        set -l hash_path
        set -l git_root (_itint_find_git_root $PWD)

        if test -n "$git_root"
            set hash_path $git_root
        else
            set hash_path $PWD
        end

        # Apply hash mode
        if test "$ITINT_HASH_MODE" = "folder_name_only"
            set hash_path (basename -- $hash_path)
            test -z "$hash_path"; and set hash_path "/"
        end

        # Generate hue
        set hue (_itint_path_to_hue $hash_path)

        # Use config values
        set saturation $ITINT_DEFAULT_SATURATION
        set lightness $ITINT_DEFAULT_LIGHTNESS
    end

    # Validate hue (must be numeric and in range 0-360)
    if test -z "$hue"; or not string match -qr '^[0-9]+$' -- "$hue"; or test $hue -gt 360
        return 1
    end

    # Convert to RGB
    set -l rgb (_itint_hsl_to_rgb $hue $saturation $lightness)
    test -z "$rgb"; and return 1

    set -l rgb_parts (string split ' ' -- $rgb)

    # Set tab color
    _itint_set_tab_color $rgb_parts[1] $rgb_parts[2] $rgb_parts[3] $lightness
end

# Guard against duplicate sourcing - only run initialization once
if not set -q _ITINT_INITIALIZED
    set -g _ITINT_INITIALIZED 1

    # Initialize
    _itint_load_config

    # Set initial tab color
    _itint_update
end
