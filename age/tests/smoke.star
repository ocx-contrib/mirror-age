# age/tests/smoke.star — stable across upstream age releases.
#
# age is an encryption tool, so the contract is a ROUND TRIP: generate a key,
# encrypt a known plaintext, decrypt it, get the same bytes back. A round trip
# is passthrough-shaped on its own — a binary that merely copied its input
# would pass it — so every leg below is paired with a NEGATIVE CONTROL: the
# ciphertext must not contain the plaintext, the wrong key must not decrypt,
# malformed input must exit non-zero. All four declared binaries are exercised
# functionally, not just for liveness. Never asserts help/version prose.

EXE = ".exe" if ocx.target_platform.os == ocx.os.Windows else ""
AGE = "age" + EXE
KEYGEN = "age-keygen" + EXE
INSPECT = "age-inspect" + EXE
PLUGIN = "age-plugin-batchpass" + EXE

# Tier 1 + 2: every declared binary is on the composed PATH and reports a
# version SHAPE. Not the banner, not the exact version — the digits are the
# contract. (`for` is legal inside a `def`; a top-level `for` STATEMENT is a
# parse error in this Bazel dialect and would red every leg at load time.)
def check_all_binaries_live():
    for tool in [AGE, KEYGEN, INSPECT, PLUGIN]:
        r = ocx.run(tool, "--version")
        expect.ok(r)
        expect.matches(r.stdout, r"\d+\.\d+\.\d+")

check_all_binaries_live()

# Tier 3a: age-keygen must emit a real X25519 identity — a fixed-length bech32
# public key, not merely some output. The parsed key is what every assertion
# below runs on, so a garbled one fails here rather than silently downgrading
# the round trip.
r_key = ocx.run(KEYGEN)
expect.ok(r_key)
KEY_TEXT = r_key.stdout.replace("\r", "")
ocx.write_file("key.txt", KEY_TEXT)

PUB_KEYS = [
    line[len("# public key: "):]
    for line in KEY_TEXT.split("\n")
    if line.startswith("# public key: ")
]
expect.eq(len(PUB_KEYS), 1)
PUB = PUB_KEYS[0]
# age public keys are bech32 over a fixed 32-byte payload: "age1" + 58 chars.
expect.matches(PUB, r"^age1[0-9a-z]{58}$")
expect.matches(KEY_TEXT, r"AGE-SECRET-KEY-1[0-9A-Z]{58}")

# Tier 3b: the round trip. --armor keeps the ciphertext UTF-8 so it can be read
# back and inspected; the payload length (30 bytes) is asserted through
# age-inspect further down.
PLAINTEXT = "ocx-age-smoke: attack at dawn\n"
ocx.write_file("msg.txt", PLAINTEXT)

r_enc = ocx.run(AGE, "--armor", "--recipient", PUB, "--output", "msg.age", "msg.txt")
expect.ok(r_enc)

CIPHERTEXT = ocx.read_file("msg.age").replace("\r", "")
expect.contains(CIPHERTEXT, "-----BEGIN AGE ENCRYPTED FILE-----")
# NEGATIVE CONTROL — the half `expect.ok` cannot see. A tool that just copied
# its input would satisfy every "it round-tripped" assertion; the plaintext
# must NOT survive into the ciphertext.
expect.false("attack at dawn" in CIPHERTEXT)

r_dec = ocx.run(AGE, "--decrypt", "--identity", "key.txt", "--output", "out.txt", "msg.age")
expect.ok(r_dec)
expect.eq(ocx.read_file("out.txt").replace("\r", ""), PLAINTEXT)

# Tier 3c: NEGATIVE CONTROL — a DIFFERENT identity must not open the file.
# Without this, a binary that ignored the identity entirely would still pass.
r_key2 = ocx.run(KEYGEN)
expect.ok(r_key2)
ocx.write_file("wrong-key.txt", r_key2.stdout.replace("\r", ""))
r_wrong = ocx.run(AGE, "--decrypt", "--identity", "wrong-key.txt", "--output", "never.txt", "msg.age")
expect.ne(r_wrong.exit_code, 0)

# Tier 3d: NEGATIVE CONTROL — malformed ciphertext must be rejected by both the
# decryptor and the inspector, not silently passed through.
ocx.write_file("junk.age", "not an age file at all\n")
r_junk = ocx.run(AGE, "--decrypt", "--identity", "key.txt", "junk.age")
expect.ne(r_junk.exit_code, 0)
r_junk_ins = ocx.run(INSPECT, "junk.age")
expect.ne(r_junk_ins.exit_code, 0)

# Tier 3e: age-inspect, asserted on its MACHINE-READABLE output rather than its
# prose report. Every value here is computed from the file produced above — the
# recipient stanza type, the armor flag, and the exact payload size, which is
# len(PLAINTEXT) == 30 bytes.
r_ins = ocx.run(INSPECT, "--json", "msg.age")
expect.ok(r_ins)
expect.matches(r_ins.stdout, r'"version":\s*"age-encryption\.org/v1"')
expect.matches(r_ins.stdout, r'"stanza_types":\s*\[\s*"X25519"\s*\]')
expect.matches(r_ins.stdout, r'"armor":\s*true')
expect.matches(r_ins.stdout, r'"max_payload":\s*30')

# Tier 3f: age-plugin-batchpass is an age PLUGIN, so the honest exercise is a
# full round trip THROUGH it: `-j batchpass` makes age resolve
# `age-plugin-batchpass` off the composed PATH and speak the plugin protocol to
# it. The scrypt work factor is pinned to 1 — the default 18 is deliberately
# slow and would dominate the test's runtime.
PASSPHRASE = "ocx-smoke-correct-horse-battery-staple"
r_penc = ocx.run(
    AGE, "--encrypt", "--armor", "-j", "batchpass", "--output", "pp.age", "msg.txt",
    env = {"AGE_PASSPHRASE": PASSPHRASE, "AGE_PASSPHRASE_WORK_FACTOR": "1"},
)
expect.ok(r_penc)
PP_CIPHERTEXT = ocx.read_file("pp.age").replace("\r", "")
expect.contains(PP_CIPHERTEXT, "-----BEGIN AGE ENCRYPTED FILE-----")
expect.false("attack at dawn" in PP_CIPHERTEXT)

r_pdec = ocx.run(
    AGE, "--decrypt", "-j", "batchpass", "--output", "pp.txt", "pp.age",
    env = {"AGE_PASSPHRASE": PASSPHRASE},
)
expect.ok(r_pdec)
expect.eq(ocx.read_file("pp.txt").replace("\r", ""), PLAINTEXT)

# NEGATIVE CONTROL — the wrong passphrase must not open the file.
r_pbad = ocx.run(
    AGE, "--decrypt", "-j", "batchpass", "--output", "ppbad.txt", "pp.age",
    env = {"AGE_PASSPHRASE": "not-the-passphrase"},
)
expect.ne(r_pbad.exit_code, 0)

# The scrypt stanza is the receipt that the PLUGIN produced this file: the
# X25519 round trip above yields "X25519", and a missing plugin binary would
# have failed `-j batchpass` outright rather than reaching here.
r_pins = ocx.run(INSPECT, "--json", "pp.age")
expect.ok(r_pins)
expect.matches(r_pins.stdout, r'"stanza_types":\s*\[\s*"scrypt"\s*\]')

# No Tier 4: metadata.json declares PATH only (proven by Tier 1 liveness).
