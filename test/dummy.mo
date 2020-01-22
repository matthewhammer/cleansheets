import Prelude "mo:stdlib/prelude.mo";
import Adapton "../src/adapton.mo";

actor CleanSheets {     
  var state : {#empty; #init:Text} = #empty
  public func start(t:Text) : async Text {
     state := #init(t)
  };
  public func get() : async Text {
     switch state {
       case (#empty) "hello";
       case (#init(z)) z;
     }
  };
}