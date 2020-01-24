import T "types.mo";
import A "adapton.mo";
import List "mo:stdlib/list.mo";
import Result "mo:stdlib/result.mo";
import Buf "mo:stdlib/buf.mo";

module {
  public type Exp = T.Exp;
  public type Val = T.Val;
  public type Error = T.Error;
  public type Env = T.Env;
  public type Name = T.Name;
  public type Res = Result.Result<Val, Error>;

  public func envGet(env:Env, varocc:Name) : ?Val {
    assert false; null
  };

  public func varNotFound(env:Env, varocc:Name) : Error {
    { origin=?("eval", null);
      message=("Variable not found: " # "to do");
      data=#varNotFound(env, varocc)
    }
  };

  public func missingFeature(feat:Text) : Error {
    { origin=?("eval", null);
      message=("Missing feature: " # feat);
      data=#missingFeature(feat)
    }
  };
  
  public func closure(_env:Env, _exp:Exp) : T.Closure {
    {
      env=_env;
      exp=_exp;
      eval=func (ac:A.Context) : Res { evalExp(ac, env, exp) };
    }
  };

  public func evalExp(actx: A.Context, env:Env, exp:Exp) : Res {
    func eval(e:Exp) : Res = evalExp(actx, env, e);
    switch exp {
      case (#error(e)) { #err(e) };
      case (#varocc(x)) {
        switch (envGet(env, x)) {
          case null { #err(varNotFound(env,x)) };
          case (?v) { #ok(v) };
        }
      };
      case (#ref(r))  { #ok(#ref(r)) };
      case (#thunk(t)){ #ok(#thunk(t)) };
      case (#name(n)) { #ok(#name(n)) };
      case (#text(t)) { #ok(#text(t)) };
      case (#int(i))  { #ok(#int(i)) };
      case (#nat(n))  { #ok(#nat(n)) };
      case (#list(es)) { 
             assert false;
             #err(missingFeature("list expressions"))
           };
      case (#grid(rows)) {
          /* func evalRow(row:[Exp]) : [Val] = Array.map(row, eval);
          #grid(Array.map(rows, evalRow)) */
            #err(missingFeature("grid expressions"))
        };
      case (#block(block)) {
             #err(missingFeature("block expressions"))
           };
      case (#binOp(b, e1, e2)) {
             #err(missingFeature("binop expressions"))
           };

      case (#get(e)) {
             #err(missingFeature("get expressions"))
           };
      case (#put(e1, e2)) {
            #err(missingFeature("put expressions"))
        };
      case (#putThunk(e, closure)) {
             #err(missingFeature("thunk expressions"))
           };

    }
  }
}
