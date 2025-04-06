#!/bin/bash

# Check if the user provided a folder path
if [ -z "$1" ]; then
  echo "Usage: ./fix_audio.sh /path/to/folder"
  exit 1
fi

# Input and output folders
INPUT_FOLDER="$1"
OUTPUT_FOLDER="${INPUT_FOLDER}/fixed_audio"

# Create output folder if it doesn't exist
mkdir -p "$OUTPUT_FOLDER"

# Process .wav files
for file in "$INPUT_FOLDER"/*.wav; do
  if [ -f "$file" ]; then
    echo "Processing WAV: $file"
    ffmpeg -i "$file" -ar 44100 -ac 2 -acodec pcm_s16le "$OUTPUT_FOLDER/$(basename "$file")"
  fi
done

# Process .flac files
for file in "$INPUT_FOLDER"/*.flac; do
  if [ -f "$file" ]; then
    echo "Processing FLAC: $file"
    output_name="$(basename "$file" .flac).wav" # Convert .flac to .wav
    ffmpeg -i "$file" -ar 44100 -ac 2 -acodec pcm_s16le "$OUTPUT_FOLDER/$output_name"
  fi
done

echo "Processing complete! Fixed files are in: $OUTPUT_FOLDER"