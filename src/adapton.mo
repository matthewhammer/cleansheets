/*
Nominal Adapton implementation in Motoko, specialized for CleanSheets lang.

All node identities determined user-provided names; Note: Nominal
Adapton (here) supports "classic Adapton" by choosing names
structurally, as "full hashes"; we do not support that here, yet.

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
public type PutError = T.PutError;
public type GetError = T.GetError;
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
public type EdgeBuf = T.Adapton.EdgeBuf;
public type Action = T.Adapton.Action;
public type LogEvent = T.Adapton.LogEvent;
public type LogEventTag = T.Adapton.LogEventTag;
public type LogEventBuf = T.Adapton.LogEventBuf;
public type LogBufStack = T.Adapton.LogBufStack;

public func init() : Context {
  // to do -- compiler bug? -- IR typing issue when this line is inlined to its use below:
  let a : {#editor;#archivist} = (#editor : {#editor;#archivist});
  { var store : Store = H.HashMap<Name, Node>(03, T.nameEq, T.nameHash);
    var stack : Stack = null;
    var edges : EdgeBuf = Buf.Buf<Edge>(03);
    var agent = a;
    var logBuf : LogEventBuf = Buf.Buf<T.Adapton.LogEvent>(03);
    var logStack : LogBufStack = null;
  }
};

// note: the log is just for output, for human-based debugging;
// it is not to used by evaluation logic, nor by our algorithms here.
public func getLogEvents(c:Context) : [LogEvent] {
  switch (c.agent) {
    case (#editor) { c.logBuf.toArray() };
    case (#archivist) { assert false ; loop { } };
  }
};

public func put(c:Context, n:Name, val:Val) : R.Result<NodeId, T.PutError> {
  beginLogEvent(c);
  let newRefNode : Ref = {
    incoming=newEdgeBuf();
    content=val;
  };
  switch (c.store.set(n, #ref(newRefNode))) {
  case null { /* no prior node of this name */ };
  case (?#thunk(oldThunk)) { dirtyThunk(c, n, oldThunk) };
  case (?#ref(oldRef)) {
         if (T.valEq(oldRef.content, val)) {
           // matching values ==> no dirtying.
         } else {
           dirtyRef(c, n, oldRef)
         }
       };
  };
  addEdge(c, {name=n}, #put(val));
  endLogEvent(c, #put(n, val));
  #ok({ name=n })
};

public func putThunk(c:Context, n:Name, cl:Closure) : R.Result<NodeId, T.PutError> {
  let logSaved = beginLogEvent(c);
  let newThunkNode : Thunk = {
    incoming=newEdgeBuf();
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
           dirtyThunk(c, n, oldThunk)
         }
       };
  case (?#ref(oldRef)) { dirtyRef(c, n, oldRef) };
  };
  addEdge(c, {name=n}, #putThunk(cl));
  endLogEvent(c, #putThunk(n, cl));
  #ok({ name=n })
};

public func get(c:Context, n:NodeId) : R.Result<Result, T.GetError> {
  let logSaved = beginLogEvent(c);
  switch (c.store.get(n.name)) {
    case null { #err(()) /* error: dangling/forged name posing as live node id. */ };
    case (?#ref(refNode)) {
           let val = refNode.content;
           let res = #ok(val);
           endLogEvent(c, #get(n.name, res));
           addEdge(c, n, #get(res));
           #ok(res)
         };
    case (?#thunk(thunkNode)) {
           switch (thunkNode.result) {
             case null {
                    assert (thunkNode.incoming.len() == 0);
                    let res = evalThunk(c, n.name, thunkNode);
                    endLogEvent(c, #get(n.name, res));
                    addEdge(c, n, #get(res));
                    #ok(res)
                  };
             case (?oldResult) {
                    if (thunkIsDirty(thunkNode)) {
                      if(cleanThunk(c, n.name, thunkNode)) {
                        endLogEvent(c, #get(n.name, oldResult));
                        addEdge(c, n, #get(oldResult));
                        #ok(oldResult)
                      } else {
                        let res = evalThunk(c, n.name, thunkNode);
                        endLogEvent(c, #get(n.name, res));
                        addEdge(c, n, #get(res));
                        #ok(res)
                      }
                    } else {
                      endLogEvent(c, #get(n.name, oldResult));
                      addEdge(c, n, #get(oldResult));
                      #ok(oldResult)
                    }
                  };
           }
         };
  }
};

func newEdge(source:NodeId, target:NodeId, action:Action) : Edge {
  { dependent=source;
    dependency=target;
    checkpoint=action;
    var dirtyFlag=false;
  }
};

func incomingEdgeBuf(n:Node) : T.Adapton.EdgeBuf {
  switch n {
  case (#ref(n)) { n.incoming };
  case (#thunk(t)) { t.incoming };
  }
};

func addBackEdge(c:Context, edge:Edge) {
  switch (c.store.get(edge.dependency.name)) {
    case null { P.unreachable() };
    case (?targetNode) {
           let edgeBuf = incomingEdgeBuf(targetNode);
           for (existing in edgeBuf.iter()) {
             // same edge means same source and action tag; return early.
             if (T.nameEq(edge.dependent.name,
                          existing.dependent.name)) {
               switch (edge.checkpoint, existing.checkpoint) {
                 case (#get(_), #get(_)) { return () };
                 case (#put(_), #put(_)) { return () };
                 case (#putThunk(_), #putThunk(_)) { return () };
                 case (_, _) { };
               };
             }
           };
           // not found, so add it:
           edgeBuf.add(edge);
         }
  }
};

func remBackEdge(c:Context, edge:Edge) {
  switch (c.store.get(edge.dependency.name)) {
  case (?node) {
         let nodeIncoming = incomingEdgeBuf(node);
         let newIncoming : EdgeBuf = Buf.Buf<Edge>(03);
         for (incomingEdge in nodeIncoming.iter()) {
           if (T.nameEq(edge.dependent.name, incomingEdge.dependent.name)) {
             // same source, so filter otherEdge out.
             // (we do not bother comparing actions; it's not required.)
           } else {
             newIncoming.add(incomingEdge)
           }
         };
         nodeIncoming.clear();
         nodeIncoming.append(newIncoming);
       };
  case _ { assert false };
  }
};

func addBackEdges(c:Context, edges:[Edge]) {
  for (i in edges.keys()) {
    addBackEdge(c, edges[i])
  }
};

func remBackEdges(c:Context, edges:[Edge]) {
  for (i in edges.keys()) {
    remBackEdge(c, edges[i])
  }
};

func addEdge(c:Context, target:NodeId, action:Action) {
  let edge = switch (c.agent) {
  case (#editor) { /* the editor role is not recorded or memoized */ };
  case (#archivist) {
         switch (c.stack) {
         case null { P.unreachable() };
         case (?(source, _)) {
                let edge = newEdge({name=source}, target, action);
                c.edges.add(edge)
              };
         }
       };
  };
};

func newEdgeBuf() : T.Adapton.EdgeBuf { Buf.Buf<Edge>(03) };

func thunkIsDirty(t:Thunk) : Bool {
  for (i in t.outgoing.keys()) {
    if (t.outgoing[i].dirtyFlag) {
      return true
    };
  };
  false
};

func dirtyThunk(c:Context, n:Name, thunkNode:Thunk) {
  // to do: if the node is on the stack,
  //   then the DCG is overwriting names
  //   too often for change propagation to follow soundly; signal an error.
  beginLogEvent(c);
  for (edge in thunkNode.incoming.iter()) {
    dirtyEdge(c, edge)
  };
  endLogEvent(c, #dirtyIncomingTo(n));
};

func dirtyRef(c:Context, n:Name, refNode:Ref) {
  beginLogEvent(c);
  for (edge in refNode.incoming.iter()) {
    dirtyEdge(c, edge)
  };
  endLogEvent(c, #dirtyIncomingTo(n));
};

func dirtyEdge(c:Context, edge:Edge) {
  if (edge.dirtyFlag) {
    // graph invariants ==> dirtying is already done.
  } else {
    beginLogEvent(c);
    edge.dirtyFlag := true;
    switch (c.store.get(edge.dependent.name)) {
    case null { P.unreachable() };
    case (?#ref(_)) { P.unreachable() };
    case (?#thunk(thunkNode)) {
           dirtyThunk(c, edge.dependent.name, thunkNode)
         };
    };
    endLogEvent(c, #dirtyEdgeFrom(edge.dependent.name));
  }
};

func cleanEdge(c:Context, e:Edge) : Bool {
  beginLogEvent(c);
  let successFlag = if (e.dirtyFlag) {
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
  };
  endLogEvent(c, #cleanEdgeTo(e.dependency.name, successFlag));
  successFlag;
};

func cleanThunk(c:Context, n:Name, t:Thunk) : Bool {
  beginLogEvent(c);
  for (i in t.outgoing.keys()) {
    if (cleanEdge(c, t.outgoing[i])) {
      /* continue */
    } else {
      endLogEvent(c, #cleanThunk(n, false));
      return false // outgoing[i] could not be cleaned.
    }
  };
  endLogEvent(c, #cleanThunk(n, true));
  true
};

func evalThunk(c:Context, nodeName:Name, thunkNode:Thunk) : Result {
  beginLogEvent(c);
  let oldEdges = c.edges;
  let oldStack = c.stack;
  let oldAgent = c.agent;
  c.agent := #archivist;
  c.edges := Buf.Buf<Edge>(03);
  c.stack := ?(nodeName, oldStack);
  remBackEdges(c, thunkNode.outgoing);
  let res = thunkNode.closure.eval(c);
  let edges = c.edges.toArray();
  c.agent := oldAgent;
  c.edges := oldEdges;
  c.stack := oldStack;
  let newNode = {
    closure=thunkNode.closure;
    result=?res;
    outgoing=edges;
    incoming=newEdgeBuf();
  };
  ignore c.store.set(nodeName, #thunk(newNode));
  addBackEdges(c, newNode.outgoing);
  endLogEvent(c, #evalThunk(nodeName, res));
  res
};

func beginLogEvent(c:Context) {
  c.logStack := ?(c.logBuf, c.logStack);
  c.logBuf := Buf.Buf<LogEvent>(03);
};

func logEvent(tag:LogEventTag, events:[LogEvent]) : LogEvent {
  switch tag {
  case (#put(v, n))      { #put(v, n,      events) };
  case (#putThunk(c, n)) { #putThunk(c, n, events) };
  case (#get(r, n))      { #get(r, n,      events) };
  case (#dirtyIncomingTo(n)){ #dirtyIncomingTo(n,events) };
  case (#dirtyEdgeFrom(n)){ #dirtyEdgeFrom(n,events) };
  case (#cleanEdgeTo(n,f)) { #cleanEdgeTo(n,f,events) };
  case (#cleanThunk(n,f)) { #cleanThunk(n,f,events) };
  case (#evalThunk(n,r)) { #evalThunk(n,r,events) };
  }
};

func endLogEvent(c:Context,
                 tag:LogEventTag)
{
  switch (c.logStack) {
    case null { assert false };
    case (?(prevLogBuf, logStack)) {
           let events = c.logBuf.toArray();
           let ev : LogEvent = logEvent(tag, events);
           c.logStack := logStack;
           c.logBuf := prevLogBuf;
           c.logBuf.add(ev);
         }
  }
};

}

