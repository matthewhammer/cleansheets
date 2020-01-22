import T "types.mo";

module {
public type Val = T.Val;
public type Exp = T.Exp;
public type Err = T.Err;
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

};
