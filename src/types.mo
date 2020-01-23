import Buf "mo:stdlib/buf.mo";
import List "mo:stdlib/list.mo";

// formal grammar of spreadsheet language:
module {

public type Val = {
  #name: Name;
  #text: Text;
  #nat: Nat;
  #int: Int;
  #list: List<Val>;
  #grid: [[Val]];
  #ref: NodeId; // adapton ref node
  #thunk: NodeId; // adapton thunk node
};

// a name may not merely be an identifier,
// its structure is limited to simple, first-order data.
public type Name = {
  #text: Text;
  #nat: Nat;
  #tagtup: (Name, [Name]);
};

public type NodeId = {
  name: Name
};

type List<X> = List.List<X>;

public type Env = List<(Name, Val)>;

public type Error = {
  origin: List<Text>;
  message: Text;
};

public type Binop = {
  #add;
  #sub;
  #div;
  #mul;
  #cat;
};

public type Exp = {
  #name: Name;
  #error: Error;
  #varocc: Name;
  #text: Text;
  #nat: Nat;
  #int: Int;
  #list: List<Exp>;
  #grid: [[Exp]];  
  #block: Block;
  #binOp: (Binop, Exp, Exp);
  #put: (Exp, Exp);
  #get: Exp;
  #thunk: (Exp, Closure);
};

public type Block =
  List<(Name, Exp)>;

public type Closure = {
  env: Env;
  exp: Exp;
};

}
