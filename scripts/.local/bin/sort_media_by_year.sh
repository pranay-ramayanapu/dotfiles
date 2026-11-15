#!/usr/bin/env bash
#
# sort_media_by_year.sh
#
# Sorts image and video files that sit directly inside a given folder into
# Year/ subfolders of that same folder, based on:
#
#   1. Filename   - the first occurrence of 4 consecutive digits in the
#                   filename, if it falls within MIN_YEAR..MAX_YEAR. Wins
#                   outright when valid - metadata/filesystem aren't
#                   consulted.
#   2. Everything else, oldest wins - if the filename doesn't yield a valid
#                   year, every time-related date exiftool can find for the
#                   file is gathered in one sweep: embedded metadata (EXIF
#                   Date/Time Original, CreateDate, video Media/Track
#                   create dates, ...) AND the file's own filesystem dates
#                   (modified, accessed, inode-change, and birth time where
#                   the OS exposes it). Whichever of those is the OLDEST
#                   valid year is used - a file's true date is more often
#                   the earliest timestamp found anywhere on it than any
#                   single field, since copying/syncing/re-encoding a file
#                   pushes later dates forward but rarely rewrites the
#                   original capture time.
#   3. Unknown/   - if none of the above yields a valid year.
#
# Usage:
#   ./sort_media_by_year.sh [--dry-run] <source_folder>
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
readonly MIN_YEAR=2005
readonly MAX_YEAR=2027

# Extensions handled (case-insensitive), without the leading dot.
readonly IMAGE_EXTS=(jpg jpeg png heic webp dng gif)
readonly VIDEO_EXTS=(mp4 mov mkv avi webm 3gp)
readonly ALL_EXTS=("${IMAGE_EXTS[@]}" "${VIDEO_EXTS[@]}")

DRY_RUN=0
SRC_DIR=""
TOTAL=0
declare -A COUNTS=()
declare -A PLANNED_DESTS=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [--dry-run] <source_folder>

Sorts image/video files that sit directly inside <source_folder> into
Year/ subfolders (named ${MIN_YEAR}..${MAX_YEAR}) or Unknown/. If the
filename yields a valid year, it wins outright. Otherwise every
metadata/filesystem date exiftool can find for the file (Date/Time
Original, CreateDate, modified, accessed, inode-change, birth, ...) is
gathered and the OLDEST valid one is used. Existing year/Unknown
subfolders are never re-scanned.

Options:
  --dry-run   Show what would be moved, without moving or creating anything.
  -h, --help  Show this help.
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

is_valid_year() {
    local y="$1"
    if [[ "$y" =~ ^[0-9]{4}$ ]] && ((y >= MIN_YEAR)) && ((y <= MAX_YEAR)); then
        return 0
    fi
    return 1
}

# Extract a candidate year from a filename: the FIRST occurrence of 4
# consecutive digits, accepted only if it's within range. Per spec, if that
# first match is out of range we do not keep scanning for another one - we
# just fall through to metadata (e.g. "photo_172024.jpg" -> "1720" -> reject,
# never considering the "2024" hiding inside the same digit run).
year_from_filename() {
    local filename="$1" candidate

    candidate=$(grep -oP '\d{4}' <<<"$filename" | head -n 1) || true

    if [[ -n "$candidate" ]] && is_valid_year "$candidate"; then
        echo "$candidate"
        return 0
    fi
    return 1
}

# Gather every plausible year for a file from a single exiftool sweep of
# ALL time-related tags (-time:all) - this covers embedded metadata such as
# Date/Time Original, CreateDate, and video Media/Track create dates, AND
# the file's own filesystem dates (modified, accessed, inode-change) in one
# call, whichever of those exist for that particular file. Birth time is
# added separately via stat, since exiftool doesn't expose it on every
# OS/filesystem. Returns the OLDEST valid year found across all of them.
year_from_metadata_and_fs() {
    local file="$1" line birth_epoch year
    local -a candidates=()

    while IFS= read -r line; do
        if [[ -n "$line" ]] && is_valid_year "$line"; then
            candidates+=("$line")
        fi
    done < <(exiftool -time:all -s3 -d '%Y' -- "$file" 2>/dev/null)

    birth_epoch=$(stat -c '%W' -- "$file" 2>/dev/null) || true
    if [[ -n "${birth_epoch:-}" && "$birth_epoch" != "0" ]]; then
        year=$(date -d "@${birth_epoch}" +%Y 2>/dev/null) || true
        [[ -n "$year" ]] && is_valid_year "$year" && candidates+=("$year")
    fi

    [[ ${#candidates[@]} -eq 0 ]] && return 1

    printf '%s\n' "${candidates[@]}" | sort -n | head -n 1
    return 0
}

# Given a target directory and a desired filename, return a collision-free
# destination path (never overwrites an existing file, and never collides
# with another file already planned to move there earlier in this run -
# this keeps --dry-run previews accurate even though nothing is written to
# disk yet).
resolve_collision() {
    local dest_dir="$1" base="$2"
    local name ext candidate counter=1

    if [[ "$base" == *.* ]]; then
        name="${base%.*}"
        ext="${base##*.}"
    else
        name="$base"
        ext=""
    fi

    candidate="$dest_dir/$base"
    while [[ -e "$candidate" || -n "${PLANNED_DESTS[$candidate]+x}" ]]; do
        if [[ -n "$ext" ]]; then
            candidate="$dest_dir/${name}_${counter}.${ext}"
        else
            candidate="$dest_dir/${name}_${counter}"
        fi
        counter=$((counter + 1))
    done
    PLANNED_DESTS["$candidate"]=1
    echo "$candidate"
}

# Print the move (source -> destination) and, unless --dry-run, perform it.
move_file() {
    local src="$1" dest_dir="$2" category="$3"
    local base final_dest

    base=$(basename -- "$src")
    final_dest=$(resolve_collision "$dest_dir" "$base")

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[DRY RUN] '$src' -> '$final_dest'"
    else
        mkdir -p -- "$dest_dir"
        mv -n -- "$src" "$final_dest"
        echo "'$src' -> '$final_dest'"
    fi

    COUNTS["$category"]=$((${COUNTS["$category"]:-0} + 1))
    TOTAL=$((TOTAL + 1))
}

process_file() {
    local file="$1" year

    if year=$(year_from_filename "$(basename -- "$file")"); then
        move_file "$file" "$SRC_DIR/$year" "$year"
        return
    fi

    if year=$(year_from_metadata_and_fs "$file"); then
        move_file "$file" "$SRC_DIR/$year" "$year"
        return
    fi

    move_file "$file" "$SRC_DIR/Unknown" "Unknown"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
    --dry-run)
        DRY_RUN=1
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    -*)
        die "Unknown option: $1 (see --help)"
        ;;
    *)
        if [[ -n "$SRC_DIR" ]]; then
            die "Unexpected extra argument: $1"
        fi
        SRC_DIR="$1"
        shift
        ;;
    esac
done

[[ -n "$SRC_DIR" ]] || {
    usage
    exit 1
}
[[ -d "$SRC_DIR" ]] || die "'$SRC_DIR' is not a directory"
command -v exiftool >/dev/null 2>&1 || die "exiftool is required but not installed. On Fedora: sudo dnf install perl-Image-ExifTool"

# Strip a trailing slash for cleaner output paths.
SRC_DIR="${SRC_DIR%/}"
[[ -n "$SRC_DIR" ]] || SRC_DIR="/"

# ---------------------------------------------------------------------------
# Main: only files directly inside SRC_DIR (maxdepth 1) - never descends
# into already-created Year/ or Unknown/ subfolders, so the script is safe
# to re-run.
# ---------------------------------------------------------------------------
find_expr=()
first=1
for ext in "${ALL_EXTS[@]}"; do
    if [[ $first -eq 1 ]]; then
        first=0
    else
        find_expr+=(-o)
    fi
    find_expr+=(-iname "*.${ext}")
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry run - no files will be moved or folders created."
fi
echo "Scanning '$SRC_DIR' ..."
echo

while IFS= read -r -d '' file; do
    process_file "$file"
done < <(find "$SRC_DIR" -type f \( "${find_expr[@]}" \) -print0)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
if [[ "$TOTAL" -eq 0 ]]; then
    echo "No matching image/video files found directly inside '$SRC_DIR'."
    exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry run complete. $TOTAL file(s) would be sorted:"
else
    echo "Done. $TOTAL file(s) sorted:"
fi
for category in "${!COUNTS[@]}"; do
    printf '  %s: %d\n' "$category" "${COUNTS[$category]}"
done | sort
