#!/bin/bash
# Made by VexilonHacker https://github.com/VexilonHacker

DOWNLOADED_HISTORY="$HOME/.yosobi_hist.txt"
DEFAULT_MUSIC_DIR="$HOME/Music"
DEFAULT_VIDEOS_DIR="$HOME/Videos"
TMP_DIR="/tmp/yosobi"
RAW_TXT='rwo.txt'

VIDEO_URL=""
PRESELECTED_FORMAT=""
OUTPUT_DIR=""
OUTPUT_NAME=""
MAX_RETRIES=3

print_logo() {
    local color="\e[33m"
    local reset="\e[0m"

    echo -e "${color}"
    cat <<'EOF'
                                                ░██        ░██
                                                ░██           
    ░██    ░██  ░███████   ░███████   ░███████  ░████████  ░██
    ░██    ░██ ░██    ░██ ░██        ░██    ░██ ░██    ░██ ░██
    ░██    ░██ ░██    ░██  ░███████  ░██    ░██ ░██    ░██ ░██
    ░██   ░███ ░██    ░██        ░██ ░██    ░██ ░███   ░██ ░██
     ░█████░██  ░███████   ░███████   ░███████  ░██░█████  ░██
           ░██                                                
     ░███████                                                 
EOF
    echo -e "${reset}"
}


print_help() {
    print_logo
    echo -e "\e[1;33mOptions:\e[0m"
    echo -e "  \e[1;32m-u, --url\e[0m          YouTube URL (video or playlist)"
    echo -e "  \e[1;32m-f, --format\e[0m       Preselected format code (e.g. 247, 251)"
    echo -e "  \e[1;32m-d, --dir\e[0m          Override base output directory (Videos/Music)"
    echo -e "  \e[1;32m-o, --output\e[0m       Custom output file name (no extension)"
    echo -e "  \e[1;32m-m, --max-retries\e[0m  Set maximum retries for format fetching/download (default: 3)"
    echo -e "  \e[1;32m-hs, --history\e[0m      Show download history"
    echo -e "  \e[1;32m-h, --help\e[0m         Show this help menu\n"
    echo -e "\e[1;33mExamples:\e[0m"
    echo -e "  \e[1;36m$0 -u 'https://youtu.be/FAyKDaXEAgc'\e[0m"
    echo -e "  \e[1;36m$0 --url 'https://youtu.be/FAyKDaXEAgc' --format 247 --max-retries 5\e[0m"
    echo -e "  \e[1;36m$0 -u 'https://youtube.com/playlist?list=...' --format 251 --dir ~/Downloads\e[0m"
    echo -e "  \e[1;36m$0 --history\e[0m\n"
    exit 0
}

check_deps() {
    local -a req=(yt-dlp ffmpeg perl jq)
    for cmd in "${req[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: Required program '$cmd' is missing."
            case "$cmd" in
                yt-dlp) echo "Install: pip install -U yt-dlp or via your distro." ;;
                ffmpeg) echo "Install ffmpeg via your package manager." ;;
                perl) echo "Install perl via your package manager." ;;
                jq) echo "Install jq via your package manager." ;;
            esac
            cleanup
            exit 2
        fi
    done
}

cleanup() {
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}

trap ctrl_c INT EXIT
ctrl_c() {
    if [[ "$1" == "INT" ]] || [[ "$_" == "$0" ]]; then
        echo -e "\n\e[33mDownload canceled by user. Cleaning up...\e[0m"
    fi
    cleanup
    if [[ "$1" == "INT" ]]; then exit 1; fi
}

sanitize_filename() {
    local name="$1"
    printf '%s' "$name" \
        | tr '＊' '*' \
        | tr '/' '_' \
        | tr -d ':' \
        | tr -d '|' \
        | tr -d '?' \
        | tr -d '*' \
        | tr -d '"' \
        | tr -d '<' \
        | tr -d '>' 
}

save_download_info() {
    local video_name="$1"
    local video_url="$2"
    local format_type="$3"
    local final_path="$4"

    {
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Video Name: $video_name"
        echo "URL: $video_url"
        echo "Type: $format_type"
        echo "Saved Path: $final_path"
        echo "=========================================="
    } >> "$DOWNLOADED_HISTORY"
}

show_history() {
    if [[ ! -f "$DOWNLOADED_HISTORY" ]]; then
        echo -e "\e[33mNo download history found.\e[0m"
        return
    fi

    local IFS=""
    local entry=""
    local separator="=========================================="
    local color_date="\e[36m"
    local color_name="\e[32m"
    local color_url="\e[35m"
    local color_type="\e[33m"
    local color_path="\e[1;34m"
    local reset="\e[0m"

    echo -e "\n\e[1;33m📝 Download History:\e[0m\n"

    while read -r line; do
        if [[ "$line" == "$separator" ]]; then
            if [[ -n "$entry" ]]; then
                echo -e "$entry\n$separator"
                entry=""
            fi
        else
            case "$line" in
                Date:*) entry+="${color_date}${line}${reset}\n" ;;
                "Video Name:"*) entry+="${color_name}${line}${reset}\n" ;;
                URL:*) entry+="${color_url}${line}${reset}\n" ;;
                Type:*) entry+="${color_type}${line}${reset}\n" ;;
                "Saved Path:"*) entry+="${color_path}${line}${reset}\n" ;;
                *) entry+="$line\n" ;;
            esac
        fi
    done < "$DOWNLOADED_HISTORY"

    [[ -n "$entry" ]] && echo -e "$entry\n$separator"
    echo
}

is_audio_format() {
    local selected_format_code="$1"
    [[ " ${AUDIO_FORMAT_CODES[@]} " =~ " ${selected_format_code} " ]]
}

choose_format() {
    local video_url="$1"
    local preselected_format="$2"
    local output_dir="$3"
    local output_name="$4"
    local max_retries="$5"

    local format_code=""
    local format_type=""
    local RAW_OUTPUT="$TMP_DIR/$RAW_TXT"

    # ensure TMP
    mkdir -p "$TMP_DIR"
    rm -rf "$TMP_DIR"/* 2>/dev/null || true

    # fetch formats (with retry)
    local attempt=1
    local AUDIO_FORMAT_CODES=()
    local VIDEO_FORMAT_CODES=()
    local AVAILABLE_CODES=()
    while [ $attempt -le "${max_retries:-3}" ]; do
        yt-dlp --color always --no-warnings -F "$video_url" | tee "$RAW_OUTPUT" \
            | grep -E --color=never "audio only|video only|ID|─" \
            | perl -pe '
BEGIN {
  $esc = "\x1b\[[0-9;]*m";
  sub inters { my $s = shift; $s =~ s/(.)/$1(?:$esc)*/g; return $s }
  $p_audio = inters("audio only");
  $p_video = inters("video only");
}
s/^(?:$esc)*ID/   $&/;
if (/^(?:$esc)*\x{2500}/) { $_ = ""; next }
s/^(?=(?:$esc)*\d)/\e[1;34m[+]\e[0m /;
s/($p_audio)/\e[1;32maudio only\e[0m/gi;
s/($p_video)/\e[1;33mvideo only\e[0m/gi;
'
        # parse available codes (strip color escapes)
        AUDIO_FORMAT_CODES=($(sed 's/\x1b\[[0-9;]*m//g' "$RAW_OUTPUT" | grep "audio only" | awk '{print $1}'))
        VIDEO_FORMAT_CODES=($(sed 's/\x1b\[[0-9;]*m//g' "$RAW_OUTPUT" | grep "video only" | awk '{print $1}'))
        AVAILABLE_CODES=("${AUDIO_FORMAT_CODES[@]}" "${VIDEO_FORMAT_CODES[@]}")

        if [ ${#AVAILABLE_CODES[@]} -gt 0 ]; then
            break
        fi

        echo -e "\e[33mNo audio/video formats detected. Retrying ($attempt/$max_retries)...\e[0m"
        ((attempt++))
        sleep 2
    done

    if [ ${#AVAILABLE_CODES[@]} -eq 0 ]; then
        echo -e "\e[31mError: Unable to detect any audio/video formats after $max_retries attempts.\e[0m"
        return 1
    fi

    # choose format (preselected or prompt)
    if [[ -n "$preselected_format" ]]; then
        format_code="$preselected_format"
    else
        while true; do
            # local trap so Ctrl+C exits immediately while prompting
            trap 'echo -e "\n\e[33mCanceled by user (Ctrl+C).\e[0m"; cleanup; exit 1' INT
            if ! read -p "Enter the format code to download (or type 'q' to cancel): " format_code; then
                echo -e "\n\e[33mCanceled by user (EOF).\e[0m"
                cleanup
                exit 1
            fi
            trap ctrl_c INT

            if [[ "$format_code" == "q" || "$format_code" == "exit" ]]; then
                echo -e "\e[33mCanceled by user.\e[0m"
                return 0
            fi

            if [[ "$format_code" =~ ^[0-9]+(-[0-9]+)?$ ]] && [[ " ${AVAILABLE_CODES[@]} " =~ " ${format_code} " ]]; then
                break
            fi

            echo -e "\e[31mInvalid format code. Please enter a valid number from the list.\e[0m"
        done
    fi

    SELECTED_FORMAT_CODE="$format_code"

    # get title and determine sanitized name
    local title
    title=$(yt-dlp --get-title "$video_url" 2>/dev/null || echo "video")
    local sanitized_name
    if [[ -n "$output_name" ]]; then
        sanitized_name=$(sanitize_filename "$output_name")
    else
        sanitized_name=$(sanitize_filename "$title")
    fi

    # set tmp output path (always valid)
    local output_file="$TMP_DIR/${sanitized_name}.%(ext)s"

    # determine default output_dir when not provided
    if [[ -z "$output_dir" ]]; then
        # will choose later depending on audio/video
        output_dir=""
    fi

    # perform download with retries
    local DL_ATTEMPT=1
    local ret=1

    if [[ " ${AUDIO_FORMAT_CODES[@]} " =~ " ${format_code} " ]]; then
        format_type="mp3"
        [[ -z "$output_dir" ]] && output_dir="$DEFAULT_MUSIC_DIR"
        echo -e "\n🎵 \e[33mTitle:\e[0m $title"
        echo -e "💾 \e[33mFormat:\e[0m $format_code (Audio → MP3)"
        echo -e "📂 \e[33mOutput Dir:\e[0m $output_dir"
        echo -e "⏳ \e[36mStarting download...\e[0m\n"


        while [ $DL_ATTEMPT -le "${max_retries:-3}" ]; do
            yt-dlp --progress -f "$format_code" --extract-audio --audio-format "$format_type" \
                --embed-thumbnail --add-metadata -o "$output_file" "$video_url"
            ret=$?
            [[ $ret -eq 0 ]] && break
            echo -e "\e[33mDownload failed (exit $ret). Retrying...\e[0m"
            ((DL_ATTEMPT++))
            sleep 2
        done
    else
        format_type="mp4"
        [[ -z "$output_dir" ]] && output_dir="$DEFAULT_VIDEOS_DIR"
        local LAST_AUDIO_CODE="${AUDIO_FORMAT_CODES[-1]}"
        echo -e "\n🎬 \e[33mTitle:\e[0m $title"
        echo -e "💾 \e[33mFormat:\e[0m $format_code+$LAST_AUDIO_CODE (Merged → MP4)"
        echo -e "📂 \e[33mOutput Dir:\e[0m $output_dir"
        echo -e "⏳ \e[36mStarting download...\e[0m\n"


        while [ $DL_ATTEMPT -le "${max_retries:-3}" ]; do
            yt-dlp --progress -f "${format_code}+${LAST_AUDIO_CODE}" --merge-output-format mp4 -o "$output_file" "$video_url"
            ret=$?
            [[ $ret -eq 0 ]] && break
            echo -e "\e[33mDownload failed (exit $ret). Retrying...\e[0m"
            ((DL_ATTEMPT++))
            sleep 2
        done
    fi

    if [[ $ret -ne 0 ]]; then
        echo -e "\e[31mDownload/conversion failed (exit $ret)\e[0m"
        return $ret
    fi

    # move produced file(s) from TMP to final output_dir
    mkdir -p "$output_dir"
    local moved_any=0
    for f in "$TMP_DIR"/"${sanitized_name}".*; do
        [[ -f "$f" ]] || continue
        [[ "$(basename "$f")" == "$RAW_TXT" ]] && continue

        local ext="${f##*.}"
        local final_name="${sanitized_name}.${ext}"
        mv -- "$f" "$output_dir/$final_name"
        moved_any=1

        local filesize
        filesize=$(du -h -- "$output_dir/$final_name" | cut -f1)
        local datetime
        datetime=$(date "+%Y-%m-%d %H:%M:%S")
        local icon
        if [[ "$ext" == "mp3" || "$ext" == "m4a" || "$ext" == "webm" || "$format_type" == "mp3" ]]; then
            icon="🎵"
        else
            icon="🎬"
        fi

        echo -e "\e[0;33mFile saved to: \e[0;32m$output_dir/$final_name\e[0m"
        echo -e "\e[0;33mSize: \e[0;32m$filesize\e[0m | \e[0;33mDate: \e[0;32m$datetime\e[0m"
        echo -e "\e[38;5;33m$icon Download completed successfully ✓\e[0m"

        save_download_info "$final_name" "$video_url" "$ext" "$output_dir/$final_name"
    done

    # if nothing was moved (edge case), warn
    if [ $moved_any -eq 0 ]; then
        echo -e "\e[31mWarning: no output file found in $TMP_DIR for ${sanitized_name}\e[0m"
        return 1
    fi

    return 0
}

main() {
    print_logo
    check_deps

    local url="$VIDEO_URL"

    # prompt for URL if missing
    if [[ -z "$url" ]]; then
        read -p "Enter YouTube URL (supports playlists): " url
        if [[ -z "$url" ]]; then
            echo "❌ No URL entered. Exiting."
            cleanup
            exit 1
        fi
    fi

    # validate url
    if ! [[ "$url" =~ ^https?://(www\.)?youtube\.com/ || "$url" =~ ^https?://youtu\.be/ ]]; then
        echo -e "\e[31mError: Invalid YouTube URL.\e[0m"
        cleanup
        exit 1
    fi

    # detect playlist
    local is_playlist=false
    local json_output
    json_output=$(yt-dlp --flat-playlist --dump-single-json "$url" 2>/dev/null || echo "{}")
    if echo "$json_output" | jq -e '.entries | type == "array" and length > 0' &>/dev/null; then
        is_playlist=true
    fi

    if $is_playlist; then
        echo -e "\e[36mPlaylist detected!\e[0m"
        echo "1) Select one format code and apply to all videos"
        echo "2) Select format for each video individually"
        read -p "Enter option (1 or 2): " mode

        local VIDEO_URLS
        VIDEO_URLS=($(yt-dlp --flat-playlist --dump-single-json "$url" | jq -r '.entries[].url'))
        local TOTAL=${#VIDEO_URLS[@]}

        if [[ "$mode" == "1" ]]; then
            # pick format once (allow OUTPUT_NAME for first item)
            choose_format "${VIDEO_URLS[0]}" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
            local format_selected="$SELECTED_FORMAT_CODE"

            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\e[33mDownloading video $((i+1))/$TOTAL...\e[0m"
                # do not pass output_name to subsequent videos to avoid overwriting the same name
                choose_format "${VIDEO_URLS[$i]}" "$format_selected" "$OUTPUT_DIR" "" "$MAX_RETRIES"
            done
        else
            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\e[33mDownloading video $((i+1))/$TOTAL...\e[0m"
                choose_format "${VIDEO_URLS[$i]}" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "" "$MAX_RETRIES"
            done
        fi
    else
        # single video
        choose_format "$url" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
    fi

    cleanup
}

main() {
    print_logo
    check_deps

    local url="$VIDEO_URL"

    # prompt for URL if missing
    if [[ -z "$url" ]]; then
        read -p "Enter YouTube URL (supports playlists): " url
        if [[ -z "$url" ]]; then
            echo "❌ No URL entered. Exiting."
            cleanup
            exit 1
        fi
    fi

    # validate url
    if ! [[ "$url" =~ ^https?://(www\.)?youtube\.com/ || "$url" =~ ^https?://youtu\.be/ ]]; then
        echo -e "\e[31mError: Invalid YouTube URL.\e[0m"
        cleanup
        exit 1
    fi

    # detect playlist
    local is_playlist=false
    local json_output
    json_output=$(yt-dlp --flat-playlist --dump-single-json "$url" 2>/dev/null || echo "{}")
    if echo "$json_output" | jq -e '.entries | type == "array" and length > 0' &>/dev/null; then
        is_playlist=true
    fi

    if $is_playlist; then
        echo -e "\e[36mPlaylist detected!\e[0m"
        echo "1) Select one format code and apply to all videos"
        echo "2) Select format for each video individually"
        read -p "Enter option (1 or 2): " mode

        local VIDEO_URLS
        VIDEO_URLS=($(yt-dlp --flat-playlist --dump-single-json "$url" | jq -r '.entries[].url'))
        local TOTAL=${#VIDEO_URLS[@]}

        if [[ "$mode" == "1" ]]; then
            # pick format once (allow OUTPUT_NAME for first item)
            choose_format "${VIDEO_URLS[0]}" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
            local format_selected="$SELECTED_FORMAT_CODE"

            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\e[33mDownloading video $((i+1))/$TOTAL...\e[0m"
                # do not pass output_name to subsequent videos to avoid overwriting the same name
                choose_format "${VIDEO_URLS[$i]}" "$format_selected" "$OUTPUT_DIR" "" "$MAX_RETRIES"
            done
        else
            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\e[33mDownloading video $((i+1))/$TOTAL...\e[0m"
                choose_format "${VIDEO_URLS[$i]}" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "" "$MAX_RETRIES"
            done
        fi
    else
        # single video
        choose_format "$url" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
    fi

    cleanup
}


while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)
            VIDEO_URL="$2"
            shift 2
            ;;
        -f|--format)
            PRESELECTED_FORMAT="$2"
            shift 2
            ;;
        -d|--dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -m| --max-retries)
            MAX_RETRIES="$2"
            if ! [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || [ "$MAX_RETRIES" -le 0 ]; then
                echo -e "\e[31mInvalid --max-retries value. Must be a positive integer.\e[0m"
                exit 2
            fi
            shift 2
            ;;
        -o|--output)
            OUTPUT_NAME="$2"
            shift 2
            ;;
        -hs|--history)
            show_history
            exit 0
            ;;

        -h|--help)
            print_help
            ;;
        *)
            if [[ -z "$VIDEO_URL" && "$1" =~ ^https?:// ]]; then
                VIDEO_URL="$1"
                shift
            else
                echo -e "\e[31mUnknown option: $1\e[0m"
                print_help
            fi
            ;;
    esac
done

if [[ -n "$OUTPUT_DIR" ]]; then
    DEFAULT_VIDEOS_DIR="$OUTPUT_DIR"
    DEFAULT_MUSIC_DIR="$OUTPUT_DIR"
fi

main() {
    print_logo
    check_deps

    local url="$VIDEO_URL"

    if [[ -z "$url" ]]; then
        read -p "Enter YouTube URL (supports playlists): " url
        if [[ -z "$url" ]]; then
            echo "❌ No URL entered. Exiting."
            cleanup
            exit 1
        fi
    fi

    if ! [[ "$url" =~ ^https?://(www\.)?youtube\.com/ || "$url" =~ ^https?://youtu\.be/ ]]; then
        echo -e "\e[31mError: Invalid YouTube URL.\e[0m"
        cleanup
        exit 1
    fi

    local is_playlist=false
    local json_output
    json_output=$(yt-dlp --flat-playlist --dump-single-json "$url" 2>/dev/null || echo "{}")
    if echo "$json_output" | jq -e '.entries | type == "array" and length > 0' &>/dev/null; then
        is_playlist=true
    fi

    if $is_playlist; then
        echo -e "\e[36mPlaylist detected!\e[0m"
        echo "1) Select one format code and apply to all videos"
        echo "2) Select format for each video individually"
        read -p "Enter option (1 or 2): " mode

        local VIDEO_URLS=($(yt-dlp --flat-playlist --dump-single-json "$url" | jq -r '.entries[].url'))
        local TOTAL=${#VIDEO_URLS[@]}

        if [[ "$mode" == "1" ]]; then
            choose_format "${VIDEO_URLS[0]}" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
            local format_selected="$SELECTED_FORMAT_CODE"

            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\e[33mDownloading video $((i+1))/$TOTAL...\e[0m"
                choose_format "${VIDEO_URLS[$i]}" "$format_selected" "$OUTPUT_DIR" "" "$MAX_RETRIES"
            done
        else
            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\e[33mDownloading video $((i+1))/$TOTAL...\e[0m"
                choose_format "${VIDEO_URLS[$i]}" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "" "$MAX_RETRIES"
            done
        fi
    else
        choose_format "$url" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
    fi

    cleanup
}


main "$@"
