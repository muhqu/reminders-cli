PREFIX ?= $(HOME)/.local
EXECUTABLE = reminders
RELEASE_BUILD = .build/release
ARCHIVE = $(EXECUTABLE).tar.gz

.PHONY: build install uninstall clean package

build:
	swift build -c release

install: build
	install -d $(PREFIX)/bin
	install -m 755 $(RELEASE_BUILD)/$(EXECUTABLE) $(PREFIX)/bin/$(EXECUTABLE)
	@echo "Installed $(EXECUTABLE) to $(PREFIX)/bin/$(EXECUTABLE)"

uninstall:
	rm -f $(PREFIX)/bin/$(EXECUTABLE)
	@echo "Uninstalled $(EXECUTABLE) from $(PREFIX)/bin"

package: build
	$(RELEASE_BUILD)/$(EXECUTABLE) --generate-completion-script zsh > _reminders
	tar -pvczf $(ARCHIVE) _reminders -C $(RELEASE_BUILD) $(EXECUTABLE)
	@shasum -a 256 $(ARCHIVE)
	rm _reminders
	@echo "Package created: $(ARCHIVE)"

clean:
	rm -f $(EXECUTABLE) $(ARCHIVE) _reminders
	swift package clean
