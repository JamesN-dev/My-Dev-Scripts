#!/usr/bin/env python3
import argparse
import requests
import sys
import os
import base64

# Replace with your actual Mistral API key
API_KEY = "YOUR_MISTRAL_API_KEY"

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Transcribe audio files using Mistral API')
    parser.add_argument('file_path', help='Path to the audio file to transcribe')
    parser.add_argument('--api-key', help='Mistral API key (overrides hardcoded key)')
    parser.add_argument('--model', default='voxtral-mini-latest', help='Model to use (default: voxtral-mini-latest)')
    parser.add_argument('--language', default='en', help='Language code (default: en)')
    parser.add_argument('--timestamps', action='store_true', help='Include timestamps in transcription')

    args = parser.parse_args()

    # Use provided API key, fallback to hardcoded, or ask for it
    api_key = args.api_key or API_KEY
    if not api_key or api_key == "YOUR_MISTRAL_API_KEY":
        api_key = input("Enter your Mistral API key: ").strip()
        if not api_key:
            print("Error: API key is required")
            sys.exit(1)

    # Check if file exists
    if not os.path.exists(args.file_path):
        print(f"Error: File '{args.file_path}' not found")
        sys.exit(1)

    try:
        print(f"Transcribing '{args.file_path}'...")

        # Prepare API request
        url = "https://api.mistral.ai/v1/audio/transcriptions"
        headers = {
            "Authorization": f"Bearer {api_key}",
        }

        # Prepare files for upload
        files = {
            "file": (os.path.basename(args.file_path), open(args.file_path, "rb"), "audio/mpeg"),
            "model": (None, args.model),
            "language": (None, args.language),
        }

        # Add timestamps if requested
        if args.timestamps:
            files["timestamp_granularities"] = (None, "segment")

        # Make the API request
        response = requests.post(url, headers=headers, files=files)
        response.raise_for_status()

        result = response.json()

        print("\nTranscription:")
        if args.timestamps and "segments" in result:
            # Print with timestamps
            for segment in result["segments"]:
                start_time = segment.get("start", "N/A")
                end_time = segment.get("end", "N/A")
                text = segment.get("text", "")
                print(f"[{start_time}s - {end_time}s]: {text}")
        else:
            # Print just the text
            print(result.get("text", "No transcription found"))

    except requests.exceptions.RequestException as e:
        print(f"Error making API request: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}")
        sys.exit(1)
    except Exception as e:
        print(f"Error during transcription: {e}")
        sys.exit(1)
    finally:
        # Close the file if it was opened
        try:
            files["file"][1].close()
        except:
            pass

if __name__ == "__main__":
    main()
