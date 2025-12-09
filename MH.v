module MH(
    clk,
    clk2,
    rst_n,
    in_valid,
    op_valid,
    pic_data,
    se_data,
    op,
    out_valid,
    out_data              
);

//======================================
//          I/O PORTS
//======================================
input           clk;
input          clk2;
input         rst_n;
input      in_valid;
input      op_valid;
input[31:0]   pic_data;
input[7:0]    se_data;
input[2:0]       op;

output reg out_valid;
output reg[31:0] out_data;


//======================================
//          Declaration
//======================================

////////////// parameter //////////////

parameter DATA_WIDTH = 32;

parameter IDLE      = 4'd0;
parameter INPUT     = 4'd1;
parameter OPENING   = 4'd2;
parameter CLOSING   = 4'd3;
parameter EROSION   = 4'd4;
parameter DILATION  = 4'd5;
parameter HISTOGRAM = 4'd6;
parameter BUBBLE    = 4'd7;
parameter OUTPUT    = 4'd8;
parameter HIS_BUB   = 4'd9;
parameter HIS_OUT   = 4'd10;

////////////// regs //////////////

reg[3:0] c_state, n_state;
reg[2:0] which_op;

reg[4:0] input_counter;
reg[7:0] out_counter;

reg[8:0] reload_counter;
reg[7:0] sram_counter;
reg[2:0] bubble_counter;

reg[7:0] sram_addr;
reg sram_read;
reg[DATA_WIDTH-1:0] sram_in;
wire[DATA_WIDTH-1:0] sram_out, erosion_out, dilation_out;

wire[7:0] pixel_value[3:0], sram_value[3:0];

// histogram
reg count_table_00[255:0];
reg count_table_01[255:0];
reg count_table_02[255:0];
reg count_table_03[255:0];

reg[2:0] count_table_all[255:0];
reg[10:0] cdf_table[255:0];
reg[7:0] cdf_min_index;
wire[7:0] cmp[2:0];

wire[10:0] cdf_min;
wire[10:0] divisor;
reg[10:0] divisor_pipe;
wire[18:0] mult[3:0];
reg[18:0] mult_pipe[3:0];
wire[DATA_WIDTH-1:0] histogram_pipe;
reg[DATA_WIDTH-1:0] histogram_out;

// erosion
reg[831:0] line_buffer;
reg[7:0] SE_table[16:0];
wire[7:0] sub0 [3:0];
wire[7:0] sub1 [3:0];
wire[7:0] sub2 [3:0];
wire[7:0] sub3 [3:0];
wire[7:0] sub4 [3:0];
wire[7:0] sub5 [3:0];
wire[7:0] sub6 [3:0];
wire[7:0] sub7 [3:0];
wire[7:0] sub8 [3:0];
wire[7:0] sub9 [3:0];
wire[7:0] sub10[3:0];
wire[7:0] sub11[3:0];
wire[7:0] sub12[3:0];
wire[7:0] sub13[3:0];
wire[7:0] sub14[3:0];
wire[7:0] sub15[3:0];
wire[7:0] min0 [3:0];
wire[7:0] min1 [3:0];
wire[7:0] min2 [3:0];
wire[7:0] min3 [3:0];
wire[7:0] min4 [3:0];
wire[7:0] min5 [3:0];
wire[7:0] min6 [3:0];
wire[7:0] min7 [3:0];
wire[7:0] min8 [3:0];
wire[7:0] min9 [3:0];
wire[7:0] min10[3:0];
wire[7:0] min11[3:0];
wire[7:0] min12[3:0];
wire[7:0] min13[3:0];
wire[7:0] min14[3:0];

// dilation
reg[831:0] line_buffer_2;
reg[7:0] SE_table_2[15:0];
wire[8:0] add0  [3:0];
wire[8:0] add1  [3:0];
wire[8:0] add2  [3:0];
wire[8:0] add3  [3:0];
wire[8:0] add4  [3:0];
wire[8:0] add5  [3:0];
wire[8:0] add6  [3:0];
wire[8:0] add7  [3:0];
wire[8:0] add8  [3:0];
wire[8:0] add9  [3:0];
wire[8:0] add10 [3:0];
wire[8:0] add11 [3:0];
wire[8:0] add12 [3:0];
wire[8:0] add13 [3:0];
wire[8:0] add14 [3:0];
wire[8:0] add15 [3:0];
wire[7:0] fadd0 [3:0];
wire[7:0] fadd1 [3:0];
wire[7:0] fadd2 [3:0];
wire[7:0] fadd3 [3:0];
wire[7:0] fadd4 [3:0];
wire[7:0] fadd5 [3:0];
wire[7:0] fadd6 [3:0];
wire[7:0] fadd7 [3:0];
wire[7:0] fadd8 [3:0];
wire[7:0] fadd9 [3:0];
wire[7:0] fadd10[3:0];
wire[7:0] fadd11[3:0];
wire[7:0] fadd12[3:0];
wire[7:0] fadd13[3:0];
wire[7:0] fadd14[3:0];
wire[7:0] fadd15[3:0];
wire[7:0] max0  [3:0];
wire[7:0] max1  [3:0];
wire[7:0] max2  [3:0];
wire[7:0] max3  [3:0];
wire[7:0] max4  [3:0];
wire[7:0] max5  [3:0];
wire[7:0] max6  [3:0];
wire[7:0] max7  [3:0];
wire[7:0] max8  [3:0];
wire[7:0] max9  [3:0];
wire[7:0] max10 [3:0];
wire[7:0] max11 [3:0];
wire[7:0] max12 [3:0];
wire[7:0] max13 [3:0];
wire[7:0] max14 [3:0];

//======================================
//          Design
//======================================

///////////////// FSM //////////////////

// c_state
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) c_state <= IDLE;
    else c_state <= n_state;
end

// n_state
always@(*) begin 
    case(c_state)
        IDLE: begin
            if(in_valid) n_state = INPUT;
            else n_state = c_state;
        end
        INPUT: begin
            if(input_counter == 26) begin 
                case(which_op)
                    3'b110: n_state = OPENING;
                    3'b111: n_state = CLOSING;
                    3'b010: n_state = EROSION;
                    3'b011: n_state = DILATION;
                    3'b000: n_state = HISTOGRAM;
                    default: n_state = c_state;
                endcase
            end
            else n_state = c_state;
        end 
        OPENING: begin 
            if(reload_counter > 26 && sram_counter == 0) n_state = BUBBLE;
            else n_state = c_state;
        end
        CLOSING: begin 
            if(reload_counter > 26 && sram_counter == 0) n_state = BUBBLE;
            else n_state = c_state;
        end
        EROSION: begin 
            if(sram_counter == 0 && c_state == EROSION) n_state = BUBBLE;
            else n_state = c_state;
        end
        DILATION: begin 
            if(sram_counter == 0 && c_state == DILATION) n_state = BUBBLE;
            else n_state = c_state;
        end
        HISTOGRAM: begin 
            if(sram_counter == 0 && c_state == HISTOGRAM) n_state = HIS_BUB;
            else n_state = c_state;
        end
        BUBBLE: n_state = OUTPUT;
        OUTPUT: begin 
            if(out_counter == 0 && c_state == OUTPUT) n_state = IDLE;
            else n_state = c_state;
        end
        HIS_BUB: begin 
            if(bubble_counter == 3) n_state = HIS_OUT;
            else n_state = c_state;
        end
        HIS_OUT: begin 
            if(out_counter == 0 && c_state == HIS_OUT) n_state = IDLE;
            else n_state = c_state;
        end
        default: n_state = c_state;
    endcase
end

//////////// INPUT ////////////

// which_op
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) which_op <= 3'd0;
    else if(op_valid) which_op <= op;
end

////////////// COUNTER ///////////////

// input_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) input_counter <= 5'b0;
    else if(n_state == INPUT) input_counter <= input_counter + 1;
    else input_counter <= 0;
end

// reload_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) reload_counter <= 9'b0;
    else if(n_state == OPENING || n_state == CLOSING) reload_counter <= reload_counter + 1;
    else reload_counter <= 0;
end

// sram_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) sram_counter <= 8'b0;
    else begin 
        case(n_state)
            OPENING: if(reload_counter > 25) sram_counter <= sram_counter + 8'b1;
            CLOSING: if(reload_counter > 25) sram_counter <= sram_counter + 8'b1;
            EROSION: sram_counter <= sram_counter + 8'b1;
            DILATION: sram_counter <= sram_counter + 8'b1;
            HISTOGRAM: sram_counter <= sram_counter + 8'b1;
            BUBBLE: sram_counter <= sram_counter + 8'b1;
            OUTPUT: sram_counter <= sram_counter + 8'b1;
            HIS_BUB: sram_counter <= sram_counter + 8'b1;
            HIS_OUT: sram_counter <= sram_counter + 8'b1;
            default: sram_counter <= 8'b0;
        endcase
    end
end

// bubble_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) bubble_counter <= 3'b0;
    else if(n_state == BUBBLE || n_state == HIS_BUB) bubble_counter <= bubble_counter + 1;
    else bubble_counter <= 0;
end

// out_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_counter <= 8'b0;
    else if(n_state == OUTPUT || n_state == HIS_OUT) out_counter <= out_counter + 1;
    else out_counter <= 0;
end

/////////////// OUTPUT /////////////////

// out_valid
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_valid <= 1'b0;
    else if(n_state == OUTPUT || n_state == HIS_OUT) out_valid <= 1'b1;
    else out_valid <= 1'b0;
end

// out_data
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_data <= 32'b0;
    else if(n_state == OUTPUT) out_data <= sram_out;
    else if(n_state == HIS_OUT) out_data <= histogram_out;
    else out_data <= 32'b0;
end

//////////// SRAM ////////////

RA1SH SRAM_OUT(.A(sram_addr), .D(sram_in), .CLK(clk), .OEN(1'b0), .CEN(1'b0), .WEN(sram_read), .Q(sram_out));

// sram_addr
always@(*) begin 
    sram_addr = sram_counter;
    /*
    case(n_state)
        OPENING: sram_addr = sram_counter;
        CLOSING: sram_addr = sram_counter;
        EROSION: sram_addr = sram_counter;
        DILATION: sram_addr = sram_counter;
        HISTOGRAM: sram_addr = sram_counter;
        default: sram_addr = 8'b0;
    endcase
    */
end

// sram_in
always@(*) begin 
    case(n_state)
        OPENING: sram_in = dilation_out;
        CLOSING: sram_in = erosion_out;
        EROSION: sram_in = erosion_out;
        DILATION: sram_in = dilation_out;
        HISTOGRAM: sram_in = line_buffer[31:0];
        default: sram_in = 32'b0;
    endcase
end

// sram_read
always@(*) begin 
    case(n_state)
        OPENING: sram_read = (reload_counter < 26);
        CLOSING: sram_read = (reload_counter < 26);
        EROSION: sram_read = 1'b0;
        DILATION: sram_read = 1'b0; 
        HISTOGRAM: sram_read = 1'b0;
        default: sram_read = 1'b1;
    endcase
end

assign sram_value[0] = sram_out[7:0];
assign sram_value[1] = sram_out[15:8];
assign sram_value[2] = sram_out[23:16];
assign sram_value[3] = sram_out[31:24];

//////////////////////////////// HISTOGRAM ////////////////////////////////////

assign pixel_value[0] = line_buffer[7:0];
assign pixel_value[1] = line_buffer[15:8];
assign pixel_value[2] = line_buffer[23:16];
assign pixel_value[3] = line_buffer[31:24];

genvar i;
generate
    for(i = 0; i < 256; i = i + 1) begin: count_loop
        // count_table_00
        always@(*) begin 
            if(pixel_value[0] == i || pixel_value[0] < i) count_table_00[i] = 1'b1;
            else count_table_00[i] = 1'b0;
        end
        // count_table_01
        always@(*) begin 
            if(pixel_value[1] == i || pixel_value[1] < i) count_table_01[i] = 1'b1;
            else count_table_01[i] = 1'b0;
        end
        // count_table_02
        always@(*) begin 
            if(pixel_value[2] == i || pixel_value[2] < i) count_table_02[i] = 1'b1;
            else count_table_02[i] = 1'b0;
        end
        // count_table_03
        always@(*) begin 
            if(pixel_value[3] == i || pixel_value[3] < i) count_table_03[i] = 1'b1;
            else count_table_03[i] = 1'b0;
        end
        // count_table_all
        always@(*) begin 
            count_table_all[i] = count_table_00[i] + count_table_01[i] + count_table_02[i] + count_table_03[i];
        end
        // cdf_table
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) cdf_table[i] <= 11'b0;
            else if(n_state == HISTOGRAM) cdf_table[i] <= cdf_table[i] + count_table_all[i];
            else if(n_state == IDLE) cdf_table[i] <= 11'b0;
        end
    end
endgenerate

assign cmp[0]  = (pixel_value[0]  < pixel_value[1] )? pixel_value[0]  : pixel_value[1] ;
assign cmp[1]  = (pixel_value[2]  < pixel_value[3] )? pixel_value[2]  : pixel_value[3] ;
assign cmp[2]  = (cmp[0] < cmp[1])? cmp[0] : cmp[1];

// cdf_min_index
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) cdf_min_index <= 8'd255;
    else if(n_state == HISTOGRAM && cmp[2] < cdf_min_index) cdf_min_index <= cmp[2];
    else if(n_state == IDLE) cdf_min_index <= 8'd255;
end

assign cdf_min = cdf_table[cdf_min_index];

assign divisor = 11'd1024 - cdf_min;

/////////////////// HIS_OUT //////////////////////

assign mult[0] = ((cdf_table[sram_value[0]] - cdf_min) << 8) - (cdf_table[sram_value[0]] - cdf_min);
assign mult[1] = ((cdf_table[sram_value[1]] - cdf_min) << 8) - (cdf_table[sram_value[1]] - cdf_min);
assign mult[2] = ((cdf_table[sram_value[2]] - cdf_min) << 8) - (cdf_table[sram_value[2]] - cdf_min);
assign mult[3] = ((cdf_table[sram_value[3]] - cdf_min) << 8) - (cdf_table[sram_value[3]] - cdf_min);

genvar j;
generate
    for(j = 0; j < 4; j = j + 1) begin 
        // mult_pipe
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) mult_pipe[j] <= 19'b0;
            else mult_pipe[j] <= mult[j];
        end
    end
endgenerate

// divisor_pipe
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) divisor_pipe <= 11'b0;
    else divisor_pipe <= divisor;
end

assign histogram_pipe[7:0] = mult_pipe[0] / divisor_pipe;
assign histogram_pipe[15:8] = mult_pipe[1] / divisor_pipe;
assign histogram_pipe[23:16] = mult_pipe[2] / divisor_pipe;
assign histogram_pipe[31:24] = mult_pipe[3] / divisor_pipe;

// histogram_out
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) histogram_out <= 32'b0;
    else histogram_out <= histogram_pipe;
end

////////////////////////////////////////////// EROSION & DILATION ///////////////////////////////////////////////////

// line_buffer
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        line_buffer <= 832'b0;
        line_buffer_2 <= 832'b0;
    end
    else begin 
        case(n_state)
            IDLE: begin
                line_buffer <= 832'b0;
                line_buffer_2 <= 832'b0;
            end
            INPUT: begin 
                line_buffer <= {pic_data, line_buffer[831:32]};
                line_buffer_2 <= {pic_data, line_buffer_2[831:32]};
            end
            OPENING: begin 
                if(in_valid) begin 
                    line_buffer <= {pic_data, line_buffer[831:32]};
                    line_buffer_2 <= {erosion_out, line_buffer_2[831:32]};
                end
                else if(reload_counter < 256) begin 
                    line_buffer <= {32'b0, line_buffer[831:32]};
                    line_buffer_2 <= {erosion_out, line_buffer_2[831:32]};
                end
                else begin 
                    line_buffer <= {32'b0, line_buffer[831:32]};
                    line_buffer_2 <= {32'b0, line_buffer_2[831:32]};
                end
            end
            CLOSING: begin 
                if(in_valid) begin 
                    line_buffer <= {dilation_out, line_buffer[831:32]};
                    line_buffer_2 <= {pic_data, line_buffer_2[831:32]};
                end
                else if(reload_counter < 256) begin 
                    line_buffer <= {dilation_out, line_buffer[831:32]};
                    line_buffer_2 <= {32'b0, line_buffer_2[831:32]};
                end
                else begin 
                    line_buffer <= {32'b0, line_buffer[831:32]};
                    line_buffer_2 <= {32'b0, line_buffer_2[831:32]};
                end
            end
            EROSION: begin 
                if(in_valid) line_buffer <= {pic_data, line_buffer[831:32]};
                else line_buffer <= {32'b0, line_buffer[831:32]};
            end
            DILATION: begin 
                if(in_valid) line_buffer_2 <= {pic_data, line_buffer_2[831:32]};
                else line_buffer_2 <= {32'b0, line_buffer_2[831:32]};
            end
            HISTOGRAM: begin 
                if(in_valid) line_buffer <= {pic_data, line_buffer[831:32]};
                else line_buffer <= {32'b0, line_buffer[831:32]};
            end
        endcase
    end
end

// SE_table_20
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) SE_table_2[0] <= 8'b0;
    else if(n_state == INPUT && input_counter < 16) SE_table_2[0] <= se_data;
end

// SE_table16
always@(*) begin 
    SE_table[16] = se_data;
end

genvar s;
generate
    for(s = 0; s < 16; s = s + 1) begin :se_loop
        // SE_table
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) SE_table[s] <= 8'b0;
            else if(n_state == INPUT && input_counter < 16) SE_table[s] <= SE_table[s + 1];
        end
    end

    for(s = 1; s < 16; s = s + 1) begin
        // SE_table_2
        always@(posedge clk or negedge rst_n) begin 
            if(!rst_n) SE_table_2[s] <= 8'b0;
            else if(n_state == INPUT && input_counter < 16) SE_table_2[s] <= SE_table_2[s - 1];
        end
    end

    for(s = 0; s < 4; s = s + 1) begin
        assign fadd0[s] = (add0[s][8])? 8'hff : add0[s][7:0];
        assign fadd1[s] = (add1[s][8])? 8'hff : add1[s][7:0];
        assign fadd2[s] = (add2[s][8])? 8'hff : add2[s][7:0];
        assign fadd3[s] = (add3[s][8])? 8'hff : add3[s][7:0];
        assign fadd4[s] = (add4[s][8])? 8'hff : add4[s][7:0];
        assign fadd5[s] = (add5[s][8])? 8'hff : add5[s][7:0];
        assign fadd6[s] = (add6[s][8])? 8'hff : add6[s][7:0];
        assign fadd7[s] = (add7[s][8])? 8'hff : add7[s][7:0];
        assign fadd8[s] = (add8[s][8])? 8'hff : add8[s][7:0];
        assign fadd9[s] = (add9[s][8])? 8'hff : add9[s][7:0];
        assign fadd10[s] = (add10[s][8])? 8'hff : add10[s][7:0];
        assign fadd11[s] = (add11[s][8])? 8'hff : add11[s][7:0];
        assign fadd12[s] = (add12[s][8])? 8'hff : add12[s][7:0];
        assign fadd13[s] = (add13[s][8])? 8'hff : add13[s][7:0];
        assign fadd14[s] = (add14[s][8])? 8'hff : add14[s][7:0];
        assign fadd15[s] = (add15[s][8])? 8'hff : add15[s][7:0];

        assign min0[s] = (sub0[s] < sub1[s])? sub0[s] : sub1[s];
        assign min1[s] = (sub2[s] < sub3[s])? sub2[s] : sub3[s];
        assign min2[s] = (sub4[s] < sub5[s])? sub4[s] : sub5[s];
        assign min3[s] = (sub6[s] < sub7[s])? sub6[s] : sub7[s];
        assign min4[s] = (sub8[s] < sub9[s])? sub8[s] : sub9[s];
        assign min5[s] = (sub10[s] < sub11[s])? sub10[s] : sub11[s];
        assign min6[s] = (sub12[s] < sub13[s])? sub12[s] : sub13[s];
        assign min7[s] = (sub14[s] < sub15[s])? sub14[s] : sub15[s];
        assign min8[s] = (min0[s] < min1[s])? min0[s] : min1[s];
        assign min9[s] = (min2[s] < min3[s])? min2[s] : min3[s];
        assign min10[s] = (min4[s] < min5[s])? min4[s] : min5[s];
        assign min11[s] = (min6[s] < min7[s])? min6[s] : min7[s];
        assign min12[s] = (min8[s] < min9[s])? min8[s] : min9[s];
        assign min13[s] = (min10[s] < min11[s])? min10[s] : min11[s];
        assign min14[s] = (min12[s] < min13[s])? min12[s] : min13[s];
        
        assign max0[s] = (fadd0[s] > fadd1[s])? fadd0[s] : fadd1[s];
        assign max1[s] = (fadd2[s] > fadd3[s])? fadd2[s] : fadd3[s];
        assign max2[s] = (fadd4[s] > fadd5[s])? fadd4[s] : fadd5[s];
        assign max3[s] = (fadd6[s] > fadd7[s])? fadd6[s] : fadd7[s];
        assign max4[s] = (fadd8[s] > fadd9[s])? fadd8[s] : fadd9[s];
        assign max5[s] = (fadd10[s] > fadd11[s])? fadd10[s] : fadd11[s];
        assign max6[s] = (fadd12[s] > fadd13[s])? fadd12[s] : fadd13[s];
        assign max7[s] = (fadd14[s] > fadd15[s])? fadd14[s] : fadd15[s];
        assign max8[s] = (max0[s] > max1[s])? max0[s] : max1[s];
        assign max9[s] = (max2[s] > max3[s])? max2[s] : max3[s];
        assign max10[s] = (max4[s] > max5[s])? max4[s] : max5[s];
        assign max11[s] = (max6[s] > max7[s])? max6[s] : max7[s];
        assign max12[s] = (max8[s] > max9[s])? max8[s] : max9[s];
        assign max13[s] = (max10[s] > max11[s])? max10[s] : max11[s];
        assign max14[s] = (max12[s] > max13[s])? max12[s] : max13[s];
    end
endgenerate

assign erosion_out[7:0]   = min14[0];
assign erosion_out[15:8]  = min14[1];
assign erosion_out[23:16] = min14[2];
assign erosion_out[31:24] = min14[3];

assign dilation_out[7:0]   = max14[0];
assign dilation_out[15:8]  = max14[1];
assign dilation_out[23:16] = max14[2];
assign dilation_out[31:24] = max14[3];

//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////// LEVEL 111111111 ///////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////

assign sub0[0] = (line_buffer[7:0]   > SE_table[0])? line_buffer[7:0]   - SE_table[0] : 8'b0;
assign sub0[1] = (line_buffer[15:8]  > SE_table[0])? line_buffer[15:8]  - SE_table[0] : 8'b0;
assign sub0[2] = (line_buffer[23:16] > SE_table[0])? line_buffer[23:16] - SE_table[0] : 8'b0;
assign sub0[3] = (line_buffer[31:24] > SE_table[0])? line_buffer[31:24] - SE_table[0] : 8'b0;

assign sub1[0] = (                                                                                                                                                     line_buffer[15:8]  > SE_table[1])? line_buffer[15:8]  - SE_table[1] : 8'b0;
assign sub1[1] = (                                                                                                                                                     line_buffer[23:16] > SE_table[1])? line_buffer[23:16] - SE_table[1] : 8'b0;
assign sub1[2] = (                                                                                                                                                     line_buffer[31:24] > SE_table[1])? line_buffer[31:24] - SE_table[1] : 8'b0;
assign sub1[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[39:32] > SE_table[1])? line_buffer[39:32] - SE_table[1] : 8'b0;

assign sub2[0] = (                                                                                                                                                     line_buffer[23:16] > SE_table[2])? line_buffer[23:16] - SE_table[2] : 8'b0;
assign sub2[1] = (                                                                                                                                                     line_buffer[31:24] > SE_table[2])? line_buffer[31:24] - SE_table[2] : 8'b0;
assign sub2[2] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[39:32] > SE_table[2])? line_buffer[39:32] - SE_table[2] : 8'b0;
assign sub2[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[47:40] > SE_table[2])? line_buffer[47:40] - SE_table[2] : 8'b0;

assign sub3[0] = (                                                                                                                                                     line_buffer[31:24] > SE_table[3])? line_buffer[31:24] - SE_table[3] : 8'b0;
assign sub3[1] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[39:32] > SE_table[3])? line_buffer[39:32] - SE_table[3] : 8'b0;
assign sub3[2] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[47:40] > SE_table[3])? line_buffer[47:40] - SE_table[3] : 8'b0;
assign sub3[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[55:48] > SE_table[3])? line_buffer[55:48] - SE_table[3] : 8'b0;



assign add0[0] = line_buffer_2[7:0]   + SE_table_2[0];
assign add0[1] = line_buffer_2[15:8]  + SE_table_2[0];
assign add0[2] = line_buffer_2[23:16] + SE_table_2[0];
assign add0[3] = line_buffer_2[31:24] + SE_table_2[0];

assign add1[0] =                                                                                                                                 line_buffer_2[15:8]  + SE_table_2[1];
assign add1[1] =                                                                                                                                 line_buffer_2[23:16] + SE_table_2[1];
assign add1[2] =                                                                                                                                 line_buffer_2[31:24] + SE_table_2[1];
assign add1[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[1] : line_buffer_2[39:32] + SE_table_2[1];

assign add2[0] =                                                                                                                                 line_buffer_2[23:16] + SE_table_2[2];
assign add2[1] =                                                                                                                                 line_buffer_2[31:24] + SE_table_2[2];
assign add2[2] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[2] : line_buffer_2[39:32] + SE_table_2[2];
assign add2[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[2] : line_buffer_2[47:40] + SE_table_2[2];

assign add3[0] =                                                                                                                                 line_buffer_2[31:24] + SE_table_2[3];
assign add3[1] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[3] : line_buffer_2[39:32] + SE_table_2[3];
assign add3[2] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[3] : line_buffer_2[47:40] + SE_table_2[3];
assign add3[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[3] : line_buffer_2[55:48] + SE_table_2[3];


//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////// LEVEL 222222222 ///////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////

assign sub4[0] = (line_buffer[263:256] > SE_table[4])? line_buffer[263:256] - SE_table[4] : 8'b0;
assign sub4[1] = (line_buffer[271:264] > SE_table[4])? line_buffer[271:264] - SE_table[4] : 8'b0;
assign sub4[2] = (line_buffer[279:272] > SE_table[4])? line_buffer[279:272] - SE_table[4] : 8'b0;
assign sub4[3] = (line_buffer[287:280] > SE_table[4])? line_buffer[287:280] - SE_table[4] : 8'b0;

assign sub5[0] = (                                                                                                                                                       line_buffer[271:264] > SE_table[5])? line_buffer[271:264] - SE_table[5] : 8'b0;
assign sub5[1] = (                                                                                                                                                       line_buffer[279:272] > SE_table[5])? line_buffer[279:272] - SE_table[5] : 8'b0;
assign sub5[2] = (                                                                                                                                                       line_buffer[287:280] > SE_table[5])? line_buffer[287:280] - SE_table[5] : 8'b0;
assign sub5[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[295:288] > SE_table[5])? line_buffer[295:288] - SE_table[5] : 8'b0;

assign sub6[0] = (                                                                                                                                                       line_buffer[279:272] > SE_table[6])? line_buffer[279:272] - SE_table[6] : 8'b0;
assign sub6[1] = (                                                                                                                                                       line_buffer[287:280] > SE_table[6])? line_buffer[287:280] - SE_table[6] : 8'b0;
assign sub6[2] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[295:288] > SE_table[6])? line_buffer[295:288] - SE_table[6] : 8'b0;
assign sub6[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[303:296] > SE_table[6])? line_buffer[303:296] - SE_table[6] : 8'b0;

assign sub7[0] = (                                                                                                                                                       line_buffer[287:280] > SE_table[7])? line_buffer[287:280] - SE_table[7] : 8'b0;
assign sub7[1] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[295:288] > SE_table[7])? line_buffer[295:288] - SE_table[7] : 8'b0;
assign sub7[2] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[303:296] > SE_table[7])? line_buffer[303:296] - SE_table[7] : 8'b0;
assign sub7[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[311:304] > SE_table[7])? line_buffer[311:304] - SE_table[7] : 8'b0;



assign add4[0] = line_buffer_2[263:256] + SE_table_2[4];
assign add4[1] = line_buffer_2[271:264] + SE_table_2[4];
assign add4[2] = line_buffer_2[279:272] + SE_table_2[4];
assign add4[3] = line_buffer_2[287:280] + SE_table_2[4];

assign add5[0] =                                                                                                                                 line_buffer_2[271:264] + SE_table_2[5];
assign add5[1] =                                                                                                                                 line_buffer_2[279:272] + SE_table_2[5];
assign add5[2] =                                                                                                                                 line_buffer_2[287:280] + SE_table_2[5];
assign add5[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[5] : line_buffer_2[295:288] + SE_table_2[5];

assign add6[0] =                                                                                                                                 line_buffer_2[279:272] + SE_table_2[6];
assign add6[1] =                                                                                                                                 line_buffer_2[287:280] + SE_table_2[6];
assign add6[2] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[6] : line_buffer_2[295:288] + SE_table_2[6];
assign add6[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[6] : line_buffer_2[303:296] + SE_table_2[6];

assign add7[0] =                                                                                                                                 line_buffer_2[287:280] + SE_table_2[7];
assign add7[1] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[7] : line_buffer_2[295:288] + SE_table_2[7];
assign add7[2] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[7] : line_buffer_2[303:296] + SE_table_2[7];
assign add7[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[7] : line_buffer_2[311:304] + SE_table_2[7];



//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////// LEVEL 333333333 ///////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////

assign sub8[0] = (line_buffer[519:512] > SE_table[8])? line_buffer[519:512] - SE_table[8] : 8'b0;
assign sub8[1] = (line_buffer[527:520] > SE_table[8])? line_buffer[527:520] - SE_table[8] : 8'b0;
assign sub8[2] = (line_buffer[535:528] > SE_table[8])? line_buffer[535:528] - SE_table[8] : 8'b0;
assign sub8[3] = (line_buffer[543:536] > SE_table[8])? line_buffer[543:536] - SE_table[8] : 8'b0;

assign sub9[0] = (                                                                                                                                                       line_buffer[527:520] > SE_table[9])? line_buffer[527:520] - SE_table[9] : 8'b0;
assign sub9[1] = (                                                                                                                                                       line_buffer[535:528] > SE_table[9])? line_buffer[535:528] - SE_table[9] : 8'b0;
assign sub9[2] = (                                                                                                                                                       line_buffer[543:536] > SE_table[9])? line_buffer[543:536] - SE_table[9] : 8'b0;
assign sub9[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[551:544] > SE_table[9])? line_buffer[551:544] - SE_table[9] : 8'b0;

assign sub10[0] = (                                                                                                                                                        line_buffer[535:528] > SE_table[10])? line_buffer[535:528] - SE_table[10] : 8'b0;
assign sub10[1] = (                                                                                                                                                        line_buffer[543:536] > SE_table[10])? line_buffer[543:536] - SE_table[10] : 8'b0;
assign sub10[2] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[551:544] > SE_table[10])? line_buffer[551:544] - SE_table[10] : 8'b0;
assign sub10[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[559:552] > SE_table[10])? line_buffer[559:552] - SE_table[10] : 8'b0;

assign sub11[0] = (                                                                                                                                                        line_buffer[543:536] > SE_table[11])? line_buffer[543:536] - SE_table[11] : 8'b0;
assign sub11[1] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[551:544] > SE_table[11])? line_buffer[551:544] - SE_table[11] : 8'b0;
assign sub11[2] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[559:552] > SE_table[11])? line_buffer[559:552] - SE_table[11] : 8'b0;
assign sub11[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[567:560] > SE_table[11])? line_buffer[567:560] - SE_table[11] : 8'b0;



assign add8[0] = line_buffer_2[519:512] + SE_table_2[8];
assign add8[1] = line_buffer_2[527:520] + SE_table_2[8];
assign add8[2] = line_buffer_2[535:528] + SE_table_2[8];
assign add8[3] = line_buffer_2[543:536] + SE_table_2[8];

assign add9[0] =                                                                                                                                 line_buffer_2[527:520] + SE_table_2[9];
assign add9[1] =                                                                                                                                 line_buffer_2[535:528] + SE_table_2[9];
assign add9[2] =                                                                                                                                 line_buffer_2[543:536] + SE_table_2[9];
assign add9[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[9] : line_buffer_2[551:544] + SE_table_2[9];

assign add10[0] =                                                                                                                                  line_buffer_2[535:528] + SE_table_2[10];
assign add10[1] =                                                                                                                                  line_buffer_2[543:536] + SE_table_2[10];
assign add10[2] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[10] : line_buffer_2[551:544] + SE_table_2[10];
assign add10[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[10] : line_buffer_2[559:552] + SE_table_2[10];

assign add11[0] =                                                                                                                                  line_buffer_2[543:536] + SE_table_2[11];
assign add11[1] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[11] : line_buffer_2[551:544] + SE_table_2[11];
assign add11[2] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[11] : line_buffer_2[559:552] + SE_table_2[11];
assign add11[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[11] : line_buffer_2[567:560] + SE_table_2[11];



//////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////// LEVEL 444444444 ///////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////

assign sub12[0] = (line_buffer[775:768] > SE_table[12])? line_buffer[775:768] - SE_table[12] : 8'b0;
assign sub12[1] = (line_buffer[783:776] > SE_table[12])? line_buffer[783:776] - SE_table[12] : 8'b0;
assign sub12[2] = (line_buffer[791:784] > SE_table[12])? line_buffer[791:784] - SE_table[12] : 8'b0;
assign sub12[3] = (line_buffer[799:792] > SE_table[12])? line_buffer[799:792] - SE_table[12] : 8'b0;

assign sub13[0] = (                                                                                                                                                        line_buffer[783:776] > SE_table[13])? line_buffer[783:776] - SE_table[13] : 8'b0;
assign sub13[1] = (                                                                                                                                                        line_buffer[791:784] > SE_table[13])? line_buffer[791:784] - SE_table[13] : 8'b0;
assign sub13[2] = (                                                                                                                                                        line_buffer[799:792] > SE_table[13])? line_buffer[799:792] - SE_table[13] : 8'b0;
assign sub13[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[807:800] > SE_table[13])? line_buffer[807:800] - SE_table[13] : 8'b0;

assign sub14[0] = (                                                                                                                                                        line_buffer[791:784] > SE_table[14])? line_buffer[791:784] - SE_table[14] : 8'b0;
assign sub14[1] = (                                                                                                                                                        line_buffer[799:792] > SE_table[14])? line_buffer[799:792] - SE_table[14] : 8'b0;
assign sub14[2] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[807:800] > SE_table[14])? line_buffer[807:800] - SE_table[14] : 8'b0;
assign sub14[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[815:808] > SE_table[14])? line_buffer[815:808] - SE_table[14] : 8'b0;

assign sub15[0] = (                                                                                                                                                        line_buffer[799:792] > SE_table[15])? line_buffer[799:792] - SE_table[15] : 8'b0;
assign sub15[1] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[807:800] > SE_table[15])? line_buffer[807:800] - SE_table[15] : 8'b0;
assign sub15[2] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[815:808] > SE_table[15])? line_buffer[815:808] - SE_table[15] : 8'b0;
assign sub15[3] = (((reload_counter[2:0] != 3'b111 && n_state == OPENING) || (sram_counter[2:0] != 3'b111 && n_state != OPENING)) && line_buffer[823:816] > SE_table[15])? line_buffer[823:816] - SE_table[15] : 8'b0;



assign add12[0] = line_buffer_2[775:768] + SE_table_2[12];
assign add12[1] = line_buffer_2[783:776] + SE_table_2[12];
assign add12[2] = line_buffer_2[791:784] + SE_table_2[12];
assign add12[3] = line_buffer_2[799:792] + SE_table_2[12];

assign add13[0] =                                                                                                                                  line_buffer_2[783:776] + SE_table_2[13];
assign add13[1] =                                                                                                                                  line_buffer_2[791:784] + SE_table_2[13];
assign add13[2] =                                                                                                                                  line_buffer_2[799:792] + SE_table_2[13];
assign add13[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[13] : line_buffer_2[807:800] + SE_table_2[13];

assign add14[0] =                                                                                                                                  line_buffer_2[791:784] + SE_table_2[14];
assign add14[1] =                                                                                                                                  line_buffer_2[799:792] + SE_table_2[14];
assign add14[2] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[14] : line_buffer_2[807:800] + SE_table_2[14];
assign add14[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[14] : line_buffer_2[815:808] + SE_table_2[14];

assign add15[0] =                                                                                                                                  line_buffer_2[799:792] + SE_table_2[15];
assign add15[1] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[15] : line_buffer_2[807:800] + SE_table_2[15];
assign add15[2] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[15] : line_buffer_2[815:808] + SE_table_2[15];
assign add15[3] = ((sram_counter[2:0] == 3'b111 && n_state != CLOSING) || (reload_counter[2:0] == 3'b111 && n_state == CLOSING))? SE_table_2[15] : line_buffer_2[823:816] + SE_table_2[15];


endmodule