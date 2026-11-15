mkdir -p ~/D-Drive/media-import/phone

find . -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.jpe' -o -iname '*.jfif' \
    -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.avif' \
    -o -iname '*.heic' -o -iname '*.heif' -o -iname '*.heics' -o -iname '*.heifs' \
    -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' -o -iname '*.ico' \
    -o -iname '*.raw' -o -iname '*.dng' -o -iname '*.cr2' -o -iname '*.cr3' \
    -o -iname '*.nef' -o -iname '*.nrw' -o -iname '*.arw' -o -iname '*.orf' \
    -o -iname '*.rw2' -o -iname '*.raf' -o -iname '*.pef' -o -iname '*.srw' \
    -o -iname '*.3fr' -o -iname '*.iiq' -o -iname '*.rwl' \
    -o -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.mkv' \
    -o -iname '*.avi' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' \
    -o -iname '*.3gp' -o -iname '*.3g2' -o -iname '*.mts' -o -iname '*.m2ts' \
    -o -iname '*.ts' -o -iname '*.mpg' -o -iname '*.mpeg' -o -iname '*.mpe' \
    -o -iname '*.mxf' -o -iname '*.vob' -o -iname '*.ogv' -o -iname '*.asf' \
    \) -exec bash -c '
for f do
    name=$(basename "$f")
    dest="$HOME/D-Drive/media-import/phone/$name"

    if [[ -e "$dest" ]]; then
        n=1
        ext="${name##*.}"
        base="${name%.*}"
        while [[ -e "$HOME/D-Drive/media-import/phone/${base}_$n.$ext" ]]; do
            ((n++))
        done
        dest="$HOME/D-Drive/media-import/phone/${base}_$n.$ext"
    fi

    cp "$f" "$dest"
done
' bash {} +
