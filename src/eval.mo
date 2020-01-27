import T "types.mo";
import A "adapton.mo";

import Array "mo:stdlib/list.mo";
import List "mo:stdlib/list.mo";
import Result "mo:stdlib/result.mo";
import Buf "mo:stdlib/buf.mo";

module {
  public type Exp = T.Eval.Exp;
  public type Exps = List.List<Exp>;
  public type Block = T.Eval.Block;
  public type Val = T.Eval.Val;
  public type Vals = List.List<Val>;
  public type ValTag = T.Eval.ValTag;
  public type Error = T.Eval.Error;
  public type Env = T.Eval.Env;
  public type Name = T.Eval.Name;
  public type Res = Result.Result<Val, Error>;

  public func evalExp(actx: T.Adapton.Context, env:Env, exp:Exp) : Res {
    func eval(e:Exp) : Res = evalExp(actx, env, e);
    switch exp {
      case (#block(block)) { evalBlock(actx, env, block, #unit) };
      case (#list(es)) { evalList(actx, env, es, null) };
      case (#array(es)) { evalArray(actx, env, es, 0, null) };
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
                           case (#add) { evalAdd(v1, v2) };
                           case (#mul) { evalMul(v1, v2) };
                           case (#sub) { evalSub(v1, v2) };
                           case (#div) { evalDiv(v1, v2) };
                           case (#cat) { evalDiv(v1, v2) };
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
      case (#put(e1, e2)) {
             switch (evalExp(actx, env, e1)) {
             case (#err(e)) { #err(e) };
             case (#ok(v1)) {
                    switch (evalExp(actx, env, e2)) {
                    case (#err(e)) { #err(e) };
                    case (#ok(v2)) {
                           switch v1 {
                           case (#name(n)) {
                                  switch (A.put(actx, n, v2)) {
                                  case (#err(pe)) { #err(putError(pe)) };
                                  case (#ok(refId)) { #ok(#ref(refId)) };
                                  }
                                };
                           case v { #err(valueMismatch(v, #name)) };
                           };
                         };
                    }
                  };
             }
           };
      case (#putThunk(e1, e2)) {
             switch (evalExp(actx, env, e1)) {
             case (#err(e)) { #err(e) };
             case (#ok(v1)) {
                    switch v1 {
                      case (#name(n)) {
                             switch (A.putThunk(actx, n, closure(env, e2))) {
                             case (#err(pe)) { #err(putError(pe)) };
                             case (#ok(thunkId)) { #ok(#ref(thunkId)) };
                             }
                           };
                      case v { #err(valueMismatch(v, #name)) };
                    }
                  };
             }
           };
    }
  };

  public func evalBlock(actx: T.Adapton.Context, env:Env,
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

  public func evalArray(actx: T.Adapton.Context, env:Env, exps:[Exp], expi:Nat, vals:Vals) : Res {
    if (expi >= exps.len()) {
      #ok(#array(List.toArray<Val>(List.rev<Val>(vals))))
    }
    else {
      switch (evalExp(actx, env, exps[expi])) {
      case (#ok(v)) { evalArray(actx, env, exps, expi + 1, ?(v, vals)) };
      case (#err(e)) { #err(e) };
      }
    }
  };

  public func evalList(actx: T.Adapton.Context, env:Env,
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

  public func getError(ge:T.Adapton.GetError) : Error {
    { origin=?("eval.Adapton", null);
      message=("get error: " # "to do");
      data=#getError(ge)
    }
  };

  public func putError(pe:T.Adapton.PutError) : Error {
    { origin=?("eval.Adapton", null);
      message=("put error: " # "to do");
      data=#putError(pe)
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

  public func closure(_env:Env, _exp:Exp) : T.Closure.Closure {
    {
      env=_env;
      exp=_exp;
      eval=func (ac:T.Adapton.Context) : Res { evalExp(ac, env, exp) };
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

  public func evalAdd(v1:Val, v2:Val) : Res {
    switch (v1, v2) {
      case (#nat(n1), #nat(n2)) { #ok(#nat(n1 + n2)) };
      case (_, _) {
             #err(missingFeature("addition; missing case."))
           }
    }
  };

  public func evalSub(v1:Val, v2:Val) : Res {
    switch (v1, v2) {
      case (#nat(n1), #nat(n2)) { #ok(#nat(n1 - n2)) };
      case (_, _) {
             #err(missingFeature("subtraction; missing case."))
           }
    }
  };

  public func evalMul(v1:Val, v2:Val) : Res {
    switch (v1, v2) {
      case (#nat(n1), #nat(n2)) { #ok(#nat(n1 * n2)) };
      case (_, _) {
             #err(missingFeature("multiplication; missing case."))
           }
    }
  };

  public func evalCat(v1:Val, v2:Val) : Res {
    switch (v1, v2) {
      case (#text(n1), #text(n2)) { #ok(#text(n1 # n2)) };
      case (_, _) {
             #err(missingFeature("concatenation; missing case."))
           }
    }
  };


}
