#!/usr/bin/env bash

if [[ -z "$1" || ! -f "$1" ]]; then
    echo "Error: Please provide a valid file."
    echo "Usage: $0 <commands.txt>"
    exit 1
fi

FILE="$1"
SESSION="tmux_$(basename "$FILE" | sed 's/[^a-zA-Z0-9]/_/g')"

tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION"

first_window=true
window_idx=1

while IFS= read -r cmd || [[ -n "$cmd" ]]; do
    # Trim leading/trailing whitespace
    trimmed_cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    trimmed_cmd="${trimmed_cmd%"${trimmed_cmd##*[![:space:]]}"}"

    # Skip comments
    if [[ "$trimmed_cmd" == \#* ]]; then
        continue
    fi

    # --- Extract Window Name ---
    DISPLAY_NAME="cmd_$window_idx" # Default fallback name
    
    # Check if the line starts with [Window Name]
    if [[ "$trimmed_cmd" =~ ^\[([^]]+)\][[:space:]]*(.*)$ ]]; then
        DISPLAY_NAME="${BASH_REMATCH[1]}" # The text inside the brackets
        trimmed_cmd="${BASH_REMATCH[2]}"  # The remaining command string
    fi

    # Use a unique internal ID for safe pane splitting/targeting
    TARGET_ID="win_$window_idx"

    if $first_window; then
        tmux new-session -d -s "$SESSION" -n "$TARGET_ID"
        first_window=false
    else
        tmux new-window -t "$SESSION" -n "$TARGET_ID"
    fi

    TARGET="$SESSION:$TARGET_ID"

    # Split the line by the " ::: " delimiter into an array
    pane_cmds=()
    rest="$trimmed_cmd"
    while [[ "$rest" == *" ::: "* ]]; do
        pane_cmds+=("${rest%% ::: *}")
        rest="${rest#* ::: }"
    done
    pane_cmds+=("$rest")

    # Iterate through commands to create panes
    pane_idx=0
    for p_cmd in "${pane_cmds[@]}"; do
        # Trim whitespace for the individual pane command
        p_cmd="${p_cmd#"${p_cmd%%[![:space:]]*}"}"
        p_cmd="${p_cmd%"${p_cmd##*[![:space:]]}"}"

        # If it's not the first command, split the window horizontally
        if [[ $pane_idx -gt 0 ]]; then
            prev_pane=$((pane_idx - 1))
            tmux split-window -h -t "$TARGET.$prev_pane"
        fi

        PANE_TARGET="$TARGET.$pane_idx"

        # Execute command if the pane section is not empty
        if [[ -n "$p_cmd" ]]; then
            [[ "$window_idx" -eq 1 && "$pane_idx" -eq 0 ]] && sleep 0.5 
            
            tmux send-keys -t "$PANE_TARGET" -l "$p_cmd"
            tmux send-keys -t "$PANE_TARGET" C-m
        fi
        
        ((pane_idx++))
    done

    # If we created multiple panes, force them into an even side-by-side layout
    if [[ $pane_idx -gt 1 ]]; then
        tmux select-layout -t "$TARGET" even-horizontal
    fi

    # Apply the display name (either parsed from brackets or the fallback)
    tmux rename-window -t "$TARGET" "$DISPLAY_NAME"

    ((window_idx++))

done < "$FILE"

if ! $first_window; then
    tmux attach-session -t "$SESSION"
else
    echo "No valid lines found in $FILE"
fi