/*
 Adapton implementation in Motoko, specialized for CleanSheets lang.

 Two closely-related papers:
  1. [Incremental Computation with Names](https://arxiv.org/abs/1503.07792)
  2. [Adapton: composable, demand-driven incremental computation](https://dl.acm.org/doi/abs/10.1145/2666356.2594324)
*/

import T "types.mo";
import H "mo:stdlib/hashMap.mo";
import L "mo:stdlib/list.mo";

module {
public type Val = T.Val;
public type Exp = T.Exp;
public type Error = T.Error;
public type NodeId = T.NodeId;
public type Name = T.Name;
public type Closure = T.Closure;

public type Ref = {
  var content: T.Val;
  var incoming: [Edge]
};

public type Thunk = {
  var closure: Closure;
  var result: ?Val;
  var outgoing: [Edge];
  var incoming: [Edge];
};

public type Edge = {
  var dependent: NodeId;
  var dependency: NodeId;
  var checkpoint: Action;
  var dirty_flag: Bool
};

public type Action = {
  #put:Val;
  #thunk:Closure;
  #get:Val;
};

public type Node = {
  #ref:Ref;
  #thunk:Thunk;
};

public type Context = {
  #store: H.HashMap<Name, Node>;
  #stack: L.List<Node>;
};

};
