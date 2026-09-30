# Shortcuts for working on the project. Nothing here is needed to use it.
#   make run        start it (Ctrl+C to stop); uses the real config dir
#   make sandbox    start it with a throwaway config dir, so your layout is untouched
#   make edit       open the editor in a running instance
#   make test       run every test
#   make showcase   start it showing every module at every size (page 0; PAGE=1 for the rest)
QS ?= quickshell
PAGE ?= 0
SANDBOX ?= /tmp/dwc-sandbox

.PHONY: run sandbox edit test showcase

run:
	$(QS) -p .

sandbox:
	DWC_CONFIG_DIR=$(SANDBOX) $(QS) -p .

edit:
	$(QS) -p . ipc call desktopWidgets toggle

test:
	sh tests/run.sh

showcase:
	python3 tools/showcase.py $(SANDBOX)-showcase $(PAGE)
	DWC_CONFIG_DIR=$(SANDBOX)-showcase $(QS) -p .
