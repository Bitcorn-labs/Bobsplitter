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
import ICRC4 "mo:icrc4-mo/ICRC4";

///Bob Token
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

  let ICPLedger : ICPTypes.Service = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai");
  let BOBLedger : ICPTypes.Service = actor ("7pail-xaaaa-aaaas-aabmq-cai");

  type Account = ICRC1.Account;

  let default_icrc1_args : ICRC1.InitArgs = {
    name = ?"fakeBob";
    symbol = ?"fBOB";
    logo = ?"data:image/png;base64,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";
    decimals = 8;
    fee = ? #Fixed(1_000_000);
    minting_account = ?{
      owner = _owner;
      subaccount = null;
    };
    max_supply = null;
    min_burn_amount = ?10000;
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

  let default_icrc3_args : ICRC3.InitArgs = ?{
    maxActiveRecords = 3000;
    settleToRecords = 2000;
    maxRecordsInArchiveInstance = 100000000;
    maxArchivePages = 62500;
    archiveIndexType = #Stable;
    maxRecordsToArchive = 8000;
    archiveCycles = 6_000_000_000_000;
    archiveControllers = null; //??[put cycle ops prinicpal here];
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
                  owner = _owner;
                  subaccount = null;
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
      switch (args.icrc3) {
        case (null) default_icrc3_args;
        case (?val) ?val;
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
  stable let icrc3_migration_state = ICRC3.init(ICRC3.initialState(), #v0_1_0(#id), icrc3_args, _owner);
  stable let cert_store : CertTree.Store = CertTree.newStore();
  let ct = CertTree.Ops(cert_store);

  stable var owner = _owner;

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
      can_transfer = null; //set to a function to intercept and add validation logic for transfers
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
      can_approve = null; //set to a function to intercept and add validation logic for approvals
      can_transfer_from = null; //set to a function to intercept and add validation logic for transfer froms
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
      can_approve = null; //set to a function to intercept and add validation logic for approvals
      can_transfer_from = null; //set to a function to intercept and add validation logic for transfer froms
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

  let #v0_1_0(#data(icrc3_state_current)) = icrc3_migration_state;

  private var _icrc3 : ?ICRC3.ICRC3 = null;

  private func get_icrc3_state() : ICRC3.CurrentState {
    return icrc3_state_current;
  };

  func get_state() : ICRC3.CurrentState {
    return icrc3_state_current;
  };

  private func get_icrc3_environment() : ICRC3.Environment {
    ?{
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

  func icrc3() : ICRC3.ICRC3 {
    switch (_icrc3) {
      case (null) {
        let initclass : ICRC3.ICRC3 = ICRC3.ICRC3(?icrc3_migration_state, Principal.fromActor(this), get_icrc3_environment());
        _icrc3 := ?initclass;
        ensure_block_types(initclass);

        initclass;
      };
      case (?val) val;
    };
  };

  private func updated_certification(cert : Blob, lastIndex : Nat) : Bool {

    // D.print("updating the certification " # debug_show(CertifiedData.getCertificate(), ct.treeHash()));
    ct.setCertifiedData();
    // D.print("did the certification " # debug_show(CertifiedData.getCertificate()));
    return true;
  };

  private func get_certificate_store() : CertTree.Store {
    // D.print("returning cert store " # debug_show(cert_store));
    return cert_store;
  };

  // custom function to mint myself tokens for testing:
  public shared ({ caller }) func mint_tokens() : async Result.Result<(Nat, Nat), Text> {
    let mintingAmount : Nat = 20_0000_0000;
    let newtokens = await* icrc1().mint_tokens(
      icrc1().get_state().minting_account.owner,
      {
        to = {
          owner = caller;
          subaccount = null;
        };
        amount = mintingAmount; // The number of tokens to mint.
        created_at_time = ?time64();
        memo = ?("\73\65\6c\66\20\6d\69\6e\74\20\66\6f\72\20\74\65\73\74" : Blob); //"self mint for test"
      },
    );

    let mint = switch (newtokens) {
      case (#trappable(#Ok(val))) val;
      case (#awaited(#Ok(val))) val;
      case (#trappable(#Err(err))) {
        return #err(debug_show (err));

      };
      case (#awaited(#Err(err))) {
        return #err(debug_show (err));
      };
      case (#err(#trappable(err))) {
        return #err(debug_show (err));
      };
      case (#err(#awaited(err))) {
        return #err(debug_show (err));
      };
    };

    return #ok((mint, mint));
  };

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
    switch (await* icrc1().transfer_tokens(caller, args, false, null)) {
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

  // private func refund(caller: Principal, subaccount: ?[Nat8], amount: Nat, e : Text) : async* Result.Result<(Nat, Nat), Text> {
  //   try{
  //     let result = await BOBLedger.icrc1_transfer({
  //       from_subaccount = null;
  //       fee = ?10_000;
  //       to = {
  //         owner = caller;
  //         subaccount = subaccount;
  //       };
  //       memo = ?Blob.toArray("\98\5c\db\3b\74\ce\88\61\3a\35\ee\2e\0e\39\a9\f6\c5\1d\ee\e9\ea\53\89\2d\e8\da\53\da\de\46\57\64" : Blob); //"Bob Return"
  //       created_at_time = ?time64();
  //       amount = amount;
  //     });
  //   } catch(e){
  //     return #err("stuck funds");
  //   };

  //   return #err("cannot transfer to minter " # e);
  // };

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

  public shared ({ caller }) func icrc4_transfer_batch(args : ICRC4.TransferBatchArgs) : async ICRC4.TransferBatchResults {
    switch (await* icrc4().transfer_batch_tokens(caller, args, null, null)) {
      case (#trappable(val)) val;
      case (#awaited(val)) val;
      case (#err(#trappable(err))) err;
      case (#err(#awaited(err))) err;
    };
  };

  public shared query func icrc4_balance_of_batch(request : ICRC4.BalanceQueryArgs) : async ICRC4.BalanceQueryResult {
    icrc4().balance_of_batch(request);
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

  /* /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func transfer_listener(trx: ICRC1.Transaction, trxid: Nat) : () {

  };

  /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func approval_listener(trx: ICRC2.TokenApprovalNotification, trxid: Nat) : () {

  };

  /// Uncomment this code to establish have icrc1 notify you when a transaction has occured.
  private func transfer_from_listener(trx: ICRC2.TransferFromNotification, trxid: Nat) : () {

  }; */

  private stable var _init = false;
  public shared (msg) func admin_init() : async () {
    //can only be called once

    if (_init == false) {
      //ensure metadata has been registered
      let test1 = icrc1().metadata();
      let test2 = icrc2().metadata();
      let test4 = icrc4().metadata();
      let test3 = icrc3().stats();

      //uncomment the following line to register the transfer_listener
      //icrc1().register_token_transferred_listener("my_namespace", transfer_listener);

      //uncomment the following line to register the transfer_listener
      //icrc2().register_token_approved_listener("my_namespace", approval_listener);

      //uncomment the following line to register the transfer_listener
      //icrc1().register_transfer_from_listener("my_namespace", transfer_from_listener);
    };
    _init := true;
  };

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
    ignore icrc1();
    ignore icrc2();
    ignore icrc3();
    ignore icrc4();
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
    //re wire up the listener after upgrade
    //uncomment the following line to register the transfer_listener
    //icrc1().register_token_transferred_listener("bobminter", transfer_listener);

    //uncomment the following line to register the transfer_listener
    //icrc2().register_token_approved_listener("my_namespace", approval_listener);

    //uncomment the following line to register the transfer_listener
    //icrc1().register_transfer_from_listener("my_namespace", transfer_from_listener);
  };

};
