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
            /* Last cell defined here, at "S"(0,0): */
            #strictBinOp(#mul,
                         #nat(2),
                         #cellOcc(1,0)) ]
        ]);

    let actx : T.Adapton.Context = A.init();
    let sheetRes : T.Eval.Result =
      E.evalExp(actx, null, sheet);

    // ---------------------------------------------------------------------------------
    // We assert that the dependence graph has the correct shape for last cell:
    A.assertLogEventLast(
      actx,
      #get(
        #tagTup(#text("S"), [#nat(1), #nat(1), #text("out")]),
        #ok(#nat(6)),
        [
          #evalThunk(
            #tagTup(#text("S"), [#nat(1), #nat(1), #text("out")]),
            #ok(#nat(6)),
            [
              #get(#tagTup(#text("S"), [#nat(1), #nat(1), #text("inp")]),
                   #ok(#thunk(null,
                              #strictBinOp(#mul, #nat(2),
                                           #get(#thunkNode({name = #tagTup(#text("S"), [#nat(1), #nat(0), #text("out")])}))))), []),
              #get(#tagTup(#text("S"), [#nat(1), #nat(0), #text("out")]),
                   #ok(#nat(3)), [])])])
    );
    // todo:
    //  - change sheet (API for this?)
    //  - re-assert new values and correct dirty/clean behavior.
  };
};

simpleExcelEmulation.go()
