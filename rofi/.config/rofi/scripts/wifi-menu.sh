#!/usr/bin/env bash

CACHE_FILE="/tmp/rofi_wifi_cache"
CACHE_TTL=5  # seconds
NOTIFY_TIME=3000  # 3 seconds

# --- Get current Wi-Fi ---
current_wifi=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | cut -d: -f2)

# --- Refresh cache if needed ---
if [[ ! -f "$CACHE_FILE" || $(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") )) -gt $CACHE_TTL ]]; then
    nmcli -t -f SSID,SECURITY,SIGNAL dev wifi list | sed '/^--$/d' > "$CACHE_FILE"
fi

wifi_list=$(cat "$CACHE_FILE")

# --- Build menu ---
menu="󰑐  Refresh Networks"
# Put currently connected Wi-Fi on top
if [[ -n "$current_wifi" ]]; then
    menu="$menu\n✔ $current_wifi"
fi

while IFS=: read -r ssid security signal; do
    [[ -z "$ssid" ]] && continue
    [[ "$ssid" == "$current_wifi" ]] && continue  # Already added
    if nmcli -g NAME connection show | grep -qx "$ssid"; then
        icon=""  # saved network
    else
        icon=""  # locked/new network
    fi
    menu="$menu\n$icon $ssid"
done <<< "$wifi_list"

# --- Show menu ---
chosen=$(echo -e "$menu" | rofi -dmenu -i -p "Select Wi-Fi")
[[ -z "$chosen" ]] && exit 0

# --- Handle Refresh ---
if [[ "$chosen" == "󰑐  Refresh Networks" ]]; then
    nmcli device wifi rescan >/dev/null
    sleep 1
    exec "$0"
fi

# --- Extract chosen SSID ---
icon="${chosen%% *}"
chosen_ssid="${chosen#* }"

previous_wifi="$current_wifi"

# --- Determine menu based on network state ---
if [[ "$chosen_ssid" == "$current_wifi" ]]; then
    # Currently connected
    action=$(echo -e " Forget\n↩ Return" | rofi -dmenu -i -p "$chosen_ssid options")
elif nmcli -g NAME connection show | grep -qx "$chosen_ssid"; then
    # Previously saved but not connected
    action=$(echo -e "󱘖 Connect\n Forget\n↩ Return" | rofi -dmenu -i -p "$chosen_ssid")
else
    # Forgotten or never connected
    action=$(echo -e "󱘖 Connect\n↩ Return" | rofi -dmenu -i -p "$chosen_ssid")
fi

[[ -z "$action" ]] && exit 0

# --- Handle menu actions ---
if [[ "$action" == "↩ Return" ]]; then
    exec "$0"
elif [[ "$action" == " Forget" ]]; then
    nmcli connection delete id "$chosen_ssid"
    # Return to main menu immediately without notification
    exec "$0"
elif [[ "$action" == "󱘖 Connect" ]]; then
    # Check if network is already saved
    if nmcli -g NAME connection show | grep -qx "$chosen_ssid"; then
        nmcli connection up id "$chosen_ssid" >/dev/null 2>&1
        current=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | cut -d: -f2)
        if [[ "$current" == "$chosen_ssid" ]]; then
            notify-send -t $NOTIFY_TIME "✅ Connected" "Connected to \"$chosen_ssid\"."
        else
            notify-send -t $NOTIFY_TIME "❌ Could not connect" "\"$chosen_ssid\"."
        fi
    else
        # Ask for password
        while true; do
            wifi_password=$(rofi -dmenu -password -p "Password for $chosen_ssid:")
            [[ -z "$wifi_password" ]] && exit 0

            nmcli device wifi connect "$chosen_ssid" password "$wifi_password" >/dev/null 2>&1
            sleep 1
            current=$(nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes:' | cut -d: -f2)

            if [[ "$current" == "$chosen_ssid" ]]; then
                notify-send -t $NOTIFY_TIME "✅ Connected" "Connected to \"$chosen_ssid\"."
                break
            else
                notify-send -t $NOTIFY_TIME "❌ Incorrect Password" "Try again for \"$chosen_ssid\"."
                # Reconnect previous Wi-Fi if exists
                [[ -n "$previous_wifi" ]] && nmcli connection up id "$previous_wifi" >/dev/null 2>&1
            fi
        done
    fi
fi

