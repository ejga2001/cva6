/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 19/03/25
 */

virtual class Instruction #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) extends AbstractInstruction #(
    CVA6Cfg
);
    local AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) next_instr;

    pure virtual function automatic bit is_branch();

    pure virtual function automatic bit is_conditional();

    pure virtual function automatic bit is_terminal();

    pure virtual function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) get_target_instr();

    function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) getNextInstr();
        return next_instr;
    endfunction : getNextInstr

    function automatic void setNextInstr(
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instruction_i
    );
        next_instr = instruction_i;
    endfunction : setNextInstr

    virtual function automatic void print(string tab = "");
        super.print(tab);
    endfunction : print
endclass : Instruction