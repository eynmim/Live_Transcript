"""Live Persian transcription with final accurate offline pass.

Flow:
  1. Record from default microphone (16 kHz mono) into a rolling WAV file.
  2. Every few seconds send the latest audio chunk to faster-whisper for a
     live terminal preview (not speaker-labeled — fast but rough).
  3. On Ctrl+C or Enter, stop recording and run the high-accuracy offline
     pipeline (faster-whisper large-v3 + pyannote 3.1) on the FULL WAV to
     produce the final speaker-labeled transcript.txt.

The live preview is only for real-time feedback — the final txt file is the
accurate output.
"""

from __future__ import annotations

import os
import queue
import signal
import sys
import threading
import time
from datetime import datetime
from pathlib import Path

import numpy as np
import sounddevice as sd
import soundfile as sf

from pipeline import (
    SAMPLE_RATE,
    load_diarizer,
    load_whisper,
    run_full_pipeline,
)

CHUNK_SECONDS = 6          # how many seconds of audio per live whisper call
OVERLAP_SECONDS = 1        # overlap between chunks to avoid cutting words
BLOCK_MS = 100             # mic callback block size

REC_DIR = Path(__file__).parent / "recordings"
REC_DIR.mkdir(exist_ok=True)


class MicRecorder:
    """Captures mic audio, writes to WAV, exposes chunks via a queue."""

    def __init__(self, wav_path: Path):
        self.wav_path = wav_path
        self._frames: list[np.ndarray] = []
        self._lock = threading.Lock()
        self._stream: sd.InputStream | None = None
        self._sf: sf.SoundFile | None = None
        self.running = False
        self.chunk_queue: queue.Queue[np.ndarray] = queue.Queue()
        self._emit_cursor = 0  # samples already emitted
        self._chunk_samples = int(CHUNK_SECONDS * SAMPLE_RATE)
        self._overlap_samples = int(OVERLAP_SECONDS * SAMPLE_RATE)

    def _callback(self, indata, frames, time_info, status):  # noqa: ARG002
        if status:
            print(f"[mic] warning: {status}", file=sys.stderr)
        mono = indata[:, 0].copy() if indata.ndim > 1 else indata.copy()
        with self._lock:
            self._frames.append(mono)
            if self._sf is not None:
                self._sf.write(mono)
            total = sum(len(f) for f in self._frames)
            # emit non-overlapping advancing windows, but keep an overlap tail
            while total - self._emit_cursor >= self._chunk_samples:
                buf = np.concatenate(self._frames)
                start = self._emit_cursor
                end = start + self._chunk_samples
                self.chunk_queue.put(buf[start:end].copy())
                self._emit_cursor = end - self._overlap_samples

    def start(self):
        self.running = True
        self._sf = sf.SoundFile(
            str(self.wav_path),
            mode="w",
            samplerate=SAMPLE_RATE,
            channels=1,
            subtype="PCM_16",
        )
        self._stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype="float32",
            blocksize=int(SAMPLE_RATE * BLOCK_MS / 1000),
            callback=self._callback,
        )
        self._stream.start()

    def stop(self):
        self.running = False
        if self._stream:
            self._stream.stop()
            self._stream.close()
            self._stream = None
        if self._sf:
            self._sf.close()
            self._sf = None
        self.chunk_queue.put(None)  # sentinel

    def elapsed_seconds(self) -> float:
        with self._lock:
            return sum(len(f) for f in self._frames) / SAMPLE_RATE


def live_preview_worker(recorder: MicRecorder, whisper_model):
    """Pulls chunks from the queue, runs whisper, prints to terminal."""
    print("\n--- live preview (rough, final accurate transcript written on stop) ---")
    while True:
        chunk = recorder.chunk_queue.get()
        if chunk is None:
            break
        # faster-whisper accepts a numpy float32 array at 16 kHz
        try:
            segments, _ = whisper_model.transcribe(
                chunk.astype(np.float32),
                language="fa",
                task="transcribe",
                beam_size=1,          # fast
                best_of=1,
                vad_filter=True,
                condition_on_previous_text=False,
                initial_prompt="این یک مکالمه فارسی است.",
            )
            text = " ".join(s.text.strip() for s in segments).strip()
            if text:
                ts = time.strftime("%H:%M:%S")
                print(f"[{ts}] {text}")
        except Exception as exc:  # keep the preview alive on errors
            print(f"[preview] error: {exc}", file=sys.stderr)


def main():
    print("=" * 70)
    print("Persian live transcriber — final accurate transcript on stop")
    print("=" * 70)
    print("Loading models (first run downloads ~3 GB, later runs are fast)...")

    whisper_model = load_whisper()
    # load diarizer up-front so we fail fast if HF token / terms are wrong
    diarizer = load_diarizer()

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    wav_path = REC_DIR / f"{stamp}.wav"
    txt_path = REC_DIR / f"{stamp}.txt"

    print(f"\nRecording to: {wav_path}")
    print("Press Ctrl+C (or close with Ctrl+C twice) to stop and generate transcript.")
    print()

    recorder = MicRecorder(wav_path)
    stop_flag = threading.Event()

    def _sigint(signum, frame):  # noqa: ARG001
        if stop_flag.is_set():
            print("\nforce exit.")
            os._exit(1)
        stop_flag.set()
        print("\n[main] stopping — wait for final accurate pass...")

    signal.signal(signal.SIGINT, _sigint)

    recorder.start()
    preview_thread = threading.Thread(
        target=live_preview_worker,
        args=(recorder, whisper_model),
        daemon=True,
    )
    preview_thread.start()

    try:
        t0 = time.time()
        while not stop_flag.is_set():
            time.sleep(0.5)
            # light heartbeat on the same line
            secs = int(time.time() - t0)
            mm, ss = divmod(secs, 60)
            sys.stdout.write(f"\r[recording] {mm:02d}:{ss:02d}   ")
            sys.stdout.flush()
    finally:
        recorder.stop()
        preview_thread.join(timeout=5)
        print()

    duration = recorder.elapsed_seconds()
    if duration < 1.5:
        print(f"recording too short ({duration:.1f}s) — skipping transcript.")
        return

    print(f"\n[main] recorded {duration:.1f}s. Running accurate offline pass...")
    print("    (transcription is ~5-10x realtime on the RTX 4070)")
    run_full_pipeline(
        wav_path=wav_path,
        out_path=txt_path,
        num_speakers=2,
        whisper_model=whisper_model,
        diar_pipe=diarizer,
    )
    print(f"\nDone. Final transcript: {txt_path}")


if __name__ == "__main__":
    main()
