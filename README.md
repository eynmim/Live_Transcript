# Persian Real-time Transcriber + Speaker Diarization

Offline, free, GPU-accelerated Persian speech-to-text with automatic
Speaker 1 / Speaker 2 labeling. Produces a `.txt` file.

## Requirements

- Windows with NVIDIA GPU (tested on RTX 4070 Laptop, 8 GB VRAM)
- Python 3.11 (installed via `uv`)
- A free HuggingFace token saved in `.env` (`HF_TOKEN=hf_xxx`)
- Terms accepted on:
  - https://huggingface.co/pyannote/speaker-diarization-3.1
  - https://huggingface.co/pyannote/segmentation-3.0

## One-time setup

```bash
# from F:\Transcript_Proj
python -m uv venv --python 3.11
.venv\Scripts\activate
python -m uv pip install torch==2.5.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu121
python -m uv pip install -r requirements.txt
```

First run downloads ~3 GB of models (whisper large-v3 + pyannote). Cached afterwards.

## Usage

### Live mode (record from mic + final accurate transcript)
```bash
.venv\Scripts\activate
python live_transcribe.py
```

- Shows rough live preview in the terminal as you speak.
- Press **Ctrl+C** to stop → runs accurate offline pass → writes `recordings/YYYYMMDD_HHMMSS.txt`.

### Offline mode (transcribe an existing file)
```bash
python transcribe_file.py path\to\meeting.wav
python transcribe_file.py path\to\meeting.mp3 --speakers 2
python transcribe_file.py path\to\meeting.m4a --out my_transcript.txt
```

## Notes on accuracy

- Live preview uses `beam_size=1` (fast, rough). **Do not trust it.**
- Final transcript uses `beam_size=5`, `best_of=5`, VAD filtering, Persian-biased
  initial prompt, word-level timestamps — this is the accurate output.
- Diarization uses pyannote 3.1 with `num_speakers=2` (set in `live_transcribe.py`).
  If you have more than 2 speakers, edit that call.

## Output format

```
[00:00:03 - 00:00:08] Speaker 1: سلام چطوری
[00:00:09 - 00:00:14] Speaker 2: ممنون خوبم تو چطوری
```
