import './App.css';
import React, { useState, useEffect, ReactElement, useRef } from 'react';
import motokoLogo from './assets/motoko_moving.png';
import motokoShadowLogo from './assets/motoko_shadow.png';
import reactLogo from './assets/bob.png';
import viteLogo from './assets/corn.png';
// import { useQueryCall, useUpdateCall } from '@ic-reactor/react';
import { Principal } from '@dfinity/principal';
// import {Agent, Actor, HttpAgent} from '@dfinity/agent';
import ic from 'ic0';

import { AuthClient } from '@dfinity/auth-client';
import { HttpAgent, Actor, AnonymousIdentity } from '@dfinity/agent';

import { idlFactory as icpFactory } from './declarations/nns-ledger';
import { _SERVICE as bobService } from './declarations/nns-ledger/index.d';

import { idlFactory as reBobFactory } from './declarations/backend';
import { _SERVICE as reBobService } from './declarations/service_hack/service'; // changed to service.d because dfx generate would remove the export line from index.d
import { Stats } from './declarations/backend/backend.did.d';
import { CircularProgress, TextField } from '@mui/material';
import ReBobMintingField from './components/ReBobMintingField';
import ShowTransactionStatus from './components/ShowTransactionStatus';
import BobWithdrawField from './components/BobWithdrawField';

import bigintToFloatString from './bigIntToFloatString';
import PlugLoginHandler from './components/PlugLoginHandler';
import InternetIdentityLoginHandler from './components/InternetIdentityLoginHandler';
import TokenManagement from './components/TokenManagement';

const bobCanisterID =
  process.env.DFX_NETWORK === 'local'
    ? 'bd3sg-teaaa-aaaaa-qaaba-cai'
    : '7pail-xaaaa-aaaas-aabmq-cai';
const reBobCanisterID =
  process.env.DFX_NETWORK === 'local'
    ? 'bkyz2-fmaaa-aaaaa-qaaaq-cai'
    : 'qvwlv-uyaaa-aaaas-aidpq-cai';

function App() {
  const [loading, setLoading] = useState(false);
  // const [icpBalance, setIcpBalance] = useState<bigint>(0n);
  const [bobLedgerBalance, setBobLedgerBalance] = useState<bigint>(0n);
  const [reBobLedgerBalance, setreBobLedgerBalance] = useState<bigint>(0n);

  const [bobLedgerAllowance, setBobLedgerAllowance] = useState<bigint>(0n);
  const [reBobLedgerAllowance, setReBobLedgerAllowance] = useState<bigint>(0n);

  const [share, setShare] = useState<bigint>(0n);
  const [stats, setStats] = useState<Stats | null>(null);

  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [connectionType, setConnectionType] = useState<string>('');

  const [reBobActor, setreBobActor] = useState<reBobService | null>(null);
  // const [reBobActorTemp, setreBobActorTemp] = useState<reBobService | null>(
  //   null
  // );
  const [bobLedgerActor, setBobLedgerActor] = useState<bobService | null>(null);

  const [totalBobHeld, setTotalBobHeld] = useState<string>('');
  const [totalReBobMinted, setTotalReBobMinted] = useState<string>('');

  const [loggedInPrincipal, setLoggedInPrincipal] = useState('');

  const bobFee: bigint = 1_000_000n;
  const reBobFee: bigint = 10_000n;

  const fetchTotalTokens = async () => {
    // const totalBobHeldResponse = await bobLedgerActor.icrc1_balance_of({
    //   owner: Principal.fromText(reBobCanisterID),
    //   subaccount: [],
    // }); // Can't use plug actors as anonymous.

    // We will use the internet identity anonymous calls in the next update. ic0 will work for now.
    const bobIcActor = await ic('7pail-xaaaa-aaaas-aabmq-cai'); // hard coding this because it will work in local still.

    const totalBobHeldResponse = await bobIcActor.call('icrc1_balance_of', {
      owner: Principal.fromText('qvwlv-uyaaa-aaaas-aidpq-cai'), // hard coding this because it won't work with local of reBobCanisterID
      subaccount: [],
    });

    //const totalReBobMintedResponse = await reBobActor.icrc1_total_supply();

    setTotalBobHeld(bigintToFloatString(totalBobHeldResponse, 8));
    //setTotalReBobMinted(bigintToFloatString(totalReBobMintedResponse));
  };

  const cleanUp = () => {
    setLoading(false);
    if (bobLedgerActor && reBobActor) {
      fetchBalances();
      //fetchStats();
    } else {
      console.error('Actors were not loaded when trying to cleanup!');
    }
  };

  useEffect(() => {
    //console.log('Component mounted, waiting for user to log in...');
    fetchTotalTokens();
    // checkLoggedIn();

    //setUpActors(); // can't use plug actors as anonymous?
    //console.log("first time", isConnected);
    //checkConnection();
  }, []); // Dependency array remains empty if you only want this effect to run once on component mount

  useEffect(() => {
    // This code runs after `icpActor` and `icdvActor` have been updated.
    //console.log('actors updated', bobLedgerActor, reBobActor);

    fetchBalances();
    //fetchMinters();
    // Note: If `fetchBalances` depends on `icpActor` or `icdvActor`, you should ensure it's capable of handling null values or wait until these values are not null.
  }, [bobLedgerActor, reBobActor]);

  // useEffect(() => {
  //   // This code runs after `icpActor` and `icdvActor` have been updated.
  //   //console.log("actors updated", icpActor, bobActor, bobLedgerActor, reBobActor);

  //   fetchStats();
  //   //fetchMinters();
  //   // Note: If `fetchBalances` depends on `icpActor` or `icdvActor`, you should ensure it's capable of handling null values or wait until these values are not null.
  // }, [reBobActorTemp]);

  // const fetchStats = async () => {
  //   if (reBobActorTemp != null) {
  //     const stats = await reBobActorTemp.stats();
  //     console.log({ stats });
  //     await setStats(stats);
  //   }
  // };

  const isValidPrincipal = (principalString: string): boolean => {
    try {
      Principal.fromText(principalString);
      return true;
    } catch (error) {
      return false;
    }
  };

  const getBobLedgerBalance = async () => {
    if (bobLedgerActor === null) return;

    if (!isValidPrincipal(loggedInPrincipal)) return;

    const bobLedgerBalanceResponse = await bobLedgerActor.icrc1_balance_of({
      owner: Principal.fromText(loggedInPrincipal),
      subaccount: [],
    });

    //console.log('Fetching balances...', { bobLedgerBalanceResponse });

    setBobLedgerBalance(bobLedgerBalanceResponse);
  };

  const getReBobLedgerBalance = async () => {
    if (reBobActor === null) return;
    if (!isValidPrincipal(loggedInPrincipal)) return;
    const reBobLedgerBalanceResponse = await reBobActor.icrc1_balance_of({
      owner: Principal.fromText(loggedInPrincipal),
      subaccount: [],
    });

    setreBobLedgerBalance(reBobLedgerBalanceResponse);

    //console.log('Fetching balances...', { reBobLedgerBalanceResponse });
  };

  const getBobLedgerAllowance = async () => {
    if (bobLedgerActor === null) return;
    const bobLedgerAllowanceResponse = await bobLedgerActor.icrc2_allowance({
      account: {
        owner: Principal.fromText(loggedInPrincipal),
        subaccount: [],
      },
      spender: { owner: Principal.fromText(reBobCanisterID), subaccount: [] },
    });

    setBobLedgerAllowance(bobLedgerAllowanceResponse.allowance);

    // console.log(
    //   'Fetching balances... (bobLedgerAllowanceResponse)',
    //   bobLedgerAllowanceResponse.allowance
    // ); // Need to add check if response was good.
  };

  const getReBobLedgerAllowance = async () => {
    if (reBobActor === null) return;
    const reBobLedgerAllowanceResponse = await reBobActor.icrc2_allowance({
      account: {
        owner: Principal.fromText(loggedInPrincipal),
        subaccount: [],
      },
      spender: { owner: Principal.fromText(reBobCanisterID), subaccount: [] },
    });

    setReBobLedgerAllowance(reBobLedgerAllowanceResponse.allowance); // Need to add check if response was good.

    // console.log(
    //   'Fetching balances... (reBobLedgerAllowanceResponse)',
    //   reBobLedgerAllowanceResponse.allowance
    // );
  };

  const fetchBalances = async () => {
    //
    // You'd need to replace this with actual logic to instantiate your actors and fetch balances
    // This is a placeholder for actor creation and balance fetching

    fetchTotalTokens();

    //if (!isConnected) return;

    // console.log('Fetching balances...', bobLedgerActor, reBobActor);
    if (bobLedgerActor === null || reBobActor === null) return;
    // Fetch balances (assuming these functions return balances in a suitable format)

    getBobLedgerBalance();
    getReBobLedgerBalance();
    getBobLedgerAllowance();
    getReBobLedgerAllowance();
  };

  const handleFailedWithdraw = async () => {
    setLoading(true);

    //bobWithdraw(reBobLedgerAllowance);

    setLoading(false);
  };

  const handleFailedMint = async () => {
    setLoading(true);

    //bobDeposit(bobLedgerAllowance);

    setLoading(false);
  };

  return (
    <div className="App">
      <div>
        <a href="https://aalgg-jaaaa-aaaak-afkwq-cai.icp0.io/" target="_blank">
          <img src={viteLogo} className="logo vite" alt="Vite logo" />
        </a>
        <a href="https://bob.fun" target="_blank">
          <img src={reactLogo} className="logo react" alt="React logo" />
        </a>
        <a href="https://proposals.networks/" target="_blank">
          <span className="logo-stack">
            <img
              src={motokoShadowLogo}
              className="logo motoko-shadow"
              alt="Motoko logo"
            />
            <img src={motokoLogo} className="logo motoko" alt="Motoko logo" />
          </span>
        </a>
      </div>
      <div>
        <h1>BOB reHASH dapp</h1>
        <h2>Enlarge your Bob</h2>
        <h3>
          Total Bob hashed:{' '}
          {totalBobHeld !== '' ? (
            <>{totalBobHeld} Bob</>
          ) : (
            <>
              <CircularProgress size={16} />
            </>
          )}{' '}
        </h3>
      </div>
      <PlugLoginHandler
        bobCanisterID={bobCanisterID}
        setBobLedgerActor={setBobLedgerActor}
        reBobCanisterID={reBobCanisterID}
        setreBobActor={setreBobActor}
        loading={loading}
        setLoading={setLoading}
        isConnected={isConnected}
        setIsConnected={setIsConnected}
        connectionType={connectionType}
        setConnectionType={setConnectionType}
        setBobLedgerBalance={setBobLedgerBalance}
        setreBobLedgerBalance={setreBobLedgerBalance}
        loggedInPrincipal={loggedInPrincipal}
        setLoggedInPrincipal={setLoggedInPrincipal}
      />

      <InternetIdentityLoginHandler
        bobCanisterID={bobCanisterID}
        setBobLedgerActor={setBobLedgerActor}
        reBobCanisterID={reBobCanisterID}
        setreBobActor={setreBobActor}
        loading={loading}
        setLoading={setLoading}
        isConnected={isConnected}
        setIsConnected={setIsConnected}
        connectionType={connectionType}
        setConnectionType={setConnectionType}
        loggedInPrincipal={loggedInPrincipal}
        setLoggedInPrincipal={setLoggedInPrincipal}
      />
      {!isConnected ? (
        <></>
      ) : (
        <>
          <div
            style={{
              marginTop: '16px',
              flexDirection: 'column',
              display: 'flex',
              alignItems: 'center',
              minWidth: '250px',
              width: 'fit-content', // I can't get it to stop expanding and contracting.
            }}
            className="card"
          >
            <div
              style={{
                border: '3px solid lightgrey',
                padding: '10px',
                width: '100%',
              }}
            >
              <h2>reHASH Bobs:</h2>
              <h3>$Bob Balance: {bigintToFloatString(bobLedgerBalance)}</h3>
              <ReBobMintingField
                loading={loading}
                setLoading={setLoading}
                bobLedgerBalance={bobLedgerBalance}
                bobFee={bobFee}
                isConnected={isConnected}
                reBobCanisterID={reBobCanisterID}
                bobLedgerActor={bobLedgerActor}
                cleanUp={cleanUp}
                reBobActor={reBobActor}
                minimumTransactionAmount={3000000n}
              />

              <p></p>
            </div>
            <div
              style={{
                border: '3px solid lightgrey',
                padding: '10px',
                width: '100%',
                marginTop: '16px',
              }}
            >
              <h2>unHASH reBobs: </h2>
              <h3>
                $reBob Balance: {bigintToFloatString(reBobLedgerBalance, 6)}
              </h3>
              <BobWithdrawField
                loading={loading}
                setLoading={setLoading}
                reBobLedgerBalance={reBobLedgerBalance}
                reBobFee={reBobFee}
                bobFee={bobFee}
                isConnected={isConnected}
                reBobActor={reBobActor}
                reBobCanisterID={reBobCanisterID}
                cleanUp={cleanUp}
              />
            </div>

            <div
              style={{
                border: '3px solid lightgrey',
                padding: '10px',
                width: '100%',
                marginTop: '16px',
              }}
            >
              <TokenManagement
                loading={loading}
                setLoading={setLoading}
                tokens={[
                  {
                    tokenActor: bobLedgerActor,
                    tokenFee: bobFee,
                    tokenTicker: 'Bob',
                    tokenDecimals: 8,
                    tokenLedgerBalance: bobLedgerBalance,
                  },
                  {
                    tokenActor: reBobActor,
                    tokenFee: reBobFee,
                    tokenTicker: 'reBob',
                    tokenDecimals: 6,
                    tokenLedgerBalance: reBobLedgerBalance,
                  },
                ]}
                cleanUp={cleanUp}
                loggedInPrincipal={loggedInPrincipal}
                fetchBalances={fetchBalances}
              />
            </div>
          </div>
        </>
      )}
      <p className="read-the-docs">
        Bitcorn Labs presents: build on Bob Click logos to learn more.
      </p>
    </div>
  );
}

export default App;
