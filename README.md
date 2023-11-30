# FreePBX Installation Script

This script installs Asterisk 18 and FreePBX 16 on an ubuntu 22.04 instance,

## Usage

1. **Download the script:**

    ```bash
    wget https://github.com/MossTeK/asteriskInstall/blob/main/install.sh
    ```

2. **Make the script executable:**

    ```bash
    chmod +x install-freepbx.sh
    ```

3. **Run the script with root privileges:**

    ```bash
    sudo ./install-freepbx.sh
    ```

## What the Script Does

- Installs necessary dependencies for Asterisk / FreePBX
- Installs and configures Asterisk.
- Installs and configures Apache for FreePBX.
- Downloads and installs FreePBX 16.
- opens necesarry ports with ufw, and installs Fail2Ban.

## Logging

The script creates an `install.log` file to log the installation process. Any errors encountered during the installation will be recorded in this file.

## Notes

if you want to choose different asterisk modules, you will need to edit the modules specified when `menuselect/menuselect` is invoked (during the `installAsterisk` function)
