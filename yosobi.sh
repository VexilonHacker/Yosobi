#!/bin/bash
# Made by VexilonHacker https://github.com/VexilonHacker
# Version 7.4 MPC update, exact output path, all previous features ;]

DOWNLOADED_HISTORY="$HOME/.yosobi_hist.json"
DEFAULT_MUSIC_DIR="$HOME/Music"
DEFAULT_VIDEOS_DIR="$HOME/Videos"
TMP_DIR="/tmp/yosobi"
RAW_TXT='raw.txt'

VIDEO_URL=""
PRESELECTED_FORMAT=""
OUTPUT_DIR=""
OUTPUT_NAME=""
OUTPUT_PATH=""
MAX_RETRIES=3
CONCURRENT_FRAGMENTS=5
SUBS_ENABLED=false
SUBS_FORMAT=""
SUBS_ONLY=false
SELECTED_FORMAT_CODE=""
COMMAND="download"
USE_JQ=true
MPC_NEWEST=false

print_logo() {
    local color="\e[33m"
    local reset="\e[0m"
    echo -e "${color}"
    cat <<'EOF'
       █████ █████                           █████      ███ 
      ░░███ ░░███                           ░░███      ░░░  
       ░░███ ███    ██████   █████   ██████  ░███████  ████ 
        ░░█████    ███░░███ ███░░   ███░░███ ░███░░███░░███ 
         ░░███    ░███ ░███░░█████ ░███ ░███ ░███ ░███ ░███ 
          ░███    ░███ ░███ ░░░░███░███ ░███ ░███ ░███ ░███ 
          █████   ░░██████  ██████ ░░██████  ████████  █████
         ░░░░░     ░░░░░░  ░░░░░░   ░░░░░░  ░░░░░░░░  ░░░░░ 
                                                            
EOF
    echo -e "${reset}"
}

print_help() {
    print_logo
    echo -e "\e[1;33mOptions:\e[0m"
    echo -e "  \e[1;32m-u, --url\e[0m               YouTube URL (video or playlist)"
    echo -e "  \e[1;32m-f, --format\e[0m            Preselected format code (e.g. 247, 251)"
    echo -e "  \e[1;32m-d, --dir\e[0m               Override base output directory (Videos/Music)"
    echo -e "  \e[1;32m-o, --output\e[0m            Custom output file name (no extension)"
    echo -e "  \e[1;32m-oo, --output-path\e[0m      Exact output file path (e.g. /path/to/file.mp3)"
    echo -e "  \e[1;32m-s, --subs\e[0m              Download subtitles"
    echo -e "  \e[1;32m-sf, --sub-format\e[0m       Subtitle format: lrc, vtt, srt, txt (default: lrc audio, vtt video)"
    echo -e "  \e[1;32m-so, --subs-only\e[0m        Download ONLY subtitles (no media)"
    echo -e "  \e[1;32m-m, --max-retries\e[0m       Set max retries (default: 3)"
    echo -e "  \e[1;32m-c, --concurrent\e[0m        Concurrent fragments for download (default: 5)"
    echo -e "  \e[1;32m-hs, --history\e[0m          Show download history"
    echo -e "  \e[1;32m-ch, --clear-history\e[0m    Delete all download history"
    echo -e "  \e[1;32m-h, --help\e[0m              Show this help menu"
    echo -e "  \e[1;32m-ex, --examples\e[0m         Show advanced usage examples"
    echo
    echo -e "\e[1;33mCommands:\e[0m"
    echo -e "  \e[1;32mdownload\e[0m (default)       Download video/audio with yt-dlp"
    echo -e "  \e[1;32mplay\e[0m                     Stream audio (or video) with mpv"
    echo -e "  \e[1;32msleep\e[0m                    Stream audio and then suspend the system"
    echo -e "  \e[1;32minfo\e[0m                      Fetch video/audio metadata as JSON"
    echo -e "  \e[1;32mmpc\e[0m                      Update MPD playlist (adds all music)"
    echo
    echo -e "\e[1;33mMPC usage:\e[0m"
    echo -e "  \e[1;32m$0 mpc [--newest]\e[0m"
    echo
    echo -e "\e[1;33mPlay/Sleep usage:\e[0m"
    echo -e "  \e[1;32m$0 play [--video] <url> [mpv options ...]\e[0m"
    echo -e "  \e[1;32m$0 sleep [--video] <url> [mpv options ...]\e[0m"
    echo
    echo -e "\e[1;33mExamples:\e[0m"
    echo -e "  \e[1;36m$0 -u 'URL'\e[0m"
    echo -e "  \e[1;36m$0 -u 'URL' -s -sf lrc\e[0m"
    echo -e "  \e[1;36m$0 -oo '/home/user/Music/song.mp3' -f 251\e[0m"
    echo -e "  \e[1;36m$0 play 'URL' --volume=80\e[0m"
    echo -e "  \e[1;36m$0 play --video 'URL' --start=60\e[0m"
    echo -e "  \e[1;36m$0 sleep 'URL'\e[0m"
    echo -e "  \e[1;36m$0 info 'URL'\e[0m"
    echo -e "  \e[1;36m$0 mpc --newest\e[0m"
    echo -e "  \e[1;36m$0 --history\e[0m"
    echo -e "  \e[1;36m$0 --clear-history\e[0m"
    echo -e "  \e[1;36m$0 --examples\e[0m  (show advanced examples)"
    echo
    exit 0
}

print_examples() {
    print_logo
    echo -e "\e[1;33mADVANCED USAGE EXAMPLES\e[0m\n"

    echo -e "\e[1;36m━━━ Audio Downloads ━━━\e[0m"
    echo -e "  \e[32m# Download best audio (interactive format selection)\e[0m"
    echo -e "  $0 'https://www.youtube.com/watch?v=kJQP7kiw5Fk'"
    echo
    echo -e "  \e[32m# Download audio with format 251 (opus), save as 'song.mp3'\e[0m"
    echo -e "  $0 -f 251 -o 'song' 'https://www.youtube.com/watch?v=kJQP7kiw5Fk'"
    echo
    echo -e "  \e[32m# Audio to exact path (no automatic extension)\e[0m"
    echo -e "  $0 -oo '/home/user/Music/MySong.mp3' -f 251 'URL'"
    echo
    echo -e "  \e[32m# Audio + LRC lyrics\e[0m"
    echo -e "  $0 -s -sf lrc 'https://www.youtube.com/watch?v=kJQP7kiw5Fk' -f 251"
    echo
    echo -e "  \e[32m# Audio + VTT subtitles\e[0m"
    echo -e "  $0 -s -sf vtt 'https://www.youtube.com/watch?v=kJQP7kiw5Fk' -f 251"
    echo

    echo -e "\e[1;36m━━━ Video Downloads ━━━\e[0m"
    echo -e "  \e[32m# Download 720p video (VP9, video-only) + best audio\e[0m"
    echo -e "  $0 -f 247 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    echo
    echo -e "  \e[32m# Download 1080p video with custom name\e[0m"
    echo -e "  $0 -f 137 -o 'MyVideo' 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    echo
    echo -e "  \e[32m# Video with embedded English subtitles (SRT)\e[0m"
    echo -e "  $0 -s -sf srt 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' -f 247"
    echo
    echo -e "  \e[32m# Video with LRC lyrics kept as separate file\e[0m"
    echo -e "  $0 -s -sf lrc 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' -f 247"
    echo
    echo -e "  \e[32m# Super-fast 1080p download with 10 concurrent fragments\e[0m"
    echo -e "  $0 -c 10 -f 137 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    echo

    echo -e "\e[1;36m━━━ Subtitles / Lyrics Only ━━━\e[0m"
    echo -e "  \e[32m# Download only English subtitles as VTT\e[0m"
    echo -e "  $0 -s -so -sf vtt 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    echo
    echo -e "  \e[32m# Download only lyrics as LRC, custom filename\e[0m"
    echo -e "  $0 -s -so -sf lrc -o 'lyrics' 'https://www.youtube.com/watch?v=kJQP7kiw5Fk'"
    echo
    echo -e "  \e[32m# Download only subtitles as clean text (TXT)\e[0m"
    echo -e "  $0 -s -so -sf txt -o 'transcript' 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    echo
    echo -e "  \e[32m# Download only subtitles to a custom directory\e[0m"
    echo -e "  $0 -s -so -sf srt -d ~/Subtitles 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    echo

    echo -e "\e[1;36m━━━ Streaming & Sleep ━━━\e[0m"
    echo -e "  \e[32m# Stream audio only\e[0m"
    echo -e "  $0 play 'https://www.youtube.com/watch?v=kJQP7kiw5Fk'"
    echo
    echo -e "  \e[32m# Stream audio with custom volume\e[0m"
    echo -e "  $0 play 'URL' --volume=50"
    echo
    echo -e "  \e[32m# Stream video, starting at 1 minute\e[0m"
    echo -e "  $0 play --video 'URL' --start=60"
    echo
    echo -e "  \e[32m# Stream audio then suspend the system\e[0m"
    echo -e "  $0 sleep 'https://www.youtube.com/watch?v=kJQP7kiw5Fk'"
    echo
    echo -e "  \e[32m# Stream video then suspend\e[0m"
    echo -e "  $0 sleep --video 'URL'"
    echo

    echo -e "\e[1;36m━━━ Info / Metadata ━━━\e[0m"
    echo -e "  \e[32m# Fetch all video metadata as JSON\e[0m"
    echo -e "  $0 info 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'"
    echo
    echo -e "  \e[32m# Get only the title\e[0m"
    echo -e "  $0 info 'URL' '.title'"
    echo
    echo -e "  \e[32m# Get title, duration and uploader\e[0m"
    echo -e "  $0 info 'URL' '{title: .title, duration: .duration, uploader: .uploader}'"
    echo
    echo -e "  \e[32m# Pipe info to jq for further processing\e[0m"
    echo -e "  $0 info 'URL' | jq '.formats[] | select(.vcodec != \"none\") | .format_id'"
    echo

    echo -e "\e[1;36m━━━ MPD / Music Library ━━━\e[0m"
    echo -e "  \e[32m# Update MPD playlist (alphabetical)\e[0m"
    echo -e "  $0 mpc"
    echo
    echo -e "  \e[32m# Update MPD playlist, newest files first\e[0m"
    echo -e "  $0 mpc --newest"
    echo

    echo -e "\e[1;36m━━━ History Management ━━━\e[0m"
    echo -e "  \e[32m# Show download history\e[0m"
    echo -e "  $0 --history"
    echo
    echo -e "  \e[32m# Clear download history (with confirmation)\e[0m"
    echo -e "  $0 --clear-history"
    echo

    echo -e "\e[1;36m━━━ Playlists ━━━\e[0m"
    echo -e "  \e[32m# Download an entire playlist\e[0m"
    echo -e "  $0 'https://www.youtube.com/playlist?list=PL...'"
    echo -e "  # then choose format mode (1 = same format for all, 2 = per video)"
    echo

    echo -e "\e[1;36m━━━ Combining Options ━━━\e[0m"
    echo -e "  \e[32m# Video to exact path + subtitles + 10 fragments\e[0m"
    echo -e "  $0 -oo '~/Videos/Rick.mp4' -s -sf vtt -c 10 -f 247 'URL'"
    echo
    echo -e "  \e[32m# Audio with LRC lyrics and custom output directory\e[0m"
    echo -e "  $0 -s -sf lrc -d ~/Music/Podcasts -f 251 'URL'"
    echo

    exit 0
}

check_deps() {
    local -a required=(yt-dlp ffmpeg)
    local missing_deps=()
    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "\e[31mError: Required programs missing:\e[0m"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                yt-dlp) echo "  - yt-dlp: Install with 'pip install -U yt-dlp' or via your package manager" ;;
                ffmpeg) echo "  - ffmpeg: Install via your package manager" ;;
            esac
        done
        cleanup
        exit 2
    fi
    if ! command -v jq &>/dev/null; then
        echo -e "\e[33mNote: jq not found. Playlist detection, info, history will be limited.\e[0m"
        USE_JQ=false
    fi
    if [[ "$COMMAND" == "play" || "$COMMAND" == "sleep" ]]; then
        if ! command -v mpv &>/dev/null; then
            echo -e "\e[31mError: mpv is required for streaming. Install mpv.\e[0m"
            cleanup
            exit 2
        fi
    fi
    if [[ "$COMMAND" == "mpc" ]]; then
        if ! command -v mpc &>/dev/null; then
            echo -e "\e[31mError: mpc is required for MPD control. Install mpc.\e[0m"
            cleanup
            exit 2
        fi
    fi
    if [[ "$COMMAND" == "info" ]]; then
        if ! $USE_JQ; then
            echo -e "\e[31mError: jq is required for the info command. Install jq.\e[0m"
            cleanup
            exit 2
        fi
    fi
}

cleanup() {
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}

ctrl_c() {
    tput cnorm 2>/dev/null
    echo -e "\n\e[33mCanceled by user. Cleaning up...\e[0m"
    cleanup
    exit 1
}

trap ctrl_c INT
trap cleanup EXIT

sanitize_filename() {
    local name="$1"
    printf '%s' "$name" \
        | tr '＊' '*' \
        | tr '/' '_' \
        | tr -d ':|?*"<>' \
        | sed -E 's/[[:space:]]+/ /g; s/\.+$//; s/ $//' \
        | cut -c1-240
}

init_history() {
    if [[ ! -f "$DOWNLOADED_HISTORY" ]]; then
        echo '[]' > "$DOWNLOADED_HISTORY"
    fi
}

save_download_info() {
    local video_name="$1"
    local video_url="$2"
    local format_type="$3"
    local final_path="$4"
    local date_str
    date_str=$(date '+%Y-%m-%d %H:%M:%S')
    init_history
    local tmp_hist="${DOWNLOADED_HISTORY}.tmp"
    local json_entry
    json_entry=$(jq -n \
        --arg date "$date_str" \
        --arg title "$video_name" \
        --arg url "$video_url" \
        --arg fmt "$format_type" \
        --arg path "$final_path" \
        '{
            date: $date,
            title: $title,
            url: $url,
            format: $fmt,
            path: $path
        }')
    jq --argjson entry "$json_entry" '. + [$entry]' "$DOWNLOADED_HISTORY" > "$tmp_hist" && mv "$tmp_hist" "$DOWNLOADED_HISTORY"
}

show_history() {
    if [[ ! -f "$DOWNLOADED_HISTORY" ]] || [[ "$(cat "$DOWNLOADED_HISTORY")" == "[]" ]]; then
        echo -e "\e[33mNo download history found.\e[0m"
        return
    fi
    echo -e "\n\e[1;33m📝 Download History:\e[0m\n"
    if $USE_JQ; then
        jq -r '.[] | 
            "Date: \(.date)",
            "Title: \(.title)",
            "URL: \(.url)",
            "Format: \(.format)",
            "Path: \(.path)",
            (if .resolution then "Resolution: \(.resolution)" else empty end),
            (if .vcodec then "Video Codec: \(.vcodec)" else empty end),
            (if .acodec then "Audio Codec: \(.acodec)" else empty end),
            (if .tbr then "Bitrate: \(.tbr)" else empty end),
            (if .format_note then "Note: \(.format_note)" else empty end),
            "=========================================="' "$DOWNLOADED_HISTORY" \
            | while IFS= read -r line; do
                case "$line" in
                    Date:*) echo -e "\e[36m$line\e[0m" ;;
                    Title:*) echo -e "\e[32m$line\e[0m" ;;
                    URL:*) echo -e "\e[35m$line\e[0m" ;;
                    Format:*) echo -e "\e[33m$line\e[0m" ;;
                    Path:*) echo -e "\e[1;34m$line\e[0m" ;;
                    Resolution:*|Video\ Codec:*|Audio\ Codec:*|Bitrate:*|Note:*) echo -e "\e[90m$line\e[0m" ;;
                    =*) echo "$line" ;;
                    *) echo "$line" ;;
                esac
            done
    else
        cat "$DOWNLOADED_HISTORY"
    fi
    echo
}

clear_history() {
    if [[ ! -f "$DOWNLOADED_HISTORY" ]]; then
        echo -e "\e[33mNo history file found.\e[0m"
        return
    fi
    echo -ne "\e[31mAre you sure you want to delete the entire download history? [y/N] \e[0m"
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -f "$DOWNLOADED_HISTORY"
        echo -e "\e[32mHistory cleared.\e[0m"
    else
        echo -e "\e[33mCancelled.\e[0m"
    fi
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r\e[33m⏳ %c Fetching formats...   \e[0m" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r\e[K"
    tput cnorm
}

fetch_and_display_formats() {
    local video_url="$1"
    local RAW_OUTPUT="$TMP_DIR/$RAW_TXT"
    mkdir -p "$TMP_DIR"
    rm -rf "$TMP_DIR"/* 2>/dev/null || true
    local AUDIO_FORMAT_CODES=()
    local VIDEO_FORMAT_CODES=()
    local COMBINED_FORMAT_CODES=()
    local ALL_CODES=()
    local attempt=1
    while [ $attempt -le "${MAX_RETRIES:-3}" ]; do
        yt-dlp --color always --no-warnings -F "$video_url" > "$RAW_OUTPUT" 2>/dev/null &
        local ytdlp_pid=$!
        spinner $ytdlp_pid
        wait $ytdlp_pid
        grep -E --color=never "audio only|video only|ID|─|^[[:space:]]*[0-9]+" "$RAW_OUTPUT" \
            | grep -v "m3u8\|mhtml\|storyboard" \
            | awk '
        BEGIN {
            blue   = "\033[1;34m"
            green  = "\033[1;32m"
            yellow = "\033[1;33m"
            reset  = "\033[0m"
        }

        {
            raw = $0
            clean = raw

            # strip ANSI only for matching
            gsub(/\033\[[0-9;]*m/, "", clean)

            # header
            if (clean ~ /^ID/) {
                print "    " raw

                # blue separator line
                sep = ""
                for (i = 1; i <= length(clean) + 8; i++)
                    sep = sep "─"

                print blue sep reset
                next
            }

            # remove original yt-dlp separator
            if (clean ~ /^[─━]+$/)
                next

            # add [+]
            if (clean ~ /^[[:space:]]*[0-9]/)
                raw = blue "[+]" reset " " raw

            # colors
            gsub(/audio only/, green "audio only" reset, raw)
            gsub(/video only/, yellow "video only" reset, raw)

            print raw
        }
        '
            
        local stripped
        stripped=$(sed 's/\x1b\[[0-9;]*m//g' "$RAW_OUTPUT")
        AUDIO_FORMAT_CODES=($(echo "$stripped" | grep "audio only" | awk '{print $1}'))
        VIDEO_FORMAT_CODES=($(echo "$stripped" | grep "video only" | awk '{print $1}'))
        COMBINED_FORMAT_CODES=($(echo "$stripped" | grep -v "audio only\|video only\|m3u8\|mhtml\|storyboard" | grep -E "^[0-9]+" | awk '{print $1}'))
        ALL_CODES=("${AUDIO_FORMAT_CODES[@]}" "${VIDEO_FORMAT_CODES[@]}" "${COMBINED_FORMAT_CODES[@]}")
        if [ ${#ALL_CODES[@]} -gt 0 ]; then
            break
        fi
        echo -e "\e[33mNo formats detected. Retrying ($attempt/$MAX_RETRIES)...\e[0m"
        ((attempt++))
        sleep 2
    done
    RET_AUDIO_CODES=("${AUDIO_FORMAT_CODES[@]}")
    RET_VIDEO_CODES=("${VIDEO_FORMAT_CODES[@]}")
    RET_COMBINED_CODES=("${COMBINED_FORMAT_CODES[@]}")
    RET_ALL_CODES=("${ALL_CODES[@]}")
    return 0
}

select_format_interactive() {
    local video_url="$1"
    fetch_and_display_formats "$video_url"
    if [ ${#RET_ALL_CODES[@]} -eq 0 ]; then
        echo -e "\e[31mError: No formats available.\e[0m"
        return 1
    fi
    if [[ -n "$PRESELECTED_FORMAT" ]]; then
        if [[ " ${RET_ALL_CODES[@]} " =~ " ${PRESELECTED_FORMAT} " ]]; then
            SELECTED_FORMAT_CODE="$PRESELECTED_FORMAT"
            echo -e "\e[32mUsing preselected format: $PRESELECTED_FORMAT\e[0m"
            return 0
        else
            echo -e "\e[33mWarning: Preselected format $PRESELECTED_FORMAT not available. Manual selection required.\e[0m"
        fi
    fi
    local old_trap
    old_trap=$(trap -p INT 2>/dev/null)
    trap 'echo -e "\n\e[33mCanceled by user.\e[0m"; cleanup; exit 1' INT
    local format_code=""
    while true; do
        if ! read -p "Enter the format code to download (or type 'q' to cancel): " format_code; then
            echo -e "\n\e[33mCanceled by user (EOF).\e[0m"
            cleanup
            exit 1
        fi
        if [[ "$format_code" == "q" || "$format_code" == "exit" ]]; then
            echo -e "\e[33mCanceled by user.\e[0m"
            if [[ -n "$old_trap" ]]; then
                eval "$old_trap"
            else
                trap ctrl_c INT
            fi
            return 2
        fi
        if [[ "$format_code" =~ ^[0-9]+(-[0-9]+)?$ ]] && [[ " ${RET_ALL_CODES[@]} " =~ " ${format_code} " ]]; then
            break
        fi
        echo -e "\e[31mInvalid format code. Please enter a valid number from the list.\e[0m"
    done
    if [[ -n "$old_trap" ]]; then
        eval "$old_trap"
    else
        trap ctrl_c INT
    fi
    SELECTED_FORMAT_CODE="$format_code"
    return 0
}

mpc_main() {
    echo -e "\e[36mUpdating MPD library...\e[0m"
    mpc update --wait >/dev/null
    echo -e "\e[36mRebuilding playlist...\e[0m"
    mpc clear
    if $MPC_NEWEST; then
        echo -e "\e[36mSorting by newest...\e[0m"
        find "$DEFAULT_MUSIC_DIR" -type f \( -iname "*.mp3" -o -iname "*.m4a" \) \
            -printf "%T@ %P\n" | sort -nr | cut -d" " -f2- | while IFS= read -r f; do
            mpc add "$f"
        done
    else
        mpc listall | mpc add
    fi
    mpc play
    echo -e "\e[32mMPD playlist updated and playing.\e[0m"
}

clean_txt_subs() {
    local vtt_file="$1"
    local txt_file="${vtt_file%.vtt}.txt"
    sed -i '/^[0-9]/d; /^[[:space:]]*$/d; /^WEBVTT/d; s/<[^>]*>//g' "$vtt_file"
    mv "$vtt_file" "$txt_file"
}

download_single_video() {
    local video_url="$1"
    local format_code="$2"
    local output_dir="$3"
    local output_name="$4"
    local max_retries="$5"

    local format_type=""
    local output_file=""
    local use_exact_path=false
    local exact_path=""

    if [[ -n "$OUTPUT_PATH" ]]; then
        use_exact_path=true
        exact_path="$OUTPUT_PATH"
        local dir_to_create=$(dirname "$exact_path")
        mkdir -p "$dir_to_create"
        output_file="$TMP_DIR/exact_download.out"
    else
        local title
        title=$(yt-dlp --get-title "$video_url" 2>/dev/null || echo "video")
        local sanitized_name
        if [[ -n "$output_name" ]]; then
            sanitized_name=$(sanitize_filename "$output_name")
        else
            sanitized_name=$(sanitize_filename "$title")
        fi
        output_file="$TMP_DIR/${sanitized_name}.%(ext)s"
        if [[ -z "$output_dir" ]]; then
            output_dir=""
        fi
    fi

    local DL_ATTEMPT=1
    local ret=1
    local yt_extra_args=()

    local sub_fmt=""
    if $SUBS_ENABLED; then
        sub_fmt="$SUBS_FORMAT"
        if [[ -z "$sub_fmt" ]]; then
            if $SUBS_ONLY; then
                sub_fmt="vtt"
            elif [[ " ${RET_AUDIO_CODES[@]} " =~ " ${format_code} " ]]; then
                sub_fmt="lrc"
            else
                sub_fmt="vtt"
            fi
        fi
        case "$sub_fmt" in
            lrc|vtt|srt|txt) ;;
            *) echo -e "\e[33mInvalid sub format '$sub_fmt', falling back to vtt.\e[0m"; sub_fmt="vtt" ;;
        esac
    fi

    if $SUBS_ONLY && $SUBS_ENABLED; then
        echo -e "\n🎤 \e[33mDownloading subtitles only...\e[0m"
        local title
        title=$(yt-dlp --get-title "$video_url" 2>/dev/null || echo "video")
        local sanitized_name
        if [[ -n "$output_name" ]]; then
            sanitized_name=$(sanitize_filename "$output_name")
        else
            sanitized_name=$(sanitize_filename "$title")
        fi
        local sub_output="$TMP_DIR/${sanitized_name}"
        local sub_lang="en"
        local dl_sub_fmt="$sub_fmt"
        if [[ "$sub_fmt" == "txt" ]]; then
            dl_sub_fmt="vtt"
        fi
        local attempt=1
        while [ $attempt -le "${max_retries:-3}" ]; do
            yt-dlp --skip-download --write-auto-subs --sub-langs "$sub_lang" \
                --convert-subs "$dl_sub_fmt" --output "$sub_output" "$video_url"
            local ret=$?
            if [[ $ret -eq 0 ]]; then
                local sub_file
                sub_file=$(find "$TMP_DIR" -maxdepth 1 -name "${sanitized_name}*.${dl_sub_fmt}" -print -quit)
                if [[ -z "$sub_file" ]]; then
                    sub_file="$TMP_DIR/${sanitized_name}.${sub_lang}.${dl_sub_fmt}"
                fi
                if [[ ! -f "$sub_file" ]]; then
                    echo -e "\e[33mSubtitle file not found.\e[0m"
                    return 1
                fi
                if [[ "$sub_fmt" == "txt" && "$dl_sub_fmt" == "vtt" ]]; then
                    clean_txt_subs "$sub_file"
                    sub_file="${sub_file%.vtt}.txt"
                fi
                mkdir -p "$output_dir"
                local final_name="$(basename "$sub_file")"
                if [[ -f "$output_dir/$final_name" ]]; then
                    local counter=1
                    local base="${sanitized_name}"
                    while [[ -f "$output_dir/${base}_${counter}.${sub_fmt}" ]]; do
                        ((counter++))
                    done
                    final_name="${base}_${counter}.${sub_fmt}"
                    mv "$sub_file" "$output_dir/$final_name"
                else
                    mv "$sub_file" "$output_dir/$final_name"
                fi
                echo -e "\e[0;33mSubtitle saved to: \e[0;32m$output_dir/$final_name\e[0m"
                save_download_info "$final_name" "$video_url" "subtitle" "$output_dir/$final_name"
                return 0
            else
                echo -e "\e[33mSubtitle download failed (exit $ret). Retrying ($attempt/$max_retries)...\e[0m"
            fi
            ((attempt++))
            sleep 2
        done
        echo -e "\e[31mSubtitle download failed after $max_retries attempts.\e[0m"
        return 1
    fi

    if $SUBS_ENABLED; then
        yt_extra_args+=(--write-auto-subs)
        local dl_sub_fmt="$sub_fmt"
        if [[ "$dl_sub_fmt" == "txt" ]]; then
            dl_sub_fmt="vtt"
        fi
        yt_extra_args+=(--convert-subs "$dl_sub_fmt")
        if [[ ! " ${RET_AUDIO_CODES[@]} " =~ " ${format_code} " ]]; then
            case "$sub_fmt" in
                vtt|srt) yt_extra_args+=(--embed-subs) ;;
                lrc|txt) ;;
            esac
        fi
    fi

    if [[ " ${RET_AUDIO_CODES[@]} " =~ " ${format_code} " ]]; then
        format_type="mp3"
        [[ -z "$output_dir" && "$use_exact_path" == false ]] && output_dir="$DEFAULT_MUSIC_DIR"
        echo -e "\n🎵 \e[33mTitle:\e[0m $title"
        echo -e "💾 \e[33mFormat:\e[0m $format_code (Audio → MP3)"
        [[ -n "$sub_fmt" ]] && echo -e "🎤 \e[33mSubtitles:\e[0m $sub_fmt"
        if $use_exact_path; then
            echo -e "📂 \e[33mOutput:\e[0m $exact_path"
        else
            echo -e "📂 \e[33mOutput Dir:\e[0m $output_dir"
        fi
        echo -e "⏳ \e[36mStarting download...\e[0m\n"
        while [ $DL_ATTEMPT -le "${max_retries:-3}" ]; do
            yt-dlp --progress -f "$format_code" --extract-audio --audio-format "$format_type" \
                --embed-thumbnail --add-metadata "${yt_extra_args[@]}" \
                -o "$output_file" "$video_url"
            ret=$?
            if [[ $ret -eq 0 ]]; then
                if $SUBS_ENABLED && [[ "$sub_fmt" == "txt" ]] && ! $use_exact_path; then
                    local vtt_file="$TMP_DIR/${sanitized_name}.en.vtt"
                    if [[ -f "$vtt_file" ]]; then
                        clean_txt_subs "$vtt_file"
                    fi
                fi
                break
            fi
            echo -e "\e[33mDownload failed (exit $ret). Retrying ($DL_ATTEMPT/$max_retries)...\e[0m"
            ((DL_ATTEMPT++))
            sleep 2
        done

    elif [[ " ${RET_VIDEO_CODES[@]} " =~ " ${format_code} " ]]; then
        format_type="mp4"
        [[ -z "$output_dir" && "$use_exact_path" == false ]] && output_dir="$DEFAULT_VIDEOS_DIR"
        if [ ${#RET_AUDIO_CODES[@]} -eq 0 ]; then
            echo -e "\e[33m⚠ No separate audio streams available.\e[0m"
            if [ ${#RET_COMBINED_CODES[@]} -gt 0 ]; then
                local best_combined="${RET_COMBINED_CODES[0]}"
                echo -e "\e[33mFalling back to combined format: $best_combined\e[0m"
                download_single_video "$video_url" "$best_combined" "$output_dir" "$output_name" "$max_retries"
                return $?
            else
                echo -e "\e[31mError: No audio or combined formats available.\e[0m"
                return 1
            fi
        fi
        local LAST_AUDIO_CODE="${RET_AUDIO_CODES[-1]}"
        local combined_format="${format_code}+${LAST_AUDIO_CODE}"
        echo -e "\n🎬 \e[33mTitle:\e[0m $title"
        echo -e "💾 \e[33mFormat:\e[0m $combined_format (Fragmented → MP4)"
        [[ -n "$sub_fmt" ]] && echo -e "🎤 \e[33mSubtitles:\e[0m $sub_fmt"
        if $use_exact_path; then
            echo -e "📂 \e[33mOutput:\e[0m $exact_path"
        else
            echo -e "📂 \e[33mOutput Dir:\e[0m $output_dir"
        fi
        echo -e "⏳ \e[36mStarting fast download ($CONCURRENT_FRAGMENTS concurrent fragments)...\e[0m\n"
        while [ $DL_ATTEMPT -le "${max_retries:-3}" ]; do
            yt-dlp --progress -f "$combined_format" --merge-output-format mp4 \
                --concurrent-fragments "$CONCURRENT_FRAGMENTS" "${yt_extra_args[@]}" \
                -o "$output_file" "$video_url"
            ret=$?
            [[ $ret -eq 0 ]] && break
            echo -e "\e[33mDownload failed (exit $ret). Retrying ($DL_ATTEMPT/$max_retries)...\e[0m"
            ((DL_ATTEMPT++))
            sleep 2
        done

    elif [[ " ${RET_COMBINED_CODES[@]} " =~ " ${format_code} " ]]; then
        format_type="mp4"
        [[ -z "$output_dir" && "$use_exact_path" == false ]] && output_dir="$DEFAULT_VIDEOS_DIR"
        echo -e "\n🎬 \e[33mTitle:\e[0m $title"
        echo -e "💾 \e[33mFormat:\e[0m $format_code (Combined)"
        [[ -n "$sub_fmt" ]] && echo -e "🎤 \e[33mSubtitles:\e[0m $sub_fmt"
        if $use_exact_path; then
            echo -e "📂 \e[33mOutput:\e[0m $exact_path"
        else
            echo -e "📂 \e[33mOutput Dir:\e[0m $output_dir"
        fi
        echo -e "⏳ \e[36mStarting download...\e[0m\n"
        while [ $DL_ATTEMPT -le "${max_retries:-3}" ]; do
            yt-dlp --progress -f "$format_code" "${yt_extra_args[@]}" \
                -o "$output_file" "$video_url"
            ret=$?
            [[ $ret -eq 0 ]] && break
            echo -e "\e[33mDownload failed (exit $ret). Retrying ($DL_ATTEMPT/$max_retries)...\e[0m"
            ((DL_ATTEMPT++))
            sleep 2
        done
    else
        echo -e "\e[31mError: Invalid format code $format_code\e[0m"
        return 1
    fi

    if [[ $ret -ne 0 ]]; then
        echo -e "\e[31mDownload/conversion failed (exit $ret)\e[0m"
        return $ret
    fi

    if $use_exact_path; then
        local downloaded_file
        downloaded_file=$(find "$TMP_DIR" -maxdepth 1 \
            \( -name "exact_download*" \) \
            ! -name "*.vtt" ! -name "*.srt" ! -name "*.lrc" ! -name "*.txt" \
            ! -name "*.webp" ! -name "*.png" ! -name "*.jpg" \
            -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
        if [[ -n "$downloaded_file" && -f "$downloaded_file" ]]; then
            mv -- "$downloaded_file" "$exact_path"
            local final_path="$exact_path"
        else
            echo -e "\e[31mError: Could not locate downloaded file.\e[0m"
            return 1
        fi
        local filesize
        filesize=$(stat --printf="%s" "$final_path" 2>/dev/null | numfmt --to=iec 2>/dev/null || du -h -- "$final_path" | cut -f1)
        local datetime
        datetime=$(date "+%Y-%m-%d %H:%M:%S")
        local icon
        [[ "$format_type" == "mp3" ]] && icon="🎵" || icon="🎬"
        echo -e "\e[0;33mFile saved to: \e[0;32m$final_path\e[0m"
        echo -e "\e[0;33mSize: \e[0;32m$filesize\e[0m | \e[0;33mDate: \e[0;32m$datetime\e[0m"
        echo -e "\e[38;5;33m$icon Download completed successfully ✓\e[0m"
        save_download_info "$(basename "$final_path")" "$video_url" "${final_path##*.}" "$final_path"
        return 0
    fi

    mkdir -p "$output_dir"
    local moved_any=0
    for f in "$TMP_DIR"/"${sanitized_name}".*; do
        [[ -f "$f" ]] || continue
        [[ "$(basename "$f")" == "$RAW_TXT" ]] && continue
        local ext="${f##*.}"
        local final_name="${sanitized_name}.${ext}"
        if [[ -f "$output_dir/$final_name" ]]; then
            local counter=1
            local base="${sanitized_name}"
            while [[ -f "$output_dir/${base}_${counter}.${ext}" ]]; do
                ((counter++))
            done
            final_name="${base}_${counter}.${ext}"
            echo -e "\e[33mFile exists. Saved as: $final_name\e[0m"
        fi
        mv -- "$f" "$output_dir/$final_name"
        moved_any=1
        local filesize
        filesize=$(stat --printf="%s" "$output_dir/$final_name" 2>/dev/null | numfmt --to=iec 2>/dev/null || du -h -- "$output_dir/$final_name" | cut -f1)
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
    if [ $moved_any -eq 0 ]; then
        echo -e "\e[31mWarning: no output file found in $TMP_DIR for ${sanitized_name}\e[0m"
        return 1
    fi
    return 0
}

info_main() {
    local url="$1"
    local filter="$2"
    if [[ -z "$url" ]]; then
        echo -e "\e[31mError: URL required for info command.\e[0m" >&2
        exit 1
    fi
    echo -e "\e[36mFetching metadata...\e[0m" >&2
    local json_output
    json_output=$(yt-dlp --dump-json --no-warnings "$url" 2>/dev/null)
    if [[ -z "$json_output" ]]; then
        echo -e "\e[31mError: Failed to fetch metadata.\e[0m" >&2
        exit 1
    fi
    if [[ -n "$filter" ]]; then
        echo "$json_output" | jq "$filter"
    else
        echo "$json_output" | jq '.'
    fi
}

download_main() {
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
    if $SUBS_ONLY && $SUBS_ENABLED; then
        download_single_video "$url" "" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
        return
    fi
    local is_playlist=false
    local pl_pat='[?&]list='
    if [[ "$url" =~ $pl_pat ]]; then
        if $USE_JQ; then
            local json_output
            json_output=$(yt-dlp --flat-playlist --dump-single-json "$url" 2>/dev/null || echo "{}")
            if echo "$json_output" | jq -e '.entries | type == "array" and length > 0' &>/dev/null; then
                is_playlist=true
            fi
        else
            local playlist_count
            playlist_count=$(yt-dlp --flat-playlist --print "%(playlist_count)s" "$url" 2>/dev/null)
            if [[ -n "$playlist_count" && "$playlist_count" =~ ^[0-9]+$ && "$playlist_count" -gt 1 ]]; then
                is_playlist=true
            fi
        fi
    fi
    if $is_playlist; then
        echo -e "\e[36mPlaylist detected!\e[0m"
        echo "1) Select one format code and apply to all videos"
        echo "2) Select format for each video individually"
        read -p "Enter option (1 or 2): " mode
        local VIDEO_URLS
        if $USE_JQ; then
            VIDEO_URLS=($(yt-dlp --flat-playlist --dump-single-json "$url" | jq -r '.entries[].url'))
        else
            VIDEO_URLS=($(yt-dlp --flat-playlist --get-url "$url" 2>/dev/null))
        fi
        local TOTAL=${#VIDEO_URLS[@]}
        if [[ "$TOTAL" -eq 0 ]]; then
            echo -e "\e[31mError: No videos found in playlist.\e[0m"
            cleanup
            exit 1
        fi
        if [[ -n "$OUTPUT_NAME" ]]; then
            echo -e "\e[33mNote: -o/--output ignored for playlists. Using video titles.\e[0m"
        fi
        if [[ "$mode" == "1" ]]; then
            echo -e "\e[33mFetching formats from first video...\e[0m"
            select_format_interactive "${VIDEO_URLS[0]}"
            local select_ret=$?
            if [[ $select_ret -eq 2 ]]; then
                echo -e "\e[33mPlaylist download canceled.\e[0m"
                return 0
            elif [[ $select_ret -ne 0 ]]; then
                echo -e "\e[31mFailed to select format.\e[0m"
                return 1
            fi
            local format_selected="$SELECTED_FORMAT_CODE"
            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\n\e[1;36m═══ Video $((i+1))/$TOTAL ═══\e[0m"
                fetch_and_display_formats "${VIDEO_URLS[$i]}"
                download_single_video "${VIDEO_URLS[$i]}" "$format_selected" "$OUTPUT_DIR" "" "$MAX_RETRIES"
            done
        else
            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\n\e[1;36m═══ Video $((i+1))/$TOTAL ═══\e[0m"
                select_format_interactive "${VIDEO_URLS[$i]}"
                local select_ret=$?
                if [[ $select_ret -eq 2 ]]; then
                    echo -e "\e[33mSkipping this video...\e[0m"
                    continue
                elif [[ $select_ret -ne 0 ]]; then
                    echo -e "\e[31mFailed to select format for this video. Skipping...\e[0m"
                    continue
                fi
                download_single_video "${VIDEO_URLS[$i]}" "$SELECTED_FORMAT_CODE" "$OUTPUT_DIR" "" "$MAX_RETRIES"
            done
        fi
    else
        select_format_interactive "$url"
        local select_ret=$?
        if [[ $select_ret -eq 2 ]]; then
            echo -e "\e[33mDownload canceled.\e[0m"
            return 0
        elif [[ $select_ret -ne 0 ]]; then
            echo -e "\e[31mFailed to select format.\e[0m"
            return 1
        fi
        download_single_video "$url" "$SELECTED_FORMAT_CODE" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
    fi
}

stream_play() {
    local url="$1"
    local video_mode="$2"
    shift 2
    local extra_args=("$@")
    local mpv_args=()
    if [[ "$video_mode" != "true" ]]; then
        mpv_args+=(--ytdl-format=bestaudio --no-video)
    fi
    mpv_args+=("${extra_args[@]}" "$url")
    echo -e "\e[36mLaunching mpv...\e[0m"
    mpv "${mpv_args[@]}"
}

stream_sleep() {
    local url="$1"
    local video_mode="$2"
    shift 2
    stream_play "$url" "$video_mode" "$@"
    local ret=$?
    if (( ret == 0 )); then
        echo -e "\e[33mPlayback finished. Suspending system...\e[0m"
        if command -v systemctl &>/dev/null; then
            systemctl suspend
        elif command -v pm-suspend &>/dev/null; then
            sudo pm-suspend
        elif command -v zzz &>/dev/null; then
            sudo zzz
        else
            echo -e "\e[31mNo supported suspend command found.\e[0m"
            return 1
        fi
    else
        echo -e "\e[31mPlayback failed (exit $ret). Not suspending.\e[0m"
    fi
}

main() {
    if [[ "$COMMAND" != "info" ]]; then
        print_logo
    fi
    check_deps
    case "$COMMAND" in
        download)
            download_main
            ;;
        play)
            if [[ -z "${STREAM_URL}" ]]; then
                echo -e "\e[31mError: URL required for play.\e[0m"
                exit 1
            fi
            stream_play "$STREAM_URL" "$STREAM_VIDEO" "${MPV_EXTRA_ARGS[@]}"
            ;;
        sleep)
            if [[ -z "${STREAM_URL}" ]]; then
                echo -e "\e[31mError: URL required for sleep.\e[0m"
                exit 1
            fi
            stream_sleep "$STREAM_URL" "$STREAM_VIDEO" "${MPV_EXTRA_ARGS[@]}"
            ;;
        mpc)
            mpc_main
            ;;
        info)
            if [[ -z "${INFO_URL}" ]]; then
                echo -e "\e[31mError: URL required for info.\e[0m"
                exit 1
            fi
            info_main "$INFO_URL" "$INFO_FILTER"
            ;;
    esac
    cleanup
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        play|sleep|download|info|mpc)
            COMMAND="$1"
            shift
            ;;
    esac
fi

if [[ "$COMMAND" == "download" ]]; then
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
            -oo|--output-path)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            -s|--subs)
                SUBS_ENABLED=true
                shift
                ;;
            -sf|--sub-format)
                SUBS_FORMAT="$2"
                if [[ ! "$SUBS_FORMAT" =~ ^(lrc|vtt|srt|txt)$ ]]; then
                    echo -e "\e[31mInvalid sub format. Valid: lrc, vtt, srt, txt\e[0m"
                    exit 2
                fi
                shift 2
                ;;
            -so|--subs-only)
                SUBS_ONLY=true
                shift
                ;;
            -m|--max-retries)
                MAX_RETRIES="$2"
                if ! [[ "$MAX_RETRIES" =~ ^[0-9]+$ ]] || [ "$MAX_RETRIES" -le 0 ]; then
                    echo -e "\e[31mInvalid --max-retries value. Must be a positive integer.\e[0m"
                    exit 2
                fi
                shift 2
                ;;
            -c|--concurrent)
                CONCURRENT_FRAGMENTS="$2"
                if ! [[ "$CONCURRENT_FRAGMENTS" =~ ^[0-9]+$ ]] || [ "$CONCURRENT_FRAGMENTS" -lt 1 ]; then
                    echo -e "\e[31mInvalid --concurrent value. Must be a positive integer.\e[0m"
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
            -ch|--clear-history)
                clear_history
                exit 0
                ;;
            -h|--help)
                print_help
                ;;
            -ex|--examples)
                print_examples
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
elif [[ "$COMMAND" == "mpc" ]]; then
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --newest)
                MPC_NEWEST=true
                shift
                ;;
            *)
                echo -e "\e[31mUnknown option: $1\e[0m"
                print_help
                ;;
        esac
    done
elif [[ "$COMMAND" == "info" ]]; then
    INFO_URL=""
    INFO_FILTER=""
    while [[ $# -gt 0 ]]; do
        if [[ -z "$INFO_URL" && "$1" =~ ^https?:// ]]; then
            INFO_URL="$1"
            shift
        elif [[ -z "$INFO_FILTER" ]]; then
            INFO_FILTER="$1"
            shift
        else
            echo -e "\e[31mUnknown option: $1\e[0m"
            print_help
        fi
    done
elif [[ "$COMMAND" == "play" || "$COMMAND" == "sleep" ]]; then
    STREAM_URL=""
    STREAM_VIDEO=false
    MPV_EXTRA_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --video)
                STREAM_VIDEO=true
                shift
                ;;
            -h|--help)
                print_help
                ;;
            *)
                if [[ -z "$STREAM_URL" && "$1" =~ ^https?:// ]]; then
                    STREAM_URL="$1"
                    shift
                    break
                else
                    echo -e "\e[31mUnknown option: $1\e[0m"
                    print_help
                fi
                ;;
        esac
    done
    MPV_EXTRA_ARGS=("$@")
fi

main "$@"

