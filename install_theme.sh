#!/bin/bash

# Minegrub Theme Installation Script
# Supports both interactive mode and command-line arguments

set -e

# Default configuration
CHOOSE_BACKGROUND=false
INSTALL_SERVICE=false
INSTALL_CONSOLE_BG=false
INTERACTIVE_MODE=true
UNINSTALL=false

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -t, --theme-only     Install theme only (non-interactive)"
    echo "  -s, --service        Install auto-update service"
    echo "  -b, --background     Choose background"
    echo "  -u, --uninstall      Uninstall theme"
    echo "  -h, --help           Show help"
    echo
    echo "Note: Any option activates non-interactive mode"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--theme-only)
            INTERACTIVE_MODE=false
            shift
            ;;
        -b|--background)
            CHOOSE_BACKGROUND=true
            INTERACTIVE_MODE=false
            shift
            ;;
        -s|--service)
            INSTALL_SERVICE=true
            INTERACTIVE_MODE=false
            shift
            ;;
        -u|--uninstall)
            UNINSTALL=true
            INTERACTIVE_MODE=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for help"
            exit 1
            ;;
    esac
done

# requires to be run as root, unless the user has access to the theme folder
if [[ `id -u` -ne 0 ]] ; then
	echo "Must be run as root!"
	exit 1
fi 

# this should be the directory of the clones repo
SCRIPT_DIR="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
# I accidentally deleted the above line once and it copied / into the theme folder, so lets prevent this
if [[ -z $SCRIPT_DIR ]] ; then echo "Something didn't work, exiting"; exit 1; fi

# check if the grub folder is called grub/ or grub2/
if [ -d /boot/grub ]    ; then
	grub_path="/boot/grub"
elif [ -d /boot/grub2 ] ; then
	grub_path="/boot/grub2"
else 
	echo "Can't find a /boot/grub or /boot/grub2 folder. Exiting."
	exit 1
fi
theme_path="$grub_path/themes/minegrub"

# Handle uninstall
if [[ "$UNINSTALL" = true ]]; then
    echo "Removing Minegrub theme..."
    rm -rf "$theme_path" 2>/dev/null || true
    sed -i 's|^GRUB_THEME=.*|#GRUB_THEME=|' /etc/default/grub 2>/dev/null || true
    rm -f /etc/systemd/system/minegrub-update.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    echo "✓ Theme removed. Run 'sudo grub-mkconfig -o $grub_path/grub.cfg' to apply."
    exit 0
fi

## Background Selection
if [[ "$INTERACTIVE_MODE" = true && "$CHOOSE_BACKGROUND" = false ]]; then
    read -p "Choose background? [y/N] " -en 1 choose_bg 
    [[ "$choose_bg" =~ y|Y ]] && CHOOSE_BACKGROUND=true
fi

if [[ "$CHOOSE_BACKGROUND" = true ]]; then
    [[ -x "$SCRIPT_DIR/choose_background.sh" ]] && $SCRIPT_DIR/choose_background.sh
fi

## Theme Installation
echo "Installing theme files..."
cd $SCRIPT_DIR && cp -ru ./minegrub $grub_path/themes/

## Systemd Service
if [[ "$INTERACTIVE_MODE" = true && "$INSTALL_SERVICE" = false ]]; then
    read -p "Install auto-update service? [y/N] " -en 1 install_service
    [[ "$install_service" =~ y|Y ]] && INSTALL_SERVICE=true
fi

if [[ "$INSTALL_SERVICE" = true ]]; then
    if [[ -f "$SCRIPT_DIR/minegrub-update.service" ]]; then
        cp -u $SCRIPT_DIR/minegrub-update.service /etc/systemd/system/
        systemctl daemon-reload
        echo "Service installed (enable: systemctl enable minegrub-update.service)"
    fi
fi

## Console Background
if [[ "$INTERACTIVE_MODE" = true && "$INSTALL_CONSOLE_BG" = false ]]; then
    read -p "Enable console background? [y/N] " -en 1 install_console_bg
    [[ "$install_console_bg" =~ y|Y ]] && INSTALL_CONSOLE_BG=true
fi

if [[ "$INSTALL_CONSOLE_BG" = true ]]; then
    cp --no-clobber /etc/grub.d/00_header ./00_header.bak 2>/dev/null || true
    sed --in-place -E 's/(.*)elif(.*"x\$GRUB_BACKGROUND" != x ] && [ -f "\$GRUB_BACKGROUND" ].*)/\1fi; if\2/' /etc/grub.d/00_header
    echo "Console background enabled"
fi


## GRUB Configuration
grub_config="/etc/default/grub"

# Update GRUB_THEME
if grep -q "^GRUB_THEME=" "$grub_config"; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=$theme_path/theme.txt|" "$grub_config"
elif grep -q "^#GRUB_THEME=" "$grub_config"; then
    sed -i "s|^#GRUB_THEME=.*|GRUB_THEME=$theme_path/theme.txt|" "$grub_config"
else
    echo "GRUB_THEME=$theme_path/theme.txt" >> "$grub_config"
fi

# Add GRUB_BACKGROUND if needed
if [[ "$INSTALL_CONSOLE_BG" = true ]] && ! grep -q "^GRUB_BACKGROUND=" "$grub_config"; then
    echo "GRUB_BACKGROUND=$theme_path/dirt.png" >> "$grub_config"
fi

echo
echo "Installation complete!"
echo "✓ Theme: $theme_path"
echo "✓ GRUB config updated"

[[ "$INSTALL_CONSOLE_BG" = true ]] && echo "✓ Console background enabled"
[[ "$INSTALL_SERVICE" = true ]] && echo "✓ Auto-update service installed"

echo
echo "Next: sudo grub-mkconfig -o $grub_path/grub.cfg && reboot"

