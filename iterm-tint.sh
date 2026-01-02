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
