# Squirrel (Godot 4 port) - build, export and run
#
#   make templates   one-time: download + install Godot export templates
#   make web         export the HTML5 build   -> godot/build/web/
#   make serve       serve the web build on http://localhost:8000
#   make macos       export the macOS app     -> godot/build/macos/Squirrel.app (runs full screen)
#   make run         run the game windowed from source
#   make test        headless smoke test
#
# Override the engine path with:  make web GODOT=/path/to/Godot

GODOT   ?= /Applications/Godot.app/Contents/MacOS/Godot
PROJECT := godot
PORT    ?= 8000

WEB_DIR   := $(PROJECT)/build/web
MACOS_DIR := $(PROJECT)/build/macos
MACOS_APP := $(MACOS_DIR)/Squirrel.app

# "4.7.1.stable.official.abc123" -> "4.7.1.stable" (name of the templates folder)
GODOT_VERSION  = $(shell $(GODOT) --version 2>/dev/null | cut -d. -f1-4)
GODOT_RELEASE  = $(shell echo $(GODOT_VERSION) | sed 's/\.stable$$//')-stable
TEMPLATES_ROOT := $(HOME)/Library/Application Support/Godot/export_templates
TEMPLATES_URL   = https://github.com/godotengine/godot-builds/releases/download/$(GODOT_RELEASE)/Godot_v$(GODOT_RELEASE)_export_templates.tpz

.PHONY: help import run test check-templates templates web serve macos run-macos clean

help:
	@sed -n '2,10p' Makefile | sed 's/^# \{0,1\}//'

import:
	@$(GODOT) --headless --path $(PROJECT) --import >/dev/null 2>&1 || true

run: import
	$(GODOT) --path $(PROJECT)

test: import
	$(GODOT) --headless --path $(PROJECT) -s tests/smoke.gd

check-templates:
	@test -d "$(TEMPLATES_ROOT)/$(GODOT_VERSION)" || { \
	  echo "Godot export templates $(GODOT_VERSION) are not installed."; \
	  echo "Run 'make templates' (large download) or install them in the editor:"; \
	  echo "  Editor > Manage Export Templates"; \
	  exit 1; }

# One-time download (the .tpz is large, roughly 1 GB) into the folder Godot looks in.
templates:
	@test -d "$(TEMPLATES_ROOT)/$(GODOT_VERSION)" && echo "Templates $(GODOT_VERSION) already installed." || { \
	  set -e; tmp=$$(mktemp -d); \
	  echo "Downloading $(TEMPLATES_URL)"; \
	  curl -L --fail -o "$$tmp/templates.tpz" "$(TEMPLATES_URL)"; \
	  unzip -q "$$tmp/templates.tpz" -d "$$tmp"; \
	  mkdir -p "$(TEMPLATES_ROOT)"; \
	  rm -rf "$(TEMPLATES_ROOT)/$(GODOT_VERSION)"; \
	  mv "$$tmp/templates" "$(TEMPLATES_ROOT)/$(GODOT_VERSION)"; \
	  rm -rf "$$tmp"; \
	  echo "Installed to $(TEMPLATES_ROOT)/$(GODOT_VERSION)"; }

web: import check-templates
	@mkdir -p $(WEB_DIR)
	$(GODOT) --headless --path $(PROJECT) --export-release "Web" build/web/index.html
	@echo "Web build: $(WEB_DIR)/index.html  (try: make serve)"

serve:
	@test -f $(WEB_DIR)/index.html || { echo "No web build yet - run 'make web' first."; exit 1; }
	@echo "Open http://localhost:$(PORT)  (Ctrl-C to stop)"
	python3 -m http.server $(PORT) --directory $(WEB_DIR)

macos: import check-templates
	@mkdir -p $(MACOS_DIR)
	$(GODOT) --headless --path $(PROJECT) --export-release "macOS" build/macos/Squirrel.app
	@echo "macOS app: $(MACOS_APP)  (try: make run-macos)"

run-macos:
	@test -d $(MACOS_APP) || { echo "No app yet - run 'make macos' first."; exit 1; }
	open $(MACOS_APP)

clean:
	rm -rf $(PROJECT)/build
