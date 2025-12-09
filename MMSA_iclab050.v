module MMSA(
// input signals
    clk,
    rst_n,
    in_valid,
	in_valid2,
    matrix,
	matrix_size,
    i_mat_idx,
    w_mat_idx,
	
// output signals
    out_valid,
    out_value
);
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input        clk, rst_n, in_valid, in_valid2;
input        matrix;
input [1:0]  matrix_size;
input        i_mat_idx, w_mat_idx;

output reg   out_valid;
output reg   out_value;
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

parameter IDLE = 3'd0;
parameter INPUT = 3'd1;
parameter INPUT2 = 3'd3;
parameter CALCULATE = 3'd2;
parameter BIT_LENGTH = 3'd6;
parameter OUTPUT = 3'd4;

//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------

// FSM
reg[2:0] c_state, n_state;

// INPUT
reg[3:0] serial_counter;
reg[15:0] matrix_shift;
reg[1:0] matrix_kind;
reg[2:0] matrix_pow;
reg[4:0] matrix_size_reg;
reg[12:0] input_counter;
wire[8:0] mult_counter, add_counter, ans_counter;
reg[3:0] input_mod, mult_mod, add_mod, ans_mod;

// SRAM
reg input_flag;
reg[9:0] x_address, w_address;
reg x_read, w_read;
wire[15:0] x_output, w_output;

// INPUT2
reg[3:0] i_index, w_index;
reg[8:0] matrix_square;
reg[11:0] im, wm;
reg[11:0] x_offset, w_offset;

// MULT
wire[11:0] address_offset;
wire[11:0] input_offset;
reg signed[15:0] x_reg[15:0];
reg signed[15:0] w_reg[15:0];
reg signed[31:0] mult[15:0];

// ADD
reg signed[32:0] add1_reg[15:0], add2_reg[15:0];
wire signed[39:0] add1[14:0], add2[14:0];
reg signed[39:0] ans[30:0];
reg signed[39:0] more1[1:0], more2[1:0];

// OUTPUT
reg go_to_output;
reg close_the_gate;
reg[4:0] out_counter;
reg[2:0] bit_length_count;
reg length_done;
reg output_done;
reg[5:0] now_length[14:0];
reg[5:0] length_count;
reg[5:0] length_reg;


//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------

//////////////////// FSM //////////////////////////////////

always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) c_state <= IDLE;
    else c_state <= n_state;
end

always@(*) begin 
    case(c_state)
        IDLE: begin 
            if(in_valid == 1'b1) n_state = INPUT;
            else if(in_valid2 == 1'b1) n_state = INPUT2;
            else n_state = c_state;
        end
        INPUT: begin 
            if(in_valid == 1'b0) n_state = IDLE;
            else n_state = c_state;
        end
        INPUT2: begin 
            if(in_valid2 == 1'b0) n_state = CALCULATE;
            else n_state = c_state;
        end
        CALCULATE: begin 
            if(go_to_output) n_state = BIT_LENGTH;
            else n_state = c_state;
        end
        BIT_LENGTH: begin 
            if(bit_length_count == 6) n_state = OUTPUT;
            else n_state = c_state;
        end
        OUTPUT: begin 
            if(output_done && length_done) n_state = IDLE;
            else if(length_done) n_state = BIT_LENGTH;
            else n_state = c_state;
        end
        default: n_state = c_state;
    endcase
end


///////////////////////// INPUT ////////////////////////////////

// serial_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) serial_counter <= 4'b0;
    else begin 
        case(n_state)
            INPUT: serial_counter <= serial_counter + 1;
        endcase
    end
end

// input_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) input_counter <= 13'b0;
    else begin 
        case(n_state)
            INPUT: if(serial_counter == 0 && c_state == INPUT) input_counter <= input_counter + 13'b1;
            CALCULATE: input_counter <= input_counter + 13'b1;
            //OUTPUT: input_counter <= input_counter + 13'b1;
            default: input_counter <= 13'b0;
        endcase
    end
end

assign mult_counter = input_counter[8:0] - 9'd1;
assign add_counter = input_counter[8:0] - 9'd2;
assign ans_counter = input_counter[8:0] - 9'd4;

// input_mod
always@(*) begin 
    case(matrix_kind)
        0: input_mod = {3'b0, input_counter[0]};
        1: input_mod = {2'b0, input_counter[1:0]};
        3: input_mod = input_counter[3:0];
        2: input_mod = {1'b0, input_counter[2:0]};
    endcase
end

// mult_mod
always@(*) begin 
    case(matrix_kind)
        0: mult_mod = {3'b0, mult_counter[0]};
        1: mult_mod = {2'b0, mult_counter[1:0]};
        3: mult_mod = mult_counter[3:0];
        2: mult_mod = {1'b0, mult_counter[2:0]};
    endcase
end

// add_mod
always@(*) begin 
    case(matrix_kind)
        0: add_mod = {3'b0, add_counter[0]};
        1: add_mod = {2'b0, add_counter[1:0]};
        3: add_mod = add_counter[3:0];
        2: add_mod = {1'b0, add_counter[2:0]};
    endcase
end

// ans_mod
always@(*) begin 
    case(matrix_kind)
        0: ans_mod = {3'b0, ans_counter[0]};
        1: ans_mod = {2'b0, ans_counter[1:0]};
        3: ans_mod = ans_counter[3:0];
        2: ans_mod = {1'b0, ans_counter[2:0]};
    endcase
end

// matrix_shift
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) matrix_shift <= 16'b0;
    else begin 
        case(n_state)
            INPUT: matrix_shift <= {matrix_shift[14:0], matrix};
        endcase
    end
end

// matrix_kind
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) matrix_kind <= 2'b0;
    else begin 
        case(n_state)
            INPUT: if(c_state != INPUT) matrix_kind <= matrix_size;
        endcase
    end
end

// matrix_pow
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) matrix_pow <= 3'b0;
    else begin 
        case(n_state)
            INPUT2: matrix_pow <= {1'b0, matrix_kind} + 3'b1;
        endcase
    end
end

// matrix_size_reg
always@(*) begin 
    case(matrix_kind)
        0: matrix_size_reg = 5'd2;
        1: matrix_size_reg = 5'd4;
        3: matrix_size_reg = 5'd16;
        2: matrix_size_reg = 5'd8;
    endcase
end

// matrix_square
always@(*) begin 
    case(matrix_kind)
        0: matrix_square = 9'd4;
        1: matrix_square = 9'd16;
        3: matrix_square = 9'd256;
        2: matrix_square = 9'd64;
    endcase
end

// i_index
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) i_index <= 4'b0;
    else begin 
        case(n_state)
            INPUT2: i_index <= {i_index[2:0], i_mat_idx};
        endcase
    end
end

// w_index
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) w_index <= 4'b0;
    else begin 
        case(n_state)
            INPUT2: w_index <= {w_index[2:0], w_mat_idx};
        endcase
    end
end

// im
always@(*) begin 
    case(matrix_kind)
        0: im = i_index << 2;
        1: im = i_index << 4;
        3: im = i_index << 8;
        2: im = i_index << 6;
    endcase
end

// wm
always@(*) begin 
    case(matrix_kind)
        0: wm = w_index << 2;
        1: wm = w_index << 4;
        3: wm = w_index << 8;
        2: wm = w_index << 6;
    endcase
end

// x_offset
always@(*) begin 
    case(n_state)
        CALCULATE: x_offset = im;
        default: x_offset = 12'b0;
    endcase
end

// w_offset
always@(*) begin 
    case(n_state)
        CALCULATE: w_offset = wm;
        default: w_offset = 12'b0;
    endcase
end

assign input_offset = (input_counter >> matrix_pow);
assign address_offset = (input_mod << matrix_pow) + input_offset;

RA1SH x_matrix(.A(x_address), .D(matrix_shift), .CLK(clk), .CEN(1'b0), .WEN(x_read), .OEN(1'b0), .Q(x_output));
RA1SH w_matrix(.A(w_address), .D(matrix_shift), .CLK(clk), .CEN(1'b0), .WEN(w_read), .OEN(1'b0), .Q(w_output));

// x_address
always@(*) begin 
    case(n_state)
        CALCULATE: begin 
            x_address = x_offset + address_offset;
        end
        default: begin
            case(matrix_kind)
                0: x_address = {6'b000000, input_counter[5:0]};
                1: x_address = {4'b0000, input_counter[7:0]};
                3: x_address = input_counter[9:0];
                2: x_address = {2'b00, input_counter[9:0]};
            endcase
        end
    endcase
end

// w_address
always@(*) begin 
    case(matrix_kind)
        0: w_address = {4'b0000, input_counter[5:0]} + w_offset;
        1: w_address = {2'b00, input_counter[7:0]} + w_offset;
        3: w_address = input_counter[9:0] + w_offset;
        2: w_address = input_counter[9:0] + w_offset;
    endcase
end

// input_flag
always@(*) begin 
    case(matrix_kind)
        0: input_flag = input_counter[6];
        1: input_flag = input_counter[8];
        3: input_flag = input_counter[12];
        2: input_flag = input_counter[10];
    endcase
end

// x_read
always@(*) begin 
    case(c_state)
        INPUT: begin 
            if(serial_counter == 0) x_read = input_flag;
            else x_read = 1'b1;
        end 
        default: x_read = 1'b1;
    endcase
end

// w_read
always@(*) begin  
    case(c_state)
        INPUT: begin 
            if(serial_counter == 0) w_read = !input_flag;
            else w_read = 1'b1;
        end 
        default: w_read = 1'b1;
    endcase
end

///////////////////////// CALCULATE /////////////////////////////

// x_reg 0
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) x_reg[0] <= 16'b0;
    else begin
        case(n_state)
            CALCULATE: begin 
                if(!close_the_gate && input_counter != 0) x_reg[0] <= x_output;
                else x_reg[0] <= 16'b0;
            end
            default: x_reg[0] <= 16'b0;
        endcase
    end
end

// w_reg 0
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) w_reg[0] <= 16'b0;
    else begin
        case(n_state)
            CALCULATE: if(!close_the_gate && mult_mod == 4'd0) w_reg[0] <= w_output;
            default: w_reg[0] <= 16'b0;
        endcase
    end
end

genvar i;
generate 
    for(i = 1; i < 8; i = i + 1) begin: reg_loop
        // x_reg
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) x_reg[i] <= 16'b0;
            else begin 
                case(n_state)
                    CALCULATE: if(i < matrix_size_reg) x_reg[i] <= x_reg[i - 1];
                    default: x_reg[i] <= 16'b0;
                endcase
            end
        end
        // w_reg
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) w_reg[i] <= 16'b0;
            else begin 
                case(n_state)
                    CALCULATE: if(!close_the_gate && i == mult_mod && input_counter != 0) w_reg[i] <= w_output;
                    default: w_reg[i] <= 16'b0;
                endcase
            end
        end
    end
endgenerate

genvar j;
generate 
    for(j = 0; j < 8; j = j + 1) begin: mult_loop
        // mult
        always@(*) begin 
            mult[j] = x_reg[j] * w_reg[j];
        end
    end
endgenerate

genvar k;
generate
    for(k = 0; k < 8; k = k + 1) begin: add_loop
        // add1_reg
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) add1_reg[k] <= 32'b0;
            else begin 
                if(add_mod < k) add1_reg[k] <= 32'b0;
                else add1_reg[k] <= mult[k];
            end
        end
        // add2_reg
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) add2_reg[k] <= 32'b0;
            else begin 
                if(add_mod < k && k < matrix_size_reg) add2_reg[k] <= mult[k];
                else add2_reg[k] <= 32'b0;
            end
        end
    end
endgenerate

assign add1[0] = add1_reg[0] + add1_reg[1];
assign add1[1] = add1_reg[2] + add1_reg[3];
assign add1[2] = add1_reg[4] + add1_reg[5];
assign add1[3] = add1_reg[6] + add1_reg[7];
assign add1[8] = add1[0] + add1[1];
assign add1[9] = add1[2] + add1[3];
assign add1[12] = more1[1] + more1[0];

assign add2[0] = add2_reg[0] + add2_reg[1];
assign add2[1] = add2_reg[2] + add2_reg[3];
assign add2[2] = add2_reg[4] + add2_reg[5];
assign add2[3] = add2_reg[6] + add2_reg[7];
assign add2[8] = add2[0] + add2[1];
assign add2[9] = add2[2] + add2[3];
assign add2[12] = more2[1] + more2[0];

// more
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more1[1] <= 40'b0;
    else more1[1] <= add1[8];
end
// more
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more1[0] <= 40'b0;
    else more1[0] <= add1[9];
end
// more
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more2[1] <= 40'b0;
    else more2[1] <= add2[8];
end
// more
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more2[0] <= 40'b0;
    else more2[0] <= add2[9];
end

genvar m;
generate 
    for(m = 0; m < 15; m = m + 1) begin: ans_loop
        // ans
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) ans[m] <= 40'b0;
            else begin 
                case(n_state)
                    CALCULATE: begin 
                        if(ans_mod == m && input_counter != 0 && mult_counter != 0 && add_counter != 0) ans[m] <= ans[m] + add1[12];
                        else if(ans_mod + matrix_size_reg == m && input_counter != 0 && mult_counter != 0 && add_counter != 0) ans[m] <= ans[m] + add2[12];
                    end
                    /*
                    OUTPUT: begin 
                        if(ans_mod == m) ans[m] <= ans[m] + add1[14];
                        else if(ans_mod + matrix_size_reg == m) ans[m] <= ans[m] + add2[14];
                    end
                    */
                    IDLE: ans[m] <= 40'b0;
                endcase
            end
        end
    end
endgenerate

////////////////////////// OUTPUT //////////////////////////////

// go_to_output
always@(*) begin
    case(matrix_kind)
        0: begin 
            if(ans_counter == 9'd5) go_to_output = 1'b1;
            else go_to_output = 1'b0;
        end
        1: begin 
            if(ans_counter == 9'd19) go_to_output = 1'b1;
            else go_to_output = 1'b0;
        end
        3: begin 
            if(ans_counter == 9'd241) go_to_output = 1'b1;
            else go_to_output = 1'b0;
        end
        2: begin 
            if(ans_counter == 9'd71) go_to_output = 1'b1;
            else go_to_output = 1'b0;
        end
    endcase
end

// close_the_gate
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) close_the_gate <= 1'b0;
    else begin 
        case(n_state)
            CALCULATE: if(mult_counter == matrix_square - 5'd1) close_the_gate <= 1'b1;
            default: close_the_gate <= 1'b0;
        endcase
    end
end

// out_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_counter <= 5'd0;
    else begin 
        case(n_state)
            BIT_LENGTH: if(c_state != BIT_LENGTH) out_counter <= out_counter + 5'd1;
            IDLE: out_counter <= 5'd0;
        endcase
    end
end

// bit_length_count
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) bit_length_count <= 3'b0;
    else begin 
        case(n_state)
            BIT_LENGTH: bit_length_count <= bit_length_count + 1;
            default: bit_length_count <= 0;
        endcase
    end
end

// length_done
always@(*) begin 
    if(length_count == length_reg) length_done = 1;
    else length_done = 0;
end

// length_count
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) length_count <= 6'b0;
    else begin
        case(n_state)
            OUTPUT: length_count <= length_count + 1;
            default: length_count <= 0;
        endcase
    end
end

// length_reg
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) length_reg <= 6'b0;
    else begin 
        case(n_state)
            BIT_LENGTH: if(c_state != BIT_LENGTH) length_reg <= now_length[out_counter];
        endcase
    end
end

genvar f;
generate
    // now_length
    for(f = 0; f < 15; f = f + 1) begin
        always@(*) begin 
                if(ans[f][39]) now_length[f] = 40;
                else if(ans[f][38]) now_length[f] = 39;
                else if(ans[f][37]) now_length[f] = 38;
                else if(ans[f][36]) now_length[f] = 37;
                else if(ans[f][35]) now_length[f] = 36;
                else if(ans[f][34]) now_length[f] = 35;
                else if(ans[f][33]) now_length[f] = 34;
                else if(ans[f][32]) now_length[f] = 33;
                else if(ans[f][31]) now_length[f] = 32;
                else if(ans[f][30]) now_length[f] = 31;
                else if(ans[f][29]) now_length[f] = 30;
                else if(ans[f][28]) now_length[f] = 29;
                else if(ans[f][27]) now_length[f] = 28;
                else if(ans[f][26]) now_length[f] = 27;
                else if(ans[f][25]) now_length[f] = 26;
                else if(ans[f][24]) now_length[f] = 25;
                else if(ans[f][23]) now_length[f] = 24;
                else if(ans[f][22]) now_length[f] = 23;
                else if(ans[f][21]) now_length[f] = 22;
                else if(ans[f][20]) now_length[f] = 21;
                else if(ans[f][19]) now_length[f] = 20;
                else if(ans[f][18]) now_length[f] = 19;
                else if(ans[f][17]) now_length[f] = 18;
                else if(ans[f][16]) now_length[f] = 17;
                else if(ans[f][15]) now_length[f] = 16;
                else if(ans[f][14]) now_length[f] = 15;
                else if(ans[f][13]) now_length[f] = 14;
                else if(ans[f][12]) now_length[f] = 13;
                else if(ans[f][11]) now_length[f] = 12;
                else if(ans[f][10]) now_length[f] = 11;
                else if(ans[f][ 9]) now_length[f] = 10;
                else if(ans[f][ 8]) now_length[f] =  9;
                else if(ans[f][ 7]) now_length[f] =  8;
                else if(ans[f][ 6]) now_length[f] =  7;
                else if(ans[f][ 5]) now_length[f] =  6;
                else if(ans[f][ 4]) now_length[f] =  5;
                else if(ans[f][ 3]) now_length[f] =  4;
                else if(ans[f][ 2]) now_length[f] =  3;
                else if(ans[f][ 1]) now_length[f] =  2;
                else now_length[f] = 1;
        end
    end
endgenerate

// output_done
always@(*) begin 
    case(matrix_kind)
        0: begin 
            if(out_counter == 5'd3) output_done = 1'b1;
            else output_done = 1'b0;
        end 
        1: begin 
            if(out_counter == 5'd7) output_done = 1'b1;
            else output_done = 1'b0;
        end
        3: begin 
            if(out_counter == 5'd31) output_done = 1'b1;
            else output_done = 1'b0;
        end
        2: begin 
            if(out_counter == 5'd15) output_done = 1'b1;
            else output_done = 1'b0;
        end
    endcase
end

// out_valid
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_valid <= 1'b0;
    else begin 
        case(n_state)
            BIT_LENGTH: out_valid <= 1'b1;
            OUTPUT: out_valid <= 1'b1;
            default: out_valid <= 1'b0;
        endcase
    end
end

// out_value
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_value <= 1'b0;
    else begin 
        case(n_state)
            BIT_LENGTH: begin 
                if(c_state != BIT_LENGTH) begin 
                    out_value <= now_length[out_counter][5];
                end 
                else out_value <= length_reg[5 - bit_length_count];    
            end 
            OUTPUT: out_value <= ans[out_counter - 1][length_reg - 1 - length_count];
            default: out_value <= 1'b0;
        endcase
    end
end

endmodule
