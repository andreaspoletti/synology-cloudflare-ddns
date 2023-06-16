# Installation Guide

This guide provides step-by-step instructions on how to install and set up the Cloudflare DDNS Update Script for Synology DSM.

## Prerequisites

Before starting the installation, ensure that:

- You have a Cloudflare account and have access to your API key with Zone.Zone, Zone.DNS access.
- Your domain name is managed by Cloudflare, and you have the permissions to modify its DNS records.
- `curl` and `jq` are installed on your Synology NAS.
- `ssh` access is enabled on your Synology NAS.

## What this is based on
`/usr/syno/sbin/ddnsd` **needs to be installed on your Synology NAS.**

This is the Synology DDNS client that will be used to obtain the current external IP address of your NAS, as I find it 
more reliable than the built-in method of obtaining the IP address, as we can also get the IPv6 address.
The beauty of it all is that we do not have to mingle with the `ip` command, as the Synology DDNS client will do all the
work for us.
This package was discovered by mistake and I do not currently know if it is installed by default on all Synology NAS devices.

## Installation Steps

1. **Download the Script**

   Download the `cloudflare_ddns.sh` script from this repository and save it to the `/sbin/` directory on your Synology NAS.
   ```bash
    wget https://gitlab.com/andreas.poletti/synology-cloudflare-ddns/-/raw/main/cloudflare_ddns.sh -O /sbin/cloudflare_ddns.sh
   ```

2. **Make the Script Executable**

   Change the script's permissions to make it executable:

   ```bash
   chmod +x /sbin/cloudflare_ddns.sh
   ```

3. **Configure Synology DSM**

   Append the following lines to the /etc.defaults/ddns_provider.conf file on your Synology NAS:
   ```bash
   [Cloudflare]
       modulepath=/sbin/cloudflare_ddns.sh
       queryurl=https://www.cloudflare.com/
       website=https://www.cloudflare.com/
   ```
   You can use the following command to append the lines to the file:
   ```bash
   cat << EOF >> /etc.defaults/ddns_provider.conf
   [Cloudflare]
       modulepath=/sbin/cloudflare_ddns.sh
       queryurl=https://www.cloudflare.com
       website=https://www.cloudflare.com
    EOF
    ```

## Verification

To verify that the installation was successful, run the script with your Cloudflare credentials and domain name:

```bash
/sbin/cloudflare_ddns.sh <username> <password> <hostname> <ip>
```

If the script runs without any errors and your Cloudflare DNS records are updated correctly, the installation was successful.

If you encounter any errors you can run `echo $?` to get the exit code of the script.
For a list of exit codes and their meaning, please refer to the [README.md](README.md) file.

## Synology DSM Setup
1. In the DSM GUI, go to **Control Panel > External Access > DDNS** and click **Add**.
2. Select **Cloudflare** from the **Service Provider** dropdown menu.
3. Enter your Cloudflare credentials and domain name.
4. Click **Test Connection** to verify that the script is working correctly.
5. Click **Save** to save the settings.

## Cloudflare API Token Setup
1. In Cloudflare, go to **My Profile > API Tokens** and click **Create Token**.
2. Select **Edit zone DNS** template.
3. Under permissions, select **Zone.Zone.Read** and **Zone.DNS.Edit**.
4. Select the domain name you want to update from the **Zone Resources** dropdown menu (Include -> Specific zone -> Select zone).
5. It is also recommended to set a TTL for the API token.
6. Click **Continue to summary**.

## Troubleshooting

If you encounter any problems during the installation, please refer to the [README.md](README.md) file for more information or open an issue on GitLab.