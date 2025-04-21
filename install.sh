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

    # Check desktop environment
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        DE="$XDG_CURRENT_DESKTOP"
        print_color "Detected desktop environment: $DE" "info"
    elif [ -n "$DESKTOP_SESSION" ]; then
        DE="$DESKTOP_SESSION"
        print_color "Detected desktop session: $DE" "info"
    else
        DE="unknown"
    fi

    # Check package manager
    if command -v apt-get &> /dev/null; then
        if grep -q "MINT" /etc/os-release 2>/dev/null || echo "$DE" | grep -qi "cinnamon"; then
            PKG_MANAGER="mint"
            print_color "Detected Linux Mint / Cinnamon environment" "info"
        else
            PKG_MANAGER="apt"
        fi
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
        mint)
            print_color "Installing dependencies for Linux Mint / Cinnamon..." "info"
            sudo apt-get update
            sudo apt-get install -y git cmake g++ \
                qtbase5-dev qtdeclarative5-dev qt5-qmake \
                qtquickcontrols2-5-dev \
                qml-module-qtquick2 \
                qml-module-qtquick-window2 \
                qml-module-qtquick-controls2 \
                qml-module-qtquick-layouts \
                qml-module-qt-labs-platform \
                qt5-default \
                ddcutil

            # Check if we need extra packages specific to Linux Mint
            if ! dpkg -l | grep -q qml-module-qtquick2; then
                print_color "Installing additional QML modules needed for Mint/Cinnamon..." "info"
                sudo apt-get install -y qml-module-qtgraphicaleffects \
                    libqt5svg5-dev \
                    qml-module-qtqml \
                    qml-module-qtqml-models2
            fi
            ;;
        apt)
            sudo apt-get update
            sudo apt-get install -y git cmake g++ \
                qtbase5-dev qtdeclarative5-dev qt5-qmake \
                qtquickcontrols2-5-dev \
                qml-module-qtquick2 \
                qml-module-qtquick-window2 \
                qml-module-qtquick-controls2 \
                qml-module-qtquick-layouts \
                qml-module-qt-labs-platform \
                ddcutil
            ;;
        dnf)
            sudo dnf install -y git cmake gcc-c++ \
                qt5-qtbase-devel qt5-qtdeclarative-devel \
                qt5-qtquickcontrols2-devel \
                qt5-devel \
                qt5-qtquickcontrols \
                ddcutil
            ;;
        pacman)
            sudo pacman -Sy --noconfirm git cmake gcc \
                qt5-base qt5-declarative \
                qt5-quickcontrols2 \
                qt5-tools \
                ddcutil
            ;;
        zypper)
            sudo zypper install -y git cmake gcc-c++ \
                libqt5-qtbase-devel libqt5-qtdeclarative-devel \
                libqt5-qtquickcontrols2-devel \
                libqt5-qtquickcontrols \
                ddcutil
            ;;
        *)
            print_color "Please install the following dependencies manually:" "warning"
            print_color "- git, cmake, gcc/g++" "warning"
            print_color "- Qt5 development libraries:" "warning"
            print_color "  - QtBase, QtDeclarative" "warning"
            print_color "  - QtQuick modules (QtQuick2, QtQuick.Window2, QtQuickControls2)" "warning"
            print_color "  - Qt5 QML modules (qt5-qmake if available)" "warning"
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
        git clone https://github.com/yourusername/monitor-control.git "$INSTALL_DIR"
    else
        cd "$INSTALL_DIR" && git pull
    fi

    print_color "✓ Downloaded to $INSTALL_DIR" "success"
}

# Run diagnostics for Qt
run_qt_diagnostics() {
    print_color "Running Qt diagnostics..." "warning"

    print_color "1. Checking Qt installation:" "info"
    if command -v qmake &> /dev/null; then
        qmake --version
    elif command -v qmake-qt5 &> /dev/null; then
        qmake-qt5 --version
    else
        print_color "qmake not found in PATH" "error"
    fi

    print_color "2. Checking Qt modules:" "info"
    for module in Qt5Core Qt5Gui Qt5Qml Qt5Quick Qt5Widgets; do
        if pkg-config --exists "$module" 2>/dev/null; then
            print_color "✓ $module found: $(pkg-config --modversion $module)" "success"
        else
            print_color "✗ $module not found" "error"
        fi
    done

    print_color "3. Checking QML modules installation:" "info"
    if [ -d "/usr/lib/x86_64-linux-gnu/qt5/qml/QtQuick" ]; then
        print_color "✓ QtQuick QML modules directory exists" "success"
        ls -la /usr/lib/x86_64-linux-gnu/qt5/qml/QtQuick
    else
        print_color "✗ QtQuick QML modules directory not found" "error"
    fi

    print_color "4. Checking other critical files:" "info"
    for file in /usr/include/x86_64-linux-gnu/qt5/QtQuick/QQuickWindow \
                /usr/include/x86_64-linux-gnu/qt5/QtQuick/QQuickItem; do
        if [ -f "$file" ]; then
            print_color "✓ $file exists" "success"
        else
            print_color "✗ $file not found" "error"
        fi
    done

    # Suggest packages to install
    print_color "\nBased on diagnostics, you might need to install:" "info"
    print_color "  sudo apt-get install -y qtbase5-dev qtdeclarative5-dev qt5-default qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtquick-controls2" "info"
}

# Build application
build_application() {
    print_color "➤ Building application..." "info"

    cd "$INSTALL_DIR"
    mkdir -p build
    cd build

    # Run cmake with error checking
    if ! cmake ..; then
        print_color "Error: CMake configuration failed. See above for details." "error"
        print_color "This might be due to missing Qt dependencies." "error"
        run_qt_diagnostics

        local try_fix
        read -p "Do you want to try installing additional Qt dependencies automatically? (y/n): " try_fix
        if [[ $try_fix =~ ^[Yy]$ ]]; then
            case $PKG_MANAGER in
                apt|mint)
                    sudo apt-get install -y qtbase5-dev qtdeclarative5-dev qt5-default \
                        qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtquick-controls2 \
                        qml-module-qtqml qml-module-qtqml-models2 qml-module-qtgraphicaleffects
                    # Try cmake again
                    if ! cmake ..; then
                        print_color "Error: CMake still failing after installing additional dependencies." "error"
                        exit 1
                    fi
                    ;;
                *)
                    print_color "Automatic dependency fixing is only supported on Debian/Ubuntu systems." "error"
                    exit 1
                    ;;
            esac
        else
            exit 1
        fi
    fi

    # Run make with error checking
    if ! make -j$(nproc); then
        print_color "Error: Build failed. See above for details." "error"
        run_qt_diagnostics
        exit 1
    fi

    # Verify if the executable was created
    if [ ! -f "monitor-control" ]; then
        print_color "Error: Build completed but executable was not created." "error"
        exit 1
    fi

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

# Verify Qt dependencies
verify_qt_dependencies() {
    print_color "➤ Verifying Qt dependencies..." "info"

    local missing_deps=0

    # Check for qmake
    if ! command -v qmake &> /dev/null && ! command -v qmake-qt5 &> /dev/null; then
        print_color "Warning: qmake or qmake-qt5 not found in PATH" "warning"
        missing_deps=1
    fi

    # Check for critical Qt modules by looking for pkgconfig files
    local qt_modules=("Qt5Core" "Qt5Quick" "Qt5Qml" "Qt5Gui" "Qt5Widgets")
    for module in "${qt_modules[@]}"; do
        if ! pkg-config --exists "$module" 2>/dev/null; then
            print_color "Warning: $module development package not found" "warning"
            missing_deps=1
        fi
    done

    if [ $missing_deps -eq 1 ]; then
        print_color "Some Qt dependencies appear to be missing." "warning"
        print_color "This might cause build failures later." "warning"

        local proceed
        read -p "Do you want to continue anyway? (y/n): " proceed
        if [[ ! $proceed =~ ^[Yy]$ ]]; then
            print_color "Installation aborted. Please install the missing dependencies and try again." "error"
            exit 1
        fi
    else
        print_color "✓ Qt dependencies verified" "success"
    fi
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
    verify_qt_dependencies
    setup_permissions
    clone_repository
    build_application
    create_desktop_entry
    finalize_installation
}

# Start installation
main