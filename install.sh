#!/usr/bin/env bash
set -e

# Monitor Brightness Control Installation Script
# This script installs Monitor Brightness Control on Linux systems

# Default verbose mode is off
VERBOSE=false

# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      # Unknown option
      ;;
  esac
done

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

# Only print if verbose mode is on
verbose_print() {
    if [ "$VERBOSE" = true ]; then
        print_color "$1" "$2"
    fi
}

# Run a command with output handling based on verbose mode
run_command() {
    if [ "$VERBOSE" = true ]; then
        # Show full command output in verbose mode
        "$@"
    else
        # Hide output in normal mode, but still capture exit code
        "$@" > /dev/null 2>&1
        return $?
    fi
}

# Display banner
print_banner() {
    echo ""
    print_color "================================================" "info"
    print_color "       Monitor Brightness Control Installer      " "info"
    print_color "================================================" "info"
    echo ""
}

# Check for required build tools
check_build_tools() {
    print_color "Checking for required build tools..." "info"
    if ! command -v make &> /dev/null; then
        print_color "Error: 'make' is not installed." "error"
        return 1
    fi
    if ! command -v g++ &> /dev/null; then
        print_color "Error: 'g++' is not installed." "error"
        return 1
    fi
    print_color "✓ Build tools found" "success"
    return 0
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
    if command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        if [ -f /etc/manjaro-release ]; then
            MANJARO=true
            print_color "Detected Manjaro Linux" "info"
        elif [ -f /etc/arch-release ]; then
            ARCH=true
            print_color "Detected Arch Linux" "info"
        else
            print_color "Detected pacman-based distribution" "info"
        fi
    elif command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        # Check for Ubuntu/Debian/Mint version
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            if [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID_LIKE" == *"ubuntu"* || "$ID_LIKE" == *"debian"* ]]; then
                DEBIAN_BASED=true
                print_color "Detected Debian-based distribution: $PRETTY_NAME" "info"
            fi
        fi
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        print_color "Detected Fedora/RHEL-based distribution" "info"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        print_color "Detected OpenSUSE/SUSE distribution" "info"
    else
        print_color "Warning: Unsupported package manager. You'll need to install dependencies manually." "warning"
        PKG_MANAGER="unknown"
    fi

    # Check if ddcutil is already installed and working
    if command -v ddcutil &> /dev/null; then
        print_color "ddcutil is already installed. Testing compatibility..." "info"
        if ddcutil detect &> /dev/null; then
            print_color "✓ ddcutil is working properly" "success"
        else
            print_color "⚠ ddcutil is installed but might have permission issues" "warning"
        fi
    fi

    print_color "✓ System check complete. Package manager: $PKG_MANAGER" "success"
}

# Test Qt installation
test_qt_installation() {
    print_color "➤ Testing Qt installation..." "info"

    if command -v qmake &> /dev/null; then
        QMAKE_VERSION=$(qmake --version | head -n 1)
        verbose_print "✓ Found $QMAKE_VERSION" "success"
    elif command -v qmake-qt5 &> /dev/null; then
        QMAKE_VERSION=$(qmake-qt5 --version | head -n 1)
        verbose_print "✓ Found $QMAKE_VERSION" "success"
    else
        print_color "⚠ qmake not found. Qt might not be properly installed." "warning"
    fi

    if [ -d "/usr/include/x86_64-linux-gnu/qt5" ] || [ -d "/usr/include/qt5" ]; then
        verbose_print "✓ Qt5 development headers found" "success"
    else
        verbose_print "⚠ Qt5 development headers not found" "warning"
    fi

    # Always show a success message in non-verbose mode if Qt is found
    if [ "$VERBOSE" = false ] && (command -v qmake &> /dev/null || command -v qmake-qt5 &> /dev/null); then
        print_color "✓ Qt installation found" "success"
    fi
}

# Install dependencies
install_dependencies() {
    print_color "➤ Installing dependencies..." "info"

    case $PKG_MANAGER in
        pacman)
            if [ "$MANJARO" = true ] || [ "$ARCH" = true ]; then
                print_color "Installing dependencies for Manjaro/Arch..." "info"
                if [ "$VERBOSE" = true ]; then
                    sudo pacman -Sy --noconfirm git cmake gcc base-devel make qt5-base qt5-declarative qt5-quickcontrols qt5-quickcontrols2 qt5-svg qt5-x11extras ddcutil
                else
                    print_color "Installing packages (this may take a while)..." "info"
                    sudo pacman -Sy --noconfirm git cmake gcc base-devel make qt5-base qt5-declarative qt5-quickcontrols qt5-quickcontrols2 qt5-svg qt5-x11extras ddcutil > /dev/null 2>&1
                fi
            else
                if [ "$VERBOSE" = true ]; then
                    sudo pacman -Sy --noconfirm git cmake gcc qt5-base qt5-declarative qt5-quickcontrols2 qt5-svg ddcutil
                else
                    print_color "Installing packages (this may take a while)..." "info"
                    sudo pacman -Sy --noconfirm git cmake gcc qt5-base qt5-declarative qt5-quickcontrols2 qt5-svg ddcutil > /dev/null 2>&1
                fi
            fi
            ;;
        apt)
            if [ "$VERBOSE" = true ]; then
                sudo apt-get update
            else
                print_color "Updating package lists..." "info"
                sudo apt-get update > /dev/null 2>&1
            fi

            # Modern Ubuntu/Mint/Debian doesn't use qt5-default anymore
            QT_PACKAGES="qtbase5-dev qtdeclarative5-dev libqt5svg5-dev"
            QML_PACKAGES="qml-module-qtquick2 qml-module-qtquick-window2 qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qt-labs-platform qml-module-qtquick-dialogs"

            if [ "$VERBOSE" = true ]; then
                sudo apt-get install -y git cmake g++ $QT_PACKAGES $QML_PACKAGES ddcutil

                # Check if installation was successful
                if [ $? -ne 0 ]; then
                    print_color "Warning: Some packages failed to install. Trying alternative approach..." "warning"
                    # Try with qt5-default for older distributions
                    sudo apt-get install -y qt5-default 2>/dev/null || true
                fi
            else
                print_color "Installing packages (this may take a while)..." "info"
                if ! sudo apt-get install -y git cmake g++ $QT_PACKAGES $QML_PACKAGES ddcutil > /dev/null 2>&1; then
                    print_color "Warning: Some packages failed to install. Trying alternative approach..." "warning"
                    # Try with qt5-default for older distributions
                    sudo apt-get install -y qt5-default > /dev/null 2>&1 || true
                fi
            fi
            ;;
        dnf)
            if [ "$VERBOSE" = true ]; then
                sudo dnf install -y git cmake gcc-c++ qt5-qtbase-devel qt5-qtdeclarative-devel qt5-qtquickcontrols2-devel qt5-qtsvg-devel ddcutil
            else
                print_color "Installing packages (this may take a while)..." "info"
                sudo dnf install -y git cmake gcc-c++ qt5-qtbase-devel qt5-qtdeclarative-devel qt5-qtquickcontrols2-devel qt5-qtsvg-devel ddcutil > /dev/null 2>&1
            fi
            ;;
        zypper)
            if [ "$VERBOSE" = true ]; then
                sudo zypper install -y git cmake gcc-c++ libqt5-qtbase-devel libqt5-qtdeclarative-devel libqt5-qtquickcontrols2-devel libQt5Svg5-devel ddcutil
            else
                print_color "Installing packages (this may take a while)..." "info"
                sudo zypper install -y git cmake gcc-c++ libqt5-qtbase-devel libqt5-qtdeclarative-devel libqt5-qtquickcontrols2-devel libQt5Svg5-devel ddcutil > /dev/null 2>&1
            fi
            ;;
        *)
            print_color "Please install the following dependencies manually:" "warning"
            print_color "- git, cmake, gcc/g++" "warning"
            print_color "- Qt5 development libraries (QtBase, QtDeclarative, QtQuickControls2, QtSvg)" "warning"
            print_color "- QML modules (QtQuick2, QtQuick.Window2, QtQuick.Controls2, QtQuick.Layouts, Qt.labs.platform)" "warning"
            print_color "- ddcutil" "warning"

            read -p "Press Enter to continue once dependencies are installed..."
            ;;
    esac

    # Verify build tools after installation
    check_build_tools

    test_qt_installation

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
    print_color "Note: You MUST log out and log back in for group changes to take effect" "warning"
}

# Test ddcutil detection
test_ddcutil() {
    print_color "➤ Testing ddcutil monitor detection..." "info"

    # Check if we have i2c permissions
    if groups | grep -q "\bi2c\b"; then
        print_color "✓ Current user is in the i2c group" "success"
    else
        print_color "⚠ Current user is NOT in the i2c group yet (logout and login required)" "warning"
        # Note that we continue here rather than exiting
    fi

    # Try to detect monitors - only in verbose mode or if we have i2c group
    if [ "$VERBOSE" = true ] || groups | grep -q "\bi2c\b"; then
        verbose_print "Running ddcutil detect..." "info"
        MONITOR_OUTPUT=$(ddcutil detect 2>&1)
        if echo "$MONITOR_OUTPUT" | grep -q "No displays found"; then
            print_color "⚠ No DDC-compatible monitors detected" "warning"
            verbose_print "This could be due to:" "info"
            verbose_print "  - Permission issues (logout and login to apply group changes)" "info"
            verbose_print "  - Your monitor doesn't support DDC/CI (check monitor settings)" "info"
            verbose_print "  - Hardware limitations (some GPUs/cables don't support DDC properly)" "info"
        else
            MONITOR_COUNT=$(echo "$MONITOR_OUTPUT" | grep -c "Display")
            if [ "$MONITOR_COUNT" -gt 0 ]; then
                print_color "✓ Detected $MONITOR_COUNT DDC-compatible monitor(s)" "success"
            fi
        fi
    else
        print_color "Monitor detection skipped until i2c permissions are applied" "info"
        print_color "Please log out and log back in, then run the application" "info"
    fi
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

    # Special handling for Manjaro/Arch systems
    if [ "$MANJARO" = true ] || [ "$ARCH" = true ]; then
        # Use qmake-qt5 if available to ensure Qt5 is used
        if command -v qmake-qt5 &> /dev/null; then
            QMAKE_PATH=$(which qmake-qt5)
            verbose_print "Using qmake-qt5 at $QMAKE_PATH" "info"

            if [ "$VERBOSE" = true ]; then
                cmake .. -DQT_QMAKE_EXECUTABLE="$QMAKE_PATH" 2>&1 | tee cmake_output.txt
            else
                print_color "Configuring build..." "info"
                cmake .. -DQT_QMAKE_EXECUTABLE="$QMAKE_PATH" > cmake_output.txt 2>&1
            fi
        else
            # Regular build path
            verbose_print "Using default qmake" "info"

            if [ "$VERBOSE" = true ]; then
                cmake .. 2>&1 | tee cmake_output.txt
            else
                print_color "Configuring build..." "info"
                cmake .. > cmake_output.txt 2>&1
            fi
        fi
    else
        verbose_print "Configuring build with cmake..." "info"

        if [ "$VERBOSE" = true ]; then
            # Capture cmake output to diagnose issues in verbose mode
            CMAKE_OUTPUT=$(cmake .. 2>&1)
            if [ $? -ne 0 ]; then
                print_color "Error during CMake configuration:" "error"
                print_color "$CMAKE_OUTPUT" "error"
                print_color "Trying to fix Qt detection issues..." "warning"

                # If cmake failed, try to manually specify Qt path
                QT_PATH=$(qtchooser -print-env | grep QT_SELECT | cut -d= -f2 | tr -d \")
                if [ -n "$QT_PATH" ]; then
                    print_color "Trying with Qt path: $QT_PATH" "info"
                    cmake .. -DQT_QMAKE_EXECUTABLE=$(which qmake)
                else
                    # Last resort: try to find Qt manually
                    QMAKE_PATH=$(find /usr -name qmake-qt5 -o -name qmake 2>/dev/null | head -n 1)
                    if [ -n "$QMAKE_PATH" ]; then
                        print_color "Trying with qmake found at: $QMAKE_PATH" "info"
                        cmake .. -DQT_QMAKE_EXECUTABLE=$QMAKE_PATH
                    else
                        print_color "Could not find Qt installation. Build may fail." "error"
                        cmake ..
                    fi
                fi
            fi
        else
            # Silent mode - just show basic status
            print_color "Configuring build..." "info"

            if ! cmake .. > cmake_output.txt 2>&1; then
                print_color "Error during CMake configuration, trying alternative approach..." "warning"

                # Try with qmake if initial cmake failed
                QMAKE_PATH=$(find /usr -name qmake-qt5 -o -name qmake 2>/dev/null | head -n 1)
                if [ -n "$QMAKE_PATH" ]; then
                    cmake .. -DQT_QMAKE_EXECUTABLE=$QMAKE_PATH >> cmake_output.txt 2>&1
                else
                    # Last attempt without special options
                    cmake .. >> cmake_output.txt 2>&1
                fi
            fi
        fi
    fi

    # Check if Makefile was generated
    if [ ! -f "Makefile" ]; then
        print_color "Error: CMake failed to generate Makefile." "error"
        if [ -f "cmake_output.txt" ]; then
            print_color "Check cmake_output.txt for details." "error"
        fi
        exit 1
    fi

    # Build with all available CPU cores
    print_color "Compiling (this may take a while)..." "info"

    if [ "$VERBOSE" = true ]; then
        make -j$(nproc) 2>&1 | tee make_output.txt
    else
        make -j$(nproc) > make_output.txt 2>&1
    fi

    BUILD_RESULT=$?

    if [ $BUILD_RESULT -eq 0 ] && [ -f "monitor-control" ]; then
        print_color "✓ Build complete" "success"
    else
        print_color "⚠ Build failed or executable not found" "error"
        if [ -f "make_output.txt" ]; then
            print_color "Please check make_output.txt for details" "error"
        else
            print_color "Please check the error messages above for more details" "error"
        fi
        exit 1
    fi
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

    # Test if the application was built successfully
    if [ -f "$INSTALL_DIR/build/monitor-control" ]; then
        print_color "✓ Application binary found at: $INSTALL_DIR/build/monitor-control" "success"
    else
        print_color "⚠ Application binary not found. Installation may have failed." "warning"
    fi

    # Test ddcutil again after setup
    test_ddcutil

    print_color "================================================" "success"
    print_color "   Monitor Brightness Control is now installed!   " "success"
    print_color "================================================" "success"
    print_color "" "info"
    print_color "▶ You can start the application from your desktop menu" "info"
    print_color "  or by running: $INSTALL_DIR/build/monitor-control" "info"
    print_color "" "info"
    print_color "▶ The application will start automatically when you log in" "info"
    print_color "" "info"
    print_color "▶ IMPORTANT: You MUST log out and log back in for the" "warning"
    print_color "  permission changes to take effect" "warning"
    print_color "" "info"
    print_color "▶ If you still don't see monitors after logging out and back in:" "info"
    print_color "  1. Check if your monitor supports DDC/CI in its settings menu" "info"
    print_color "  2. Run 'ddcutil detect' to see if monitors are detected" "info"
    print_color "  3. Try a different cable (some HDMI/DP cables have issues)" "info"
    print_color "" "info"
}

# Display help message
show_help() {
    echo "Monitor Brightness Control Installer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --verbose    Show detailed output during installation"
    echo "  --help       Display this help message and exit"
    echo ""
    echo "Example:"
    echo "  $0 --verbose"
    echo ""
}

# Run all steps
main() {
    # Check for help flag
    for arg in "$@"; do
        if [ "$arg" = "--help" ] || [ "$arg" = "-h" ]; then
            show_help
            exit 0
        fi
    done

    # Ensure script is not run as root
    if [ "$EUID" -eq 0 ]; then
        print_color "Please do not run this script as root or with sudo." "error"
        exit 1
    fi

    print_banner

    # Show verbose mode status
    if [ "$VERBOSE" = true ]; then
        print_color "Verbose mode: ON" "info"
    fi

    check_system
    install_dependencies
    setup_permissions
    clone_repository
    build_application
    create_desktop_entry
    finalize_installation
}

# Start installation with all arguments
main "$@"