import P "mo:stdlib/prelude.mo";
import Buf "mo:stdlib/buf.mo";
import Hash "mo:stdlib/hash.mo";
import List "mo:stdlib/list.mo";
import Result "mo:stdlib/result.mo";
import H "mo:stdlib/hashMap.mo";
import L "mo:stdlib/list.mo";

// formal grammar of spreadsheet language:
module {

// to do: move to stdlib:
public type OrdComp = {
  #lessThan;
  #equalTo;
  #greaterThan
};

public type HashVal = Hash.Hash;

// for more helpful dynamic type errors
public type ValTag = {
  #unit;
  #name;
  #bool;
  #nat;
  #int;
  #list;
  #grid;
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

public type NodeId = {
  name: Name
};

type List<X> = List.List<X>;

public type Env = List<(Name, Val)>;

public type PutError = (); // to do
public type GetError = (); // to do

public type ErrorData = {
  #varNotFound: (Env, Name);
  #missingFeature: Text;
  #valueMismatch: (Val, ValTag);
  #getError: GetError;
  #putError: PutError;
};

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
  #grid: [[Exp]];
  #block: Block;
  #ifCond: (Exp, Exp, Exp);
  #strictBinOp: (StrictBinOp, Exp, Exp);
  #put: (Exp, Exp);
  #putThunk: (Exp, Closure);
  #get: Exp;
};

public type Block =
  List<(Name, Exp)>;

public type Closure = {
  env: Env;
  exp: Exp;
  // ------------
  // invariant: for all c:Closure.
  //   c.eval == \ctx. Eval.evalExp(ctx, c.env, c.exp)
  eval: Adapton.Context -> Result;
};


public module Adapton {

public type Store = H.HashMap<Name, Node>;
public type Stack = L.List<(Name, Node)>;
public type EdgeBuf = Buf.Buf<Edge>;

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

// Logs are tree-structured.
public type LogEvent = {
  #put: (Val, NodeId, [LogEvent]);
  #putThunk: (Closure, NodeId, [LogEvent]);
  #get: (Result, NodeId, [LogEvent]);
};
public type LogEventBuf = Buf.Buf<LogEvent>;

public type Node = {
  #ref:Ref;
  #thunk:Thunk;
};

public type Context = {
  var agent: {#editor; #archivist};
  var edges: EdgeBuf;
  var logeb: LogEventBuf;
  var stack: Stack;
  var store: Store;
};

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

public func closureEq(c1:Closure, c2:Closure) : Bool {
  P.nyi()
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

// delete this?
module Comp {

public func valComp(v1:Val, v2:Val) : OrdComp {
  P.nyi()
};

// to do: move to stdlib:
public func natComp(n1:Nat, n2:Nat) : OrdComp {
  if (n1 == n2) { #equalTo }
  else if (n1 < n2) { #lessThan }
  else { #greaterThan }
};

// to do: move to stdlib:
public func textComp(t1:Text, t2:Text) : OrdComp {
  P.nyi()
};

public func nameComp(n1:Name, n2:Name) : OrdComp {
  switch (n1, n2) {
  case (#nat(n1), #nat(n2)) { natComp(n1, n2) };
  case (#text(t1), #text(t2)) { textComp(t1, t2) };
  case (#tagTup(tag1, tup1), #tagTup(tag2, tup2)) {
         switch (nameComp(tag1, tag2)) {
           case (#equalTo) {
                  if (tup1.len() == tup2.len()) {
                    for (i in tup1.keys()) {
                      let c = nameComp(tup1[i], tup2[i]);
                      switch c {
                        case (#equalTo) { /* continue */ };
                        case comp { return comp };
                      }
                    };
                    #equalTo
                  } else {
                    natComp(tup1.len(), tup2.len())
                  }
                };
           case comp comp;
         }
       };
  case (#nat(_), _) { #lessThan };
  case (_, #nat(_)) { #greaterThan };
  case (#text(_), _) { #lessThan };
  case (_, #text(_)) { #greaterThan };
  }
};

};

}
