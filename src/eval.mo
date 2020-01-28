import T "types.mo";
import A "adapton.mo";

import Array "mo:stdlib/list.mo";
import List "mo:stdlib/list.mo";
import Result "mo:stdlib/result.mo";
import Buf "mo:stdlib/buf.mo";
import P "mo:stdlib/prelude.mo";

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
      case (#cellOcc(x, y)) { P.unreachable() };
      case (#sheet(sheetName, body)) { evalSheet(actx, env, sheetName, body) };
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
             case (#ok(#refNode(refId))) {
                    switch (A.get(actx, refId)) {
                    case (#ok(res)) { res };
                    case (#err(getErr)) { #err(getError(getErr)) };
                    }
                  };
             case (#ok(#thunkNode(thunkId))) {
                    switch (A.get(actx, thunkId)) {
                    case (#ok(res)) { res };
                    case (#err(getErr)) { #err(getError(getErr)) };
                    }
                  };
             case (#ok(v)) {
                    #err(valueMismatch(v, #refNode))
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
      case (#thunk(e)){ #ok(#thunk(env, e)) };
      case (#force(e)){
             switch (evalExp(actx, env, e)) {
             case (#err(e)) { #err(e) };
             case (#ok(#thunk(env2, e2))) { evalExp(actx, env2, e2) };
             case (#ok(v)) { #err(valueMismatch(v, #thunk)) };
             }
           };
      case (#unit)    { #ok(#unit) };
      case (#name(n)) { #ok(#name(n)) };
      case (#text(t)) { #ok(#text(t)) };
      case (#int(i))  { #ok(#int(i)) };
      case (#nat(n))  { #ok(#nat(n)) };
      case (#bool(b)) { #ok(#bool(b)) };
      case (#refNode(i))  { #ok(#refNode(i)) };
      case (#thunkNode(i)) { #ok(#thunkNode(i)) };
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
                                  case (#ok(refId)) { #ok(#refNode(refId)) };
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
                             case (#ok(thunkId)) { #ok(#thunkNode(thunkId)) };
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

  public func resolveCellOcc(actx: T.Adapton.Context, sheetName:Name, numRows:Nat, numCols:Nat, exp:Exp) : Exp {
    switch exp {
    case (#unit) { #unit };
    case (#name(n)) { #name(n) };
    case (#nat(n)) { #nat(n) };
    case (#error(e)) { #error(e) };
    case (#varocc(n)) { #varocc(n) };
    case (#cellOcc(x,y)) {
           if (x < numRows and y < numCols) {
             let n = #tagTup(sheetName,[#nat(x), #nat(y), #text("out")]);
             #get(#thunkNode({name=n}))
           } else {
             #error({origin=?("eval", null);
                     message= "cellOcc is out of bounds";
                     data=#badCellOcc(sheetName,x,y)})
           }
         };
    case (#strictBinOp(bop, e1, e2)) {
           #strictBinOp(bop,
                        resolveCellOcc(actx, sheetName, numRows, numCols, e1),
                        resolveCellOcc(actx, sheetName, numRows, numCols, e2))
         };
    case _ {
           P.nyi()
         };
    }
  };

  public func evalSheet(actx: T.Adapton.Context, env:Env,
                        sheetName: Name, body:[[Exp]]) : Res {
   /*

    Note The definition of each sheet is "always cyclic" in the sense
that any cell may mention any other cell in its definition, and truly
cyclic definitions are dynamic errors detected by Adapton; they arise
during incremental re-evaluation, where they may come and go as the
cells change dynamically.

    */
    if (body.len() == 0) {
      #ok(#sheet({name=sheetName;
                  grid=[]}))
    } else {
      let columnCount = body[0].len();
      for (rowi in body.keys()) {
        if (body[rowi].len() == columnCount) { /* ok */ } else {
          return #err(columnMiscount(columnCount, rowi, body[rowi].len()))
        }
      };
      let gridBuf = Buf.Buf<[T.Sheet.SheetCell]>(03);
      for (rowi in body.keys()) {
        let rowBuf = Buf.Buf<T.Sheet.SheetCell>(03);
        let row = body[rowi];
        for (coli in row.keys()) {
          let inpName : Name = #tagTup(sheetName, [#nat(rowi), #nat(coli), #text("inp")]);
          let outName : Name = #tagTup(sheetName, [#nat(rowi), #nat(coli), #text("out")]);
          let cellExp : Exp = resolveCellOcc(actx, sheetName, body.len(), row.len(), row[coli]);
          let cellThunk = #thunk(env, cellExp);
          let refNode : A.NodeId = switch (A.put(actx, inpName, cellThunk)) {
          case (#err(e)) { return #err(putError(e)) };
          case (#ok(i)) { i };
          };
          let thunkNode : A.NodeId = switch (
            A.putThunk(actx, outName, closure(env, #force(#get(#refNode(refNode)))))
          ) {
          case (#err(e)) { return #err(putError(e)) };
          case (#ok(i)) { i };
          };
          let sheetCell : T.Sheet.SheetCell = {
            inputExp=refNode;
            evalResult=thunkNode
          };
          rowBuf.add(sheetCell);
        };
        gridBuf.add(rowBuf.toArray());
      };
      let gridArr = gridBuf.toArray();
      // eagerly force the evaluated result of each grid cell, and collect possible errors.
      for (i in gridArr.keys()) {
        for (j in gridArr[i].keys()) {
          switch (A.get(actx, gridArr[i][j].evalResult)) {
            case (#ok(res)) { };
            case (#err(e)) { /* todo -- save error in a buffer; */ }
          }
        };
      };
      #ok(#sheet({name=sheetName;
                  grid=gridArr}))
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

  public func columnMiscount(expectedCount:Nat, offendingRow:Nat, rowCount:Nat) : Error {
    { origin=?("eval", null);
      message=("Sheet construction: Column count mismatch: ...");
      data=#columnMiscount(expectedCount, offendingRow, rowCount)
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
