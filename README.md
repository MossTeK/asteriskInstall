# Asterisk 18 FreePBX 16 Installation Script
This shell script automates the installation process of Asterisk with FreePBX on Ubuntu 22.04 LTS.

## Prerequisites

- Ubuntu 22.04 LTS
- Internet connection
- **Note:** This script is intended for fresh installations and may not work as expected on systems with existing configurations.

## Usage

1. Clone this repository:

    ```bash
    git clone https://github.com/your-username/asterisk-freepbx-install.git
    cd asterisk-freepbx-install
    ```

2. Make the script executable:

    ```bash
    chmod +x install.sh
    ```

3. Run the script with sudo privileges:

    ```bash
    sudo ./install.sh
    ```

4.

## Configuration

This script is built with a default preset of the essential and usfel modules wich would usally be set in the menuselect process. If you want to build with a specific module, simply insert insert --enable *module_name* to line 25 between `menuselect/menuselect` and `menuselect.makeopts`. See [menuselect documentation](https://docs.asterisk.org/Getting-Started/Installing-Asterisk/Installing-Asterisk-From-Source/Using-Menuselect-to-Select-Asterisk-Options/) for more.


## Disclaimer

- Use this script at your own risk.
- The author is not responsible for any data loss or damage caused by the use of this script. Functionality is not garunteed