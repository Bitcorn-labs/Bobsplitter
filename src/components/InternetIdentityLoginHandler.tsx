import { idlFactory as reBobFactory } from '../declarations/backend';
import { _SERVICE as reBobService } from '../declarations/service_hack/service'; // changed to service.d because dfx generate would remove the export line from index.d
import { idlFactory as icpFactory } from '../declarations/nns-ledger';
import { _SERVICE as bobService } from '../declarations/nns-ledger/index.d';
import { useEffect, useRef, useState } from 'react';
import { AuthClient } from '@dfinity/auth-client';
import { HttpAgent, Actor, AnonymousIdentity } from '@dfinity/agent';

interface InternetIdentityLoginHandlerProps {
  bobCanisterID: string;
  setBobLedgerActor: (value: bobService | null) => void;
  reBobCanisterID: string;
  setreBobActor: (value: reBobService | null) => void;
  loading: boolean;
  setLoading: (value: boolean) => void;
  isConnected: boolean;
  setIsConnected: (value: boolean) => void;
  connectionType: string;
  setConnectionType: (value: string) => void;
  loggedInPrincipal: string;
  setLoggedInPrincipal: (value: string) => void;
}

const InternetIdentityLoginHandler: React.FC<
  InternetIdentityLoginHandlerProps
> = ({
  bobCanisterID,
  setBobLedgerActor,
  reBobCanisterID,
  setreBobActor,
  loading,
  setLoading,
  isConnected,
  setIsConnected,
  connectionType,
  setConnectionType,
  loggedInPrincipal,
  setLoggedInPrincipal,
}) => {
  const authClientRef = useRef<AuthClient | null>(null);
  const [authClient, setAuthClient] = useState<AuthClient | null>(null);
  const [buttonToggle, setButtonToggle] = useState(false);

  const [identityProvider, setIdentityProvider] = useState<URL | null>(null);

  const setupIdentityProvider = (option: number) => {
    //0 for ic0.app; 1 for internetcomputer.org
    if (process.env.DFX_NETWORK === 'local') {
      setIdentityProvider(
        new URL('http://br5f7-7uaaa-aaaaa-qaaca-cai.localhost:4943')
      );
      return;
    } else if (option === 0) {
      setIdentityProvider(new URL('https://identity.ic0.app/'));
    } else if (option === 1) {
      setIdentityProvider(new URL('https://identity.internetcomputer.org/'));
    }
  };

  const authClientLogin = async () => {
    if (!authClient || !identityProvider) return;

    return new Promise<void>((resolve, reject) => {
      authClient.login({
        identityProvider,
        onSuccess: () => {
          setIsConnected(true); // Set authentication state to true
          setConnectionType('ii');
          resolve(); // Resolve the promise on success
        },
        onError: (error) => {
          console.error('Login failed:', error);
          reject(error); // Reject the promise on error
        },
      });
    });
  };

  const login = async () => {
    setLoading(true);
    await authClientLogin();

    if (!authClient) return;

    const identity = authClient.getIdentity();

    setLoggedInPrincipal(identity.getPrincipal().toString());
    setIsConnected(true);
    setConnectionType('ii');
    await createAgent();
    setLoading(false);
  };

  useEffect(() => {
    if (!identityProvider || !authClient) return;

    login();
  }, [identityProvider]);

  const createAuthClient = async (): Promise<void> => {
    setAuthClient(await AuthClient.create());
  };

  useEffect(() => {
    createAuthClient(); //Need to check if already logged in on refresh!
  }, []);

  const checkLoggedIn = async () => {
    if (!authClient) return;

    const authenticated = await authClient.isAuthenticated();
    if (authenticated) {
      const identity = authClient.getIdentity();

      setLoggedInPrincipal(identity.getPrincipal().toString());
      setIsConnected(true);
      setConnectionType('ii');
      await createAgent();
    }
  };

  useEffect(() => {
    if (!authClient) return;

    checkLoggedIn();
  }, [authClient]);

  const logout = async () => {
    if (!authClient) return;
    if (authClient) {
      await authClient.logout();
      setIsConnected(false);
      setConnectionType('');
      setLoggedInPrincipal('');
      setreBobActor(null);
      setBobLedgerActor(null);
      setIdentityProvider(null);
    }
  };

  const createAgent = async () => {
    if (!authClient) {
      console.log('authClientRef was null in createAgent()');
      return;
    }
    const identity = authClient.getIdentity();

    const agent = new HttpAgent({
      host:
        process.env.DFX_NETWORK === 'local'
          ? 'http://localhost:4943'
          : String(identityProvider) ===
            'https://identity.internetcomputer.org/'
          ? 'https://internetcomputer.org'
          : 'https://ic0.app/', // Will identityProvider work?
      identity: identity,
    });

    if (process.env.DFX_NETWORK === 'local') {
      agent.fetchRootKey();
      console.log('aaa');
    }

    setreBobActor(
      await Actor.createActor(reBobFactory, {
        agent,
        canisterId: reBobCanisterID,
      })
    );

    setBobLedgerActor(
      await Actor.createActor(icpFactory, {
        agent,
        canisterId: bobCanisterID,
      })
    );
  };

  return (
    <div>
      {!isConnected ? (
        <>
          {!buttonToggle ? (
            <button
              disabled={loading}
              onClick={() => {
                setButtonToggle(!buttonToggle);
              }}
            >
              Login with Internet Identity
            </button>
          ) : (
            <>
              <button
                disabled={loading}
                onClick={() => {
                  setupIdentityProvider(0);
                }}
              >
                ic0.app
              </button>
              <button
                disabled={loading}
                onClick={() => {
                  setupIdentityProvider(1);
                }}
              >
                internetcomputer.org
              </button>
            </>
          )}
        </>
      ) : connectionType === 'ii' ? (
        <>
          <p>
            Your Internet Identity Principal is <br />
            {loggedInPrincipal}
          </p>
          <button onClick={logout}>Logout</button>
        </>
      ) : (
        <></>
      )}
    </div>
  );
};

export default InternetIdentityLoginHandler;
