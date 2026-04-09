# Makefile — pow_solver.c
#
# Usage
# -----
#   make                          # build pow_solver
#   make OPENSSL_PREFIX=/path     # build with a specific OpenSSL installation
#   make install                  # install to /usr/local/bin (optional)
#   make clean                    # remove build artifacts
#
# Platform notes
# --------------
#  macOS (LibreSSL)
#    The system OpenSSL is LibreSSL, which typically lacks EVP_PBE_scrypt.
#    SHA-256 works fine.  For scrypt:
#      brew install openssl
#      make OPENSSL_PREFIX=/opt/homebrew/opt/openssl
#
#  Linux (OpenSSL)
#    Both SHA-256 and scrypt work out of the box with OpenSSL >= 1.1.
#    Install: apt install libssl-dev   (Debian/Ubuntu)
#             yum install openssl-devel (RHEL/CentOS)

TARGET  := pow_solver
SRC     := pow_solver.c
CC      ?= cc
CFLAGS  ?= -O2 -std=c99 -Wall -Wextra

# Allow caller to override the OpenSSL prefix
OPENSSL_PREFIX ?=

# ---- detect OpenSSL/LibreSSL prefix if not specified --------------------
ifeq ($(OPENSSL_PREFIX),)
  UNAME := $(shell uname -s)
  ifeq ($(UNAME),Darwin)
    # Prefer Homebrew OpenSSL over system LibreSSL
    BREW_OPENSSL := $(shell brew --prefix openssl 2>/dev/null)
    ifneq ($(BREW_OPENSSL),)
      OPENSSL_PREFIX := $(BREW_OPENSSL)
    endif
  endif
endif

# ---- build flags ---------------------------------------------------------
ifneq ($(OPENSSL_PREFIX),)
  SSL_CFLAGS  := -I$(OPENSSL_PREFIX)/include
  SSL_LDFLAGS := -L$(OPENSSL_PREFIX)/lib -lssl -lcrypto
else
  SSL_CFLAGS  :=
  SSL_LDFLAGS := -lssl -lcrypto
endif

# ---- detect scrypt support at compile time --------------------------------
SCRYPT_CHECK := $(shell echo 'void f(void);void f(void){EVP_PBE_scrypt(0,0,0,0,0,0,0,0,0,0);}int main(void){f();return 0;}' | \
  $(CC) $(SSL_CFLAGS) -include openssl/evp.h -x c - $(SSL_LDFLAGS) -o /dev/null 2>/dev/null \
  && echo yes || echo no)

ifeq ($(SCRYPT_CHECK),yes)
  SCRYPT_DEFINE := -DEVP_PBE_SCRYPT_DEFINED
  SCRYPT_MSG    := scrypt: YES
else
  SCRYPT_DEFINE :=
  SCRYPT_MSG    := scrypt: NO (LibreSSL or old OpenSSL — SHA-256 only)
endif

# ---- targets -------------------------------------------------------------

.PHONY: all clean install info

all: info $(TARGET)

info:
	@echo "OpenSSL prefix : $(if $(OPENSSL_PREFIX),$(OPENSSL_PREFIX),(system))"
	@echo "$(SCRYPT_MSG)"
	@echo ""

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) $(SSL_CFLAGS) $(SCRYPT_DEFINE) -o $@ $< $(SSL_LDFLAGS)
	@echo "Built: $(TARGET)"

install: $(TARGET)
	install -d $(DESTDIR)/usr/local/bin
	install -m 755 $(TARGET) $(DESTDIR)/usr/local/bin/$(TARGET)
	@echo "Installed to /usr/local/bin/$(TARGET)"

clean:
	rm -f $(TARGET) $(TARGET).o
