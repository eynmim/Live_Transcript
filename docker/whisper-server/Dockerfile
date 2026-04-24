# Optional STT server — for users who want to offload whisper.cpp to a home server / GPU box.
# Default app path uses the bundled whisper.cpp in OpenWhispr; this is purely opt-in.

FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch v1.7.2 https://github.com/ggerganov/whisper.cpp.git .
RUN cmake -B build -DWHISPER_BUILD_SERVER=ON && \
    cmake --build build --config Release -j$(nproc)

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /src/build/bin/whisper-server /usr/local/bin/whisper-server

ENV WHISPER_MODEL=/models/ggml-base.en.bin
EXPOSE 9000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD curl -fsS http://localhost:9000/health || exit 1

ENTRYPOINT ["/bin/sh", "-c", "whisper-server --host 0.0.0.0 --port 9000 --model $WHISPER_MODEL"]
