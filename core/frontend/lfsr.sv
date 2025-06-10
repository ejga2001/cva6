/*
 * Copyright (c) 2024. All rights reserved.
 * Created by enrique, 15/12/24
 */

module lfsr#(
    parameter NBITS = 2,
    parameter int WIDTH = 4
)(
    input logic clk_i,
    input logic rst_ni,
    output logic [NBITS-1:0] rand_o
);

    logic [WIDTH-1:0] rand_q, rand_d;

    assign rand_o = rand_q[(WIDTH-1)-:NBITS];

    assign rand_d = {rand_q[WIDTH-2:0], rand_q[WIDTH-1] ^ rand_q[WIDTH-2]};

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni)
            rand_q <= WIDTH'(1'b1);
        else
            rand_q <= rand_d;
    end

endmodule