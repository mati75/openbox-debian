#!/bin/bash

# ---- Config ----
applications_dirs=("/usr/share/applications")
image_dir_base="/usr/share"
icon_theme="Numix"
image_cat_prefix="applications-"
terminal_string="x-terminal-emulator -e"
simpleOBheader=false
show_icons=true
[[ "$1" == "--no-icons" ]] && show_icons=false

application_groups=("Office" "Development" "Graphics" "Internet" "Games" "System" "Multimedia" "Utilities" "Settings")
declare -A group_aliases=(["Audio"]="Multimedia" ["AudioVideo"]="Multimedia" ["Network"]="Internet" ["Game"]="Games" ["Utility"]="Utilities" ["GTK"]="" ["GNOME"]="")
ignoreList=("evince-previewer" "Ted" "wingide3.2" "python3.4" "feh" "xfce4-power-manager-settings")

declare -A categoryDict
for cat in "${application_groups[@]}"; do
    categoryDict["$cat"]=""
done

# ---- Helpers ----

escape_xml() {
    echo "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e "s/\"/\&quot;/g" -e "s/'/\&apos;/g"
}

get_icon_path() {
    local icon="$1"
    for ext in png svg xpm; do
        if [ -f "$image_dir_base/pixmaps/$icon.$ext" ]; then
            echo "$image_dir_base/pixmaps/$icon.$ext"
            return
        fi
    done
    echo ""
}

get_cat_icon() {
    local name="${1,,}"  # lowercase category name
    local cat_icon="${image_cat_prefix}${name}"
    local search_dirs=(
        "$HOME/.icons/$icon_theme/categories/24"
        "$HOME/.icons/$icon_theme/24x24/categories"
        "$HOME/.local/share/icons/$icon_theme/categories/24"
        "$HOME/.local/share/icons/$icon_theme/24x24/categories"
        "/usr/share/icons/$icon_theme/categories/24"
        "/usr/share/icons/$icon_theme/24x24/categories"
	"/usr/share/icons/$icon_theme/24x2x/categories"
        "/usr/share/icons/$icon_theme/scalable/categories"
        "/usr/share/pixmaps"
    )

    for dir in "${search_dirs[@]}"; do
        for ext in png svg xpm; do
            icon="$dir/$cat_icon.$ext"
            [[ -f "$icon" ]] && echo "$icon" && return
        done
    done

    echo ""
}
process_category() {
    local cat="$1"
    [[ "${group_aliases[$cat]+_}" ]] && cat="${group_aliases[$cat]}"
    [[ -z "$cat" ]] && return
    for g in "${application_groups[@]}"; do
        [ "$cat" == "$g" ] && echo "$cat" && return
    done
}

parse_desktop_file() {
    local file="$1"

    grep -q "^\[Desktop Entry\]" "$file" || return

    local name=""
    local name_local=""
    local exec=""
    local icon=""
    local terminal="false"
    local type=""
    local categories=""
    local lang="${LANG%%_*}"

    while IFS= read -r line; do
        line="${line%%#*}"
        case "$line" in
            Name["[$lang]"]\=*) name_local="${line#*=}" ;;
            Name\=*) name="${line#*=}" ;;
            Exec\=*) exec="${line#*=}"; exec="${exec// %*}" ;;
            Icon\=*) icon="${line#*=}" ;;
            Terminal\=*) terminal="${line#*=}" ;;
            Type\=*) type="${line#*=}" ;;
            Categories\=*) categories="${line#*=}" ;;
        esac
    done < "$file"

    [[ "$type" != "Application" ]] && return
    for ign in "${ignoreList[@]}"; do
        [[ "$file" == *"$ign"* ]] && return
    done

    local final_name="${name_local:-$name}"
    [[ -z "$final_name" || -z "$exec" ]] && return
    final_name="$(escape_xml "$final_name")"

    [[ "$show_icons" == true ]] && icon_path="$(get_icon_path "$icon")" || icon_path=""

    IFS=';' read -ra cat_list <<< "${categories%;}"
    for cat in "${cat_list[@]}"; do
        valid_cat=$(process_category "$cat")
        [[ -n "$valid_cat" ]] && categoryDict["$valid_cat"]+="$final_name|$exec|$terminal|$icon_path"$'\n'
    done
}

# ---- MAIN ----

for dir in "${applications_dirs[@]}"; do
    for file in "$dir"/*.desktop; do
        [ -f "$file" ] && parse_desktop_file "$file"
    done
done

# ---- Output ----

$simpleOBheader && echo "<openbox_pipe_menu>" || echo '<?xml version="1.0" encoding="UTF-8"?><openbox_pipe_menu xmlns="http://openbox.org/">'

for cat in "${application_groups[@]}"; do
    entries="${categoryDict[$cat]}"
    [ -z "$entries" ] && continue

    echo -n "  <menu id=\"openbox-${cat}\" label=\"$cat\""
    if $show_icons; then
        cat_icon="$(get_cat_icon "$cat")"
        [ -n "$cat_icon" ] && echo -n " icon=\"$cat_icon\""
    fi
    echo ">"

    echo "$entries" | sort -f | while IFS='|' read -r label cmd term icon; do
	if [[ -n "$label" ]]; then
        echo -n "    <item label=\"$label\""
        [ "$show_icons" == true ] && [ -n "$icon" ] && echo -n " icon=\"$icon\""
        echo "><action name=\"Execute\"><command><![CDATA["
        [ "$term" == "true" ] && echo -n "$terminal_string "
        echo "$cmd]]></command></action></item>"
	fi
    done

    echo "  </menu>"
done

echo "</openbox_pipe_menu>"
