#!/usr/bin/env bash
# mov2mp4: convert any video to H.264/AAC-MP4

if [[ $# -ne 2 ]]; then
  echo "Usage: mov2mp4 <input_file> <output_file.mp4>"
  exit 1
fi

in="$1"
out="$2"

ffmpeg -i "$in" \
       -c:v libx264 -crf 23 -preset medium \
       -c:a aac -b:a 192k \
       "$out"