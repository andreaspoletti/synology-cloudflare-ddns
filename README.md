# Cloudflare DDNS Update Script for Synology DSM

This script automatically updates Cloudflare DNS records when the IP address of your Synology NAS changes. This allows you to always access your NAS via a domain name, even if your ISP changes your IP address.

## Features

- Supports both IPv4 (A records) and IPv6 (AAAA records).
- Utilizes the Cloudflare API to keep your DNS records up-to-date.
- Integrates with Synology DSM DDNS package to obtain the current external IP address of your NAS.

## Prerequisites

Before using this script, make sure that:

- You have a Cloudflare account and have access to your API key.
- `curl` and `jq` are installed on your Synology NAS.
- Your domain name is managed by Cloudflare, and you have the permissions to modify its DNS records.
- Synology DDNS client is installed on your Synology NAS (more info on this in the [Installation](#installation) section).

## Usage

Use the following command to run the script:

```bash
/sbin/cloudflare_ddns.sh <username> <password> <hostname> <ip>
```

Where:

- `<username>` is your Cloudflare account ID.
- `<password>` is your Cloudflare API key.
- `<hostname>` is the hostname you want to update, for example, `example.com`.
- `<ip>` is the IP address to set. This is optional and if not specified, the script will automatically detect the external IP address of your NAS.

## Exit Codes

The script uses the following exit codes:

- `1` - Prerequisites are missing or parameters are invalid.
- `2` - The hostname format is invalid.
- `3` - Authentication failed.
- `4` - Prerequisites are missing.

## Limitations

The script currently makes separate API calls for updating the A and AAAA records. As of the time of writing this README, Cloudflare does not support batch updates for DNS records.

## Installation
In order to install this script, please follow the instructions in the [INSTALLATION.md](INSTALLATION.md) file.

## Contribution

Contributions are welcome. Please feel free to submit a pull request or open an issue on GitLab.

## Disclaimer

This script is provided as is with no warranty. Please use it at your own risk and ensure you understand what the script does before running it.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE.md) file for details.
