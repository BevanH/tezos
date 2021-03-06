(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)

open Alpha_context

let custom_root =
  (RPC_path.(open_root / "context" / "contracts") : RPC_context.t RPC_path.context)

type info = {
  manager: public_key_hash ;
  balance: Tez.t ;
  spendable: bool ;
  delegate: bool * public_key_hash option ;
  counter: int32 ;
  script: Script.t option ;
  storage: Script.expr option ;
}

let info_encoding =
  let open Data_encoding in
  conv
    (fun {manager ; balance ; spendable ; delegate ; script ; counter ; storage } ->
       (manager, balance, spendable, delegate, script, storage, counter))
    (fun (manager, balance, spendable, delegate, script, storage, counter) ->
       {manager ; balance ; spendable ; delegate ; script ; storage ; counter}) @@
  obj7
    (req "manager" Ed25519.Public_key_hash.encoding)
    (req "balance" Tez.encoding)
    (req "spendable" bool)
    (req "delegate" @@ obj2
       (req "setable" bool)
       (opt "value" Ed25519.Public_key_hash.encoding))
    (opt "script" Script.encoding)
    (opt "storage" Script.expr_encoding)
    (req "counter" int32)

module S = struct

  open Data_encoding

  let balance =
    RPC_service.post_service
      ~description: "Access the balance of a contract."
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "balance" Tez.encoding))
      RPC_path.(custom_root /: Contract.arg / "balance")

  let manager =
    RPC_service.post_service
      ~description: "Access the manager of a contract."
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "manager" Ed25519.Public_key_hash.encoding))
      RPC_path.(custom_root /: Contract.arg / "manager")

  let delegate =
    RPC_service.post_service
      ~description: "Access the delegate of a contract, if any."
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "delegate" Ed25519.Public_key_hash.encoding))
      RPC_path.(custom_root /: Contract.arg / "delegate")

  let counter =
    RPC_service.post_service
      ~description: "Access the counter of a contract, if any."
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "counter" int32))
      RPC_path.(custom_root /: Contract.arg / "counter")

  let spendable =
    RPC_service.post_service
      ~description: "Tells if the contract tokens can be spent by the manager."
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "spendable" bool))
      RPC_path.(custom_root /: Contract.arg / "spendable")

  let delegatable =
    RPC_service.post_service
      ~description: "Tells if the contract delegate can be changed."
      ~query: RPC_query.empty
      ~input: empty
      ~output: (obj1 (req "delegatable" bool))
      RPC_path.(custom_root /: Contract.arg / "delegatable")

  let script =
    RPC_service.post_service
      ~description: "Access the code and data of the contract."
      ~query: RPC_query.empty
      ~input: empty
      ~output: Script.encoding
      RPC_path.(custom_root /: Contract.arg / "script")

  let storage =
    RPC_service.post_service
      ~description: "Access the data of the contract."
      ~query: RPC_query.empty
      ~input: empty
      ~output: Script.expr_encoding
      RPC_path.(custom_root /: Contract.arg / "storage")

  let info =
    RPC_service.post_service
      ~description: "Access the complete status of a contract."
      ~query: RPC_query.empty
      ~input: empty
      ~output: info_encoding
      RPC_path.(custom_root /: Contract.arg)

  let list =
    RPC_service.post_service
      ~description:
        "All existing contracts (including non-empty default contracts)."
      ~query: RPC_query.empty
      ~input: empty
      ~output: (list Contract.encoding)
      custom_root

end

let () =
  let open Services_registration in
  register0 S.list begin fun ctxt () () ->
    Contract.list ctxt >>= return
  end

let () =
  let open Services_registration in
  let register_field s f =
    register1 s (fun ctxt contract () () ->
        Contract.exists ctxt contract >>=? function
        | true -> f ctxt contract
        | false -> raise Not_found) in
  let register_opt_field s f =
    register_field s
      (fun ctxt a1 ->
         f ctxt a1 >>=? function
         | None -> raise Not_found
         | Some v -> return v) in
  register_field S.balance Contract.get_balance ;
  register_field S.manager Contract.get_manager ;
  register_opt_field S.delegate Delegate.get ;
  register_field S.counter Contract.get_counter ;
  register_field S.spendable Contract.is_spendable ;
  register_field S.delegatable Contract.is_delegatable ;
  register_opt_field S.script Contract.get_script ;
  register_opt_field S.storage Contract.get_storage ;
  register_field S.info (fun ctxt contract ->
      Contract.get_balance ctxt contract >>=? fun balance ->
      Contract.get_manager ctxt contract >>=? fun manager ->
      Delegate.get ctxt contract >>=? fun delegate ->
      Contract.get_counter ctxt contract >>=? fun counter ->
      Contract.is_delegatable ctxt contract >>=? fun delegatable ->
      Contract.is_spendable ctxt contract >>=? fun spendable ->
      Contract.get_script ctxt contract >>=? fun script ->
      Contract.get_storage ctxt contract >>=? fun storage ->
      return { manager ; balance ;
               spendable ; delegate = (delegatable, delegate) ;
               script ; counter ; storage})

let list ctxt block =
  RPC_context.make_call0 S.list ctxt block () ()

let info ctxt block contract =
  RPC_context.make_call1 S.info ctxt block contract () ()

let balance ctxt block contract =
  RPC_context.make_call1 S.balance ctxt block contract () ()

let manager ctxt block contract =
  RPC_context.make_call1 S.manager ctxt block contract () ()

let delegate ctxt block contract =
  RPC_context.make_call1 S.delegate ctxt block contract () ()

let delegate_opt ctxt block contract =
  RPC_context.make_opt_call1 S.delegate ctxt block contract () ()

let counter ctxt block contract =
  RPC_context.make_call1 S.counter ctxt block contract () ()

let is_delegatable ctxt block contract =
  RPC_context.make_call1 S.delegatable ctxt block contract () ()

let is_spendable ctxt block contract =
  RPC_context.make_call1 S.spendable ctxt block contract () ()

let script ctxt block contract =
  RPC_context.make_call1 S.script ctxt block contract () ()

let script_opt ctxt block contract =
  RPC_context.make_opt_call1 S.script ctxt block contract () ()

let storage ctxt block contract =
  RPC_context.make_call1 S.storage ctxt block contract () ()

let storage_opt ctxt block contract =
  RPC_context.make_opt_call1 S.storage ctxt block contract () ()

