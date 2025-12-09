//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : B2BCD_IP.v
//   Module Name : B2BCD_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module B2BCD_IP #(parameter WIDTH = 4, parameter DIGIT = 2) (
    // Input signals
    Binary_code,
    // Output signals
    BCD_code
);

// ===============================================================
// Declaration
// ===============================================================

input  [WIDTH - 1 : 0]   Binary_code;
output [DIGIT * 4 - 1 : 0] BCD_code;

wire[DIGIT * 4 + WIDTH - 1 : 0] bcd_array[WIDTH : 0];
wire[DIGIT * 4 + WIDTH - 1 : 0] add_array[WIDTH : 1];

// ===============================================================
// Soft IP DESIGN
// ===============================================================

genvar i, j, k;
generate
    assign bcd_array[0][WIDTH - 1 : 0] = Binary_code;
    assign bcd_array[0][DIGIT * 4 + WIDTH - 1 : WIDTH] = 1'b0;

    for(j = 1; j < WIDTH + 1; j = j + 1) begin: structual_loop

        assign add_array[j][WIDTH - 1 : 0] = bcd_array[j - 1][WIDTH - 1 : 0];

        for(k = 0; k < DIGIT; k = k + 1) begin: digit_loop

            assign add_array[j][WIDTH + (k + 1) * 4 - 1 -: 4] = (bcd_array[j - 1][WIDTH + (k + 1) * 4 - 1 -: 4] > 4'd4)? 

		    bcd_array[j - 1][WIDTH + (k + 1) * 4 - 1 -: 4] + 4'd3 : bcd_array[j - 1][WIDTH + (k + 1) * 4 - 1 -: 4];
        end

        assign bcd_array[j] = add_array[j] << 1;
    end

    assign BCD_code = bcd_array[WIDTH][DIGIT * 4 + WIDTH - 1 : WIDTH];
endgenerate	

endmodule
