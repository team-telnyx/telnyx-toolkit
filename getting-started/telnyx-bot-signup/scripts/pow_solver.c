/*
 * pow_solver.c — Proof of Work solver for Telnyx bot signup challenge.
 *
 * Supported algorithms
 * --------------------
 *  sha256  : Uses OpenSSL SHA-256.  No challenge_config params needed.
 *  scrypt  : Memory-hard hash.  Uses OpenSSL EVP_PBE_scrypt (requires
 *            OpenSSL 1.1+ or LibreSSL 3.3+).  Reads n, r, p from
 *            challenge_config JSON.
 *
 * macOS / LibreSSL note
 * ---------------------
 *  The OpenSSL shipped with macOS is actually LibreSSL, which often lacks
 *  EVP_PBE_scrypt.  For scrypt support on macOS either:
 *    brew install openssl   (then compile with OPENSSL_PREFIX=/opt/homebrew/opt/openssl)
 *  or run this solver on Linux.  SHA-256 works fine with LibreSSL.
 *
 * Build
 * -----
 *  See the accompanying Makefile.  Quick start:
 *    make
 *    ./pow_solver <nonce> <leading_zero_bits> [algorithm] [challenge_config_json]
 *
 * Examples
 * --------
 *  # SHA-256 (default)
 *  ./pow_solver "abc123..." 22
 *
 *  # scrypt
 *  ./pow_solver "abc123..." 16 scrypt '{"n":4096,"r":8,"p":1}'
 *
 * Performance vs Python
 * ---------------------
 *  The C solver is typically 10–50x faster than the Python equivalent,
 *  depending on algorithm, hardware, and difficulty level.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>

#include <openssl/sha.h>
#include <openssl/evp.h>

/* ------------------------------------------------------------------ helpers */

static int count_leading_zero_bits(const unsigned char *digest, size_t len) {
    int count = 0;
    for (size_t i = 0; i < len; i++) {
        unsigned char byte = digest[i];
        if (byte == 0) {
            count += 8;
        } else {
            /* count leading zero bits in this byte */
            for (int bit = 7; bit >= 0; bit--) {
                if ((byte >> bit) & 1) return count;
                count++;
            }
            return count;
        }
    }
    return count;
}

/* ------------------------------------------------------------ sha-256 solver */

static int64_t solve_sha256(const char *nonce, int leading_zero_bits) {
    char buf[4096];
    unsigned char digest[SHA256_DIGEST_LENGTH];

    for (int64_t i = 0; i < INT64_MAX; i++) {
        if (i > 0 && i % 1000 == 0) {
            fputc('.', stderr);
            fflush(stderr);
        }

        int len = snprintf(buf, sizeof(buf), "%s%" PRId64, nonce, i);
        if (len < 0 || (size_t)len >= sizeof(buf)) {
            fprintf(stderr, "\nERROR: nonce+counter string too long\n");
            return -1;
        }

        SHA256((unsigned char *)buf, (size_t)len, digest);

        if (count_leading_zero_bits(digest, SHA256_DIGEST_LENGTH) >= leading_zero_bits) {
            if (i >= 1000) fputc('\n', stderr);
            return i;
        }
    }

    fprintf(stderr, "\nERROR: No solution found within search space\n");
    return -1;
}

/* ------------------------------------------------------------- scrypt solver */

static int64_t solve_scrypt(const char *nonce, int leading_zero_bits,
                             uint64_t N, uint64_t r, uint64_t p) {
#if defined(OPENSSL_NO_SCRYPT) || !defined(EVP_PBE_SCRYPT_DEFINED)
    (void)nonce; (void)leading_zero_bits; (void)N; (void)r; (void)p;
    fprintf(stderr,
        "\nERROR: scrypt support was not compiled in.\n"
        "This build was compiled against LibreSSL or an OpenSSL version without scrypt.\n"
        "To use scrypt on macOS:\n"
        "    brew install openssl\n"
        "    make OPENSSL_PREFIX=/opt/homebrew/opt/openssl\n"
        "Or run the Python solver instead:\n"
        "    python3 pow_solver.py <nonce> <bits> scrypt '<config_json>'\n");
    return -1;
#else
    char buf[4096];
    unsigned char out[32];

    fprintf(stderr, "[scrypt] N=%" PRIu64 " r=%" PRIu64 " p=%" PRIu64
            " — solving, please wait...\n", N, r, p);

    for (int64_t i = 0; i < INT64_MAX; i++) {
        if (i > 0 && i % 1000 == 0) {
            fputc('.', stderr);
            fflush(stderr);
        }

        int len = snprintf(buf, sizeof(buf), "%s%" PRId64, nonce, i);
        if (len < 0 || (size_t)len >= sizeof(buf)) {
            fprintf(stderr, "\nERROR: nonce+counter string too long\n");
            return -1;
        }

        /* password = nonce+i, salt = nonce */
        if (EVP_PBE_scrypt(buf, (size_t)len,
                           (unsigned char *)nonce, strlen(nonce),
                           N, r, p, 0,
                           out, sizeof(out)) != 1) {
            fprintf(stderr, "\nERROR: EVP_PBE_scrypt failed\n");
            return -1;
        }

        if (count_leading_zero_bits(out, sizeof(out)) >= leading_zero_bits) {
            if (i >= 1000) fputc('\n', stderr);
            return i;
        }
    }

    fprintf(stderr, "\nERROR: No solution found within search space\n");
    return -1;
#endif
}

/* ----------------------------------------------------------------- JSON mini-parser
 * Extracts a single integer value from a flat JSON object like
 * {"n":4096,"r":8,"p":1} without pulling in a JSON library.
 */
static long json_get_long(const char *json, const char *key, long default_val) {
    /* look for "key": or "key" : */
    char search[64];
    snprintf(search, sizeof(search), "\"%s\"", key);
    const char *pos = strstr(json, search);
    if (!pos) return default_val;
    pos += strlen(search);
    while (*pos == ' ' || *pos == '\t' || *pos == ':') pos++;
    if (*pos == '\0') return default_val;
    return strtol(pos, NULL, 10);
}

/* ---------------------------------------------------------------------- main */

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr,
            "Usage: %s <nonce> <leading_zero_bits> [algorithm] [challenge_config_json]\n"
            "\n"
            "Examples:\n"
            "  # SHA-256 (default)\n"
            "  %s \"abc123...\" 22\n"
            "\n"
            "  # scrypt\n"
            "  %s \"abc123...\" 16 scrypt '{\"n\":4096,\"r\":8,\"p\":1}'\n",
            argv[0], argv[0], argv[0]);
        return 1;
    }

    const char *nonce            = argv[1];
    int         leading_zero_bits = atoi(argv[2]);
    const char *algorithm        = (argc > 3) ? argv[3] : "sha256";
    const char *config_json      = (argc > 4) ? argv[4] : "{}";

    int64_t solution = -1;

    if (strcmp(algorithm, "sha256") == 0) {
        solution = solve_sha256(nonce, leading_zero_bits);
    } else if (strcmp(algorithm, "scrypt") == 0) {
        uint64_t N = (uint64_t)json_get_long(config_json, "n", 4096);
        uint64_t r = (uint64_t)json_get_long(config_json, "r", 8);
        uint64_t p = (uint64_t)json_get_long(config_json, "p", 1);
        solution = solve_scrypt(nonce, leading_zero_bits, N, r, p);
    } else {
        fprintf(stderr,
            "ERROR: Unknown algorithm: %s\n"
            "Supported: sha256, scrypt\n"
            "If the server returned a new algorithm, use the Python solver as a\n"
            "reference — the loop structure is the same.\n", algorithm);
        return 1;
    }

    if (solution < 0) return 1;

    printf("%" PRId64 "\n", solution);
    return 0;
}
