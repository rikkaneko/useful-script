# Useful Script

Small utility scripts for common operational tasks.

## Installation

Install the AWS CLI and Python 3, then make the scripts executable:

```bash
chmod +x upload-s3.sh;
chmod +x fetch-s3;
```

Copy `upload-s3.conf` and fill in your S3-compatible endpoint, access key, secret key, bucket, and region.

## Environment Configuration

Credentials can be provided through `upload-s3.conf` or CLI arguments. The scripts export them as AWS CLI environment variables for S3 commands:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`

Do not hardcode real credentials in committed config files.

## Features

- Sync a local directory to an S3-compatible bucket.
- Configure endpoint, bucket, credentials, and region through a config file or CLI arguments.
- Use predefined upload presets with `--preset image` or `--preset video`.
- Add repeatable custom AWS sync filters with `--include` and `--exclude`.
- Run unfiltered syncs by omitting preset and custom filters.
- List S3 objects with optional prefix filtering and object size, capped to 50 objects by default.
- Download all objects under an S3 prefix.
- Generate presigned URLs for full object keys.

## Usage

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

List object names and sizes:

```bash
./fetch-s3 list --config upload-s3.conf;
```

List object names and sizes by prefix:

```bash
./fetch-s3 list --config upload-s3.conf --prefix assets/;
```

List object tags when available:

```bash
./fetch-s3 list --config upload-s3.conf --prefix assets/ --object-tag;
```

List up to 10 objects:

```bash
./fetch-s3 list --config upload-s3.conf --prefix assets/ --max-items 10;
```

List objects as JSON:

```bash
./fetch-s3 list --config upload-s3.conf --prefix assets/ --format json;
```

Download all objects under a prefix:

```bash
./fetch-s3 download --config upload-s3.conf --prefix assets/ --destination ./downloads;
```

Generate a presigned URL for a full object key:

```bash
./fetch-s3 url --config upload-s3.conf --key assets/example.jpg --expires-in 3600;
```

## License

No license has been specified.
