# Useful Script

Small utility scripts for common operational tasks.

## Installation

Install the AWS CLI and Python 3, then make the scripts executable:

```bash
chmod +x upload-s3.sh;
chmod +x fetch-s3.sh;
chmod +x llm-launch.sh;
chmod +x run-acme-cf.sh;
chmod +x start-tmux-windows.sh;
```

Copy `upload-s3.conf` and fill in your S3-compatible endpoint, access key, secret key, bucket, and region.

## Environment Configuration

Credentials can be provided through `upload-s3.conf` or CLI arguments. The scripts export them as AWS CLI environment variables for S3 commands:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`

Do not hardcode real credentials in committed config files.

`llm-launch.sh` expects `llama-server` to be available on `PATH` and reads API keys from `${HOME}/.llm_api_key`.

`run-acme-cf.sh` sources `.env` from the current directory. Configure Cloudflare DNS credentials for `acme.sh`, plus a Bash array of domains:

```bash
CF_Token="cloudflare-api-token";
DOMAINS=("example.com" "*.example.com");
CERT_HOME="${HOME}/.acme.sh";
```

`start-tmux-windows.sh` expects `tmux` to be installed locally.

## Features

- Sync a local directory to an S3-compatible bucket.
- Configure endpoint, bucket, credentials, and region through a config file or CLI arguments.
- Use predefined upload presets with `--preset image` or `--preset video`.
- Add repeatable custom AWS sync filters with `--include` and `--exclude`.
- Run unfiltered syncs by omitting preset and custom filters.
- List S3 objects with optional prefix filtering and object size, capped to 50 objects by default.
- Download all objects under an S3 prefix.
- Generate presigned URLs for full object keys.
- Launch `llama-server` with model aliases, computed context size, concurrency, and optional multimodal settings.
- Issue and install Cloudflare DNS certificates for one or more configured domains.
- Start a tmux session with named windows and optional side-by-side panes from a command file.

## Usage

### upload-s3

Syncs local files to an S3-compatible bucket using config-driven endpoint, credentials, bucket, region, presets, and filters.

Sync all files from a directory:

```bash
./upload-s3.sh --config upload-s3.conf --path ./assets;
```

Sync common image files:

```bash
./upload-s3.sh --config upload-s3.conf --path ./assets --preset image;
```

Sync common video files and exclude drafts:

```bash
./upload-s3.sh --config upload-s3.conf --path ./assets --preset video --exclude "drafts/*";
```

Use custom filters only:

```bash
./upload-s3.sh --config upload-s3.conf --path ./assets --exclude "*" --include "*.pdf";
```

Config files can also include filters:

```conf
preset = image
include = *.avif
exclude = raw/*
```

### fetch-s3

Lists, downloads, and creates presigned URLs for objects in an S3-compatible bucket.

List object names and sizes:

```bash
./fetch-s3.sh list --config upload-s3.conf;
```

List object names and sizes by prefix:

```bash
./fetch-s3.sh list --config upload-s3.conf --prefix assets/;
```

List object tags when available:

```bash
./fetch-s3.sh list --config upload-s3.conf --prefix assets/ --object-tag;
```

List up to 10 objects:

```bash
./fetch-s3.sh list --config upload-s3.conf --prefix assets/ --max-items 10;
```

List objects as JSON:

```bash
./fetch-s3.sh list --config upload-s3.conf --prefix assets/ --format json;
```

Download all objects under a prefix:

```bash
./fetch-s3.sh download --config upload-s3.conf --prefix assets/ --destination ./downloads;
```

Generate a presigned URL for a full object key:

```bash
./fetch-s3.sh url --config upload-s3.conf --key assets/example.jpg --expires-in 3600;
```

### start-tmux-windows

Starts a tmux session from a command file. Each non-comment line creates one window, an optional `[Window Name]` prefix sets the display name, and ` ::: ` splits multiple commands into side-by-side panes.

Example command file:

```text
# System dashboard
[glances] glances
[logs] tail -f /var/log/system.log ::: htop
[shell]
```

Start the tmux session:

```bash
./start-tmux-windows.sh start-tmux-windows.conf.example;
```

The generated session name is based on the command file name. If that session already exists, the script replaces it before attaching.

### llm-launch

Launches `llama-server` for a local model with metrics, API key loading, GPU layers, continuous batching, and computed total context size. The final context size is `--context-size` multiplied by `--max-user`.

Basic launch:

```bash
./llm-launch.sh /models/qwen3.gguf --alias qwen3 --context-size 8192 --max-user 8;
```

Launch with speculative MTP decoding, reasoning disabled, and extra `llama-server` arguments passed through:

```bash
./llm-launch.sh /models/qwen3.gguf --alias qwen3 --use-mtp --nothink --host 0.0.0.0 --port 8080;
```

Launch a multimodal model. The script looks for the first `*mmproj-*.gguf` file in the model file's parent directory:

```bash
./llm-launch.sh /models/vision-model.gguf --alias vision --multimodel;
```

Common options:

- `--alias <name>`: Sets the served model alias.
- `--context-size <N>`: Sets per-user context size before multiplication by `--max-user`.
- `--max-user <N>`: Sets `llama-server --parallel` and contributes to total context size.
- `--use-mtp`: Enables draft MTP speculative decoding.
- `--nothink`: Adds `--reasoning off`.
- `--embeddings`: Enables the script's embeddings option name as implemented.
- `--multimodel`: Adds a matching multimodal projection file when present.
- `--use-ssl`: Adds certificate and key paths from `~/certs/fullchain.pem` and `~/certs/privkey.pem`.

### run-acme-cf.sh

Issues and installs certificates with `acme.sh` using Cloudflare DNS validation for each domain listed in `DOMAINS`. Installed certificate files are written under a directory named after each domain.

Example `.env`:

```bash
CF_Token="cloudflare-api-token";
DOMAINS=("example.com" "*.example.com");
CERT_HOME="${HOME}/.acme.sh";
```

Issue and install certificates:

```bash
./run-acme-cf.sh;
```

For `example.com`, the installed files are:

```text
example.com/fullchain.pem
example.com/privkey.pem
```

### cloudflare-ddns

Dynamically update the DNS entries under Cloudflare.

Usage:

```bash
cloudflare-ddns.sh --env-file /path/to/env/file
```

To update DNS on public IP changes, install `networkd-dispatcher`, then copy `cloudflare-ddns-hook` to `/etc/networkd-dispatcher/configured.d`

## License

GPLv3
