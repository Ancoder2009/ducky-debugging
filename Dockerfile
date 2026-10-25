FROM ubuntu:22.04 AS builder

ENV GODOT_VERSION=4.7.2
ENV DOWNLOAD_URL=https://github.com{GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip
ENV TEMPLATES_URL=https://github.com{GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN wget ${DOWNLOAD_URL} && unzip *.zip && mv Godot_* /usr/local/bin/godot && rm *.zip
RUN wget ${TEMPLATES_URL} && unzip *.tpz && mkdir -p ~/.local/share/godot/export_templates/${GODOT_VERSION}.stable && cp -r templates/* ~/.local/share/godot/export_templates/${GODOT_VERSION}.stable/ && rm -rf templates *.tpz

COPY . .

RUN mkdir -p dist/ \
    && godot --headless --export-release "Linux" dist/game.x86_64

# Runtime Environment
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/dist/ .

EXPOSE 8000

# Run the server in headless mode
ENTRYPOINT ["./game.x86_64", "--headless"]
