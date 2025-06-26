/*
* Copyright (c) 2025. All rights reserved.
* Created by enrique, 2025-03-24
*/

class ExitInstruction #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) extends AbstractInstruction #(
    CVA6Cfg
);
    logic [CVA6Cfg.VLEN-1:0] target_address;

    function automatic new (
        logic [CVA6Cfg.VLEN-1:0] vpc_i
    );
        this.vpc = vpc_i;
        this.target_address = -1;   // End of stream
    endfunction : new

    function automatic bit is_branch();
        return 0;
    endfunction : is_branch

    function automatic bit is_forward_branch();
        return 0;
    endfunction : is_forward_branch

    function automatic bit is_terminal();
        return 1;
    endfunction : is_terminal

    function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) get_target_instr();
        return null;
    endfunction : get_target_instr

    function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) getNextInstr();
        return null;
    endfunction : getNextInstr

    function automatic void setNextInstr(AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) instruction_i);
        return;
    endfunction : setNextInstr

    function automatic void print(string tab = "");
        super.print(tab);
        $display({tab, "target_address = %x"}, this.target_address);
        $display({tab, "END OF STREAM"});
    endfunction : print
endclass : ExitInstruction