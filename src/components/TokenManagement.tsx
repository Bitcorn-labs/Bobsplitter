import React, { useEffect, useState } from 'react';
import { _SERVICE as bobService } from '../declarations/nns-ledger/index.d';
import { _SERVICE as reBobService } from '../declarations/service_hack/service';
import TransactionBox from './TransactionBox';
import TokenReceive from './TokenReceive';

interface Token {
  tokenActor: bobService | reBobService | null;
  tokenFee: bigint;
  tokenTicker: string;
  tokenDecimals: number;
  tokenLedgerBalance: bigint;
}

interface TokenManagementProps {
  loading: boolean;
  setLoading: (value: boolean) => void;
  tokens: Token[]; // Array of tokens
  cleanUp: () => void;
  loggedInPrincipal: string;
  fetchBalances: () => void;
}

const TokenManagement: React.FC<TokenManagementProps> = ({
  loading,
  setLoading,
  tokens,
  cleanUp,
  loggedInPrincipal,
  fetchBalances,
}) => {
  const [activeTab, setActiveTab] = useState(0); // Use index to track active tab
  const [lastUpdate, setLastUpdate] = useState(Date.now());

  // Function to render the content based on the selected tab
  const renderContent = () => {
    const activeToken = tokens[activeTab];

    return (
      <div>
        <TokenReceive
          activeToken={activeToken}
          loggedInPrincipal={loggedInPrincipal}
        />
        <h2>Send {activeToken.tokenTicker}s:</h2>
        <TransactionBox
          key={activeTab}
          loading={loading}
          setLoading={setLoading}
          tokenActor={activeToken.tokenActor}
          tokenFee={activeToken.tokenFee}
          tokenTicker={activeToken.tokenTicker}
          tokenDecimals={activeToken.tokenDecimals}
          tokenLedgerBalance={activeToken.tokenLedgerBalance}
          cleanUp={cleanUp}
        />
      </div>
    );
  };

  useEffect(() => {
    if (lastUpdate + 2000 < Date.now()) {
      // prevent a lot of unneccessary calls.
      fetchBalances();
      setLastUpdate(Date.now());
    }
  }, [activeTab]);

  return (
    <div>
      {/* Tabs */}
      <div style={{ display: 'flex', borderBottom: '2px solid #ddd' }}>
        {tokens.map((token, index) => (
          <button
            key={index}
            onClick={() => setActiveTab(index)}
            style={{
              padding: '10px',
              cursor: 'pointer',
              border: activeTab === index ? '2px solid #646cff' : 'none',
              color: activeTab === index ? '' : '',
              borderBottom: activeTab === index ? '2px solid #646cff' : 'none',
              outline: 'none',
              width: '50%',
            }}
          >
            {index === 0 ? `$${token.tokenTicker}` : `$${token.tokenTicker}`}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      <div style={{ padding: '20px' }}>{renderContent()}</div>
    </div>
  );
};

export default TokenManagement;
