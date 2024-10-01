import { Principal } from '@dfinity/principal';
import { _SERVICE as genericTokenService } from '../declarations/nns-ledger/index.d';
import { TextField, ThemeProvider } from '@mui/material';
import { useEffect, useState } from 'react';
import bigintToFloatString from '../bigIntToFloatString';
import theme from '../theme';

interface TransactionBoxProps {
  loading: boolean;
  setLoading: (value: boolean) => void;
  tokenActor: genericTokenService | null;
  tokenFee: bigint;
  tokenTicker: string;
  tokenDecimals: number;
  tokenLedgerBalance: bigint;
}

const TransactionBox: React.FC<TransactionBoxProps> = ({
  loading,
  setLoading,
  tokenActor,
  tokenFee,
  tokenTicker,
  tokenDecimals,
  tokenLedgerBalance,
}) => {
  const [transactionFieldValue, setTransactionFieldValue] =
    useState<string>('');
  const [transactionFieldNatValue, setTransactionFieldNatValue] =
    useState<bigint>(0n);

  const [buttonDisabled, setButtonDisabled] = useState<boolean>(false);
  const [textFieldValueTooLow, setTextFieldValueTooLow] =
    useState<boolean>(false);
  const [textFieldErrored, setTextFieldErrored] = useState<boolean>(false);

  const minimumTransactionAmount = tokenFee + 1n;

  const transfer = async (amountInE8s: bigint, toPrincipal: Principal) => {
    if (!tokenActor) return;

    try {
      // Call the token actor's icrc1_transfer function
      const result = await tokenActor.icrc1_transfer({
        amount: amountInE8s, // The amount to transfer (must be a bigint)
        to: {
          owner: toPrincipal, // The recipient's principal
          subaccount: [], // Optional, an empty array for no subaccount
        },
        fee: [tokenFee], // Optional fee, default is empty
        memo: [], // Optional memo, default is empty
        from_subaccount: [], // Optional, if you want to specify a subaccount
        created_at_time: [BigInt(Date.now()) * 1000000n],
      });

      // Handle the result
      if ('Ok' in result) {
        console.log(`Transfer successful! Transaction ID: ${result.Ok}`);
        return result.Ok;
      } else if ('Err' in result) {
        console.error('Transfer failed:', result.Err);
        return result.Err;
      }
    } catch (error) {
      console.error('Error during token transfer:', error);
      throw error;
    }
  };

  const handleTransactionFieldChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    const regex = new RegExp(`^\\d*\\.?\\d{0,${tokenDecimals}}$`);
    const newBobFieldValue = event.target.value;

    if (regex.test(newBobFieldValue) || newBobFieldValue === '') {
      setTransactionFieldValue(newBobFieldValue);
    }
  };

  useEffect(() => {
    const decimalMultiplier = 10 ** tokenDecimals;
    const natValue =
      transactionFieldValue && transactionFieldValue !== '.'
        ? BigInt(
            (parseFloat(transactionFieldValue) * decimalMultiplier).toFixed(0)
          ) // Convert to Nat
        : 0n;

    // console.log(bobNatValue);
    setButtonDisabled(natValue + minimumTransactionAmount > tokenLedgerBalance);

    setTextFieldValueTooLow(natValue < minimumTransactionAmount);
    setTextFieldErrored(
      (tokenLedgerBalance < minimumTransactionAmount && natValue > 0) ||
        (tokenLedgerBalance >= minimumTransactionAmount &&
          natValue + minimumTransactionAmount > tokenLedgerBalance)
    );
    setTransactionFieldNatValue(natValue);
  }, [transactionFieldValue, tokenLedgerBalance]);

  const handleTransaction = () => {
    console.log('hi');
  };

  return (
    <ThemeProvider theme={theme}>
      <div
        style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'start',
          width: '100%',
        }}
      >
        <TextField label="principal" />
        <TextField
          label={tokenTicker}
          variant="filled"
          value={transactionFieldValue}
          onChange={handleTransactionFieldChange}
          helperText={
            buttonDisabled
              ? `You don't have enough ${tokenTicker}!`
              : textFieldValueTooLow
              ? `You must input at least ${bigintToFloatString(
                  minimumTransactionAmount,
                  tokenDecimals
                )} to transfer.`
              : ''
          }
          error={textFieldErrored}
          disabled={loading}
          slotProps={{
            input: {
              inputMode: 'decimal', // Helps show the numeric pad with decimal on mobile devices
            },
          }}
          style={{ width: '200px', minHeight: '84px' }} // Set a fixed width or use a percentage
        />
        <button onClick={handleTransaction} style={{ height: '56px' }}>
          SEND
        </button>
      </div>
    </ThemeProvider>
  );
};

export default TransactionBox;
