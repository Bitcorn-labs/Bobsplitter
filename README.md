#REHASHER & exohashing


fakebob is for testnet only


1 canister on bob subnet for reBOB

dfx canister --network ic create --subnet bkfrj-6k62g-dycql-7h53p-atvkj-zg4to-gaogh-netha-ptybj-ntsgw-rqe

they you should just need to replace the const reBobCanisterID = "bd3sg-teaaa-aaaaa-qaaba-cai"; line in App.tsx with the reBob canister id.
(furst put cycles in ledger princple)

then npm instal

then npm start; it should build 

then go into dfx.json and for the frontend and backend entries you'll need to add something like:

"backend": {
        "id": {
          "ic": "rno2w-sqaaa-aaaaa-aaacq-cai",
        }
      },

But backend will be your rebob canister and frontend will be your front end

then dfx deploy --network ic backend
then dfx deploy --network ic frontend

it should build,

You may need to update the compute allocation of the rebob canister to 1

dfx canister --network ic update-settings backend --compute-allocation 1

This will ensure you get scheduled to run at least every 100 rounds

--

notes:

dfx,json may require reformatting to canister_ids.json

{
  "backend": {
    "ic": "xxx"
  },
  "frontend": {
    "ic": "xxx"
  },
  "rebob": {
    "ic": "xxx"
  }
}


# Vite + React + Motoko

### Get started directly in your browser:

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/rvanasa/vite-react-motoko)

This template gives you everything you need to build a full-stack Web3 application on the [Internet Computer](https://internetcomputer.org/).

For an example of a real-world dapp built using this starter project, check out the [source code](https://github.com/dfinity/feedback) for DFINITY's [Developer Experience Feedback Board](https://dx.internetcomputer.org/).

## 📦 Create a New Project

Make sure that [Node.js](https://nodejs.org/en/) `>= 16` and [`dfx`](https://internetcomputer.org/docs/current/developer-docs/build/install-upgrade-remove) `>= 0.14` are installed on your system.

Run the following commands in a new, empty project directory:

```sh
npx degit rvanasa/vite-react-motoko # Download this starter project
dfx start --clean --background # Run dfx in the background
npm run setup # Install packages, deploy canisters, and generate type bindings

npm start # Start the development server
```

When ready, run `dfx deploy --network ic` to deploy your application to the Internet Computer.

## 🛠️ Technology Stack

- [Vite](https://vitejs.dev/): high-performance tooling for front-end web development
- [React](https://reactjs.org/): a component-based UI library
- [TypeScript](https://www.typescriptlang.org/): JavaScript extended with syntax for types
- [Sass](https://sass-lang.com/): an extended syntax for CSS stylesheets
- [Prettier](https://prettier.io/): code formatting for a wide range of supported languages
- [Motoko](https://github.com/dfinity/motoko#readme): a safe and simple programming language for the Internet Computer
- [Mops](https://mops.one): an on-chain community package manager for Motoko
- [mo-dev](https://github.com/dfinity/motoko-dev-server#readme): a live reload development server for Motoko
- [@ic-reactor](https://github.com/B3Pay/ic-reactor): A suite of JavaScript libraries for seamless frontend development on the Internet Computer

## 📚 Documentation

- [Vite developer docs](https://vitejs.dev/guide/)
- [React quick start guide](https://react.dev/learn)
- [Internet Computer docs](https://internetcomputer.org/docs/current/developer-docs/ic-overview)
- [`dfx.json` reference schema](https://internetcomputer.org/docs/current/references/dfx-json-reference/)
- [Motoko developer docs](https://internetcomputer.org/docs/current/developer-docs/build/cdks/motoko-dfinity/motoko/)
- [Mops usage instructions](https://j4mwm-bqaaa-aaaam-qajbq-cai.ic0.app/#/docs/install)
- [@ic-reactor/react](https://b3pay.github.io/ic-reactor/modules/react.html)

## 💡 Tips and Tricks

- Customize your project's code style by editing the `.prettierrc` file and then running `npm run format`.
- Reduce the latency of update calls by passing the `--emulator` flag to `dfx start`.
- Install a Motoko package by running `npx ic-mops add <package-name>`. Here is a [list of available packages](https://mops.one/).
- Split your frontend and backend console output by running `npm run frontend` and `npm run backend` in separate terminals.
