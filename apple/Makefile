# apple/Makefile — builds this Ruby (mkxp-z 3.1.3 + QuestPlay patches) for
# macOS arm64, iOS arm64 (device) and iOS Simulator arm64, and packages the
# three as Ruby-MKXPZ.xcframework.
#
#   make -f apple/Makefile xcframework    # run from the repo root
#   make -f apple/Makefile help           # list all targets
#
# Ruby's own build system is used unchanged: for each platform we run Ruby's
# configure in its own build folder, then Ruby's generated Makefile there
# (recursive make). This file only orchestrates around it and adds the
# Apple-specific steps: one merged embeddable archive per platform, staged
# headers, smoke tests, the xcframework, and the pure-Ruby stdlib export.
#
# Everything generated goes to build-apple/ (gitignored by Ruby's /build*/
# rule), except autogen.sh's output (configure, tool/config.*), which Ruby
# keeps in the source tree and also gitignores.
#
# Requires: Xcode; autoconf (Homebrew) for autogen.sh; /usr/bin/ruby as the
# base Ruby of the macOS build. No network access: this branch's
# gems/bundled_gems is empty, so nothing is downloaded.
#
# Must stay compatible with Apple's GNU Make 3.81.
#
# Build notes:
#   - Order: macOS first. The iOS builds are cross builds and use the macOS
#     build's installed bin/ruby as their base Ruby (it must be the same Ruby
#     version), so they depend on it.
#   - iOS gets NO `make install`: in cross mode rbinstall runs under the fake
#     baseruby (no static exts) and dies at the default-gem step requiring
#     psych.so. Everything needed is taken from the build tree instead; the
#     pure-Ruby stdlib is platform-independent, so the macOS install serves all.
#   - macOS build: NO --build/--host (either flips autoconf into cross mode and
#     install then fails). iOS builds: --host + --build set deliberately; the
#     differing spellings are what turn cross mode on. The actual iOS targeting
#     comes from CC: the SDK (-isysroot) and the min-version flag, which also
#     stamps device vs simulator into every object.
#   - CFLAGS: Ruby 3.1 is not valid C23 → -std=gnu99 on modern clang (mkxp-z's
#     own recipe), plus ruby-build's standard old-ruby insurance.
#   - --disable-shared: only the static library is built. This needs this
#     branch's configure.ac fix: Ruby 3.1 tested $EXTSTATIC before assigning it,
#     so a static build always got "-bundle_loader ''" and the ext build failed
#     with `ld: -bundle_loader missing <path>` (the old workaround was
#     --enable-shared, which built an unused libruby.dylib).
#   - No bundled gems (gems/bundled_gems is empty on this branch, like
#     mkxp-z's): rubygems is disabled and only the core + static exts are
#     embedded, so they'd be dead weight. Their C extensions (rbs, debug) are
#     also always built as loadable bundles, which on iOS can only link against
#     libruby.dylib, i.e. they would break --disable-shared.
#   - fiddle excluded (libffi dependency, iOS-hostile, unneeded). psych NOT
#     excluded: the macOS `make install` needs it (rbinstall's default-gem step
#     loads YAML); free in 3.1 because libyaml is vendored in-tree.
#   - JIT compiled out (--disable-jit-support): impossible on iOS anyway.
#
# App-side notes:
#   - link libz (the zlib extension needs the system zlib) and CoreFoundation
#     (file.c uses it for path normalization).
#   - the pure-Ruby stdlib (`make stdlib` → build-apple/ruby-stdlib) must ship
#     in the app as a folder, put on $LOAD_PATH at boot; without it
#     yaml/json/date etc. raise LoadError (zlib still works, it is static).
#   - embedders MUST boot via ruby_init() → ruby_options() → ruby_exec_node():
#     Init_ext (the static extensions) only runs during ruby_options().

SRC   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
APPLE := $(SRC)/apple
OUT   := $(SRC)/build-apple

MACOS_MIN := 15.4
IOS_MIN   := 18.4

JOBS      ?= $(shell sysctl -n hw.ncpu)
BASE_RUBY ?= /usr/bin/ruby

RUBY_CFLAGS := -std=gnu99 -DRUBY_FUNCTION_NAME_STRING=__func__ -Wno-error=implicit-function-declaration

CONFIG_FLAGS := \
  --disable-shared \
  --enable-install-static-library \
  --with-static-linked-ext \
  --disable-install-doc \
  --disable-rubygems \
  --disable-jit-support \
  --without-gmp \
  --with-out-ext=openssl,readline,pty,ripper,io/console,fiddle

MAC_BUILD   := $(OUT)/macos-arm64
MAC_INSTALL := $(OUT)/install-macos-arm64
IOS_BUILD   := $(OUT)/ios-arm64
SIM_BUILD   := $(OUT)/ios-sim-arm64

CROSS_FLAGS := --host=arm64-apple-darwin --build=aarch64-apple-darwin \
               --with-baseruby=$(MAC_INSTALL)/bin/ruby

# The full configure command per platform, run from its build folder.
# Recursive (=) on purpose: the $$(xcrun …) parts must reach the shell
# unexpanded.
MAC_CONFIGURE = MACOSX_DEPLOYMENT_TARGET=$(MACOS_MIN) CFLAGS="$(RUBY_CFLAGS)" \
  $(SRC)/configure --prefix=$(MAC_INSTALL) --with-baseruby=$(BASE_RUBY) $(CONFIG_FLAGS)

IOS_CONFIGURE = IPHONEOS_DEPLOYMENT_TARGET=$(IOS_MIN) \
  CC="$$(xcrun -f clang) -arch arm64 -isysroot $$(xcrun -sdk iphoneos --show-sdk-path) -miphoneos-version-min=$(IOS_MIN)" \
  CFLAGS="$(RUBY_CFLAGS)" $(SRC)/configure $(CROSS_FLAGS) $(CONFIG_FLAGS)

SIM_CONFIGURE = IPHONEOS_DEPLOYMENT_TARGET=$(IOS_MIN) \
  CC="$$(xcrun -f clang) -arch arm64 -isysroot $$(xcrun -sdk iphonesimulator --show-sdk-path) -mios-simulator-version-min=$(IOS_MIN)" \
  CFLAGS="$(RUBY_CFLAGS)" $(SRC)/configure $(CROSS_FLAGS) $(CONFIG_FLAGS)

SLICES      := $(OUT)/slices
SMOKE       := $(OUT)/smoke
# Written straight into the Swift package (SwiftPM requires a binary target's
# xcframework to live inside the package folder; gitignored there).
XCFRAMEWORK := $(APPLE)/RubyEmbed/Ruby-MKXPZ.xcframework
STDLIB      := $(OUT)/ruby-stdlib

SMOKE_LIBS := -lz -lpthread -ldl -lobjc -framework CoreFoundation

# Our targets run one after another (deterministic order, readable logs);
# the parallelism happens inside each Ruby build via -j$(JOBS).
.NOTPARALLEL:

.PHONY: all help xcframework stdlib macos ios sim ruby-macos ruby-ios ruby-sim clean

all: xcframework stdlib

help:
	@echo "make -f apple/Makefile <target>"
	@echo ""
	@echo "  xcframework  macos + ios + sim slices → $(XCFRAMEWORK)"
	@echo "  stdlib       pure-Ruby stdlib → $(STDLIB)"
	@echo "  all          xcframework + stdlib (default)"
	@echo "  macos | ios | sim   build + merge + headers + smoke-test one slice"
	@echo "  clean        delete build-apple/ and the package's xcframework"
	@echo ""
	@echo "  variables: JOBS=$(JOBS) BASE_RUBY=$(BASE_RUBY)"

# ================================================================ configure
# A git checkout has no configure script; autogen.sh generates it (once, or
# again when configure.ac changes). --install copies tool/config.guess and
# tool/config.sub instead of symlinking them into Homebrew's autoconf, so a
# `brew upgrade` can't leave dangling links behind.

$(SRC)/configure: $(SRC)/configure.ac
	cd $(SRC) && ./autogen.sh --install

# Each build folder records the configure command it was set up with in
# qp-configure-cmd, rewritten only when the command text changes. A build
# folder's Makefile depends on it, so changing a flag above re-runs that
# configure, while an unchanged command leaves the build alone.
FORCE:

$(MAC_BUILD)/qp-configure-cmd: FORCE
	@mkdir -p $(@D)
	@echo '$(MAC_CONFIGURE)' | cmp -s - $@ || echo '$(MAC_CONFIGURE)' > $@

$(IOS_BUILD)/qp-configure-cmd: FORCE
	@mkdir -p $(@D)
	@echo '$(IOS_CONFIGURE)' | cmp -s - $@ || echo '$(IOS_CONFIGURE)' > $@

$(SIM_BUILD)/qp-configure-cmd: FORCE
	@mkdir -p $(@D)
	@echo '$(SIM_CONFIGURE)' | cmp -s - $@ || echo '$(SIM_CONFIGURE)' > $@

# ============================================================== macOS slice

$(MAC_BUILD)/Makefile: $(SRC)/configure $(MAC_BUILD)/qp-configure-cmd
	@echo "==> [macos-arm64] configure"
	cd $(MAC_BUILD) && $(MAC_CONFIGURE)

# Always handed to Ruby's make: only it knows its internal dependencies, and
# it is a quick no-op when nothing changed. Install runs serially, as before.
ruby-macos: $(MAC_BUILD)/Makefile
	@echo "==> [macos-arm64] make + install"
	MACOSX_DEPLOYMENT_TARGET=$(MACOS_MIN) $(MAKE) -C $(MAC_BUILD) -j$(JOBS)
	MACOSX_DEPLOYMENT_TARGET=$(MACOS_MIN) $(MAKE) -C $(MAC_BUILD) -j1 install

# Smoke test: link a minimal embedder against the merged archive, then boot
# the VM and require zlib + yaml (yaml.rb → psych.rb → static psych ext, the
# stdlib-from-disk chain).
macos: ruby-macos
	@echo "==> [macos-arm64] merge + headers + smoke test"
	$(APPLE)/merge-embed.sh $(MAC_BUILD) $(MAC_INSTALL)/lib/libruby.3.1-static.a \
	  $(SLICES)/macos-arm64/libruby-embed.a
	$(APPLE)/stage-headers.sh $(MAC_INSTALL)/include/ruby-3.1.0 $(MAC_INSTALL)/include/ruby-3.1.0 \
	  $(SLICES)/macos-arm64/Headers
	mkdir -p $(SMOKE)
	cc $(APPLE)/smoke.c -mmacosx-version-min=$(MACOS_MIN) \
	  -I $(SLICES)/macos-arm64/Headers -DSTDLIB_DIR='"$(MAC_INSTALL)/lib/ruby/3.1.0"' \
	  -o $(SMOKE)/macos-arm64 $(SLICES)/macos-arm64/libruby-embed.a $(SMOKE_LIBS)
	$(SMOKE)/macos-arm64
	@echo "    smoke OK (VM boots, zlib + yaml load)"

# ========================================================= iOS device slice
# The order-only `| ruby-macos` makes sure the base Ruby exists before this
# configure runs, without forcing a reconfigure every time.

$(IOS_BUILD)/Makefile: $(SRC)/configure $(IOS_BUILD)/qp-configure-cmd | ruby-macos
	@echo "==> [ios-arm64] configure (cross)"
	cd $(IOS_BUILD) && $(IOS_CONFIGURE)

ruby-ios: ruby-macos $(IOS_BUILD)/Makefile
	@echo "==> [ios-arm64] make (cross, no install)"
	IPHONEOS_DEPLOYMENT_TARGET=$(IOS_MIN) $(MAKE) -C $(IOS_BUILD) -j$(JOBS)

# Device binaries can't run here; a successful link proves the archive is
# symbol-complete.
ios: ruby-ios
	@echo "==> [ios-arm64] merge + headers + link test"
	$(APPLE)/merge-embed.sh $(IOS_BUILD) $(IOS_BUILD)/libruby.3.1-static.a \
	  $(SLICES)/ios-arm64/libruby-embed.a
	$(APPLE)/stage-headers.sh $(SRC)/include $(IOS_BUILD)/.ext/include \
	  $(SLICES)/ios-arm64/Headers
	mkdir -p $(SMOKE)
	xcrun -sdk iphoneos clang $(APPLE)/smoke.c -arch arm64 -miphoneos-version-min=$(IOS_MIN) \
	  -I $(SLICES)/ios-arm64/Headers -DSTDLIB_DIR='"/"' \
	  -o $(SMOKE)/ios-arm64 $(SLICES)/ios-arm64/libruby-embed.a $(SMOKE_LIBS)
	@echo "    smoke link OK (run skipped)"

# ====================================================== iOS simulator slice

$(SIM_BUILD)/Makefile: $(SRC)/configure $(SIM_BUILD)/qp-configure-cmd | ruby-macos
	@echo "==> [ios-sim-arm64] configure (cross)"
	cd $(SIM_BUILD) && $(SIM_CONFIGURE)

ruby-sim: ruby-macos $(SIM_BUILD)/Makefile
	@echo "==> [ios-sim-arm64] make (cross, no install)"
	IPHONEOS_DEPLOYMENT_TARGET=$(IOS_MIN) $(MAKE) -C $(SIM_BUILD) -j$(JOBS)

sim: ruby-sim
	@echo "==> [ios-sim-arm64] merge + headers + link test"
	$(APPLE)/merge-embed.sh $(SIM_BUILD) $(SIM_BUILD)/libruby.3.1-static.a \
	  $(SLICES)/ios-sim-arm64/libruby-embed.a
	$(APPLE)/stage-headers.sh $(SRC)/include $(SIM_BUILD)/.ext/include \
	  $(SLICES)/ios-sim-arm64/Headers
	mkdir -p $(SMOKE)
	xcrun -sdk iphonesimulator clang $(APPLE)/smoke.c -arch arm64 -mios-simulator-version-min=$(IOS_MIN) \
	  -I $(SLICES)/ios-sim-arm64/Headers -DSTDLIB_DIR='"/"' \
	  -o $(SMOKE)/ios-sim-arm64 $(SLICES)/ios-sim-arm64/libruby-embed.a $(SMOKE_LIBS)
	@echo "    smoke link OK (run skipped)"

# ============================================================== xcframework
# Built into a staging folder and moved into place, so a failed run never
# leaves a half-written xcframework where apps look for it.

xcframework: macos ios sim
	@echo "==> creating xcframework (macos-arm64 + ios-arm64 + ios-arm64-simulator)"
	rm -rf $(OUT)/staging
	mkdir -p $(OUT)/staging
	xcodebuild -create-xcframework \
	  -library $(SLICES)/macos-arm64/libruby-embed.a   -headers $(SLICES)/macos-arm64/Headers \
	  -library $(SLICES)/ios-arm64/libruby-embed.a     -headers $(SLICES)/ios-arm64/Headers \
	  -library $(SLICES)/ios-sim-arm64/libruby-embed.a -headers $(SLICES)/ios-sim-arm64/Headers \
	  -output $(OUT)/staging/Ruby-MKXPZ.xcframework
	rm -rf $(XCFRAMEWORK)
	mv $(OUT)/staging/Ruby-MKXPZ.xcframework $(XCFRAMEWORK)
	rm -rf $(OUT)/staging
	@echo "    $(XCFRAMEWORK)"

# =================================================================== stdlib
# Pure-Ruby standard library (platform-independent) for bundling into the app.

stdlib: ruby-macos
	@echo "==> exporting stdlib"
	rm -rf $(STDLIB)
	cp -R $(MAC_INSTALL)/lib/ruby/3.1.0 $(STDLIB)
	@echo "    $(STDLIB)"

# ==================================================================== clean

clean:
	rm -rf $(OUT) $(XCFRAMEWORK)
