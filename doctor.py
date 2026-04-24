"""Environment sanity check. Run after install to confirm everything works."""

import os
import sys


def ok(msg: str) -> None:
    print(f"  [ OK ] {msg}")


def fail(msg: str) -> None:
    print(f"  [FAIL] {msg}")


def main() -> int:
    rc = 0
    print(f"python: {sys.version.split()[0]}  ({sys.executable})")

    try:
        import torch
        ok(f"torch {torch.__version__}")
        if torch.cuda.is_available():
            ok(f"CUDA available: {torch.cuda.get_device_name(0)}")
            vram = torch.cuda.get_device_properties(0).total_memory / (1024**3)
            ok(f"VRAM: {vram:.1f} GB")
        else:
            fail("CUDA not available — transcription will run on CPU (slow)")
            rc = 1
    except Exception as e:
        fail(f"torch: {e}")
        return 1

    try:
        import faster_whisper  # noqa: F401
        ok(f"faster-whisper {faster_whisper.__version__}")
    except Exception as e:
        fail(f"faster-whisper: {e}")
        rc = 1

    try:
        import pyannote.audio  # noqa: F401
        ok("pyannote.audio imported")
    except Exception as e:
        fail(f"pyannote.audio: {e}")
        rc = 1

    try:
        import sounddevice as sd
        devs = sd.query_devices()
        inputs = [d for d in devs if d["max_input_channels"] > 0]
        ok(f"sounddevice: {len(inputs)} input device(s)")
        default_in = sd.default.device[0]
        if default_in is not None and default_in >= 0:
            ok(f"default input: {devs[default_in]['name']}")
    except Exception as e:
        fail(f"sounddevice: {e}")
        rc = 1

    try:
        import soundfile  # noqa: F401
        ok(f"soundfile {soundfile.__version__}")
    except Exception as e:
        fail(f"soundfile: {e}")
        rc = 1

    try:
        from dotenv import load_dotenv
        load_dotenv()
        if os.getenv("HF_TOKEN"):
            ok("HF_TOKEN loaded from .env")
        else:
            fail("HF_TOKEN not found in .env")
            rc = 1
    except Exception as e:
        fail(f"dotenv: {e}")
        rc = 1

    print()
    print("All checks passed." if rc == 0 else "Some checks failed — see above.")
    return rc


if __name__ == "__main__":
    sys.exit(main())
