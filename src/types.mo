import P "mo:stdlib/prelude";
import Buf "mo:stdlib/buf";
import Hash "mo:stdlib/hash";
import List "mo:stdlib/list";
import H "mo:stdlib/hashMap";
import L "mo:stdlib/list";

module {

public module Sheet {

  // A sheet has a 2D grid of cells
  public type Sheet = {
    name: Eval.Name; // (name used for globally-unique Adapton resources)
    grid: [[SheetCell]];
    errors: [Eval.Error];
  };

  // A sheet cell holds an expression to eval, and the eval result
  public type SheetCell = {
    // Adapton ref cell we can mutate via `put`:
    inputExp: Adapton.NodeId;
    // Adapton incr thunk we can demand via `get`:
    evalResult: Adapton.NodeId;
  };
};

public module Eval {

  public type NodeId = Adapton.NodeId;

  // spreadsheet formula language:
  public type Exp = {
    #unit;
    #name: Name;
    #error: Error;
    #varocc: Name;
    #text: Text;
    #nat: Nat;
    #int: Int;
    #bool: Bool;
    #list: List<Exp>;
    #array: [Exp];
    #sheet: (Name, [[Exp]]);
    #sheetUpdate: (Exp, Exp, Exp, Exp); // update sheet at 2D coord with new expression
    #cellOcc: (Nat, Nat); // for now: cell occurrences use number-based coordinates
    #force: Exp;
    #thunk: Exp;
    #block: Block;
    #ifCond: (Exp, Exp, Exp);
    #strictBinOp: (StrictBinOp, Exp, Exp);
    #put: (Exp, Exp);
    #putThunk: (Exp, Exp);
    #get: Exp;
    #refNode: NodeId; // adapton ref node
    #thunkNode: NodeId; // adapton thunk node
  };

  public type Block =
    List<(Name, Exp)>;

  // to do --
  //  this matches standard library definition; copying to overcome cyclic def compiler error.
  public type Result = {#ok:Val; #err:Error};

  // strict means left and right sides _always_ evaluated to values
  public type StrictBinOp = {
    #eq;
    #div;
    #add;
    #sub;
    #mul;
    #cat;
  };

  // for more helpful dynamic type errors
  public type ValTag = {
    #unit;
    #name;
    #bool;
    #nat;
    #int;
    #thunk;
    #list;
    #array;
    #sheet;
    #refNode;
    #thunkNode;
  };

  public type Val = {
    #unit;
    #name: Name;
    #bool: Bool;
    #text: Text;
    #nat: Nat;
    #int: Int;
    #array: [Val];
    #list: List<Val>;
    #thunk: (Env, Exp);
    #sheet: Sheet.Sheet;
    #refNode: NodeId; // adapton ref node
    #thunkNode: NodeId; // adapton thunk node
  };

  public type Name = {
    #text: Text;
    #nat: Nat;
    #tagTup: (Name, [Name]);
  };

  type List<X> = List.List<X>;

  public type Env = List<(Name, Val)>;

  public type Error = {
    #uninitializedEvaluatorField;
    #cyclicDependency: (Adapton.Stack, Name);
    #varNotFound: (Env, Name);
    #missingFeature: Text;
    #valueMismatch: (Val, ValTag);
    #getError: Adapton.GetError;
    #putError: Adapton.PutError;
    #badCellOcc: (Name, Nat, Nat);
    #columnMiscount: (Nat, Nat, Nat); // (expected col count, first bad row, row's actual count)
  };

  public type HashVal = Hash.Hash;

  // ---------------------- all type definitions above ----------------------
  // ---------------------- all function definitions below ------------------

  public func nameHash(n:Name) : HashVal {
    // to do -- fix hash collisions introduced here:
    0
  };

  public func envEq(env1:Env, env2:Env) : Bool {
    switch (env1, env2) {
      case (null, null) { true };
      case (_, _) {
             // to do
             false
           };
    }
  };

  public func strictBinOpEq(b1:StrictBinOp, b2:StrictBinOp) : Bool {
    switch (b1, b2) {
    case (#add, #add) { true };
    case (#mul, #mul) { true };
    case (_, _) { /* to do */ false };
    }
  };

  public func expEq(e1:Exp, e2:Exp) : Bool {
    switch (e1, e2) {
      case (#nat(n1), #nat(n2)) { n1 == n2 };
      case (#force(e1), #force(e2)) { expEq(e1, e2) };
      case (#thunk(e1), #thunk(e2)) { expEq(e1, e2) };
      case (#get(e1), #get(e2)) { expEq(e1, e2) };
      case (#thunkNode(n1), #thunkNode(n2)) { nameEq(n1.name, n2.name) };
      case (#refNode(n1), #refNode(n2)) { nameEq(n1.name, n2.name) };
      case (#strictBinOp(bop1, e11, e12), #strictBinOp(bop2, e21, e22)) {
             strictBinOpEq(bop1, bop2) and expEq(e11, e21) and expEq(e12, e22)
           };
      case (_, _) { P.nyi() };
    }
  };

  public func valEq(v1:Val, v2:Val) : Bool {
    switch (v1, v2) {
    case (#nat(n1), #nat(n2)) { n1 == n2 };
    case (#thunk(env1, e1), #thunk(env2, e2)) {
           envEq(env1, env2) and expEq(e1, e2)
         };
    case (_, _) { P.nyi() };
    }
  };

  public func errorEq(err1:Error, err2:Error) : Bool {
    // to do
    false
  };

  public func resultEq(r1:Result, r2:Result) : Bool {
    switch (r1, r2) {
    case (#ok(v1), #ok(v2)) { valEq(v1, v2) };
    case (#err(e1), #err(e2)) { errorEq(e1, e2) };
    case (_, _) { false };
    }
  };

  public func nameEq(n1:Name, n2:Name) : Bool {
    switch (n1, n2) {
    case (#nat(n1), #nat(n2)) { n1 == n2 };
    case (#text(t1), #text(t2)) { t1 == t2 };
    case (#tagTup(tag1, tup1), #tagTup(tag2, tup2)) {
           if (nameEq(tag1, tag2)) {
             if (tup1.len() == tup2.len()) {
               for (i in tup1.keys()) {
                 if(nameEq(tup1[i], tup2[i])) {
                   // continue checking...
                 } else { return false }
               }; true
             } else { false };
           } else { false };
         };
    case (_, _) { false };
    }
  };

};

// Each closure's type (transitively) uses all the types defined here.
public module Closure {

  public type Closure = {
    env: Eval.Env;
    exp: Eval.Exp;
  };

  public func closureEq(c1:Closure, c2:Closure) : Bool {
    Eval.envEq(c1.env, c2.env)
    and Eval.expEq(c1.exp, c2.exp)
  };
};

// Types that represent Adapton state, and the demanded computation graph (DCG).
public module Adapton {

  public type Name = Eval.Name;
  public type Closure = Closure.Closure;
  public type Val = Eval.Val;
  public type Result = Eval.Result;

  public type Store = H.HashMap<Name, Node>;
  public type Stack = L.List<Name>;
  public type EdgeBuf = Buf.Buf<Edge>;

  public type NodeId = {
    name: Name
  };

  public type Ref = {
    content: Val;
    incoming: EdgeBuf;
  };

  public type Thunk = {
    closure: Closure;
    result: ?Result;
    outgoing: [Edge];
    incoming: EdgeBuf;
  };

  public type Edge = {
    dependent: NodeId;
    dependency: NodeId;
    checkpoint: Action;
    var dirtyFlag: Bool
  };

  public type Action = {
    #put:Val;
    #putThunk:Closure;
    #get:Result;
  };

  public type PutError = (); // to do
  public type GetError = (); // to do

  // Logs are tree-structured.
  public type LogEvent = {
    #put:      (Name, Val, [LogEvent]);
    #putThunk: (Name, MissingClosure, [LogEvent]);
    #get:      (Name, Result, [LogEvent]);
    #dirtyIncomingTo:(Name, [LogEvent]);
    #dirtyEdgeFrom:(Name, [LogEvent]);
    #cleanEdgeTo:(Name, Bool, [LogEvent]);
    #cleanThunk:(Name, Bool, [LogEvent]);
    #evalThunk:(Name, Result, [LogEvent]);
  };
  public type MissingClosure = (); // to get the compiler to accept things
  public type LogEventTag = {
    #put:      (Name, Val);
    #putThunk: (Name, MissingClosure);
    #get:      (Name, Result);
    #dirtyIncomingTo:Name;
    #dirtyEdgeFrom: Name;
    #cleanEdgeTo:(Name, Bool);
    #cleanThunk:(Name, Bool);
    #evalThunk:(Name, Result);
  };
  public type LogEventBuf = Buf.Buf<LogEvent>;
  public type LogBufStack = List.List<LogEventBuf>;

  public type Node = {
    #ref:Ref;
    #thunk:Thunk;
  };

  public type Context = {
    var agent: {#editor; #archivist};
    var edges: EdgeBuf;
    var stack: Stack;
    var store: Store;
    // logging for debugging; not essential for other state:
    var logFlag: Bool;
    var logBuf: LogEventBuf;
    var logStack: LogBufStack;
    // initially gives errors; real `eval` is installed by `Eval` module:
    var eval: (Context, Eval.Env, Eval.Exp) -> Eval.Result;
  };

  public func logEventsEq (e1:[LogEvent], e2:[LogEvent]) : Bool {
    if (e1.len() == e2.len()) {
      for (i in e1.keys()) {
        if (logEventEq(e1[i], e2[i])) {
          /* continue */
        } else {
          return false
        }
      };
      true
    } else { false }
  };

  public func logEventEq (e1:LogEvent, e2:LogEvent) : Bool {
    switch (e1, e2) {
    case (#put(n1, v1, es1), #put(n2, v2, es2)) {
           Eval.nameEq(n1, n2) and Eval.valEq(v1, v2) and logEventsEq(es1, es2)
         };
    case (#putThunk(n1, c1, es1), #putThunk(n2, c2, es2)) {
           P.nyi()
         };
    case (#get(n1, r1, es1), #get(n2, r2, es2)) {
           Eval.nameEq(n1, n2) and Eval.resultEq(r1, r2) and logEventsEq(es1, es2)
         };
    case (#dirtyIncomingTo(n1, es1), #dirtyIncomingTo(n2, es2)) {
           Eval.nameEq(n1, n2) and logEventsEq(es1, es2)
         };
    case (#dirtyEdgeFrom(n1, es1), #dirtyEdgeFrom(n2, es2)) {
           Eval.nameEq(n1, n2) and logEventsEq(es1, es2)
         };
    case (#cleanEdgeTo(n1, f1, es1), #cleanEdgeTo(n2, f2, es2)) {
           Eval.nameEq(n1, n2) and f1 == f2 and logEventsEq(es1, es2)
         };
    case (#cleanThunk(n1, f1, es1), #cleanThunk(n2, f2, es2)) {
           Eval.nameEq(n1, n2) and f1 == f2 and logEventsEq(es1, es2)
         };
    case (#evalThunk(n1, r1, es1), #evalThunk(n2, r2, es2)) {
           Eval.nameEq(n1, n2) and Eval.resultEq(r1, r2) and logEventsEq(es1, es2)
         };
    case (_, _) {
           false
         }
    }

  };

};

}
