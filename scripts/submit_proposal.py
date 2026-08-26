#!/usr/bin/env python3
"""Submit the GLDT VAULT backend upgrade proposal to Sneed DAO SNS governance.

Adapted from the Sneed DeFi deploy scripts. Reads the Candid argument file
produced by scripts/make_proposal_args.py and submits it to the SNS governance
canister's manage_neuron method via `icp canister call`.

Usage:
    python3 scripts/submit_proposal.py [--identity NAME] [--network NAME]
                                       [--yes] [--dry-run]

Generate the argument file first with scripts/make_proposal_args.py.

This submits an UPGRADE only. There is deliberately no reinstall path; see the
note in make_proposal_args.py.

The calling identity must control the proposing neuron -- manage_neuron is
authorised against the neuron's permissioned principals, not against the
canister's controllers.
"""

import argparse
import pathlib
import shlex
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
OUT = REPO / "proposal_args"

# Sneed DAO SNS governance; its manage_neuron method submits the proposal.
# Verified as the governance canister of the SNS whose root,
# fp274-iaaaa-aaaaq-aacha-cai, is the sole controller of the target below.
GOVERNANCE = "fi3zi-fyaaa-aaaaq-aachq-cai"

# The canister the proposal upgrades.
TARGET = "i2s4q-syaaa-aaaan-qz4sq-cai"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Submit the GLDT VAULT backend upgrade proposal to Sneed DAO governance."
    )
    parser.add_argument(
        "--identity",
        help="icp identity to submit as; must control the proposing neuron "
        "(default: icp's currently selected identity)",
    )
    parser.add_argument("--network", default="ic", help="network to target (default: ic)")
    parser.add_argument("--yes", action="store_true", help="skip the confirmation prompt")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the icp command without running it",
    )
    args = parser.parse_args()

    did_file = OUT / "deploy_upgrade.did"
    if not did_file.exists():
        print(f"error: argument file not found at {did_file}", file=sys.stderr)
        print("Generate it first: python3 scripts/make_proposal_args.py", file=sys.stderr)
        return 1

    cmd = [
        "icp", "canister", "call", GOVERNANCE, "manage_neuron",
        "--args-file", str(did_file),
        "--network", args.network,
    ]
    if args.identity:
        cmd += ["--identity", args.identity]

    print(f"mode:       upgrade")
    print(f"args file:  {did_file.relative_to(REPO)} ({did_file.stat().st_size:,} bytes)")
    print(f"governance: {GOVERNANCE}  (Sneed DAO)")
    print(f"upgrades:   {TARGET}  (GLDT VAULT backend / sGLDT ledger)")
    print(f"network:    {args.network}")
    print(f"identity:   {args.identity or '(icp default)'}")
    print()
    print("command:", shlex.join(cmd))
    print()

    if args.dry_run:
        print("dry run: not submitting")
        return 0

    if not args.yes:
        print("This submits a proposal to a live DAO and, if adopted, upgrades a")
        print("canister holding real user funds. The proposal costs the neuron")
        print("0.1 SNEED if it is rejected.")
        try:
            answer = input("Submit this proposal? [y/N] ").strip().lower()
        except EOFError:
            answer = ""
        if answer not in ("y", "yes"):
            print("aborted")
            return 1

    try:
        return subprocess.run(cmd).returncode
    except FileNotFoundError:
        print("error: `icp` not found on PATH", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
