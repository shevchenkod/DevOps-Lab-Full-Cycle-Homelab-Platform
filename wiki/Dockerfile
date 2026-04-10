# ── Build stage ──────────────────────────────────────────────────────────────
FROM python:3.12-slim-bookworm AS builder

WORKDIR /wiki

# System libs required by cairosvg (social cards) + pillow
RUN apt-get update && apt-get install -y --no-install-recommends \
        libcairo2 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libgdk-pixbuf2.0-0 \
        libffi8 \
        git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy wiki source
COPY . .

# Build MkDocs static site
RUN mkdocs build --site-dir site

# ── Serve stage ───────────────────────────────────────────────────────────────
FROM nginx:alpine

RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /wiki/site/ /usr/share/nginx/html/

RUN printf 'server {\n\
    listen 80;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ $uri/index.html =404;\n\
    }\n\
    server_tokens off;\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
