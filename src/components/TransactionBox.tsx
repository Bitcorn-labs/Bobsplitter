import { Principal } from '@dfinity/principal';
import { _SERVICE as bobService } from '../declarations/nns-ledger/index.d';
import { _SERVICE as reBobService } from '../declarations/service_hack/service';
import { InputAdornment, TextField, ThemeProvider } from '@mui/material';
import { useEffect, useState } from 'react';
import bigintToFloatString from '../bigIntToFloatString';
import theme from '../theme';

interface TransactionBoxProps {
  loading: boolean;
  setLoading: (value: boolean) => void;
  tokenActor: bobService | reBobService | null;
  tokenFee: bigint;
  tokenTicker: string;
  tokenDecimals: number;
  tokenLedgerBalance: bigint;
  cleanUp: () => void;
}

const TransactionBox: React.FC<TransactionBoxProps> = ({
  loading,
  setLoading,
  tokenActor,
  tokenFee,
  tokenTicker,
  tokenDecimals,
  tokenLedgerBalance,
  cleanUp,
}) => {
  const [transactionFieldValue, setTransactionFieldValue] =
    useState<string>('');
  const [transactionFieldNatValue, setTransactionFieldNatValue] =
    useState<bigint>(0n);

  const [buttonDisabled, setButtonDisabled] = useState<boolean>(false);
  const [textFieldValueTooLow, setTextFieldValueTooLow] =
    useState<boolean>(false);
  const [valueFieldErrored, setValueFieldErrored] = useState<boolean>(false);

  const [principalField, setPrincipalField] = useState<string>('');
  const [principalFieldErrored, setPrincipalFieldErrored] =
    useState<boolean>(false);

  const [remainder, setRemainder] = useState<string>('');

  const transfer = async (amountInE8s: bigint, toPrincipal: Principal) => {
    if (!tokenActor) return;

    setLoading(true);

    console.log({ amountInE8s, toPrincipal });

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

      console.log({ result });
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
    } finally {
      cleanUp();
      setTransactionFieldValue('');
      setPrincipalField('');
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
    setButtonDisabled(natValue + tokenFee > tokenLedgerBalance);

    setTextFieldValueTooLow(natValue < tokenFee);
    setValueFieldErrored(
      (tokenLedgerBalance < tokenFee && natValue > 0) ||
        (tokenLedgerBalance >= tokenFee &&
          natValue + tokenFee > tokenLedgerBalance)
    );
    setTransactionFieldNatValue(natValue);
    if (tokenLedgerBalance - natValue - tokenFee > 0) {
      setRemainder(
        bigintToFloatString(
          tokenLedgerBalance - natValue - tokenFee,
          tokenDecimals
        )
      );
    } else {
      setRemainder('0');
    }
  }, [transactionFieldValue, tokenLedgerBalance]);

  const handleTransaction = () => {
    if (!isValidPrincipal(principalField)) return;
    transfer(transactionFieldNatValue, Principal.fromText(principalField));
  };

  const handlePrincipalFieldChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setPrincipalField(event.target.value);
    if (event.target.value === '') {
      setPrincipalFieldErrored(false);
    } else {
      setPrincipalFieldErrored(!isValidPrincipal(event.target.value));
    }
  };

  const isValidPrincipal = (principalString: string): boolean => {
    try {
      Principal.fromText(principalString);
      return true;
    } catch (error) {
      return false;
    }
  };

  const handleMaxClick = () => {
    setTransactionFieldValue(
      bigintToFloatString(tokenLedgerBalance - tokenFee, tokenDecimals)
    );
  };

  return (
    <ThemeProvider theme={theme}>
      <div
        style={{
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'start',
          width: '100%',
          flexDirection: 'column',
        }}
      >
        <div>
          <div>
            <div>{`Remaining: ${remainder} ${tokenTicker}s`}</div>
          </div>
          <div style={{ display: 'flex' }}>
            <TextField
              label="To Principal"
              variant="filled"
              onChange={handlePrincipalFieldChange}
              value={principalField}
              error={principalFieldErrored}
              helperText={
                principalFieldErrored ? 'Enter a valid principal!' : ''
              }
              disabled={loading}
            />

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
                      tokenFee,
                      tokenDecimals
                    )} to transfer.`
                  : ''
              }
              error={valueFieldErrored}
              disabled={loading}
              slotProps={{
                input: {
                  inputMode: 'decimal', // Helps show the numeric pad with decimal on mobile devices
                },
              }}
              style={{ width: '200px', minHeight: '84px' }} // Set a fixed width or use a percentage
            />
            <div>
              <button style={{ height: '56px' }} onClick={handleMaxClick}>
                MAX
              </button>
            </div>
            <div>
              <button
                disabled={buttonDisabled || principalFieldErrored || loading}
                onClick={handleTransaction}
                style={{ height: '56px' }}
              >
                SEND
              </button>
            </div>
          </div>
        </div>
      </div>
    </ThemeProvider>
  );
};

export default TransactionBox;
