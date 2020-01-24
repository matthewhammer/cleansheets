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
    checkpoint=action;
    var dirtyFlag=false;
  }
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
  switch (c.store.set(n, #thunk(newThunkNode))) {
  case null { /* no prior node of this name */ };
  case (?#thunk(oldThunk)) {
         if (T.closureEq(oldThunk.closure, cl)) {
           // matching closures ==> no dirtying.
         } else {
           // to do: if the node exists and the name is currently on the stack,
           //   then the thunk-stack is cyclic; signal an error.
           dirtyThunk(c, oldThunk)
         }
       };
  case (?#ref(oldRef)) { dirtyRef(c, oldRef) };
  };
  addEdge(c, {name=n}, #putThunk(cl));
  #ok({ name=n })
};

public func put(c:Context, n:Name, val:Val) : R.Result<NodeId, T.PutError> {
  let newRefNode : Ref = {
    incoming=[];
    content=val;
  };
  switch (c.store.set(n, #ref(newRefNode))) {
  case null { /* no prior node of this name */ };
  case (?#thunk(oldThunk)) { dirtyThunk(c, oldThunk) };
  case (?#ref(oldRef)) {
         if (T.valEq(oldRef.content, val)) {
           // matching values ==> no dirtying.
         } else {
           dirtyRef(c, oldRef)
         }
       };
  };
  addEdge(c, {name=n}, #put(val));
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

func dirtyThunk(c:Context, thunkNode:Thunk) {
  for (i in thunkNode.incoming.keys()) {
    dirtyEdge(c, thunkNode.incoming[i])
  }
};

func dirtyRef(c:Context, refNode:Ref) {
  for (i in refNode.incoming.keys()) {
    dirtyEdge(c, refNode.incoming[i])
  }
};

func dirtyEdge(c:Context, edge:Edge) {
  edge.dirtyFlag := true;
  switch (c.store.get(edge.dependent.name)) {
    case null { P.unreachable() };
    case (?#ref(_)) { P.unreachable() };
    case (?#thunk(thunkNode)) {
           dirtyThunk(c, thunkNode)
         };
  }
};

func cleanEdge(c:Context, e:Edge) : Bool {
  if (e.dirtyFlag) {
    switch (e.checkpoint, c.store.get(e.dependency.name)) {
    case (#get(oldRes), ?#ref(refNode)) {
           if (T.resultEq(oldRes, #ok(refNode.content))) {
             e.dirtyFlag := false;
             true
           } else { false }
         };
    case (#put(oldVal), ?#ref(refNode)) {
           if (T.valEq(oldVal, refNode.content)) {
             e.dirtyFlag := false;
             true
           } else { false }
         };
    case (#putThunk(oldClos), ?#thunk(thunkNode)) {
           if (T.closureEq(oldClos, thunkNode.closure)) {
             e.dirtyFlag := false;
             true
           } else { false }
         };
    case (#get(oldRes), ?#thunk(thunkNode)) {
           let oldRes = switch (thunkNode.result) {
             case (?res) { res };
             case null { P.unreachable() };
           };
           // dirty flag true ==> we must re-evaluate thunk:
           let newRes = evalThunk(c, e.dependency.name, thunkNode);
           if (T.resultEq(oldRes, newRes)) {
             e.dirtyFlag := false;
             true // equal results ==> clean.
           } else {
             false // changed result ==> thunk could not be cleaned.
           }
         };
    case (_, _) {
           P.unreachable()
         };
    }
  } else {
    true // already clean
  }
};

func cleanThunk(c:Context, t:Thunk) : Bool {
  for (i in t.outgoing.keys()) {
    if (cleanEdge(c, t.outgoing[i])) {
      /* continue */
    } else {
      return false // outgoing[i] could not be cleaned.
    }
  };
  true
};

func evalThunk(c:Context, nodeName:Name, thunkNode:Thunk) : Result {
  let oldEdges = c.edges;
  let oldStack = c.stack;
  c.edges := Buf.Buf<Edge>(0);
  c.stack := ?((nodeName, #thunk(thunkNode)), oldStack);
  let res = thunkNode.closure.eval(c);
  let edges = c.edges.toArray();
  c.edges := oldEdges;
  c.stack := oldStack;
  let newNode = {
    closure=thunkNode.closure;
    result=?res;
    outgoing=edges;
    incoming=[];
  };
  ignore c.store.set(nodeName, #thunk(newNode));
  res
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
                    let res = evalThunk(c, n.name, thunkNode);
                    addEdge(c, n, #get(res));
                    #ok(res)
                  };
             case (?oldResult) {
                    if (thunkIsDirty(thunkNode)) {
                      if(cleanThunk(c, thunkNode)) {
                        addEdge(c, n, #get(oldResult));
                        #ok(oldResult)
                      } else {
                        let res = evalThunk(c, n.name, thunkNode);
                        addEdge(c, n, #get(res));
                        #ok(res)
                      }
                    } else {
                      addEdge(c, n, #get(oldResult));
                      #ok(oldResult)
                    }
                  };
           }
         };
  }
};

}
