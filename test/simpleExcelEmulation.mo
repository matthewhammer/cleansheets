import R "mo:stdlib/result.mo";
import P "mo:stdlib/prelude.mo";
import Debug "mo:stdlib/debug.mo";

import T "../src/types.mo";
import A "../src/adapton.mo";
import E "../src/eval.mo";

actor simpleExcelEmulation {

  public func go() {

    let sheetExp : T.Eval.Exp =
      #sheet(
        #text("S"),
        [
          [ #nat(1),  #nat(2) ],
          [ #strictBinOp(#add,
                         #cellOcc(0,0),
                         #cellOcc(0,1)),
            #strictBinOp(#mul,
                         #nat(2),
                         #cellOcc(1,0)) ]
        ]);

    // Adapton maintains our dependence graph
    let actx : T.Adapton.Context = A.init();

    // create the initial Sheet datatype from the DSL expression above
    let s : T.Sheet.Sheet = {
      switch (E.evalExp(actx, null, sheetExp)) {
      case (#ok(#sheet(s))) s;
      case _ { P.unreachable() };
      }};

    // Demand that the sheet's results are fully refreshed
    ignore E.Sheet.refresh(actx, s);
    ignore E.Sheet.refresh(actx, s);
    A.assertLogEventLast(
      actx,
      #get(#tagTup(#text("S"), [#nat(1), #nat(1), #text("out")]), #ok(#nat(6)), [])
    );

    // Update the sheet by overwriting (0,0) with a new formula:
    ignore E.Sheet.update(actx, s, 0, 0,
                          #strictBinOp(#add, #nat(666), #cellOcc(0,1)));

    // Demand that the sheet's results are fully refreshed
    ignore E.Sheet.refresh(actx, s);
    ignore E.Sheet.refresh(actx, s);
    assert (s.errors.len() == 0);
    A.assertLogEventLast(
      actx,
      #get(#tagTup(#text("S"), [#nat(1), #nat(1), #text("out")]), #ok(#nat(1_340)), [])
    );

    // Update the sheet, creating a cycle at (0,0):
    ignore E.Sheet.update(actx, s, 0, 0, #cellOcc(0,0));
    ignore E.Sheet.refresh(actx, s);
    assert (s.errors.len() != 0);

    // Update the sheet, removing the cycle:
    ignore E.Sheet.update(actx, s, 0, 0,
                          #strictBinOp(#add, #nat(666), #cellOcc(0,1)));

    // Demand that the sheet's results are fully refreshed
    ignore E.Sheet.refresh(actx, s);
    ignore E.Sheet.refresh(actx, s);
    assert (s.errors.len() == 0);
    A.assertLogEventLast(
      actx,
      #get(#tagTup(#text("S"), [#nat(1), #nat(1), #text("out")]), #ok(#nat(1_340)), [])
    );
  };
};

//simpleExcelEmulation.go()
