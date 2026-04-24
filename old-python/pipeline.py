"""Offline Persian transcription + speaker diarization pipeline.

Uses faster-whisper large-v3 for transcription and pyannote/speaker-diarization-3.1
for diarization, then merges them into speaker-labeled Persian text.
"""

from __future__ import annotations

import gc
import os
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable

import torch
from dotenv import load_dotenv
from faster_whisper import WhisperModel
from pyannote.audio import Pipeline as PyannotePipeline

load_dotenv()

WHISPER_MODEL_SIZE = "large-v3"
COMPUTE_TYPE = "float16"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
SAMPLE_RATE = 16000


@dataclass
class WordHit:
    start: float
    end: float
    text: str


@dataclass
class SpeakerTurn:
    start: float
    end: float
    speaker: str
    text: str


def _format_ts(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def load_whisper(model_size: str = WHISPER_MODEL_SIZE) -> WhisperModel:
    print(f"[pipeline] loading faster-whisper {model_size} on {DEVICE} ({COMPUTE_TYPE})...")
    compute = COMPUTE_TYPE if DEVICE == "cuda" else "int8"
    return WhisperModel(model_size, device=DEVICE, compute_type=compute)


def load_diarizer() -> PyannotePipeline:
    token = os.getenv("HF_TOKEN")
    if not token:
        raise RuntimeError("HF_TOKEN missing. Put it in .env as HF_TOKEN=hf_xxx")
    print("[pipeline] loading pyannote speaker-diarization-3.1...")
    pipe = PyannotePipeline.from_pretrained(
        "pyannote/speaker-diarization-3.1",
        use_auth_token=token,
    )
    if DEVICE == "cuda":
        pipe.to(torch.device("cuda"))
    return pipe


def transcribe_words(
    wav_path: Path,
    model: WhisperModel,
    initial_prompt: str | None = None,
) -> list[WordHit]:
    """Accuracy-focused Persian transcription. Returns word-level timestamps."""
    # Persian-biasing initial prompt helps disambiguate numbers, names, English loanwords.
    prompt = initial_prompt or (
        "این یک مکالمه به زبان فارسی است. لطفاً با دقت و بدون اشتباه متن را بنویسید."
    )
    segments, info = model.transcribe(
        str(wav_path),
        language="fa",
        task="transcribe",
        beam_size=5,
        best_of=5,
        temperature=[0.0, 0.2, 0.4, 0.6],
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 500},
        word_timestamps=True,
        condition_on_previous_text=True,
        initial_prompt=prompt,
        no_speech_threshold=0.6,
        compression_ratio_threshold=2.4,
        log_prob_threshold=-1.0,
    )
    words: list[WordHit] = []
    for seg in segments:
        if seg.words:
            for w in seg.words:
                txt = (w.word or "").strip()
                if txt:
                    words.append(WordHit(start=w.start, end=w.end, text=txt))
        else:
            words.append(WordHit(start=seg.start, end=seg.end, text=seg.text.strip()))
    print(f"[pipeline] transcribed {len(words)} word units ({info.duration:.1f}s audio)")
    return words


def diarize(
    wav_path: Path,
    pipe: PyannotePipeline,
    num_speakers: int | None = 2,
) -> list[tuple[float, float, str]]:
    """Returns [(start, end, speaker_id), ...]. Pass num_speakers if known."""
    kwargs = {}
    if num_speakers is not None:
        kwargs["num_speakers"] = num_speakers
    diar = pipe(str(wav_path), **kwargs)
    segs = [(t.start, t.end, spk) for t, _, spk in diar.itertracks(yield_label=True)]
    segs.sort(key=lambda x: x[0])
    print(f"[pipeline] diarized into {len(segs)} speaker segments")
    return segs


def _speaker_for_time(
    t: float,
    diar_segs: list[tuple[float, float, str]],
) -> str | None:
    """Find which diarization segment contains time t (binary-search-ish)."""
    best = None
    best_dist = float("inf")
    for s, e, spk in diar_segs:
        if s <= t <= e:
            return spk
        # track nearest segment in case the word falls in a small gap
        d = min(abs(t - s), abs(t - e))
        if d < best_dist:
            best_dist = d
            best = spk
    # only fall back to nearest if reasonably close (< 1 sec)
    return best if best_dist < 1.0 else None


def merge_words_to_turns(
    words: list[WordHit],
    diar_segs: list[tuple[float, float, str]],
) -> list[SpeakerTurn]:
    """Assign a speaker to each word, then group consecutive same-speaker words."""
    if not words:
        return []
    # map raw pyannote IDs (SPEAKER_00, SPEAKER_01) to stable "Speaker 1", "Speaker 2"
    speaker_map: dict[str, str] = {}

    def label(spk: str | None) -> str:
        if spk is None:
            return "Speaker ?"
        if spk not in speaker_map:
            speaker_map[spk] = f"Speaker {len(speaker_map) + 1}"
        return speaker_map[spk]

    turns: list[SpeakerTurn] = []
    cur: SpeakerTurn | None = None
    for w in words:
        mid = (w.start + w.end) / 2.0
        spk = label(_speaker_for_time(mid, diar_segs))
        if cur is None or spk != cur.speaker:
            if cur:
                turns.append(cur)
            cur = SpeakerTurn(start=w.start, end=w.end, speaker=spk, text=w.text)
        else:
            cur.end = w.end
            # persian uses spaces between words; whisper word tokens may include leading space
            cur.text = (cur.text + " " + w.text).strip()
    if cur:
        turns.append(cur)
    return turns


def write_transcript(turns: list[SpeakerTurn], out_path: Path) -> None:
    lines = ["# Transcript", f"# generated: {datetime.now().isoformat(timespec='seconds')}", ""]
    for t in turns:
        lines.append(f"[{_format_ts(t.start)} - {_format_ts(t.end)}] {t.speaker}: {t.text}")
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[pipeline] wrote {out_path}")


def run_full_pipeline(
    wav_path: Path,
    out_path: Path | None = None,
    num_speakers: int | None = 2,
    whisper_model: WhisperModel | None = None,
    diar_pipe: PyannotePipeline | None = None,
) -> Path:
    """Full offline pipeline: transcribe + diarize + merge + write txt."""
    wav_path = Path(wav_path)
    if not wav_path.exists():
        raise FileNotFoundError(wav_path)
    out_path = out_path or wav_path.with_suffix(".txt")

    owns_whisper = whisper_model is None
    owns_diar = diar_pipe is None
    try:
        whisper_model = whisper_model or load_whisper()
        diar_pipe = diar_pipe or load_diarizer()

        print(f"[pipeline] pass 1/2: transcribing {wav_path.name}...")
        words = transcribe_words(wav_path, whisper_model)

        print(f"[pipeline] pass 2/2: diarizing {wav_path.name}...")
        diar_segs = diarize(wav_path, diar_pipe, num_speakers=num_speakers)

        turns = merge_words_to_turns(words, diar_segs)
        write_transcript(turns, out_path)
        return out_path
    finally:
        if owns_whisper and whisper_model is not None:
            del whisper_model
        if owns_diar and diar_pipe is not None:
            del diar_pipe
        gc.collect()
        if DEVICE == "cuda":
            torch.cuda.empty_cache()
