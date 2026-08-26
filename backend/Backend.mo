import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import D "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";

import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Timer "mo:base/Timer";

import CertifiedData "mo:base/CertifiedData";
import Nat64 "mo:base/Nat64";
import CertTree "mo:cert/CertTree";

import ICRC1 "mo:icrc1-mo/ICRC1";
import Account "mo:icrc1-mo/ICRC1/Account";
import ICRC2 "mo:icrc2-mo/ICRC2";
import ICRC3 "mo:icrc3-mo/";
import ICRC3Legacy "mo:icrc3-mo/legacy";
import ICRC4 "mo:icrc4-mo/ICRC4";
import ClassPlus "mo:class-plus";

///GLDT Token
import Types "Types";
import Blob "mo:base/Blob";
import Int "mo:base/Int";
import ICPTypes "ICPTypes";

shared ({ caller = _owner }) actor class Token(
  args : ?{
    icrc1 : ?ICRC1.InitArgs;
    icrc2 : ?ICRC2.InitArgs;
    icrc3 : ICRC3.InitArgs; //already typed nullable
    icrc4 : ?ICRC4.InitArgs;
  }
) = this {

  let Set = ICRC1.Set;
  let Map = ICRC1.Map;

  // The minting account deliberately uses a NON-DEFAULT subaccount.
  //
  // Under ICRC-1 a transfer to the minting account is a burn. When the minting
  // account is the canister's default account, anyone who sends sGLDT to this
  // canister's principal destroys it -- the ledger returns Ok, waives the fee,
  // and the GLDT backing it stays locked forever. Guarding icrc1_transfer alone
  // is not enough: icrc2_transfer_from and icrc4_transfer_batch reach the same
  // account. Moving the minting account off subaccount null closes every path at
  // once, and makes an accidental send land in an ordinary, recoverable account.
  //
  // Must not be all-zero: an all-zero subaccount is treated as equivalent to
  // null. The ASCII tag keeps it non-zero and self-documenting.
  //
  // NOTE: this applies at INSTALL only. The minting account lives in ledger
  // state, so an upgrade does not move it -- an existing deployment needs a
  // one-time admin_update_icrc1 #MintingAccount call. Production currently uses
  // the deploying principal as its minting account, not this canister, so the
  // burn address there is that principal until such a call is made.
  let minting_sub_account : Blob = Blob.fromArray([
    0x6d, 0x69, 0x6e, 0x74, 0x69, 0x6e, 0x67, 0x00, // "minting\0"
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]);

  let ICPLedger : ICPTypes.Service = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai");
  // let BOBLedger : ICPTypes.Service = actor ("7pail-xaaaa-aaaas-aabmq-cai");
  let BOBLedger : ICPTypes.Service = actor ("6c7su-kiaaa-aaaar-qaira-cai"); // GLDT Ledger

  type Account = ICRC1.Account;

  let default_icrc1_args : ICRC1.InitArgs = {
    name = ?"sGLDT - GLDT Wrapper";
    symbol = ?"sGLDT";
    logo = ?"data:image/png;base64,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";
    decimals = 8;
    fee = ? #Fixed(1000);
    minting_account = ?{
      owner = Principal.fromActor(this);
      subaccount = ?minting_sub_account;
    };
    max_supply = null;
    min_burn_amount = ?1000;
    max_memo = ?32;
    advanced_settings = null;
    metadata = null;
    fee_collector = null;
    transaction_window = null;
    permitted_drift = null;
    max_accounts = ?100000000;
    settle_to_accounts = ?99999000;
  };

  let default_icrc2_args : ICRC2.InitArgs = {
    max_approvals_per_account = ?10000;
    max_allowance = ? #TotalSupply;
    fee = ? #ICRC1;
    advanced_settings = null;
    max_approvals = ?10000000;
    settle_to_approvals = ?9990000;
  };

  let default_icrc3_args : ICRC3.InitArgs = {
    maxActiveRecords = 3000;
    settleToRecords = 2000;
    maxRecordsInArchiveInstance = 500_000;
    maxArchivePages = 62500;
    archiveIndexType = #Stable;
    maxRecordsToArchive = 8000;
    archiveCycles = 6_000_000_000_000;
    archiveControllers = null; // Single optional, not double optional
    supportedBlocks = [
      {
        block_type = "1xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "2xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "2approve";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "1mint";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
      {
        block_type = "1burn";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      },
    ];
  };

  let default_icrc4_args : ICRC4.InitArgs = {
    max_balances = ?200;
    max_transfers = ?200;
    fee = ? #ICRC1;
  };

  let icrc1_args : ICRC1.InitArgs = switch (args) {
    case (null) default_icrc1_args;
    case (?args) {
      switch (args.icrc1) {
        case (null) default_icrc1_args;
        case (?val) {
          {
            val with minting_account = switch (
              val.minting_account
            ) {
              case (?val) ?val;
              case (null) {
                ?{
                  owner = Principal.fromActor(this);
                  subaccount = ?minting_sub_account;
                };
              };
            };
          };
        };
      };
    };
  };

  let icrc2_args : ICRC2.InitArgs = switch (args) {
    case (null) default_icrc2_args;
    case (?args) {
      switch (args.icrc2) {
        case (null) default_icrc2_args;
        case (?val) val;
      };
    };
  };

  let icrc3_args : ICRC3.InitArgs = switch (args) {
    case (null) default_icrc3_args;
    case (?args) {
      switch (?args.icrc3) {
        case (null) default_icrc3_args;
        case (?val) val;
      };
    };
  };

  let icrc4_args : ICRC4.InitArgs = switch (args) {
    case (null) default_icrc4_args;
    case (?args) {
      switch (args.icrc4) {
        case (null) default_icrc4_args;
        case (?val) val;
      };
    };
  };

  stable let icrc1_migration_state = ICRC1.init(ICRC1.initialState(), #v0_1_0(#id), ?icrc1_args, _owner);
  stable let icrc2_migration_state = ICRC2.init(ICRC2.initialState(), #v0_1_0(#id), ?icrc2_args, _owner);
  stable let icrc4_migration_state = ICRC4.init(ICRC4.initialState(), #v0_1_0(#id), ?icrc4_args, _owner);
  stable let icrc3_migration_state = ICRC3.initialState();
  stable let cert_store : CertTree.Store = CertTree.newStore();
  let ct = CertTree.Ops(cert_store);

  stable var icrc3_migration_state_new = icrc3_migration_state;

  let manager = ClassPlus.ClassPlusInitializationManager(_owner, Principal.fromActor(this), true);

  stable var owner = _owner;
  stable var accumulated_fees : Nat = 0;
  stable var fee_collector : Principal = _owner;
  stable var authorized_fee_collector : Principal = Principal.fromText("ok64y-uiaaa-aaaag-qdcbq-cai");
  stable var total_deposit_fees : Nat = 0;
  stable var total_withdraw_fees : Nat = 0;
  stable var total_ledger_fees : Nat = 0;
  stable var total_dead_gldt_collected : Nat = 0;

  stable var gldt_transaction_fee : Nat = 10_000_000;
  stable var gldt_conversion_fee : Nat = 20_000_000;

  stable var sgldt_transaction_fee : Nat = 1000; // todo find in metadata

  // NEW STABLE VARIABLES FOR ICRC UPGRADE (Phase 1)
  stable var icrc106IndexCanister : ?Principal = null;
  // Retained deliberately. The Phase 4 methods that used these
  // (upgrade_archives / get_upgrade_status / reset_upgrade_status) were removed:
  // upgrade_archives only logged, set upgradeComplete := true and returned #ok
  // without performing any archive migration, so it reported success while doing
  // nothing. icrc3-mo 0.3.5 provides upgradeArchive() for that job; wiring it up
  // is a separate change deserving its own testing.
  //
  // These two are kept rather than deleted so the stable signature is unchanged
  // by this release. They are inert.
  stable var upgradeError = "";
  stable var upgradeComplete = false;

  let #v0_1_0(#data(icrc1_state_current)) = icrc1_migration_state;

  private var _icrc1 : ?ICRC1.ICRC1 = null;

  private func get_icrc1_state() : ICRC1.CurrentState {
    return icrc1_state_current;
  };

  private func get_icrc1_environment() : ICRC1.Environment {
    {
      get_time = null;
      get_fee = null;
      add_ledger_transaction = ?icrc3().add_record;
    };
  };

  func icrc1() : ICRC1.ICRC1 {
    switch (_icrc1) {
      case (null) {
        let initclass : ICRC1.ICRC1 = ICRC1.ICRC1(?icrc1_migration_state, Principal.fromActor(this), get_icrc1_environment());
        ignore initclass.register_supported_standards({
          name = "ICRC-3";
          url = "https://github.com/dfinity/ICRC/ICRCs/icrc-3/";
        });
        ignore initclass.register_supported_standards({
          name = "ICRC-10";
          url = "https://github.com/dfinity/ICRC/ICRCs/icrc-10/";
        });
        
        // NEW ICRC STANDARDS FOR UPGRADE (Phase 2)
        ignore initclass.register_supported_standards({
          name = "ICRC-103";
          url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-103"
        });
        ignore initclass.register_supported_standards({
          name = "ICRC-106";
          url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-106"
        });
        ignore initclass.register_supported_standards({
          name = "ICRC-130";
          url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-130"
        });
        ignore initclass.register_supported_standards({
          name = "ICRC-4";
          url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-4"
        });
        
        _icrc1 := ?initclass;
        initclass;
      };
      case (?val) val;
    };
  };

  let #v0_1_0(#data(icrc2_state_current)) = icrc2_migration_state;

  private var _icrc2 : ?ICRC2.ICRC2 = null;

  private func get_icrc2_state() : ICRC2.CurrentState {
    return icrc2_state_current;
  };

  private func get_icrc2_environment() : ICRC2.Environment {
    {
      icrc1 = icrc1();
      get_fee = null;
    };
  };

  func icrc2() : ICRC2.ICRC2 {
    switch (_icrc2) {
      case (null) {
        let initclass : ICRC2.ICRC2 = ICRC2.ICRC2(?icrc2_migration_state, Principal.fromActor(this), get_icrc2_environment());
        _icrc2 := ?initclass;
        initclass;
      };
      case (?val) val;
    };
  };

  let #v0_1_0(#data(icrc4_state_current)) = icrc4_migration_state;

  private var _icrc4 : ?ICRC4.ICRC4 = null;

  private func get_icrc4_state() : ICRC4.CurrentState {
    return icrc4_state_current;
  };

  private func get_icrc4_environment() : ICRC4.Environment {
    {
      icrc1 = icrc1();
      get_fee = null;
    };
  };

  func icrc4() : ICRC4.ICRC4 {
    switch (_icrc4) {
      case (null) {
        let initclass : ICRC4.ICRC4 = ICRC4.ICRC4(?icrc4_migration_state, Principal.fromActor(this), get_icrc4_environment());
        _icrc4 := ?initclass;
        initclass;
      };
      case (?val) val;
    };
  };

  private func updated_certification(cert : Blob, lastIndex : Nat) : Bool {
    ct.setCertifiedData();
    return true;
  };

  private func get_certificate_store() : CertTree.Store {
    return cert_store;
  };

  private func get_icrc3_environment() : ICRC3.Environment {
    {
      updated_certification = ?updated_certification;
      get_certificate_store = ?get_certificate_store;
    };
  };

  func ensure_block_types(icrc3Class : ICRC3.ICRC3) : () {
    let supportedBlocks = Buffer.fromIter<ICRC3.BlockType>(icrc3Class.supported_block_types().vals());

    let blockequal = func(a : { block_type : Text }, b : { block_type : Text }) : Bool {
      a.block_type == b.block_type;
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1xfer"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "2xfer"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "2xfer";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "2approve"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "2approve";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1mint"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1mint";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    if (Buffer.indexOf<ICRC3.BlockType>({ block_type = "1burn"; url = "" }, supportedBlocks, blockequal) == null) {
      supportedBlocks.add({
        block_type = "1burn";
        url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";
      });
    };

    icrc3Class.update_supported_blocks(Buffer.toArray(supportedBlocks));
  };

  let icrc3 = ICRC3.Init<system>({
    manager = manager;
    initialState = icrc3_migration_state_new;
    args = ?icrc3_args;
    pullEnvironment = ?get_icrc3_environment;
    onInitialize = ?(func(newClass : ICRC3.ICRC3) : async*() {
      ensure_block_types(newClass);
    });
    onStorageChange = func(state : ICRC3.State) {
      icrc3_migration_state_new := state;
    };
  });




  /// Functions for the ICRC1 token standard
  public shared query func icrc1_name() : async Text {
    icrc1().name();
  };

  public shared query func icrc1_symbol() : async Text {
    icrc1().symbol();
  };

  public shared query func icrc1_decimals() : async Nat8 {
    icrc1().decimals();
  };

  public shared query func icrc1_fee() : async ICRC1.Balance {
    icrc1().fee();
  };

  public shared query func icrc1_metadata() : async [ICRC1.MetaDatum] {
    icrc1().metadata();
  };

  public shared query func icrc1_total_supply() : async ICRC1.Balance {
    icrc1().total_supply();
  };

  public shared query func icrc1_minting_account() : async ?ICRC1.Account {
    ?icrc1().minting_account();
  };

  public shared query func icrc1_balance_of(args : ICRC1.Account) : async ICRC1.Balance {
    icrc1().balance_of(args);
  };

  public shared query func icrc1_supported_standards() : async [ICRC1.SupportedStandard] {
    icrc1().supported_standards();
  };

  public shared query func icrc10_supported_standards() : async [ICRC1.SupportedStandard] {
    icrc1().supported_standards();
  };

  public shared ({ caller }) func icrc1_transfer(args : ICRC1.TransferArgs) : async ICRC1.TransferResult {
    // Reject transfers addressed to this canister. Whether such a transfer is a
    // burn depends on the deployment: it is one only when the minting account is
    // this canister's own account -- this file's default, but NOT what production
    // runs, where the minting account is the deploying principal and that is the
    // address which burns. Either way, sending here is a mistake; rejecting it
    // turns a silent loss into a clear error. Callers unwrap via withdraw().
    //
    // This guard is necessary but NOT sufficient by itself: icrc2_transfer_from
    // and icrc4_transfer_batch pass null validators and reach the same account.
    // Verified on staging -- with only this guard in place, icrc4_transfer_batch
    // to the canister returned Ok and destroyed the tokens. Moving the minting
    // account off subaccount null is what closes every path; see
    // minting_sub_account above.
    //
    // Accidental burns observed on production: 4 events, 32.17 sGLDT total
    // (blocks 10011, 11210, 11231, 40071), all from one principal.
    switch (await* icrc1().transfer_tokens(caller, args, false,
      ?#Sync(
        func<system>(
          trx : ICRC1.Value,
          trxtop : ?ICRC1.Value,
          notification : ICRC1.TransactionRequestNotification,
        ) : Result.Result<(ICRC1.Value, ?ICRC1.Value, ICRC1.TransactionRequestNotification), Text> {
          if (notification.to.owner == Principal.fromActor(this)) {
            return #err("Cannot transfer to the token canister - this would burn your tokens. Use withdraw() to unwrap.");
          };
          #ok((trx, trxtop, notification));
        }
      )
    )) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  private func time64() : Nat64 {
    Nat64.fromNat(Int.abs(Time.now()));
  };

  let ONE_DAY = 86_400_000_000_000;

  stable var lastError : (Text, Int) = ("null", 0);

  public query (msg) func getLastError() : async (Text, Int) {
    if (msg.caller != owner) {
      return ("Unauthorized", 0);
    };
    lastError;
  };

  private func refund(caller : Principal, subaccount : ?[Nat8], amount : Nat, e : Text) : async* Result.Result<(Nat, Nat), Text> {
    try {
      let result = await BOBLedger.icrc1_transfer({
        from_subaccount = null;
        fee = null;
        to = {
          owner = caller;
          subaccount = subaccount;
        };
        memo = ?Blob.toArray("\98\5c\db\3b\74\ce\88\61\3a\35\ee\2e\0e\39\a9\f6\c5\1d\ee\e9\ea\53\89\2d\e8\da\53\da\de\46\57\64" : Blob); //"GLDT Return"
        created_at_time = ?time64();
        amount = amount;
      });
    } catch (e) {
      return #err("stuck funds");
    };

    return #err("cannot transfer to minter " # e);
  };

  public shared ({ caller }) func deposit(subaccount : ?[Nat8], amount : Nat) : async Result.Result<(Nat, Nat), Text> {
    log.add(debug_show (Time.now()) # "trying deposit " # debug_show (subaccount));

    if (amount < 50_000_000) {
      // Minimum amount to account for high GLDT fees (10,000,000)
      return #err("amount too low");
    };

    let result = try {
      await BOBLedger.icrc2_transfer_from({
        to = {
          owner = Principal.fromActor(this);
          subaccount = null;
        };
        fee = null;
        spender_subaccount = null;
        from = {
          owner = caller;
          subaccount = subaccount;
        };
        memo = ?Blob.toArray("\4d\03\4c\3e\2f\15\84\ae\3d\86\d6\70\a5\e2\7e\9b\ad\3c\14\17\a6\3c\d8\9e\9b\f9\37\01\35\8d\c3\0e" : Blob); //"sGLDT Deposit"
        created_at_time = ?time64();
        amount = amount;
      });
    } catch (e) {
      log.add(debug_show (Time.now()) # "trying transfer from " # Error.message(e));
      D.trap("cannot transfer from failed" # Error.message(e));
    };

    let block = switch (result) {
      case (#Ok(block)) block;
      case (#Err(err)) {
        D.trap("cannot transfer from failed" # debug_show (err));
      };
    };

    // Track the GLDT ledger fee (0.1 GLDT) that was deducted during transfer
    total_ledger_fees := total_ledger_fees + gldt_transaction_fee;

    let mintingAmount = amount;

    let newtokens = await* icrc1().mint_tokens(
      // Must be the minting account's OWNER, which mint_tokens authorises
      // against. The previous hardcoded Principal.fromActor(this) matches only
      // when the minting account is this canister -- true for a fresh install
      // from this file, but NOT for production, whose minting account owner is
      // the deploying principal. Deployed there, the hardcoded form returns 401
      // and EVERY wrap fails.
      icrc1().get_state().minting_account.owner,
      {
        to = {
          owner = caller;
          subaccount = switch (subaccount) {
            case (null) null;
            case (?val) ?Blob.fromArray(val);
          };
        };
        amount = mintingAmount; // The number of tokens to mint.
        created_at_time = ?time64();
        memo = ?("\6d\7a\68\d6\ce\4d\2f\8e\60\72\af\e3\73\91\c8\d8\67\b5\6f\69\35\bc\ca\9a\7b\d9\40\19\fd\6e\3c\16" : Blob); //"sGLDT mint"
      },
    );

    log.add(debug_show (Time.now()) # "trying mint from mint " # debug_show (newtokens));

    let mint = switch (newtokens) {
      case (#trappable(#Ok(val))) val;
      case (#awaited(#Ok(val))) val;
      case (#trappable(#Err(err))) {
        return await* refund(caller, subaccount, amount, debug_show (err));

      };
      case (#awaited(#Err(err))) {
        return await* refund(caller, subaccount, amount, debug_show (err));
      };
      case (#err(#trappable(err))) {
        return await* refund(caller, subaccount, amount, debug_show (err));
      };
      case (#err(#awaited(err))) {
        return await* refund(caller, subaccount, amount, debug_show (err));
      };
    };

    return #ok((block, mint));
  };

  public shared ({ caller }) func withdraw(subaccount : ?[Nat8], amount : Nat) : async Result.Result<(Nat, Nat), Text> {
    log.add(debug_show (Time.now()) # "trying withdraw " # debug_show (subaccount));

    let gldt_total_fee = gldt_transaction_fee + gldt_conversion_fee;

    if (amount <= gldt_total_fee) {
      // Minimum amount to ensure user gets at least 0.1 GLDT after fees (0.1 GLDT canister fee)
      return #err("amount too low - must be at least 0.3 GLDT to account for fees");
    };

    let burnResult = await* icrc1().burn(
      caller,
      {
        from_subaccount = switch (subaccount) {
          case (null) null;
          case (?val) ?Blob.fromArray(val);
        }; // The subaccount from which tokens are burned.
        amount = amount; // Burn the full amount requested by user
        memo = ?("\d8\d9\b4\5f\41\5d\5a\c3\be\e5\21\2c\10\f4\bb\6d\07\52\7d\01\17\7e\58\e0\13\03\39\90\00\c5\a8\94" : Blob); //sGLDT Withdraw
        created_at_time = ?time64(); // The time the burn operation was created.
      },
    );

    let parse = switch (burnResult) {
      case (#Ok(val)) val;
      case (#Err((err))) return #err(debug_show (err));
    };

    let transferResult = await BOBLedger.icrc1_transfer({
        to = {
          owner = caller;
          subaccount = subaccount;
        };
        fee = null;
        from_subaccount = null;
        memo = ?Blob.toArray("\d8\d9\b4\5f\41\5d\5a\c3\be\e5\21\2c\10\f4\bb\6d\07\52\7d\01\17\7e\58\e0\13\03\39\90\00\c5\a8\94"); //sGLDT Withdraw
        created_at_time = ?time64();
        amount = amount - gldt_total_fee; // keep this amount as part of the transfer fee to keep our GLDT from being drained.
      },
    );

    let block = switch (transferResult) {
      case (#Ok(block)) {
        // Mint the conversion fee.
        if (gldt_conversion_fee > 0) {
          switch (icrc1().get_state().fee_collector) {
            case (null) {
              // count gldt retained as fees that admin may collect (gldt fee mode) 
              accumulated_fees := accumulated_fees + gldt_conversion_fee;
            };
            case (?fee_collector) {
              let mintFeeResult = await* icrc1().mint(
                icrc1().get_state().minting_account.owner,
                {
                  to = fee_collector;
                  amount = gldt_conversion_fee; // Remint the same amount that was retained as conversion fee
                  memo = ?("\d8\d9\b4\5f\41\5d\5a\c3\be\e5\21\2c\10\f4\bb\6d\07\52\7d\01\17\7e\58\e0\13\03\39\90\00\c5\a8\94" : Blob); //sGLDT Withdraw
                  created_at_time = ?time64(); // The time the burn operation was created.
                },
              );

              // Never discard this. On production these mints SUCCEED -- 428 of
              // them are on the ledger, each exactly the conversion fee -- because
              // the collector is a normal account distinct from the minting
              // account. That is a property of the deployment, not of the code:
              // point the collector at the minting account and every mint fails,
              // retaining GLDT as unbacked surplus with nothing recording it.
              //
              // icrc1().mint returns a plain TransferResult, NOT a Star: it
              // unwraps the Star internally and traps on the #err arms. Matching
              // #trappable/#awaited/#err compiles but never fires (moc M0146),
              // which would leave the failure swallowed by `case (_)`.
              switch (mintFeeResult) {
                case (#Err(err)) {
                  log.add(debug_show (Time.now()) # " conversion fee mint failed: " # debug_show (err));
                };
                case (#Ok(_)) {};
              };
            };
          };
        };

        // Track the canister fee
        total_withdraw_fees := total_withdraw_fees + gldt_transaction_fee;
        block;
      };
      case (#Err(err)) {
        //put back

        // The withdraw already burned the caller's sGLDT, so this refund is the
        // only thing standing between a failed GLDT transfer and permanent loss
        // of user funds. It passed `caller` -- the withdrawing user -- where
        // mint_tokens authorises against the minting account owner, so it
        // returned 401 every single time, and the result was discarded.
        let remintResult = await* icrc1().mint(
          icrc1().get_state().minting_account.owner,
          {
            to = {
              owner = caller;
              subaccount = switch (subaccount) {
                case (null) null;
                case (?val) ?Blob.fromArray(val);
              }; // The subaccount from which tokens are burned.
            };
            amount = amount; // Remint the same amount that was burned
            memo = ?("\d8\d9\b4\5f\41\5d\5a\c3\be\e5\21\2c\10\f4\bb\6d\07\52\7d\01\17\7e\58\e0\13\03\39\90\00\c5\a8\94" : Blob); //sGLDT Withdraw
            created_at_time = ?time64(); // The time the burn operation was created.
          },
        );
        switch (remintResult) {
          case (#Err(reErr)) {
            // Burned, not refunded, and not transferred out. Loud on purpose.
            log.add(debug_show (Time.now()) # " CRITICAL: refund after failed withdraw did not mint back " # debug_show (amount) # " to " # debug_show (caller) # ": " # debug_show (reErr));
            return #err("withdraw failed AND refund failed - funds burned, contact support. withdraw: " # debug_show (err) # " refund: " # debug_show (reErr));
          };
          case (#Ok(_)) {};
        };

        log.add(debug_show (Time.now()) # "trying withdraw from " # debug_show (err));
        return #err("cannot withdraw - failed" # debug_show (err));
      };
    };

    return #ok((parse, block));
  };

  public type Stats = {
    totalSupply : Nat;
    holders : Nat;
  };

  public query func stats() : async Stats {
    return {
      totalSupply = icrc1().total_supply();
      holders = ICRC1.Map.size(icrc1().get_state().accounts);
    };
  };

  public query func holders(min : ?Nat, max : ?Nat, prev : ?ICRC1.Account, take : ?Nat) : async [(ICRC1.Account, Nat)] {

    let results = ICRC1.Vector.new<(ICRC1.Account, Nat)>();
    let (bFound_, targetAccount) = switch (prev) {
      case (null)(true, { owner = Principal.fromActor(this); subaccount = null });
      case (?val)(false, val);
    };

    var bFound : Bool = bFound_;

    let takeVal = switch (take) {
      case (null) 1000; //default take
      case (?val) val;
    };

    label search for (thisAccount in ICRC1.Map.entries(icrc1().get_state().accounts)) {
      if (bFound) {
        if (ICRC1.Vector.size(results) >= takeVal) {
          break search;
        };

      } else {
        if (ICRC1.account_eq(targetAccount, thisAccount.0)) {
          bFound := true;
        } else {
          continue search;
        };
      };
      let minSearch = switch (min) {
        case (null) 0;
        case (?val) val;
      };
      let maxSearch = switch (max) {
        case (null) 20_000_000_0000_0000; //our max supply is far less than 20M
        case (?val) val;
      };
      if (thisAccount.1 >= minSearch and thisAccount.1 <= maxSearch) ICRC1.Vector.add(results, (thisAccount.0, thisAccount.1));
    };

    return ICRC1.Vector.toArray(results);
  };

  public query ({ caller }) func icrc2_allowance(args : ICRC2.AllowanceArgs) : async ICRC2.Allowance {
    return icrc2().allowance(args.spender, args.account, false);
  };

  public shared ({ caller }) func icrc2_approve(args : ICRC2.ApproveArgs) : async ICRC2.ApproveResponse {
    switch (await* icrc2().approve_transfers(caller, args, false, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public shared ({ caller }) func icrc2_transfer_from(args : ICRC2.TransferFromArgs) : async ICRC2.TransferFromResponse {
    switch (await* icrc2().transfer_tokens_from(caller, args, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) D.trap(err);
      case (#err(#awaited(err))) D.trap(err);
    };
  };

  public query func icrc3_get_blocks(args : ICRC3.GetBlocksArgs) : async ICRC3.GetBlocksResult {
    return icrc3().get_blocks(args);
  };

  public query func icrc3_get_archives(args : ICRC3.GetArchivesArgs) : async ICRC3.GetArchivesResult {
    return icrc3().get_archives(args);
  };

  public query func icrc3_get_tip_certificate() : async ?ICRC3.DataCertificate {
    return icrc3().get_tip_certificate();
  };

  public query func icrc3_supported_block_types() : async [ICRC3.BlockType] {
    return icrc3().supported_block_types();
  };

  public query func get_tip() : async ICRC3.Tip {
    return icrc3().get_tip();
  };

  public query func get_transactions(args: { start : Nat; length : Nat }) : async ICRC3Legacy.GetTransactionsResponse {
    let results = icrc3().get_blocks_legacy(args);
    return {
      first_index = icrc3().get_state().firstIndex;
      log_length = icrc3().get_state().lastIndex + 1;
      transactions = results.transactions;
      archived_transactions = results.archived_transactions;
    };
  };

  public shared ({ caller }) func icrc4_transfer_batch(args : ICRC4.TransferBatchArgs) : async ICRC4.TransferBatchResults {
    switch (await* icrc4().transfer_batch_tokens(caller, args, null, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) err;
      case (#err(#awaited(err))) err;
    };
  };

  public shared query func icrc4_balance_of_batch(request : ICRC4.BalanceQueryArgs) : async ICRC4.BalanceQueryResult {
    return icrc4().balance_of_batch(request);
  };

  public shared query func icrc4_maximum_update_batch_size() : async ?Nat {
    ?icrc4().get_state().ledger_info.max_transfers;
  };

  public shared query func icrc4_maximum_query_batch_size() : async ?Nat {
    ?icrc4().get_state().ledger_info.max_balances;
  };

  public shared ({ caller }) func admin_update_owner(new_owner : Principal) : async Bool {
    if (caller != owner) { D.trap("Unauthorized") };
    owner := new_owner;
    return true;
  };

  public shared ({ caller }) func admin_update_icrc1(requests : [ICRC1.UpdateLedgerInfoRequest]) : async [Bool] {
    if (caller != owner) { D.trap("Unauthorized") };
    return icrc1().update_ledger_info(requests);
  };

  public shared ({ caller }) func admin_update_icrc2(requests : [ICRC2.UpdateLedgerInfoRequest]) : async [Bool] {
    if (caller != owner) { D.trap("Unauthorized") };
    return icrc2().update_ledger_info(requests);
  };

  public shared ({ caller }) func admin_update_icrc4(requests : [ICRC4.UpdateLedgerInfoRequest]) : async [Bool] {
    if (caller != owner) { D.trap("Unauthorized") };
    return icrc4().update_ledger_info(requests);
  };

  // Fee collection functions
  public shared ({ caller }) func admin_update_fee_collector(new_collector : Principal) : async Bool {
    if (caller != owner) { D.trap("Unauthorized") };
    fee_collector := new_collector;
    return true;
  };

  public shared ({ caller }) func admin_update_authorized_fee_collector(new_collector : Principal) : async Bool {
    if (caller != owner) { D.trap("Unauthorized") };
    authorized_fee_collector := new_collector;
    return true;
  };

  public shared ({ caller }) func admin_update_gldt_transaction_fee(new_fee : Nat) : async Bool {
    if (caller != owner) { D.trap("Unauthorized") };
    gldt_transaction_fee := new_fee;
    return true;
  };

  public shared ({ caller }) func admin_update_gldt_conversion_fee(new_fee : Nat) : async Bool {
    if (caller != owner) { D.trap("Unauthorized") };
    gldt_conversion_fee := new_fee;
    return true;
  };

  public shared ({ caller }) func admin_collect_fees() : async Result.Result<Nat, Text> {
    if (caller != fee_collector and caller != authorized_fee_collector) { return #err("Unauthorized") };
    let this_pid = Principal.fromActor(this);
    let fees = icrc1().balance_of({owner = this_pid; subaccount = null});
    
    if (fees == 0) { return #err("No fees to collect") };

    if (fees <= sgldt_transaction_fee * 2) { return #err("Not enough fees to collect") };
    
    let fees_minus_tx_fees = fees - (sgldt_transaction_fee * 2);
    
    // Calculate 50/50 split (accounting for odd amounts)
    let half_fees = fees_minus_tx_fees / 2;
    let second_half = fees_minus_tx_fees - half_fees; // This handles odd amounts correctly
    
    // Transfer first half to address 1
    let transfer1_result = try {
      await* icrc1().transfer_tokens(
        this_pid,
        {
          to = {
            owner = Principal.fromText("okpx5-c7nln-u3qii-ub55e-374ug-kjede-segkn-jgbv5-dkbfr-m55ma-yqe");
            subaccount = null;
          };
          fee = null;
          from_subaccount = null;
          memo = ?("\46\65\65\20\43\6f\6c\6c\65\63\74\69\6f\6e" : Blob); // "Fee Collection"
          created_at_time = ?time64();
          amount = half_fees;
        }, false, null);
    } catch (e) {
      return #err("Failed to transfer first half of fees: " # Error.message(e));
    };

    // transfer_tokens signals failure by *returning* it (Star / TransferResult),
    // not by throwing, so the catch above never sees it. Inspect both layers.
    switch (transfer1_result) {
      case (#trappable(#Err(err)) or #awaited(#Err(err))) {
        return #err("Failed to transfer first half of fees: " # debug_show (err));
      };
      case (#err(#trappable(err)) or #err(#awaited(err))) {
        return #err("Failed to transfer first half of fees: " # err);
      };
      case (_) {};
    };
    
    // Transfer second half to address 2
    let transfer2_result = try {
      await* icrc1().transfer_tokens(
        this_pid,
        {
          to = {
            owner = Principal.fromText("ok64y-uiaaa-aaaag-qdcbq-cai");
            subaccount = null;
          };
          fee = null;
          from_subaccount = null;
          memo = ?("\46\65\65\20\43\6f\6c\6c\65\63\74\69\6f\6e" : Blob); // "Fee Collection"
          created_at_time = ?time64();
          amount = second_half;
        }, false, null);
    } catch (e) {
      return #err("Failed to transfer second half of fees: " # Error.message(e));
    };

    // transfer_tokens signals failure by *returning* it (Star / TransferResult),
    // not by throwing, so the catch above never sees it. Inspect both layers.
    switch (transfer2_result) {
      case (#trappable(#Err(err)) or #awaited(#Err(err))) {
        return #err("Failed to transfer second half of fees: " # debug_show (err));
      };
      case (#err(#trappable(err)) or #err(#awaited(err))) {
        return #err("Failed to transfer second half of fees: " # err);
      };
      case (_) {};
    };
    
    return #ok(fees);
  };

  public query func get_sgldt_balance() : async Nat {
    icrc1().balance_of({owner = Principal.fromActor(this); subaccount = null});
  };

  public query func get_accumulated_fees() : async Nat {
    accumulated_fees;
  };

  public query func get_fee_collector() : async Principal {
    fee_collector;
  };

  public query func get_authorized_fee_collector() : async Principal {
    authorized_fee_collector;
  };

  public query func is_authorized_fee_collector(principal : Principal) : async Bool {
    principal == fee_collector or principal == authorized_fee_collector;
  };

  public query func get_fee_stats() : async {
    accumulated_fees : Nat;
    total_deposit_fees : Nat;
    total_withdraw_fees : Nat;
    total_ledger_fees : Nat;
  } {
    {
      accumulated_fees = accumulated_fees;
      total_deposit_fees = total_deposit_fees;
      total_withdraw_fees = total_withdraw_fees;
      total_ledger_fees = total_ledger_fees;
    };
  };

  public query func get_fee_breakdown() : async {
    gldt_ledger_fee : Nat;
    canister_withdraw_fee : Nat;
    sgldt_transfer_fee : Nat;
  } {
    {
      gldt_ledger_fee = gldt_transaction_fee; // 0.1 GLDT
      canister_withdraw_fee = gldt_conversion_fee; // 0.2 sGLDT
      sgldt_transfer_fee = 1_000; // 0.00001 sGLDT
    };
  };

  /* /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func transfer_listener(trx: ICRC1.Transaction, trxid: Nat) : () {

  };

  /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func approval_listener(trx: ICRC2.TokenApprovalNotification, trxid: Nat) : () {

  };

  /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func transfer_from_listener(trx: ICRC2.TransferFromNotification, trxid: Nat) : () {

  }; */

  // private stable var _init = false;
  // public shared(msg) func admin_init() : async () {
  //   //can only be called once

  //   if(_init == false){
  //     //ensure metadata has been registered
  //     let test1 = icrc1().metadata();
  //     let test2 = icrc2().metadata();
  //     let test4 = icrc4().metadata();
  //     let test3 = icrc3().stats();

  //     //uncomment the following line to register the transfer_listener
  //     //icrc1().register_token_transferred_listener("my_namespace", transfer_listener);

  //     //uncomment the following line to register the transfer_listener
  //     //icrc2().register_token_approved_listener("my_namespace", approval_listener);

  //     //uncomment the following line to register the transfer_listener
  //     //icrc1().register_transfer_from_listener("my_namespace", transfer_from_listener);
  //   };
  //   _init := true;
  // };

  let log = Buffer.Buffer<Text>(1);

  public shared (msg) func clearLog() : async () {
    if (msg.caller != owner) {
      D.trap("Unauthorized");
    };
    log.clear();
  };

  public query (msg) func get_log() : async [Text] {
    Buffer.toArray(log);
  };

  // Deposit cycles into this canister.
  public shared func deposit_cycles() : async () {
    let amount = ExperimentalCycles.available();
    let accepted = ExperimentalCycles.accept<system>(amount);
    assert (accepted == amount);
  };

  public shared (msg) func init() : async () {
    if (Principal.fromActor(this) != msg.caller) {
      D.trap("Only the canister can initialize the canister");
    };
    log.add(debug_show (Time.now()) # "In init ");
    ignore icrc1().metadata();
    ignore icrc2().metadata();
    ignore icrc3().stats();
    ignore icrc4().metadata();
  };

  ignore Timer.setTimer<system>(
    #nanoseconds(0),
    func() : async () {
      let selfActor : actor {
        init : shared () -> async ();
      } = actor (Principal.toText(Principal.fromActor(this)));
      await selfActor.init();
    },
  );

  system func postupgrade() {
    ignore icrc1().init_metadata();
  };
  //re wire up the listener after upgrade
  //uncomment the following line to register the transfer_listener
  //icrc1().register_token_transferred_listener("gldtminter", transfer_listener);

  //uncomment the following line to register the transfer_listener
  //icrc2().register_token_approved_listener("my_namespace", approval_listener);

  //uncomment the following line to register the transfer_listener
  //icrc1().register_transfer_from_listener("my_namespace", transfer_from_listener);

  // NEW ICRC-106 INDEX CANISTER FUNCTIONS (Phase 3)
  public shared({caller}) func icrc106_set_index_canister(index_canister : Principal) : async Result.Result<(), Text> {
    if (caller != owner) {
      return #err("Unauthorized");
    };
    icrc106IndexCanister := ?index_canister;
    log.add(debug_show (Time.now()) # " ICRC-106 index canister set to: " # Principal.toText(index_canister));
    #ok(());
  };

  public query func icrc106_get_index_canister() : async ?Principal {
    icrc106IndexCanister;
  };

  public shared({caller}) func icrc106_remove_index_canister() : async Result.Result<(), Text> {
    if (caller != owner) {
      return #err("Unauthorized");
    };
    icrc106IndexCanister := null;
    log.add(debug_show (Time.now()) # " ICRC-106 index canister removed");
    #ok(());
  };

};
