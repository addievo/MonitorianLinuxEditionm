#!/usr/bin/env bash
set -e

# Monitor Brightness Control Installation Script
# This script installs Monitor Brightness Control on Linux systems

# Display colored text
print_color() {
    if [ "$2" = "info" ]; then
        COLOR="96m"    # Light blue
    elif [ "$2" = "success" ]; then
        COLOR="92m"    # Light green
    elif [ "$2" = "warning" ]; then
        COLOR="93m"    # Light yellow
    elif [ "$2" = "error" ]; then
        COLOR="91m"    # Light red
    else
        COLOR="0m"     # Default
    fi

    echo -e "\033[${COLOR}$1\033[0m"
}

# Display banner
print_banner() {
    echo ""
    print_color "================================================" "info"
    print_color "       Monitor Brightness Control Installer      " "info"
    print_color "================================================" "info"
    echo ""
}

# Check system and prerequisites
check_system() {
    print_color "➤ Checking system compatibility..." "info"

    # Check if running Linux
    if [ "$(uname)" != "Linux" ]; then
        print_color "Error: This script is designed for Linux systems only." "error"
        exit 1
    fi

    # Check package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
    else
        print_color "Warning: Unsupported package manager. You'll need to install dependencies manually." "warning"
        PKG_MANAGER="unknown"
    fi

    print_color "✓ System check complete. Package manager: $PKG_MANAGER" "success"
}

# Install dependencies
install_dependencies() {
    print_color "➤ Installing dependencies..." "info"

    case $PKG_MANAGER in
        apt)
            sudo apt-get update
            sudo apt-get install -y git cmake g++ qtbase5-dev qtdeclarative5-dev qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qt-labs-platform ddcutil
            ;;
        dnf)
            sudo dnf install -y git cmake gcc-c++ qt5-qtbase-devel qt5-qtdeclarative-devel qt5-qtquickcontrols2-devel ddcutil
            ;;
        pacman)
            sudo pacman -Sy --noconfirm git cmake gcc qt5-base qt5-declarative qt5-quickcontrols2 ddcutil
            ;;
        zypper)
            sudo zypper install -y git cmake gcc-c++ libqt5-qtbase-devel libqt5-qtdeclarative-devel libqt5-qtquickcontrols2-devel ddcutil
            ;;
        *)
            print_color "Please install the following dependencies manually:" "warning"
            print_color "- git, cmake, gcc/g++" "warning"
            print_color "- Qt5 development libraries (QtBase, QtDeclarative, QtQuickControls2)" "warning"
            print_color "- ddcutil" "warning"

            read -p "Press Enter to continue once dependencies are installed..."
            ;;
    esac

    print_color "✓ Dependencies installed" "success"
}

# Set up ddcutil permissions
setup_permissions() {
    print_color "➤ Setting up ddcutil permissions..." "info"

    # Create i2c group if it doesn't exist
    if ! getent group i2c >/dev/null; then
        sudo groupadd i2c
    fi

    # Add current user to i2c group
    sudo usermod -aG i2c "$USER"

    # Create udev rule for i2c devices if it doesn't exist
    if [ ! -f /etc/udev/rules.d/90-i2c-permissions.rules ]; then
        echo 'KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"' | sudo tee /etc/udev/rules.d/90-i2c-permissions.rules > /dev/null
        sudo udevadm control --reload-rules
        sudo udevadm trigger
    fi

    print_color "✓ Permissions configured" "success"
    print_color "Note: You may need to log out and log back in for group changes to take effect" "warning"
}

# Clone repository
clone_repository() {
    print_color "➤ Downloading Monitor Brightness Control..." "info"

    # Create app directory
    INSTALL_DIR="$HOME/.local/share/monitor-control"
    mkdir -p "$INSTALL_DIR"

    if [ ! -d "$INSTALL_DIR/.git" ]; then
        git clone https://github.com/addievo/MonitorianLinuxEditionm.git "$INSTALL_DIR"
    else
        cd "$INSTALL_DIR" && git pull
    fi

    print_color "✓ Downloaded to $INSTALL_DIR" "success"
}

# Build application
build_application() {
    print_color "➤ Building application..." "info"

    cd "$INSTALL_DIR"
    mkdir -p build
    cd build
    cmake ..
    make -j$(nproc)

    print_color "✓ Build complete" "success"
}

# Create desktop entry
create_desktop_entry() {
    print_color "➤ Creating desktop entry..." "info"

    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"

    cat > "$DESKTOP_DIR/monitor-control.desktop" << EOF
[Desktop Entry]
Name=Monitor Brightness Control
Comment=Control your monitor brightness
Exec=$INSTALL_DIR/build/monitor-control
Icon=display
Terminal=false
Type=Application
Categories=Utility;
StartupNotify=true
X-GNOME-Autostart-enabled=true
EOF

    mkdir -p "$HOME/.config/autostart"
    cp "$DESKTOP_DIR/monitor-control.desktop" "$HOME/.config/autostart/"

    print_color "✓ Desktop entry created" "success"
}

# Complete installation
finalize_installation() {
    print_color "➤ Finalizing installation..." "info"

    print_color "================================================" "success"
    print_color "   Monitor Brightness Control is now installed!   " "success"
    print_color "================================================" "success"
    print_color "" "info"
    print_color "▶ You can start the application from your desktop menu" "info"
    print_color "  or by running: $INSTALL_DIR/build/monitor-control" "info"
    print_color "" "info"
    print_color "▶ The application will start automatically when you log in" "info"
    print_color "" "info"
    print_color "▶ If monitors are not detected, please log out and log back in" "info"
    print_color "  to apply the permission changes" "info"
    print_color "" "info"
}

# Run all steps
main() {
    # Ensure script is not run as root
    if [ "$EUID" -eq 0 ]; then
        print_color "Please do not run this script as root or with sudo." "error"
        exit 1
    fi

    print_banner
    check_system
    install_dependencies
    setup_permissions
    clone_repository
    build_application
    create_desktop_entry
    finalize_installation
}

# Start installation
main