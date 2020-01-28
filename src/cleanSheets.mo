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
  public shared { caller = c }
  func eval(n:?Name, exp:Exp)
    : async T.Eval.Result
  {
    let res = E.evalExp(adaptonCtx, env, exp);
    switch (res, n) {
    case (#err(err), _) { return #err(err) };
    case (#ok(resVal), null) { return #ok(resVal) };
    case (#ok(resVal), ?resName) {
           // the environment collects all variables together,
           // but each caller only shadows their own definitions:
           let callerId : Blob = c;
           let varName = #tagTup(resName, [#blob callerId]);
           env := ?((varName, resVal), env);
           #ok(resVal)
         };
    }
  };

  // list the entire (public) environment
  // (to do -- "private state" via faceted values, or something else)
  public func getEnv() : async T.Eval.Env { env };

}

/* To do in the future:

 - Nice UI that looks like a Cloud-based data science notebook
   (e.g., https://jupyter.org/), or the basic outlines of one.

 - `eval` function uses caller ID to save
   per-caller resources (environments and adapton contexts).

 - more complete formula features, and more end-to-end tests...

 - some basic abstractions for privacy; e.g., "faceted values" would be nice.

 - inter-canister dependencies and inter-canister updates.

*/
