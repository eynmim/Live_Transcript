"""Offline Persian transcription for an existing audio file.

Usage:
    python transcribe_file.py path/to/audio.wav
    python transcribe_file.py path/to/audio.mp3 --speakers 2
    python transcribe_file.py path/to/audio.m4a --out custom_name.txt
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from pipeline import run_full_pipeline


def main():
    ap = argparse.ArgumentParser(description="Persian transcription + diarization")
    ap.add_argument("audio", help="input audio file (wav/mp3/m4a/flac/ogg)")
    ap.add_argument("--speakers", type=int, default=2, help="known speaker count (0 = auto)")
    ap.add_argument("--out", help="output txt path (default: <audio>.txt next to input)")
    args = ap.parse_args()

    audio_path = Path(args.audio).resolve()
    if not audio_path.exists():
        print(f"error: {audio_path} does not exist", file=sys.stderr)
        sys.exit(1)

    out_path = Path(args.out).resolve() if args.out else audio_path.with_suffix(".txt")
    num_speakers = args.speakers if args.speakers > 0 else None

    run_full_pipeline(
        wav_path=audio_path,
        out_path=out_path,
        num_speakers=num_speakers,
    )


if __name__ == "__main__":
    main()
