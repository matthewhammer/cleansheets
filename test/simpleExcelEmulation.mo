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
        [
          [ // Row 0 has two cells named `S(0,0)` and `S(0,1)`:
            #nat(1),  #nat(2) ],
          [ // Row 1 has two cells: cell `S(1,0)` and ...
            #strictBinOp(#add,
                         #cellOcc(0,0),
                         #cellOcc(0,1)),
            /* cell `S(1,1)`. */
            #strictBinOp(#mul,
                         #nat(2),
                         #cellOcc(1,0)) ]
        ]);

    let actx : T.Adapton.Context = A.init();

    // Evaluate the sheet, including all of the cells:
    let sheetRes : T.Eval.Result =
      E.evalExp(actx, null, sheet);

    // Assert that the dependence graph has the correct shape for last cell, S(1,1):
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
