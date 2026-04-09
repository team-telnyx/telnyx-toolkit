#!/usr/bin/env python3
"""
Proof of Work solver for Telnyx bot signup challenge.

Supported algorithms
--------------------
- sha256  : Uses hashlib.sha256. No challenge_config params needed.
- scrypt  : Memory-hard. Uses hashlib.scrypt (requires OpenSSL-linked
            Python — see note below). Reads N, r, p from challenge_config.

Extensibility
-------------
If the server returns an `algorithm` value not listed above, use the SHA-256
and scrypt implementations below as a reference. The protocol is always the
same brute-force loop — only the hash primitive changes. Use the algorithm
name and `challenge_config` keys to understand which hash function to call
and how to parameterize it.

macOS note on scrypt
--------------------
macOS ships Python linked against LibreSSL, which does NOT expose
hashlib.scrypt. If you see an AttributeError on `hashlib.scrypt`, you need
an OpenSSL-linked Python:

    brew install python   # then use /opt/homebrew/bin/python3
    # — or —
    run the solver on Linux

CLI usage
---------
    python3 pow_solver.py <nonce> <leading_zero_bits> [algorithm] [challenge_config_json]

Examples:
    # SHA-256 (default)
    python3 pow_solver.py "abc123..." 22

    # scrypt
    python3 pow_solver.py "abc123..." 16 scrypt '{"n": 4096, "r": 8, "p": 1}'
"""

import hashlib
import json
import sys


def _count_leading_zero_bits(digest_hex: str) -> int:
    """Return the number of leading zero bits in a hex digest string."""
    digest_int = int(digest_hex, 16)
    total_bits = len(digest_hex) * 4  # each hex char = 4 bits
    if digest_int == 0:
        return total_bits
    return total_bits - digest_int.bit_length()


def solve_sha256(nonce: str, leading_zero_bits: int) -> int:
    """Solve PoW using SHA-256."""
    for i in range(0, 2**63):
        if i > 0 and i % 1000 == 0:
            print(".", end="", flush=True, file=sys.stderr)
        digest = hashlib.sha256(f"{nonce}{i}".encode()).hexdigest()
        if _count_leading_zero_bits(digest) >= leading_zero_bits:
            if i >= 1000:
                print(file=sys.stderr)  # newline after progress dots
            return i
    raise RuntimeError("No solution found within search space")


def solve_scrypt(nonce: str, leading_zero_bits: int, config: dict) -> int:
    """
    Solve PoW using scrypt.

    Parameters are read from challenge_config:
      - n  : CPU/memory cost factor (e.g. 4096)
      - r  : block size (e.g. 8)
      - p  : parallelisation factor (e.g. 1)

    The salt is the nonce string encoded as UTF-8 bytes.
    The password is (nonce + str(i)) encoded as UTF-8 bytes.
    """
    if not hasattr(hashlib, "scrypt"):
        print(
            "\nERROR: hashlib.scrypt is not available on this Python installation.\n"
            "macOS ships Python linked against LibreSSL, which does not expose scrypt.\n"
            "To fix this, use an OpenSSL-linked Python:\n"
            "    brew install python   # then use /opt/homebrew/bin/python3\n"
            "    — or — run this solver on Linux.",
            file=sys.stderr,
        )
        sys.exit(1)

    n = config.get("n", 4096)
    r = config.get("r", 8)
    p = config.get("p", 1)

    # The salt is the nonce string itself as UTF-8 bytes (not hex-decoded).
    salt = nonce.encode()

    print(
        f"[scrypt] N={n} r={r} p={p} — solving, please wait...",
        file=sys.stderr,
    )

    for i in range(0, 2**63):
        if i > 0 and i % 1000 == 0:
            print(".", end="", flush=True, file=sys.stderr)
        password = f"{nonce}{i}".encode()
        raw = hashlib.scrypt(password, salt=salt, n=n, r=r, p=p, dklen=32)
        digest_hex = raw.hex()
        if _count_leading_zero_bits(digest_hex) >= leading_zero_bits:
            if i >= 1000:
                print(file=sys.stderr)  # newline after progress dots
            return i
    raise RuntimeError("No solution found within search space")


def solve(
    nonce: str,
    leading_zero_bits: int,
    algorithm: str = "sha256",
    config: dict = None,
) -> int:
    """Dispatch to the correct solver based on algorithm name."""
    if config is None:
        config = {}

    if algorithm == "sha256":
        return solve_sha256(nonce, leading_zero_bits)
    elif algorithm == "scrypt":
        return solve_scrypt(nonce, leading_zero_bits, config)
    else:
        raise ValueError(
            f"Unknown algorithm: {algorithm!r}. "
            "Supported: sha256, scrypt. "
            "If the server returned a new algorithm, use the sha256 and scrypt "
            "implementations as a reference — the loop structure is always the same."
        )


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(
            f"Usage: {sys.argv[0]} <nonce> <leading_zero_bits> [algorithm] [challenge_config_json]",
            file=sys.stderr,
        )
        sys.exit(1)

    nonce = sys.argv[1]
    leading_zero_bits = int(sys.argv[2])
    algorithm = sys.argv[3] if len(sys.argv) > 3 else "sha256"
    config = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}

    solution = solve(nonce, leading_zero_bits, algorithm, config)
    print(solution)
