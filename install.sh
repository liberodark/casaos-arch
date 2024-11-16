#!/bin/bash

# Terminal colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}
   _____                 ____   _____ 
  / ____|               / __ \ / ____|
 | |     __ _ ___  __ _| |  | | (___  
 | |    / _\` / __|/ _\` | |  | |\___ \ 
 | |___| (_| \__ \ (_| | |__| |____) |
  \_____\__,_|___/\__,_|\____/|_____/ 

Installation Script for Arch Linux
${NC}"

# Check if root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script must not be run as root${NC}"
   exit 1
fi

# Check if Arch Linux
if [ ! -f /etc/arch-release ]; then
    echo -e "${RED}This script is for Arch Linux only${NC}"
    exit 1
fi

# Function to install package via pacman
install_package() {
    if ! pacman -Qi "$1" >/dev/null 2>&1; then
        echo -e "${BLUE}Installing $1...${NC}"
        sudo pacman -S --noconfirm "$1"
    fi
}

# Install yay if not present
install_yay() {
    if ! command -v yay &> /dev/null; then
        echo -e "${YELLOW}Installing yay...${NC}"
        temp_dir=$(mktemp -d)
        cd "$temp_dir" || exit
        
        sudo pacman -S --needed --noconfirm git base-devel
        
        git clone https://aur.archlinux.org/yay.git
        cd yay || exit
        makepkg -si --noconfirm
        
        cd "$HOME" || exit
        rm -rf "$temp_dir"
        
        echo -e "${GREEN}yay installed successfully${NC}"
    fi
}

echo -e "${GREEN}[1/8] Installing and configuring reflector...${NC}"
install_package reflector
echo -e "${BLUE}Updating mirrors...${NC}"
# Backup current mirrorlist
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
# Update mirrors list with fastest ones
sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
# Force refresh repositories
sudo pacman -Syy

echo -e "${GREEN}[2/8] Updating system...${NC}"
sudo pacman -Syu --noconfirm

echo -e "${GREEN}[3/8] Installing yay...${NC}"
install_yay

echo -e "${GREEN}[4/8] Installing pacman dependencies...${NC}"
# Official packages installation
PACMAN_PACKAGES=(
    'docker'
    'wget'
    'curl'
    'smartmontools'
    'parted'
    'ntfs-3g'
    'net-tools'
    'samba'
    'cifs-utils'
    'unzip'
)

for package in "${PACMAN_PACKAGES[@]}"; do
    install_package "$package"
done

echo -e "${GREEN}[5/8] Installing AUR packages...${NC}"
# AUR packages installation
AUR_PACKAGES=(
    'mergerfs'
    'udevil'
)

for package in "${AUR_PACKAGES[@]}"; do
    if ! pacman -Qi "$package" >/dev/null 2>&1; then
        echo -e "${BLUE}Installing $package from AUR...${NC}"
        yay -S --noconfirm "$package"
    fi
done

echo -e "${GREEN}[6/8] Configuring Docker...${NC}"
# Enable and start Docker
sudo systemctl enable --now docker
# Add current user to docker group
sudo usermod -aG docker "$USER"

echo -e "${YELLOW}NOTE: You'll need to log out and back in for docker group changes to take effect${NC}"

echo -e "${GREEN}[7/8] Installing CasaOS...${NC}"
# Create temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit

# Architecture detection
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        TARGET_ARCH="amd64"
        ;;
    aarch64)
        TARGET_ARCH="arm64"
        ;;
    armv7l)
        TARGET_ARCH="arm-7"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

# Configure udevil
echo -e "${BLUE}Configuring udevil...${NC}"
# Create devmon user if not exists
if ! id "devmon" &>/dev/null; then
    sudo useradd -M -u 300 devmon
    sudo usermod -L devmon
fi

# Configure udevil
sudo sed -i '/exfat/s/, nonempty//g' /etc/udevil/udevil.conf
sudo sed -i '/default_options/s/, noexec//g' /etc/udevil/udevil.conf

# Enable and start devmon
sudo systemctl enable --now devmon@devmon

# Download and install CasaOS
wget -qO- https://get.casaos.io | sudo bash

echo -e "${GREEN}[8/8] Cleaning up...${NC}"
# Cleanup
cd "$HOME" || exit
rm -rf "$TMP_DIR"

echo -e "${GREEN}Installation completed!${NC}"
echo -e "${BLUE}CasaOS should be accessible at: http://localhost:80${NC}"
echo -e "${BLUE}To uninstall: casaos-uninstall${NC}"
echo -e "${YELLOW}Don't forget to log out and back in for docker group changes to take effect${NC}"
