#!/usr/bin/env bash

DIR="${1:-.}"

mkdir -p "$DIR/images" "$DIR/audio" "$DIR/videos" "$DIR/documents"

find "$DIR" -type f -print0 |
    while IFS= read -r -d '' file; do
        # Don't process files already inside our destination folders
        case "$file" in
        "$DIR/images/"* | "$DIR/audio/"* | "$DIR/videos/"* | "$DIR/documents/"*)
            continue
            ;;
        esac

        ext="${file##*.}"
        ext="${ext,,}"

        case "$ext" in
        jpg | jpeg | png | gif | webp | bmp | tiff | tif | heic | heif | raw | dng)
            dest="$DIR/images"
            ;;
        mp3 | wav | flac | m4a | aac | ogg | opus | wma)
            dest="$DIR/audio"
            ;;
        mp4 | mkv | avi | mov | webm | wmv | flv | m4v | 3gp)
            dest="$DIR/videos"
            ;;
        pdf | doc | docx | odt | txt | rtf | xls | xlsx | ods | ppt | pptx | odp | csv)
            dest="$DIR/documents"
            ;;
        *)
            continue
            ;;
        esac

        echo "Moving: $file"
        mv -- "$file" "$dest/"
    done

echo "Done."
