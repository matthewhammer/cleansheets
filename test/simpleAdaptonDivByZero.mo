import R "mo:stdlib/result.mo";
import P "mo:stdlib/prelude.mo";

import T "../src/types.mo";
import E "../src/eval.mo";
import A "../src/adapton.mo";

// Same example (with pictures) from Adapton Rust docs, here:
//
//    https://docs.rs/adapton/0/adapton/#demand-driven-change-propagation
//
actor SimpleAdaptonDivByZero {

  func assertOkPut(r:R.Result<A.NodeId, A.PutError>) : A.NodeId {
    switch r {
      case (#ok(id)) { id };
      case _ { P.unreachable() };
    }
  };

  func assertOkGet(r:R.Result<T.Result, A.GetError>) : T.Result {
    switch r {
      case (#ok(res)) { res };
      case _ { P.unreachable() };
    }
  };

  public func go() {
    let ctx : A.Context = A.init();

    // "cell 1 holds 42":
    let cell1 : A.NodeId = assertOkPut(A.put(ctx, #nat(1), #nat(42)));

    // "cell 2 holds 2":
    let cell2 : A.NodeId = assertOkPut(A.put(ctx, #nat(2), #nat(2)));

    // "cell 3 holds a suspended closure for this expression:
    //
    //   get(cell1) / get(cell2)
    //
    // ...and it is still unevaluated".
    //
    let cell3 : A.NodeId = assertOkPut(
      A.putThunk(ctx, #nat(3),
                 E.closure(
                   null,
                   #strictBinOp(#div,
                                #get(#ref(cell1)),
                                #get(#ref(cell2))
                   )))
    );

    // "cell 4 holds a suspended closure for this expression:
    //
    //   if (get(cell2) == 0) { 0 }
    //   else { get(cell3) }
    //
    // ...and it is still unevaluated".
    //
    let cell4 : A.NodeId = assertOkPut(
      A.putThunk(ctx, #nat(4),
                 E.closure(
                   null,
                   #ifCond(#strictBinOp(#eq,
                                        #get(#ref(cell2)),
                                        #nat(0)),
                           #nat(0),
                           #get(#ref(cell3)))))
    );

    // demand division:
    let res1 = assertOkGet(A.get(ctx, cell4));
    switch res1 {
      case (#ok(#nat(21))) { };
      case _ { assert false };
    };

    // "cell 2 holds 0":
    ignore A.put(ctx, #nat(2), #nat(0));

    // re-demand division:
    let res2 = assertOkGet(A.get(ctx, cell4));
    switch res2 {
      case (#ok(#nat(0))) { };
      case _ { assert false };
    };

    // "cell 2 holds 1":
    ignore A.put(ctx, #nat(2), #nat(2));

    // re-demand division:
    let res3 = assertOkGet(A.get(ctx, cell4));
    switch res3 {
      case (#ok(#nat(21))) { };
      case _ { assert false };
    };

    // inspect the events
    let events = A.getLogEvents(ctx);
  };
};

SimpleAdaptonDivByZero.go();

/*
Log summary:
---------------

Cleaning/dirtying looks right, except the inner log of the #get ops on cell4 seem absent; investigation is to do:

- #put(#nat(1), #nat(42), []),
- #put(#nat(2), #nat(2), []),
- #putThunk(#nat(3), {env = null; eval = func; exp = #strictBinOp(#div, #get(#ref({name = #nat(1)})), #get(#ref({name = #nat(2)})))}, []),
- #putThunk(#nat(4), {env = null; eval = func; exp = #ifCond(#strictBinOp(#eq, #get(#ref({name = #nat(2)})), #nat(0)), #nat(0), #get(#ref({name = #nat(3)})))}, []),

- #get(#nat(4), #ok(#nat(21)), [
  #evalThunk(#nat(4), #ok(#nat(21)), [])
  ]),

- #put(#nat(2), #nat(0), [
  #dirtyIncomingTo(#nat(2), [
     #dirtyEdgeFrom(#nat(3), [
      #dirtyIncomingTo(#nat(3), [
        #dirtyEdgeFrom(#nat(4), [
          #dirtyIncomingTo(#nat(4), [])
          ])])]),
      #dirtyEdgeFrom(#nat(4), [
        #dirtyIncomingTo(#nat(4), [])
      ])
    ])
  ]),

- #get(#nat(4), #ok(#nat(0)),  [
    #cleanThunk(#nat(4), false, [
    #cleanEdgeTo(#nat(2), false, [])]),
    #evalThunk(#nat(4), #ok(#nat(0)), [])]),

- #put(#nat(2), #nat(2), [
   #dirtyIncomingTo(#nat(2), [
     #dirtyEdgeFrom(#nat(4), [
       #dirtyIncomingTo(#nat(4), [])])])]),

- #get(#nat(4), #ok(#nat(21)), [
   #cleanThunk(#nat(4), false, [
     #cleanEdgeTo(#nat(2), false, [])]),
   #evalThunk(#nat(4), #ok(#nat(21)), [])])

*/
