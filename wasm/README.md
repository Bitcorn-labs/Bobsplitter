# Build artifacts

Compiled canister modules for this branch, committed so the deployed code can
be verified against source without rebuilding.

Built from commit `9c545d2` with **dfx 0.28.0** (`DFX_VERSION=0.28.0`).

## Hashes

| Artifact | SHA-256 |
|---|---|
| `backend.wasm` | `b475f126f2459e24cc2107f1d5df51cdff49997e6b5eaf2304fe7bf48f3cc6fc` |
| `frontend.wasm.gz` | `2f73b9e18b992f221a5fbab7fc59d840a9cbc461f7cfe875049f51354d23696c` |

`backend` and `backend-staging` share `backend/Backend.mo` and compile to the
same module, so a single `backend.wasm` covers both. Likewise `frontend` and
`frontend-staging` are the stock dfx asset canister and share one module.

## Deployed state at time of commit

| Canister | ID | On-chain module | Matches |
|---|---|---|---|
| backend-staging | `5r3gp-3iaaa-aaaap-qqaeq-cai` | `b475f126…` | yes |
| frontend-staging | `coqqu-zaaaa-aaaai-q32ma-cai` | `2f73b9e1…` | yes |
| backend (prod) | `i2s4q-syaaa-aaaan-qz4sq-cai` | `88612b28…` | no — older module |
| frontend (prod) | `itrxm-eqaaa-aaaan-qz4ta-cai` | `865eb25d…` | no — older module |

## Reproducing

```bash
DFX_VERSION=0.28.0 dfx build --network ic backend
sha256sum .dfx/ic/canisters/backend/backend.wasm
```

The default dfx (0.31.0) **cannot build this project** — it rejects
`icrc3-mo@0.3.5` with M0219 (implicit transient). 0.27.0 and earlier fail on
`sha2@0.1.4`. Use 0.28.0.

## Note on the frontend module

`frontend.wasm.gz` is the stock dfx asset canister and contains **no** application
code — the UI ships as assets uploaded into it. Its hash is therefore identical
for the production and staging builds and says nothing about which backend the
app targets. Verify a frontend deployment by fetching the live bundle:

```bash
curl -s https://<canister>.icp0.io/ | grep -oE '/assets/index-[a-z0-9]+\.js'
```

Staging must contain `5r3gp-3iaaa-aaaap-qqaeq-cai`; production `i2s4q-syaaa-aaaan-qz4sq-cai`.
