# Minegrub Theme Makefile

# Variables
GRUB_DIR := $(shell if [ -d /boot/grub ]; then echo "/boot/grub"; elif [ -d /boot/grub2 ]; then echo "/boot/grub2"; else echo ""; fi)
THEME_DIR := $(GRUB_DIR)/themes/minegrub
GRUB_CONFIG := /etc/default/grub

# Check if we have a valid GRUB directory
ifeq ($(GRUB_DIR),)
$(error No GRUB directory found. Expected /boot/grub or /boot/grub2)
endif

# Default target
.PHONY: help
help:
	@echo "Targets:"
	@echo "  install      - Install theme"
	@echo "  uninstall    - Remove theme"
	@echo "  update-grub  - Update GRUB config"
	@echo "  clean        - Clean files"
	@echo "  full         - Install with service"

# Check if running as root
.PHONY: check-root
check-root:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "Error: Must be run as root (use sudo)"; \
		exit 1; \
	fi

# Install theme only
.PHONY: install
install: check-root
	@./install_theme.sh -t

# Remove theme
.PHONY: uninstall
uninstall: check-root
	@./install_theme.sh -u

# Update GRUB configuration
.PHONY: update-grub
update-grub: check-root
	@echo "Updating GRUB configuration..."
	@grub-mkconfig -o $(GRUB_DIR)/grub.cfg
	@echo "✓ GRUB updated successfully!"

# Clean generated files
.PHONY: clean
clean:
	@rm -f *.bak
	@rm -rf ./minegrub/cache 2>/dev/null || true
	@echo "✓ Cleaned generated files"

# Full installation with all features
.PHONY: full
full: check-root
	@./install_theme.sh -t -s

