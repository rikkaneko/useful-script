# Useful Script

My collections of useful scripts.

## upload-s3

### Requirements

`aws-cli-v2`

### Configuration

Use the provided `upload-s3.conf.example` as reference. The scripts export them as AWS CLI environment variables for S3 commands

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`

Syncs local files to an S3-compatible bucket using config-driven endpoint, credentials, bucket, region, presets, and filters.

Copy `upload-s3.conf` and fill in your S3-compatible endpoint, access key, secret key, bucket, and region.

### Usage

Sync all files from a directory

```bash
./upload-s3.sh --config upload-s3.conf --path ./assets;
```

Sync common image files

```bash
./upload-s3.sh --config upload-s3.conf --path ./assets --preset image;
```

Sync common video files and exclude drafts

```bash
./upload-s3.sh --config upload-s3.conf --path ./assets --preset video --exclude "drafts/*";
```

Use custom filters only

```bash
./upload-s3.sh --config upload-s3.conf --path ./assets --exclude "*" --include "*.pdf";
```

Config files can also include filters

```conf
preset = image
include = *.avif
exclude = raw/*
```

## fetch-s3

Lists, downloads, and creates presigned URLs for objects in an S3-compatible bucket.

### Requirements

*(Same as upload-s3)*

### Configuration

*(Same as upload-s3)*

### Usage

List object names and sizes

```bash
./fetch-s3.sh list --config upload-s3.conf;
```

List object names and sizes by prefix

```bash
./fetch-s3.sh list --config upload-s3.conf --prefix assets/;
```

List object tags when available

```bash
./fetch-s3.sh list --config upload-s3.conf --prefix assets/ --object-tag;
```

List up to 10 objects

```bash
./fetch-s3.sh list --config upload-s3.conf --prefix assets/ --max-items 10;
```

List objects as JSON

```bash
./fetch-s3.sh list --config upload-s3.conf --prefix assets/ --format json;
```

Download all objects under a prefix

```bash
./fetch-s3.sh download --config upload-s3.conf --prefix assets/ --destination ./downloads;
```

Generate a presigned URL for a full object key

```bash
./fetch-s3.sh url --config upload-s3.conf --key assets/example.jpg --expires-in 3600;
```

## start-tmux-windows

Starts a tmux session from a command file.

### Configuration

Use the provided `start-tmux-windows.conf.example` as reference. 

Each non-comment line creates one window, the format is `[Window Name] <cmd1> [::: <cmd2>]?*` where `:::` splits multiple commands into side-by-side panes.

```text
# System dashboard
[glances] glances
[logs] tail -f /var/log/system.log ::: htop
[shell]
```

### Usage

Start the tmux session

```bash
./start-tmux-windows.sh start-tmux-windows.conf;
```

The generated session name is based on the command file name. If that session already exists, the script replaces it before attaching.

## llm-launch

Launches `llama-server` for a local model with metrics, API key loading, GPU layers, continuous batching, and computed total context size. The final context size is `--context-size` multiplied by `--max-user`.

### Configuration
Read API keys from `${HOME}/.llm_api_key`

### Usage

Basic launch

```bash
./llm-launch.sh /models/qwen3.gguf --alias qwen3 --context-size 8192 --max-user 8;
```

Launch with speculative MTP decoding, reasoning disabled, and extra `llama-server` arguments passed through

```bash
./llm-launch.sh /models/qwen3.gguf --alias qwen3 --use-mtp --nothink --host 0.0.0.0 --port 8080;
```

Launch a multimodal model. The script looks for the first `*mmproj-*.gguf` file in the model file's parent directory

```bash
./llm-launch.sh /models/vision-model.gguf --alias vision --multimodel;
```

Common options

- `--alias <name>`: Sets the served model alias.
- `--context-size <N>`: Sets per-user context size before multiplication by `--max-user`.
- `--max-user <N>`: Sets `llama-server --parallel` and contributes to total context size.
- `--use-mtp`: Enables draft MTP speculative decoding.
- `--nothink`: Adds `--reasoning off`.
- `--embeddings`: Enables the script's embeddings option name as implemented.
- `--multimodel`: Adds a matching multimodal projection file when present.
- `--use-ssl`: Adds certificate and key paths from `~/certs/fullchain.pem` and `~/certs/privkey.pem`.

## run-acme-cf.sh

Issues and installs certificates with `acme.sh` using Cloudflare DNS validation for each domain listed in `DOMAINS`. Installed certificate files are written under a directory named after each domain.

### Configuration
Use the provided `.env.acme` as reference. 

```bash
CF_Token="cloudflare-api-token";
DOMAINS=("example.com" "*.example.com");
CERT_HOME="${HOME}/.acme.sh";
```

### Usage

Issue and install certificates

```bash
./run-acme-cf.sh;
```

For `example.com`, the installed files are

```text
example.com/fullchain.pem
example.com/privkey.pem
```

## cloudflare-ddns

Dynamically update the DNS entries under Cloudflare.

### Requirements

*(Optional)* To update DNS on public IP changes, install `networkd-dispatcher`, then copy `cloudflare-ddns-hook` to `/etc/networkd-dispatcher/configured.d`

### Configuration

Use the provided `.env.cloudflare-ddns` as reference. 

```bash
CLOUDFLARE_API_KEY=<Cloudflare API Key, requires DNS Write permission>
CLOUDFLARE_ZONE_ID=<Zone ID, Find this ID in Overview page of your domain>
DOMAINS=("subdomain1.example.com" "subdomain2.example.com" "subdomainN.example.com")
```

### Usage

Basic Usage

```bash
cloudflare-ddns.sh --env-file /path/to/env/file
```

## update-git-commit-author

Replace the author and sign off message in all git commit

### Usage

Basic Usage

```bash
update-git-commit-author.sh old@exmaple.com new-username new@exmaple.com
```

## fail2ban-from-log

Scan and ban malicious IPs from old logs file

### Usage

Basic Usage

```bash
fail2ban-from-log.sh nginx.log nginx-nonhttp nginx-banip
```

## License

GPLv3
