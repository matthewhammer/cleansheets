import R "mo:stdlib/result.mo";
import P "mo:stdlib/prelude.mo";

import T "../src/types.mo";
import E "../src/eval.mo";
import A "../src/adapton.mo";

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

    // "cell 2 holds 1":
    let cell2 : A.NodeId = assertOkPut(A.put(ctx, #nat(2), #nat(1)));

    // "cell 3 holds [[cell1 / cell2]], still unevaluated":
    let cell3 : A.NodeId = assertOkPut(
      A.putThunk(ctx, #nat(3),
                 E.closure(
                   null,
                   #binOp(#div,
                          #ref(cell1),
                          #ref(cell2)))
      ));

    // demand division:
    let res1 = assertOkGet(A.get(ctx, cell3));
    switch res1 {
      case (#ok(#nat(42))) { };
      case _ { assert false };
    };

    // "cell 2 holds 0":
    ignore A.put(ctx, #nat(2), #nat(1));

    // re-demand division:
    let res2 = assertOkGet(A.get(ctx, cell3));
    switch res1 {
      case (#err(_)) { };
      case _ { assert false };
    };

    // "cell 2 holds 1":
    ignore A.put(ctx, #nat(2), #nat(1));

    // re-demand division:
    let res3 = assertOkGet(A.get(ctx, cell3));
    switch res1 {
      case (#ok(#nat(42))) { };
      case _ { assert false };
    };

  };
}