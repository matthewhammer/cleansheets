import T "../src/types.mo";
import A "../src/adapton.mo";
import E "../src/eval.mo";

/* To do in the future:

 - `evalLine` function uses caller ID to save per-caller environments and adapton contexts.
 - nice UI that looks like a Cloud-based data science notebook (e.g., https://jupyter.org/)
 - more complete features, and more end-to-end tests...
*/

actor {
  public type Env = T.Eval.Env;
  public type Name = T.Eval.Name;
  public type Exp = T.Eval.Exp;

  var env : T.Eval.Env = null;
  var adaptonCtx : T.Adapton.Context = A.init();

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
