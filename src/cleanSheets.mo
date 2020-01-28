import T "../src/types.mo";
import A "../src/adapton.mo";
import E "../src/eval.mo";

actor {
  public type Env = T.Eval.Env;
  public type Name = T.Eval.Name;
  public type Exp = T.Eval.Exp;

  var env : T.Eval.Env = null;
  var adaptonCtx : T.Adapton.Context = A.init();

  // the `E` part of a Cloud-backed `REPL` for the CleanSheets lang.
  public func eval(n:?Name, exp:Exp) : async T.Eval.Result {
    let res = E.evalExp(adaptonCtx, env, exp);
    switch (res, n) {
    case (#err(e), _) { return #err(e) };
    case (#ok(v), null) { return #ok(v) };
    case (#ok(v), ?n) {
           env := ?((n, v), env);
           #ok(v)
         };
    }
  };
}

/* To do in the future:

 - Nice UI that looks like a Cloud-based data science notebook
   (e.g., https://jupyter.org/), or the basic outlines of one.

 - `eval` function uses caller ID to save
   per-caller resources (environments and adapton contexts).

 - more complete formula features, and more end-to-end tests...

 - inter-canister dependencies and inter-canister updates.

*/
