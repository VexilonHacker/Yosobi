#!/bin/bash

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
    echo -e "  \e[1;32m-h, --help\e[0m         Show this help menu\n"
    echo -e "\e[1;33mExamples:\e[0m"
    echo -e "  \e[1;36m$0 -u 'https://youtu.be/FAyKDaXEAgc'\e[0m"
    echo -e "  \e[1;36m$0 --url 'https://youtu.be/FAyKDaXEAgc' --format 247 --max-retries 5\e[0m"
    echo -e "  \e[1;36m$0 -u 'https://youtube.com/playlist?list=...' --format 251 --dir ~/Downloads\e[0m\n"
    exit 0

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
    # if called by trap on EXIT, $? may be non-zero; show cancel only on INT
    if [[ "$1" == "INT" ]] || [[ "$_" == "$0" ]]; then
        echo -e "\n\e[33mDownload canceled by user. Cleaning up...\e[0m"
    fi
    cleanup
    # When triggered by INT, exit with 1. When normal EXIT, let script finish.
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
        | tr -d '>' \
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

is_audio_format() {
    local selected_format_code="$1"
    [[ " ${AUDIO_FORMAT_CODES[@]} " =~ " ${selected_format_code} " ]]
}

choose_format() {
    local video_url="$1"
    local preselected_format="$2"
    local format_code=""
    local format_type=""
    local output_dir=""
    local title=""
    local RAW_OUTPUT="$TMP_DIR/$RAW_TXT"

    mkdir -p "$TMP_DIR"
    rm -rf "$TMP_DIR"/* 2>/dev/null || true

    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do

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

        AUDIO_FORMAT_CODES=($(sed 's/\x1b\[[0-9;]*m//g' "$RAW_OUTPUT" | grep "audio only" | awk '{print $1}'))
        VIDEO_FORMAT_CODES=($(sed 's/\x1b\[[0-9;]*m//g' "$RAW_OUTPUT" | grep "video only" | awk '{print $1}'))
        AVAILABLE_CODES=("${AUDIO_FORMAT_CODES[@]}" "${VIDEO_FORMAT_CODES[@]}")

        if [ ${#AVAILABLE_CODES[@]} -gt 0 ]; then
            break
        fi

        echo -e "\e[33mNo audio/video formats detected. Retrying ($attempt/$MAX_RETRIES)...\e[0m"
        echo -e "⏳ \e[36m Attempt $attempt/$MAX_RETRIES: Requesting formats for the video...\e[0m\n"
        ((attempt++))
        sleep 2
    done

    if [ ${#AUDIO_FORMAT_CODES[@]} -eq 0 ] && [ ${#VIDEO_FORMAT_CODES[@]} -eq 0 ]; then
        echo -e "\e[31mError: Unable to detect any audio/video formats after $MAX_RETRIES attempts.\e[0m"
        return 1
    fi

    if [[ -n "$preselected_format" ]]; then
        format_code="$preselected_format"
    else
        while true; do
            read -p "Enter the format code to download (or type 'q' to cancel): " format_code
            if [[ "$format_code" == "q" || "$format_code" == "exit" ]]; then
                echo -e "\e[33mCanceled by user.\e[0m"
                return 0
            fi
            if [[ "$format_code" =~ ^[0-9]+$ ]] && [[ " ${AVAILABLE_CODES[@]} " =~ " ${format_code} " ]]; then
                break
            fi
            echo -e "\e[31mInvalid format code. Please enter a valid number from the list.\e[0m"
        done
    fi

    SELECTED_FORMAT_CODE="$format_code"

    title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || true
    [[ -z "$title" ]] && title="${video_url##*/}" && title="${title%%&*}"

    if [[ " ${AUDIO_FORMAT_CODES[@]} " =~ " ${format_code} " ]]; then
        # audio-only
        format_type="mp3"
        output_dir="${OUTPUT_DIR:-$DEFAULT_MUSIC_DIR}"
        echo -e "\n🎵 \e[33mTitle:\e[0m $title"
        echo -e "💾 \e[33mFormat:\e[0m $format_code (Audio → MP3)"
        echo -e "📂 \e[33mOutput Dir:\e[0m $output_dir"
        echo -e "⏳ \e[36mStarting download...\e[0m\n"


        DL_ATTEMPT=1
        ret=1
        while [ $DL_ATTEMPT -le $MAX_RETRIES ]; do
            yt-dlp --progress  -f "$format_code" \
                --extract-audio --audio-format "$format_type" \
                --embed-thumbnail --add-metadata \
                -o "$TMP_DIR/%(title)s.%(ext)s" "$video_url"
            ret=$?
            [[ $ret -eq 0 ]] && break
            echo -e "\e[33mDownload failed (exit $ret). Retrying...\e[0m"
            sleep 2
            echo -e "⏳ \e[36mDownload attempt $DL_ATTEMPT/$MAX_DL_RETRIES...\e[0m\n"
            ((DL_ATTEMPT++))
        done
    else
        # video+audio merge
        format_type="mp4"
        output_dir="${OUTPUT_DIR:-$DEFAULT_VIDEOS_DIR}"
        LAST_AUDIO_CODE="${AUDIO_FORMAT_CODES[-1]}"
        echo -e "\n🎬 \e[33mTitle:\e[0m $title"
        echo -e "💾 \e[33mFormat:\e[0m $format_code+$LAST_AUDIO_CODE (Merged → MP4)"
        echo -e "📂 \e[33mOutput Dir:\e[0m $output_dir"
        echo -e "⏳ \e[36mStarting download...\e[0m\n"

        DL_ATTEMPT=1
        ret=1
        while [ $DL_ATTEMPT -le $MAX_RETRIES ]; do
            echo -e "⏳ Download attempt $DL_ATTEMPT/$MAX_RETRIES..."
            yt-dlp --progress  -f "${format_code}+${LAST_AUDIO_CODE}" --merge-output-format mp4 \
                -o "$TMP_DIR/%(title)s.%(ext)s" "$video_url"
            ret=$?
            [[ $ret -eq 0 ]] && break
            echo -e "\e[33mDownload failed (exit $ret). Retrying...\e[0m"
            ((DL_ATTEMPT++))
            sleep 2
        done
    fi

    echo "Exit code: $ret"
    [[ $ret -ne 0 ]] && { echo -e "\e[31mDownload/conversion failed (exit $ret)\e[0m"; return $ret; }


    mkdir -p "$output_dir"
    for f in "$TMP_DIR"/*; do
        [[ -f "$f" ]] || continue
        fname=$(basename -- "$f")
        [[ "$(basename "$f")" == "$RAW_TXT" ]] && continue 

        sanitized=$(sanitize_filename "$fname")
        mv -- "$f" "$output_dir/$sanitized"

        filesize=$(du -h -- "$output_dir/$sanitized" | cut -f1)
        datetime=$(date "+%Y-%m-%d %H:%M:%S")
        icon=$([[ "$format_type" == "mp3" ]] && echo "🎵" || echo "🎬")

        echo -e "\e[0;33mFile saved to: \e[0;32m$output_dir/$sanitized\e[0m"
        echo -e "\e[0;33mSize: \e[0;32m$filesize\e[0m | \e[0;33mDate: \e[0;32m$datetime\e[0m"
        echo -e "\e[38;5;33m$icon Download completed successfully ✓\e[0m"

        save_download_info "$sanitized" "$video_url" "$format_type" "$output_dir/$sanitized"
    done

    return 0
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

        VIDEO_URLS=($(yt-dlp --flat-playlist --dump-single-json "$url" | jq -r '.entries[].url'))
        TOTAL=${#VIDEO_URLS[@]}

        if [[ "$mode" == "1" ]]; then
            choose_format "${VIDEO_URLS[0]}" "$PRESELECTED_FORMAT" "$OUTPUT_DIR"  "$MAX_RETRIES"
            local format_selected="$SELECTED_FORMAT_CODE"
            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\e[33mDownloading video $((i+1))/$TOTAL...\e[0m"
                choose_format "${VIDEO_URLS[$i]}" "$format_selected" "$OUTPUT_DIR"  "$MAX_RETRIES"
            done
        else
            for i in "${!VIDEO_URLS[@]}"; do
                echo -e "\e[33mDownloading video $((i+1))/$TOTAL...\e[0m"
                choose_format "${VIDEO_URLS[$i]}" "$PRESELECTED_FORMAT" "$OUTPUT_DIR"  "$MAX_RETRIES"
            done
        fi
    else
        choose_format "$url" "$PRESELECTED_FORMAT" "$OUTPUT_DIR" "$OUTPUT_NAME" "$MAX_RETRIES"
    fi

    cleanup
}

main "$@"

# Made by VexilonHacker https://github.com/VexilonHacker
