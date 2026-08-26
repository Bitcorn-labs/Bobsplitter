#!/usr/bin/env python3
"""Submit the GLDT VAULT backend upgrade proposal to Sneed DAO SNS governance.

Adapted from the Sneed DeFi deploy scripts. Reads the Candid argument file
produced by scripts/make_proposal_args.py and submits it to the SNS governance
canister's manage_neuron method.

Usage:
    python3 scripts/submit_proposal.py [--cli dfx|icp] [--identity NAME]
                                       [--network NAME] [--yes] [--dry-run]

Generate the argument file first with scripts/make_proposal_args.py.

This submits an UPGRADE only. There is deliberately no reinstall path; see the
note in make_proposal_args.py.

The calling identity must control the proposing neuron -- manage_neuron is
authorised against the neuron's permissioned principals, not against the
canister's controllers. It defaults to dfx for that reason: the neuron is held
by a dfx identity, and an encrypted icp-cli identity cannot sign at all without
an interactive terminal to prompt for its password.
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
        help="identity to submit as; must control the proposing neuron "
        "(default: the selected identity of whichever CLI is used)",
    )
    parser.add_argument(
        "--cli",
        choices=("dfx", "icp"),
        default="dfx",
        help="which CLI signs and sends the call (default: dfx)",
    )
    parser.add_argument("--network", default="ic", help="network to target (default: ic)")
    parser.add_argument("--yes", action="store_true", help="skip the confirmation prompt")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the command without running it",
    )
    args = parser.parse_args()

    did_file = OUT / "deploy_upgrade.did"
    if not did_file.exists():
        print(f"error: argument file not found at {did_file}", file=sys.stderr)
        print("Generate it first: python3 scripts/make_proposal_args.py", file=sys.stderr)
        return 1

    # Both CLIs can do this; they differ in flag placement and in the argument
    # flag's name. dfx is the default because the proposing neuron is held by a
    # dfx identity -- an encrypted icp-cli identity cannot sign without a TTY to
    # prompt for its password, which rules it out of any non-interactive run.
    if args.cli == "dfx":
        cmd = [
            "dfx", "canister", "--network", args.network, "call",
            GOVERNANCE, "manage_neuron",
            "--argument-file", str(did_file),
        ]
    else:
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
    print(f"cli:        {args.cli}")
    print(f"identity:   {args.identity or f'({args.cli} default)'}")
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
        print(f"error: `{args.cli}` not found on PATH", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
