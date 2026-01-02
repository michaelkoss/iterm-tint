#!/bin/bash
# iterm-tint - Dynamic iTerm2 tab colors based on working directory
# https://github.com/michaelkoss/iterm-tint

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
