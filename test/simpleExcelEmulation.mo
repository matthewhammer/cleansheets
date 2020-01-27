import R "mo:stdlib/result.mo";
import P "mo:stdlib/prelude.mo";

import T "../src/types.mo";
import A "../src/adapton.mo";
import E "../src/eval.mo";

actor simpleExcelEmulation {

  public func go() {
    
    let sheet : T.Eval.Exp = 
      #sheet(
        #text("S"),
        [ [ #nat(1), 
            #nat(2)
          ],
          [ #strictBinOp(#add,
                         #cellOcc(0,0),
                         #cellOcc(0,1)),
            #strictBinOp(#mul,
                         #nat(2),
                         #cellOcc(1,0)) ]
        ]);
    // todo:
    //  - perform eval sheet
    //  - assert correct result values
    //  - change sheet (API for this?)
    //  - re-assert new values
    //  - assert correct dirty/clean behavior
  };  
}
