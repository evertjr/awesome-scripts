#!/bin/bash

# CrossOver GStreamer Patcher
# This script patches CrossOver to use system-wide GStreamer instead of bundled version
# Place the patched winegstreamer.so in the same directory as this script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WINEGSTREAMER_SO="$SCRIPT_DIR/winegstreamer.so"
FINGERPRINT_FILE=".gstreamer_patch_applied"
BACKUP_DIR_NAME="gstreamer-backup"

# Function to print colored output
print_color() {
    color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to find CrossOver applications
find_crossover_apps() {
    local apps=()

    # Look for apps that START with "CrossOver" in /Applications
    while IFS= read -r -d '' app; do
        local app_name=$(basename "$app")
        # Only match apps that start with "CrossOver" (case insensitive)
        if [[ "$app_name" =~ ^[Cc]ross[Oo]ver.*\.app$ ]]; then
            apps+=("$app")
        fi
    done < <(find /Applications -maxdepth 1 -name "*.app" -print0 2>/dev/null)

    printf '%s\n' "${apps[@]}"
}

# Function to check if system GStreamer is installed
check_system_gstreamer() {
    if [[ -d "/Library/Frameworks/GStreamer.framework" ]]; then
        print_color $GREEN "✓ System GStreamer found at /Library/Frameworks/GStreamer.framework"
        return 0
    else
        print_color $RED "✗ System GStreamer not found at /Library/Frameworks/GStreamer.framework"
        print_color $YELLOW "Please install GStreamer from: https://gstreamer.freedesktop.org/download/"
        return 1
    fi
}

# Function to check if app is already patched
is_patched() {
    local app_path="$1"
    local fingerprint_path="$app_path/Contents/SharedSupport/CrossOver/$FINGERPRINT_FILE"
    [[ -f "$fingerprint_path" ]]
}

# Function to get GStreamer libraries to remove/restore
get_gstreamer_libs() {
    local lib64_path="$1"

    # All GStreamer and related libraries that CXPatcher removes
    local libs=(
        "libgst*.dylib"
        "libgio-2.0*.dylib"
        "libglib-2.0*.dylib"
        "libgmodule-2.0*.dylib"
        "libgobject-2.0*.dylib"
        "libgthread-2.0*.dylib"
        "libffi*.dylib"
        "libintl*.dylib"
        "libpcre2*.dylib"
        "gstreamer-1.0"
    )

    local found_items=()
    for pattern in "${libs[@]}"; do
        while IFS= read -r -d '' item; do
            if [[ -e "$item" ]]; then
                found_items+=("$item")
            fi
        done < <(find "$lib64_path" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    done

    printf '%s\n' "${found_items[@]}"
}

# Function to create backup
create_backup() {
    local app_path="$1"
    local crossover_path="$app_path/Contents/SharedSupport/CrossOver"
    local backup_path="$crossover_path/$BACKUP_DIR_NAME"

    print_color $BLUE "Creating backup..."

    # Create backup directory
    mkdir -p "$backup_path/lib64"
    mkdir -p "$backup_path/lib/wine/x86_64-unix"

    # Backup GStreamer libraries
    local lib64_path="$crossover_path/lib64"
    while IFS= read -r item; do
        if [[ -n "$item" ]]; then
            local item_name=$(basename "$item")
            cp -R "$item" "$backup_path/lib64/$item_name"
        fi
    done < <(get_gstreamer_libs "$lib64_path")

    # Backup original winegstreamer.so
    local wine_lib_path="$crossover_path/lib/wine/x86_64-unix"
    if [[ -f "$wine_lib_path/winegstreamer.so" ]]; then
        cp "$wine_lib_path/winegstreamer.so" "$backup_path/lib/wine/x86_64-unix/"
    fi

    print_color $GREEN "✓ Backup created at: $backup_path"
}

# Function to restore from backup
restore_backup() {
    local app_path="$1"
    local crossover_path="$app_path/Contents/SharedSupport/CrossOver"
    local backup_path="$crossover_path/$BACKUP_DIR_NAME"

    if [[ ! -d "$backup_path" ]]; then
        print_color $RED "✗ No backup found for this installation"
        return 1
    fi

    print_color $BLUE "Restoring from backup..."

    # Restore GStreamer libraries
    if [[ -d "$backup_path/lib64" ]]; then
        cp -R "$backup_path/lib64"/* "$crossover_path/lib64/"
    fi

    # Restore original winegstreamer.so
    if [[ -f "$backup_path/lib/wine/x86_64-unix/winegstreamer.so" ]]; then
        cp "$backup_path/lib/wine/x86_64-unix/winegstreamer.so" "$crossover_path/lib/wine/x86_64-unix/"
    fi

    # Remove fingerprint
    rm -f "$crossover_path/$FINGERPRINT_FILE"

    # Remove backup directory
    rm -rf "$backup_path"

    print_color $GREEN "✓ Successfully restored from backup"
}

# Function to apply patch
apply_patch() {
    local app_path="$1"
    local crossover_path="$app_path/Contents/SharedSupport/CrossOver"
    local lib64_path="$crossover_path/lib64"
    local wine_lib_path="$crossover_path/lib/wine/x86_64-unix"

    print_color $BLUE "Applying GStreamer patch..."

    # Create backup first
    create_backup "$app_path"

    # Remove GStreamer libraries
    print_color $BLUE "Removing bundled GStreamer libraries..."
    while IFS= read -r item; do
        if [[ -n "$item" && -e "$item" ]]; then
            print_color $YELLOW "Removing: $(basename "$item")"
            rm -rf "$item"
        fi
    done < <(get_gstreamer_libs "$lib64_path")

    # Replace winegstreamer.so
    if [[ -f "$WINEGSTREAMER_SO" ]]; then
        print_color $BLUE "Replacing winegstreamer.so..."
        cp "$WINEGSTREAMER_SO" "$wine_lib_path/winegstreamer.so"
        print_color $GREEN "✓ winegstreamer.so replaced"
    else
        print_color $RED "✗ winegstreamer.so not found in script directory"
        print_color $YELLOW "Please place the patched winegstreamer.so in the same directory as this script"
        return 1
    fi

    # Create fingerprint
    echo "GStreamer patch applied on $(date)" > "$crossover_path/$FINGERPRINT_FILE"

    print_color $GREEN "✓ GStreamer patch applied successfully"
}

# Function to show app status
show_app_status() {
    local app_path="$1"
    local app_name=$(basename "$app_path")

    if is_patched "$app_path"; then
        print_color $GREEN "✓ $app_name [PATCHED]"
    else
        print_color $YELLOW "○ $app_name [UNPATCHED]"
    fi
}

# Function to patch/unpatch app
process_app() {
    local app_path="$1"
    local app_name=$(basename "$app_path")

    print_color $BLUE "\n=== Processing $app_name ==="

    # Verify CrossOver structure
    local crossover_path="$app_path/Contents/SharedSupport/CrossOver"
    if [[ ! -d "$crossover_path" ]]; then
        print_color $RED "✗ Invalid CrossOver installation: $app_path"
        return 1
    fi

    if is_patched "$app_path"; then
        print_color $YELLOW "App is currently PATCHED. Reverting..."
        restore_backup "$app_path"
    else
        print_color $YELLOW "App is currently UNPATCHED. Applying patch..."
        apply_patch "$app_path"
    fi
}

# Main function
main() {
    print_color $BLUE "CrossOver GStreamer Patcher"
    print_color $BLUE "=========================="

    # Check for system GStreamer
    if ! check_system_gstreamer; then
        exit 1
    fi

    # Find CrossOver applications
    print_color $BLUE "\nScanning for CrossOver applications..."
    crossover_apps=()
    while IFS= read -r app; do
        crossover_apps+=("$app")
    done < <(find_crossover_apps)

    if [[ ${#crossover_apps[@]} -eq 0 ]]; then
        print_color $RED "No CrossOver applications found in /Applications"
        exit 1
    fi

    # Show found applications
    print_color $BLUE "\nFound CrossOver applications:"
    for i in "${!crossover_apps[@]}"; do
        echo -n "$((i+1)). "
        show_app_status "${crossover_apps[$i]}"
    done

    # Show menu
    echo
    print_color $BLUE "Options:"
    print_color $BLUE "a) Process all applications"
    print_color $BLUE "q) Quit"
    echo -n "Select application number, 'a' for all, or 'q' to quit: "

    read -r choice

    case "$choice" in
        q|Q)
            print_color $YELLOW "Exiting..."
            exit 0
            ;;
        a|A)
            for app in "${crossover_apps[@]}"; do
                process_app "$app"
            done
            ;;
        [1-9]*)
            if [[ "$choice" -le ${#crossover_apps[@]} && "$choice" -gt 0 ]]; then
                process_app "${crossover_apps[$((choice-1))]}"
            else
                print_color $RED "Invalid selection"
                exit 1
            fi
            ;;
        *)
            print_color $RED "Invalid selection"
            exit 1
            ;;
    esac

    print_color $GREEN "\n✓ Operation completed successfully!"
    print_color $YELLOW "Note: You may need to restart CrossOver for changes to take effect."
}

# Check if running as root (not recommended)
if [[ $EUID -eq 0 ]]; then
    print_color $RED "Warning: Running as root is not recommended"
    print_color $YELLOW "Press Enter to continue or Ctrl+C to cancel..."
    read
fi

# Run main function
main "$@"
