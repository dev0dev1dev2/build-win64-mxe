# This file is part of MXE. See LICENSE.md for licensing information.

PKG             := llvm-mingw
$(PKG)_WEBSITE  := https://github.com/mstorsjo/llvm-mingw
$(PKG)_DESCR    := An LLVM/Clang/LLD based mingw-w64 toolchain
$(PKG)_IGNORE   :=
# https://api.github.com/repos/mstorsjo/llvm-mingw/tarball/ee894b6f6365425ddafec6e8a01173be820f81bf
$(PKG)_VERSION  := ee894b6
$(PKG)_CHECKSUM := c23f741fff77cd4c588b700ce9995271c22ba0e550374dd9afc98378e6513fb0
$(PKG)_PATCHES  := $(realpath $(sort $(wildcard $(dir $(lastword $(MAKEFILE_LIST)))/patches/llvm-mingw-[0-9]*.patch)))
$(PKG)_GH_CONF  := mstorsjo/llvm-mingw/branches/master
$(PKG)_DEPS     := llvm mingw-w64

# Note that the minimum Windows version we support is Windows 7, as libc++ uses
# TryAcquireSRWLockExclusive which didn't exist until Windows 7. See:
# https://github.com/mstorsjo/llvm-mingw/commit/dcf34a9a35ee3d490a85bdec02999cf96615d406
# https://github.com/mstorsjo/llvm-mingw/blob/master/build-mingw-w64.sh#L5-L6
define $(PKG)_BUILD_mingw-w64
    # install mingw-w64 headers
    $(call PREPARE_PKG_SOURCE,mingw-w64,$(BUILD_DIR))
    mkdir '$(BUILD_DIR).headers'
    cd '$(BUILD_DIR).headers' && '$(BUILD_DIR)/$(mingw-w64_SUBDIR)/mingw-w64-headers/configure' \
        --host='$(TARGET)' \
        --prefix='$(PREFIX)/$(TARGET)' \
        --enable-sdk=all \
        --enable-idl \
        --enable-secure-api \
        --with-default-msvcrt=ucrt \
        --with-default-win32-winnt=0x601 \
        $(mingw-w64-headers_CONFIGURE_OPTS)
    $(MAKE) -C '$(BUILD_DIR).headers' install

    # build mingw-w64-crt
    mkdir '$(BUILD_DIR).crt'
    cd '$(BUILD_DIR).crt' && '$(BUILD_DIR)/$(mingw-w64_SUBDIR)/mingw-w64-crt/configure' \
        --host='$(TARGET)' \
        --prefix='$(PREFIX)/$(TARGET)' \
        --with-default-msvcrt=ucrt \
        @mingw-crt-config-opts@ \
        CC='$(PREFIX)/$(TARGET)/bin/clang' \
        STRIP='$(PREFIX)/$(TARGET)/bin/llvm-strip' \
        AR='$(PREFIX)/$(TARGET)/bin/llvm-ar' \
        RANLIB='$(PREFIX)/$(TARGET)/bin/llvm-ranlib' \
        DLLTOOL='$(PREFIX)/$(TARGET)/bin/llvm-dlltool'
    $(MAKE) -C '$(BUILD_DIR).crt' -j '$(JOBS)' || $(MAKE) -C '$(BUILD_DIR).crt' -j '$(JOBS)'
    $(MAKE) -C '$(BUILD_DIR).crt' -j 1 $(INSTALL_STRIP_TOOLCHAIN)

    # install the usual wrappers
    $($(PKG)_POST_BUILD)
endef

define $(PKG)_POST_BUILD
    $(foreach EXEC, clang-target dlltool ld objdump, \
        $(SED) -i -e 's|^DEFAULT_TARGET=.*|DEFAULT_TARGET=$(TARGET)|' \
                  -e 's|^DIR=.*|DIR="$(PREFIX)/$(TARGET)/bin"|' '$(SOURCE_DIR)/wrappers/$(EXEC)-wrapper.sh'; \
        $(INSTALL) -m755 '$(SOURCE_DIR)/wrappers/$(EXEC)-wrapper.sh' '$(PREFIX)/$(TARGET)/bin';)

    $(foreach EXEC, clang clang++ gcc g++ cc c99 c11 c++, \
        ln -sf '$(PREFIX)/$(TARGET)/bin/clang-target-wrapper.sh' '$(PREFIX)/bin/$(TARGET)-$(EXEC)';)

    $(BUILD_CC) $(SOURCE_DIR)/wrappers/windres-wrapper.c \
        -o '$(PREFIX)/bin/$(TARGET)-windres' \
        -O2 -Wl,-s -DLLVM_RC="\"rc\"" -DLLVM_CVTRES="\"cvtres\"" -DDEFAULT_TARGET="\"$(TARGET)\""

    # Can't symlink here, it will break the basename detection of LLVM. See:
    # sys::path::stem("x86_64-w64-mingw32.shared-ranlib"); -> x86_64-w64-mingw32
    # https://github.com/llvm/llvm-project/blob/9a432161c68774e6c717616e3d688142e89bbb42/llvm/tools/llvm-ar/llvm-ar.cpp#L1181-L1192
    $(foreach EXEC, addr2line ar cvtres nm objcopy ranlib rc strings strip, \
        (echo '#!/bin/sh'; \
         echo 'exec "$(PREFIX)/$(TARGET)/bin/llvm-$(EXEC)" "$$@"') \
                 > '$(PREFIX)/bin/$(TARGET)-$(EXEC)'; \
        chmod 0755 '$(PREFIX)/bin/$(TARGET)-$(EXEC)';)

    $(foreach EXEC, dlltool ld objdump, \
        ln -sf '$(PREFIX)/$(TARGET)/bin/$(EXEC)-wrapper.sh' '$(PREFIX)/bin/$(TARGET)-$(EXEC)';)
endef

$(PKG)_BUILD_x86_64-w64-mingw32 = $(subst @mingw-crt-config-opts@,--disable-lib32 --enable-lib64,$($(PKG)_BUILD_mingw-w64))
$(PKG)_BUILD_i686-w64-mingw32   = $(subst @mingw-crt-config-opts@,--enable-lib32 --disable-lib64,$($(PKG)_BUILD_mingw-w64))

# TODO: These targets needs to be tested
$(PKG)_BUILD_armv7-w64-mingw32    = $(subst @mingw-crt-config-opts@,--disable-lib32 --disable-lib64 --enable-libarm32,$($(PKG)_BUILD_mingw-w64))
$(PKG)_BUILD_aarch64-w64-mingw32  = $(subst @mingw-crt-config-opts@,--disable-lib32 --disable-lib64 --enable-libarm64,$($(PKG)_BUILD_mingw-w64))