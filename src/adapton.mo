/*
 Adapton implementation in Motoko, specialized for CleanSheets lang.

 Two closely-related papers:
  1. [Incremental Computation with Names](https://arxiv.org/abs/1503.07792)
  2. [Adapton: composable, demand-driven incremental computation](https://dl.acm.org/doi/abs/10.1145/2666356.2594324)
*/

import T "types.mo";
import H "mo:stdlib/hashMap.mo";
import Hash "mo:stdlib/hash.mo";
import Buf "mo:stdlib/buf.mo";
import L "mo:stdlib/list.mo";
import R "mo:stdlib/result.mo";
import P "mo:stdlib/prelude.mo";

module {
public type Val = T.Val;
public type Exp = T.Exp;
public type Error = T.Error;
public type NodeId = T.NodeId;
public type Name = T.Name;
public type Closure = T.Closure;
public type Result = T.Result;

public type Context = T.Adapton.Context;
public type Thunk = T.Adapton.Thunk;
public type Ref = T.Adapton.Ref;
public type Node = T.Adapton.Node;
public type Store = T.Adapton.Store;
public type Stack = T.Adapton.Stack;
public type Edge = T.Adapton.Edge;
public type Action = T.Adapton.Action;

public func init() : Context {
  let st : Store = H.HashMap<Name, Node>(0, T.nameEq, T.nameHash);
  let sk : Stack = null;
  let es = Buf.Buf<Edge>(0);
  let ag : {#editor; #archivist} = #editor;
  { var store = st;
    var stack = sk;
    var edges = es;
    var agent = ag;
  }
};

func newEdge(source:NodeId, target:NodeId, action:Action) : Edge {
  { dependent=source;
    dependency=target;
    dirtyFlag=false;
    checkpoint=action }
};

func addEdge(c:Context, target:NodeId, action:Action) {
  let edge = switch (c.agent) {
  case (#archivist) {
         switch (c.stack) {
         case null { P.unreachable() };
         case (?((source, _), _)) {
                let edge = newEdge({name=source}, target, action);
                c.edges.add(edge)
              };
         }
       };
  case (#editor) {
         // no need to do anything;
         // the editor role is not recorded or memoized
       };
  };
};

public func putThunk(c:Context, n:Name, cl:Closure) : R.Result<NodeId, T.PutError> {
  let newThunkNode : Thunk = {
    incoming=[];
    outgoing=[];
    result=null;
    closure=cl;
  };
  let _oldNode = c.store.set(n, #thunk(newThunkNode));
  // to do: if the node exists,
  //   then we have to do more tests, and possibly dirty its dependents
  #ok({ name=n })
};

public func put(c:Context, n:Name, val:Val) : R.Result<NodeId, T.PutError> {
  // to do: record edge in the context
  let newRefNode : Ref = {
    incoming=[];
    content=val;
  };
  let _oldNode = c.store.set(n, #ref(newRefNode));
  // to do: if the node exists,
  //   then we have to do more tests, and possibly dirty its dependents
  #ok({ name=n })
};

func thunkIsDirty(t:Thunk) : Bool {
  for (i in t.outgoing.keys()) {
    if (t.outgoing[i].dirtyFlag) {
      return true
    };
  };
  false
};

public func get(c:Context, n:NodeId) : R.Result<Result, T.GetError> {
  switch (c.store.get(n.name)) {
    case null { #err(()) /* error: dangling/forged name posing as live node id. */ };
    case (?#ref(refNode)) {
           let val = refNode.content;
           let res = #ok(val);
           addEdge(c, n, #get(res));
           #ok(res)
         };
    case (?#thunk(thunkNode)) {
           switch (thunkNode.result) {
             case null {
                    assert (thunkNode.incoming.len() == 0);
                    let parentEdges = c.edges;
                    c.edges := Buf.Buf<Edge>(0);
                    c.stack := ?((n.name, #thunk(thunkNode)), c.stack);
                    let res = thunkNode.closure.eval(c);
                    let edges = c.edges.toArray();
                    c.edges := parentEdges;
                    let newNode = {
                      closure=thunkNode.closure;
                      result=?res;
                      outgoing=edges;
                      incoming=[];
                    };
                    ignore c.store.set(n.name, #thunk(newNode));
                    addEdge(c, n, #get(res));
                    #ok(res)
                  };
             case (?oldResult) {
                    if (thunkIsDirty(thunkNode)) {
                      // to do:
                      // - first attempt to "clean" the thunk's edges, one by one.
                      // - if that fails at any point, then re-evaluate it.
                      // - if it succeeds, then the edges are clean and
                      //   that implies that the result is consistent (the key idea).
                      P.nyi()
                    } else {
                      // ** key idea:
                      // global graph invariants imply consistency here:
                      #ok(oldResult)
                    }
                  };
           }
         };
  }
};

}
