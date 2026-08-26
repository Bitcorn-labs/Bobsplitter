#!/usr/bin/env python3
"""Generate the Candid argument file for a GLDT VAULT backend upgrade proposal.

Adapted from the Sneed DeFi deploy scripts. The proposal embeds the backend
wasm, which is far too large to paste on a command line, so the argument is
written to a file and passed to `icp canister call` with --args-file.

Usage:
    NEURON_ID="<64 hex chars: your neuron's 32-byte subaccount>" \
    TITLE="Upgrade GLDT VAULT backend" \
    SUMMARY="What this upgrade changes and why." \
    python3 scripts/make_proposal_args.py

Any of NEURON_ID, TITLE and SUMMARY not supplied via the environment are
prompted for interactively (only the missing ones).

This script only ever produces an UPGRADE (mode 3). There is deliberately no
reinstall option: mode 2 wipes canister state, and on this canister that would
destroy every holder's sGLDT balance and permanently orphan the GLDT reserves
backing them. If a reinstall is ever genuinely wanted it should be a separate,
deliberate piece of work -- not a flag one word away from the normal command.

Writes proposal_args/deploy_upgrade.did. The wasm sha256 is appended to the
summary automatically, and is cross-checked against wasm/SHA256SUMS so a stale
or unexpected artifact cannot be proposed by accident.
"""

import hashlib
import os
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
WASM = REPO / "wasm" / "backend.wasm"
SUMS = REPO / "wasm" / "SHA256SUMS"
OUT = REPO / "proposal_args"

# The canister the proposal upgrades: the GLDT VAULT backend, which is also the
# sGLDT ledger. Registered as a dapp of the Sneed DAO SNS (root
# fp274-iaaaa-aaaaq-aacha-cai), which is why SNS governance must act.
TARGET = "i2s4q-syaaa-aaaan-qz4sq-cai"

REPO_URL = "https://github.com/Bitcorn-labs/Bobsplitter"

BUILD_HINT = "DFX_VERSION=0.28.0 dfx build --network ic backend"

# CanisterInstallMode value used by UpgradeSnsControlledCanister.
MODE_UPGRADE = 3


def prompt_required(name: str, prompt_text: str) -> str:
    """Return the env value for ``name`` if set, else prompt for it."""
    value = os.environ.get(name, "")
    if value.strip():
        return value
    while True:
        try:
            entered = input(f"{prompt_text}: ").strip()
        except EOFError:
            print(f"error: {name} not set and no input available", file=sys.stderr)
            print(f'Set it in the environment, e.g. {name}="..."', file=sys.stderr)
            sys.exit(1)
        if entered:
            return entered
        print(f"{name} cannot be empty.", file=sys.stderr)


def parse_neuron_id(neuron_hex: str):
    """Parse a neuron subaccount, returning 32 bytes or ``None`` if invalid."""
    neuron_hex = neuron_hex.strip().lower()
    try:
        neuron_bytes = bytes.fromhex(neuron_hex)
    except ValueError:
        print(f"error: neuron id must be hex characters, got: {neuron_hex!r}", file=sys.stderr)
        return None
    if len(neuron_bytes) != 32:
        print(
            f"error: neuron id must be 32 bytes (64 hex chars), got {len(neuron_bytes)} bytes",
            file=sys.stderr,
        )
        return None
    return neuron_bytes


def prompt_neuron_id() -> bytes:
    """Return the proposing neuron's 32-byte subaccount."""
    from_env = os.environ.get("NEURON_ID", "")
    if from_env.strip():
        neuron_bytes = parse_neuron_id(from_env)
        if neuron_bytes is None:
            sys.exit(1)
        return neuron_bytes
    while True:
        try:
            entered = input("Neuron id (64 hex chars): ")
        except EOFError:
            print("error: NEURON_ID not set and no input available", file=sys.stderr)
            print('Set it in the environment, e.g. NEURON_ID="<64 hex chars>"', file=sys.stderr)
            sys.exit(1)
        neuron_bytes = parse_neuron_id(entered)
        if neuron_bytes is not None:
            return neuron_bytes


def expected_hash() -> str | None:
    """The backend.wasm digest recorded in wasm/SHA256SUMS, if present."""
    if not SUMS.exists():
        return None
    for line in SUMS.read_text().splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == "backend.wasm":
            return parts[0]
    return None


def candid_blob(data: bytes) -> str:
    """Render bytes as a Candid blob literal."""
    return 'blob "' + "".join(f"\\{b:02x}" for b in data) + '"'


def candid_text(text: str) -> str:
    """Render a Python string as a quoted Candid text literal."""
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{escaped}"'


def proposal(subaccount: str, title: str, summary: str, action: str) -> str:
    return f"""(
  record {{
    subaccount = {subaccount};
    command = opt variant {{
      MakeProposal = record {{
        title = {candid_text(title)};
        url = "{REPO_URL}";
        summary = {candid_text(summary)};
        action = opt variant {{
{action}
        }};
      }}
    }};
  }}
)
"""


def main() -> int:
    # Fail fast on the build artifact before prompting for anything.
    if not WASM.exists():
        print(f"error: wasm not found at {WASM}", file=sys.stderr)
        print(f"Run: {BUILD_HINT}", file=sys.stderr)
        return 1

    wasm_bytes = WASM.read_bytes()
    wasm_hash = hashlib.sha256(wasm_bytes).hexdigest()

    # Refuse to build a proposal around an artifact that does not match the
    # committed checksum. A reviewer will verify the module hash against a
    # build of their own, so proposing an unrecorded artifact wastes a vote.
    recorded = expected_hash()
    if recorded is None:
        print(f"warning: no backend.wasm entry in {SUMS}; skipping checksum cross-check",
              file=sys.stderr)
    elif recorded != wasm_hash:
        print("error: wasm does not match the committed checksum", file=sys.stderr)
        print(f"  {WASM}: {wasm_hash}", file=sys.stderr)
        print(f"  {SUMS}: {recorded}", file=sys.stderr)
        print(f"Rebuild with: {BUILD_HINT}", file=sys.stderr)
        return 1

    title = prompt_required("TITLE", "Proposal title")
    summary = prompt_required("SUMMARY", "Proposal summary")
    neuron_bytes = prompt_neuron_id()

    OUT.mkdir(exist_ok=True)
    full_summary = f"{summary}\n\nwasm sha256: {wasm_hash}"

    action = f"""          UpgradeSnsControlledCanister = record {{
            canister_id = opt principal "{TARGET}";
            new_canister_wasm = {candid_blob(wasm_bytes)};
            canister_upgrade_arg = null;
            chunked_canister_wasm = null;
            mode = opt ({MODE_UPGRADE} : int32);
          }}"""

    out_file = OUT / "deploy_upgrade.did"
    out_file.write_text(proposal(candid_blob(neuron_bytes), title, full_summary, action))

    size = out_file.stat().st_size
    print(f"target:      {TARGET}")
    print(f"wasm:        {WASM.relative_to(REPO)}")
    print(f"wasm sha256: {wasm_hash}")
    print(f"wasm bytes:  {len(wasm_bytes):,}")
    print(f"mode:        upgrade ({MODE_UPGRADE})")
    print()
    print(f"wrote {out_file.relative_to(REPO)} ({size:,} bytes)")

    # Each wasm byte renders as a 4-character escape, so the argument file is
    # roughly 4x the wasm. The encoded ingress message is ~1x, and the limit is
    # 2 MB; it is the text-parsing step that is most likely to complain first.
    if len(wasm_bytes) > 1_900_000:
        print()
        print("warning: wasm exceeds ~1.9 MB and may not fit the 2 MB ingress limit.",
              file=sys.stderr)
        print("Consider chunked_canister_wasm instead of new_canister_wasm.",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
