import P "mo:stdlib/prelude.mo";
import Buf "mo:stdlib/buf.mo";
import Hash "mo:stdlib/hash.mo";
import List "mo:stdlib/list.mo";
import Result "mo:stdlib/result.mo";
import H "mo:stdlib/hashMap.mo";
import L "mo:stdlib/list.mo";

module {

// to do: move to stdlib:
public type OrdComp = {
  #lessThan;
  #equalTo;
  #greaterThan
};

public type HashVal = Hash.Hash;

public module Eval {

  public type NodeId = Adapton.NodeId;

  // spreadsheet formula language:
  public type Exp = {
    #ref: NodeId; // adapton ref node
    #thunk: NodeId; // adapton thunk node
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
    #block: Block;
    #ifCond: (Exp, Exp, Exp);
    #strictBinOp: (StrictBinOp, Exp, Exp);
    #put: (Exp, Exp);
    #putThunk: (Exp, Exp);
    #get: Exp;
  };

  public type Block =
    List<(Name, Exp)>;

  public type Error = {
    origin: List<Text>;
    message: Text;
    data: ErrorData;
  };

  public type Result = Result.Result<Val, Error>;

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
    #list;
    #array;
    #ref;
    #thunk;
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
    #grid: [[Val]];
    #ref: NodeId; // adapton ref node
    #thunk: NodeId; // adapton thunk node
  };

  public type Name = {
    #text: Text;
    #nat: Nat;
    #tagTup: (Name, [Name]);
  };

  type List<X> = List.List<X>;

  public type Env = List<(Name, Val)>;

  public type ErrorData = {
    #varNotFound: (Env, Name);
    #missingFeature: Text;
    #valueMismatch: (Val, ValTag);
    #getError: Adapton.GetError;
    #putError: Adapton.PutError;
  };

  // ---------------------- all type definitions above ----------------------
  // ---------------------- all function definitions below ------------------

  public func nameHash(n:Name) : HashVal {
    // to do -- fix hash collisions introduced here:
    0
  };

  public func valEq(v1:Val, v2:Val) : Bool {
    switch (v1, v2) {
    case (#nat(n1), #nat(n2)) { n1 == n2 };
    case (_, _) { P.nyi() };
    }
  };

  public func errorEq(err1:ErrorData, err2:ErrorData) : Bool {
    // to do
    false
  };

  public func resultEq(r1:Result, r2:Result) : Bool {
    switch (r1, r2) {
    case (#ok(v1), #ok(v2)) { valEq(v1, v2) };
    case (#err(e1), #err(e2)) { errorEq(e1.data, e2.data) };
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
    // ------------
    // invariant: for all c:Closure.
    //   c.eval == \ctx. Eval.evalExp(ctx, c.env, c.exp)
    // (only the Eval module creates these closures)
    eval: Adapton.Context -> Eval.Result;
  };
  
  public func closureEq(c1:Closure, c2:Closure) : Bool {
    P.nyi()
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
    #putThunk: (Name, Closure, [LogEvent]);
    #get:      (Name, Result, [LogEvent]);
    #dirtyIncomingTo:(Name, [LogEvent]);
    #dirtyEdgeFrom:(Name, [LogEvent]);
    #cleanEdgeTo:(Name, Bool, [LogEvent]);
    #cleanThunk:(Name, Bool, [LogEvent]);
    #evalThunk:(Name, Result, [LogEvent]);
  };
  public type LogEventTag = {
    #put:      (Name, Val);
    #putThunk: (Name, Closure);
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
    var logBuf: LogEventBuf;
    var logStack: LogBufStack;
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
