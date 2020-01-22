import Prelude "mo:stdlib/prelude.mo";
import Adapton "../src/adapton.mo";

type State = {#empty; #init:Text};

actor CleanSheets {
  var state : ?State = null;
  public func start(t:Text) {
     state := ?#init(t)
  };
  public func get() : async Text {
     switch state {
       case null "null";
       case (?#empty) "?#empty";
       case (?#init(z)) z;
     }
  };
}




/*
========================================================

import Prelude "mo:stdlib/prelude.mo";
import Adapton "../src/adapton.mo";

type State = {#empty; #init:Text};

actor CleanSheets {
  var state : State = (#empty : State);
  public func start(t:Text) {
     state := #init(t)
  };
  public func get() : async Text {
     switch state {
       case (#empty) "hello";
       case (#init(z)) z;
     }
  };
}
-----------------
Ill-typed intermediate code after Desugaring (use -v to see dumped IR):
/Users/matthew/dfn/cleansheets/app/main.mo-4273828251432228027:16.6-16.11: IR type error, subtype violation:
  var {#empty}
  var {#empty; #init : Text}

Raised at file "ir_def/check_ir.ml", line 75, characters 30-92
Called from file "ir_def/check_ir.ml", line 457, characters 4-24
Called from file "ir_def/check_ir.ml", line 505, characters 4-23
Called from file "ir_def/check_ir.ml", line 622, characters 4-40
Called from file "ir_def/check_ir.ml", line 861, characters 4-21
Called from file "list.ml", line 110, characters 12-15
Called from file "ir_def/check_ir.ml", line 646, characters 4-23
Called from file "ir_def/check_ir.ml", line 861, characters 4-21
Called from file "list.ml", line 110, characters 12-15
  Failed to build canister "cleansheets":
BuildError(MotokoCompilerError("", ""))
Build failed. Reason:
  Motoko returned an error:

*/
