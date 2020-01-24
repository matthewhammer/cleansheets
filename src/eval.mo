import T "types.mo";
import A "adapton.mo";
import List "mo:stdlib/list.mo";
import Result "mo:stdlib/result.mo";
import Buf "mo:stdlib/buf.mo";

module {
  public type Exp = T.Exp;
  public type Exps = List.List<Exp>;
  public type Block = T.Block;
  public type Val = T.Val;
  public type Vals = List.List<Val>;
  public type ValTag = T.ValTag;
  public type Error = T.Error;
  public type Env = T.Env;
  public type Name = T.Name;
  public type Res = Result.Result<Val, Error>;

  public func evalExp(actx: A.Context, env:Env, exp:Exp) : Res {
    func eval(e:Exp) : Res = evalExp(actx, env, e);
    switch exp {
      case (#block(block)) { evalBlock(actx, env, block, #unit) };
      case (#list(es)) { evalList(actx, env, es, null) };
      case (#error(e)) { #err(e) };
      case (#varocc(x)) {
        switch (envGet(env, x)) {
          case null { #err(varNotFound(env,x)) };
          case (?v) { #ok(v) };
        }
      };
      case (#get(e)) {
             switch (evalExp(actx, env, e)) {
             case (#err(e)) { #err(e) };
             case (#ok(#ref(refId))) {
                    switch (A.get(actx, refId)) {
                      case (#err(getErr)) { #err(getError(getErr)) };
                      case (#ok(res)) { res };
                    }
                  };
             case (#ok(v)) {
                    #err(valueMismatch(v, #ref))
                  };
             }
           };
      case (#strictBinOp(binop, e1, e2)) {
             switch (evalExp(actx, env, e1)) {
             case (#err(e)) { #err(e) };
             case (#ok(v1)) {
                    switch (evalExp(actx, env, e2)) {
                    case (#err(e)) { #err(e) };
                    case (#ok(v2)) {
                           switch (binop) {
                           case (#eq)  { evalEq(v1, v2) };
                           case (#div) { evalDiv(v1, v2) };
                           case _    { #err(missingFeature("binop: to do")) }
                           }
                         };
                    }
                  }
             }
           };
      case (#ifCond(e1, e2, e3)) {
             switch (evalExp(actx, env, e1)) {
               case (#err(e)) { #err(e) };
               case (#ok(#bool(b))) {
                      if b { evalExp(actx, env, e2) }
                      else { evalExp(actx, env, e3) }
                    };
               case (#ok(v)) { #err(valueMismatch(v, #bool)) };
             }
           };
      case (#unit)    { #ok(#unit) };
      case (#ref(r))  { #ok(#ref(r)) };
      case (#thunk(t)){ #ok(#thunk(t)) };
      case (#name(n)) { #ok(#name(n)) };
      case (#text(t)) { #ok(#text(t)) };
      case (#int(i))  { #ok(#int(i)) };
      case (#nat(n))  { #ok(#nat(n)) };
      case (#bool(b)) { #ok(#bool(b)) };
      case (#grid(rows)) {
          /* func evalRow(row:[Exp]) : [Val] = Array.map(row, eval);
          #grid(Array.map(rows, evalRow)) */
            #err(missingFeature("grid expressions"))
        };
      case (#put(e1, e2)) {
            #err(missingFeature("put expressions"))
        };
      case (#putThunk(e, closure)) {
             #err(missingFeature("thunk expressions"))
           };

    }
  };

  public func evalBlock(actx: A.Context, env:Env,
                        block:Block, last:Val) : Res {
    switch block {
      case null { #ok(last) };
      case (?((x, exp), exps)) {
             switch (evalExp(actx, env, exp)) {
             case (#ok(v)) {
                    let env2 = ?((x, v), env);
                    evalBlock(actx, env2, exps, v);
                  };
             case (#err(e)) { #err(e) };
             }
           };
    }
  };

  public func evalList(actx: A.Context, env:Env,
                       exps:Exps, vals:Vals) : Res {
    switch exps {
      case null { #ok(#list(List.rev<Val>(vals))) };
      case (?(exp, exps)) {
             switch (evalExp(actx, env, exp)) {
             case (#ok(v)) { evalList(actx, env, exps, ?(v, vals)); };
             case (#err(e)) { #err(e) };
             }
           };
    }
  };

  public func envGet(env:Env, varocc:Name) : ?Val {
    assert false; null
  };

  public func getError(ge:T.GetError) : Error {
    { origin=?("eval.Adapton", null);
      message=("get error: " # "to do");
      data=#getError(ge)
    }
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

  public func valueMismatch(v:Val, t:ValTag) : Error {
    { origin=?("eval", null);
      message=("Dynamic type error: ...");
      data=#valueMismatch(v, t)
    }
  };

  public func closure(_env:Env, _exp:Exp) : T.Closure {
    {
      env=_env;
      exp=_exp;
      eval=func (ac:A.Context) : Res { evalExp(ac, env, exp) };
    }
  };

  public func evalEq(v1:Val, v2:Val) : Res {
    switch (v1, v2) {
      case (#nat(n1), #nat(n2)) { #ok(#bool(n1 == n2)) };
      case (_, _) {
             #err(missingFeature("boolean eq test; missing case."))
           }
    }
  };

  public func evalDiv(v1:Val, v2:Val) : Res {
    switch (v1, v2) {
      case (#nat(n1), #nat(n2)) { #ok(#nat(n1 / n2)) };
      case (_, _) {
             #err(missingFeature("division; missing case."))
           }
    }
  };


}
