//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : UT_TOP.v
//   Module Name : UT_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "B2BCD_IP.v"
//synopsys translate_on

module UT_TOP (
    // Input signals
    clk, rst_n, in_valid, in_time,
    // Output signals
    out_valid, out_display, out_day
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [30:0] in_time;
output reg out_valid;
output reg [3:0] out_display;
output reg [2:0] out_day;

// ===============================================================
// Parameter & Integer Declaration
// ===============================================================
parameter IDLE = 2'd0;
parameter INPUT = 2'd1;
parameter CALCULATION = 2'd2;
parameter OUTPUT = 2'd3;

//================================================================
// Wire & Reg Declaration
//================================================================

reg[1:0] c_state, n_state;
reg[3:0] out_counter;
reg[4:0] calculation_counter;
reg[30:0] timestamp;

wire[31:0] year0;
wire[30:0] year1;
wire[29:0] year2;
wire[28:0] year3;
wire[27:0] year4;
wire[26:0] year5;
wire[25:0] year6;
wire[25:0] year7;
wire[6:0] year_64, year_32, year_16,
        year_8, year_4, year_2, year_1, year_leap;
reg[10:0] which_year;

reg[24:0] month_stamp;
wire[25:0] month[11:0], feb[1:0];
reg[3:0] which_month;

reg[21:0] day_stamp;
wire[21:0] day0;
wire[20:0] day1;
wire[19:0] day2;
wire[18:0] day3;
wire[17:0] day4;
wire[4:0] day_16, day_8, day_4, day_2, day_1;
reg[4:0] which_day;

reg[16:0] hour_stamp;
wire[16:0] hour0;
wire[15:0] hour1;
wire[14:0] hour2;
wire[13:0] hour3;
wire[12:0] hour4;
wire[4:0] hour_16, hour_8, hour_4, hour_2, hour_1;
reg[4:0] which_hour;

reg[11:0] minute_stamp;
wire[11:0] min0;
wire[10:0] min1;
wire[9:0] min2;
wire[8:0] min3;
wire[7:0] min4;
wire[6:0] min5;
wire[5:0] min_32, min_16, min_8, min_4, min_2, min_1;
reg[5:0] which_minute;

reg[5:0] which_second;

wire[15:0] bcd_year;
wire[7:0] bcd_month, bcd_day, bcd_hour, bcd_minute, bcd_second;
wire[3:0] ans[13:0];

wire[30:0] week_0;
wire[29:0] week_1;
wire[28:0] week_2;
wire[27:0] week_3;
wire[26:0] week_4;
wire[25:0] week_5;
wire[24:0] week_6;
wire[23:0] week_7;
wire[22:0] week_8;
wire[21:0] week_9;
wire[20:0] week_10;
wire[19:0] week_11;
wire[19:0] wday0;
wire[18:0] wday1;
wire[17:0] wday2;
wire[2:0] wday_4, wday_2, wday_1;
wire[2:0] which_weekday;

reg[31:0] more[9:0];

//================================================================
// DESIGN
//================================================================

//////////////// FSM /////////////////

always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) c_state <= IDLE;
    else c_state <= n_state;
end

always@(*) begin 
    case(c_state)
        IDLE: begin 
            if(in_valid == 1'b1) n_state = INPUT;
            else n_state = c_state;
        end
        INPUT: begin 
            n_state = CALCULATION;
        end
        OUTPUT: begin 
            if(out_counter == 4'd14) n_state = IDLE;
            else n_state = c_state;
        end
        CALCULATION: begin 
            if(calculation_counter == 5'd3) n_state = OUTPUT;
            else n_state = c_state;
        end
    endcase
end

////////////// INPUT ///////////////

// timestamp
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) timestamp <= 31'b0;
    else begin 
        case(n_state)
            INPUT: timestamp <= in_time;
        endcase        
    end
end

////////////// CALCULATION //////////////

// calculation_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) calculation_counter <= 5'b0;
    else begin 
        case(n_state)
            IDLE: calculation_counter <= 5'b0;
            INPUT: calculation_counter <= calculation_counter + 5'b1;
            OUTPUT: calculation_counter <= calculation_counter + 5'b1;
            CALCULATION: calculation_counter <= calculation_counter + 5'b1;
        endcase
    end
end

assign year0 = (timestamp > 'd2019686399)? {1'b0, timestamp - 'd2019686400} : {1'b1, timestamp};
assign year1 = (year0[30:0] > 'd1009843199)? year0[30:0] - 'd1009843200 : {1'b1, year0[29:0]};
assign year2 = (year1[29:0] > 'd504921599)? year1[29:0] - 'd504921600 : {1'b1, year1[28:0]};
assign year3 = (year2[28:0] > 'd252460799)? year2[28:0] - 'd252460800 : {1'b1, year2[27:0]};

// more0
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[0] <= 32'b0;
    else begin 
        case(calculation_counter)
            1: more[0] <= year3;
        endcase
    end
end

assign year4 = (more[0][27:0] > 'd126230399)? more[0][27:0] - 'd126230400 : {1'b1, more[0][26:0]};
assign year5 = (year4[26:0] > 'd63158399)? year4[26:0] - 'd63158400 : {1'b1, year4[25:0]};
assign year6 = (year5[25:0] > 'd31535999)? year5[25:0] - 'd31536000 : {1'b1, year5[24:0]};
assign year7 = (year6[24:0] > 'd31535999)? year6[24:0] - 'd31536000 : {1'b1, year6[24:0]};

assign year_64 = (!year0[31])? 'd64 : 0;
assign year_32 = (!year1[30])? 'd32 : 0;
assign year_16 = (!year2[29])? 'd16 : 0;

assign year_8 = (!more[0][28])? 'd8 : 0;
assign year_4 = (!year4[27])? 'd4 : 0;
assign year_2 = (!year5[26])? 'd2 : 0;
assign year_1 = (!year6[25])? 'd1 : 0;
assign year_leap = (!year7[25])? 'd1 : 0;

// which_year
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) which_year <= 11'd0;
    else begin 
        case(calculation_counter)
            1: which_year <= 'd1970 + year_64 + year_32 + year_16;
            2: which_year <= which_year + year_8 + year_4 + year_2 + year_1 + year_leap;
        endcase
    end
end

// more6
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[6] <= 32'b0;
    else begin 
        case(calculation_counter)
            2: more[6] <= (!year5[26] & year6[25]);
        endcase
    end
end

// month_stamp
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) month_stamp <= 25'b0;
    else begin 
        case(calculation_counter)
            2: month_stamp <= year7[24:0];
        endcase
    end
end

assign month[0] = (more[6])? month_stamp + 'd86400 : month_stamp;
assign month[1] = (month[0][24:0] > 'd2678399)? {1'b0, month[0][24:0] - 'd2678400} : {1'b1, month[0][24:0]};
assign feb[0] = (!month[1][25] && month[1][24:0] > 'd2419199)? {1'b0, month[1][24:0] - 'd2419200} : {1'b1, month[1][24:0]};
assign feb[1] = (!month[1][25] && month[1][24:0] > 'd2505599)? {1'b0, month[1][24:0] - 'd2505600} : {1'b1, month[1][24:0]};
assign month[2] = (more[6])? feb[1] : feb[0];

// more1
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[1] <= 32'b0;
    else begin 
        case(calculation_counter)
            3: more[1] <= month[2];
        endcase
    end
end

assign month[3] = (!more[1][25] && more[1][24:0] > 'd2678399)? {1'b0, more[1][24:0] - 'd2678400} : {1'b1, more[1][24:0]};
assign month[4] = (!month[3][25] && month[3][24:0] > 'd2591999)? {1'b0, month[3][24:0] - 'd2592000} : {1'b1, month[3][24:0]};
assign month[5] = (!month[4][25] && month[4][24:0] > 'd2678399)? {1'b0, month[4][24:0] - 'd2678400} : {1'b1, month[4][24:0]};

// more7
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[7] <= 32'b0;
    else begin 
        case(calculation_counter)
            4: more[7] <= month[5];
        endcase
    end
end

assign month[6] = (!more[7][25] && more[7][24:0] > 'd2591999)? {1'b0, more[7][24:0] - 'd2592000} : {1'b1, more[7][24:0]};
assign month[7] = (!month[6][25] && month[6][24:0] > 'd2678399)? {1'b0, month[6][24:0] - 'd2678400} : {1'b1, month[6][24:0]};
assign month[8] = (!month[7][25] && month[7][24:0] > 'd2678399)? {1'b0, month[7][24:0] - 'd2678400} : {1'b1, month[7][24:0]};

// more2
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[2] <= 32'b0;
    else begin 
        case(calculation_counter)
            5: more[2] <= month[8];
        endcase
    end
end

assign month[9] = (!more[2][25] && more[2][24:0] > 'd2591999)? {1'b0, more[2][24:0] - 'd2592000} : {1'b1, more[2][24:0]};
assign month[10] = (!month[9][25] && month[9][24:0] > 'd2678399)? {1'b0, month[9][24:0] - 'd2678400} : {1'b1, month[9][24:0]};
assign month[11] = (!month[10][25] && month[10][24:0] > 'd2591999)? {1'b0, month[10][24:0] - 'd2592000} : {1'b1, month[10][24:0]};

// which_month
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) which_month <= 4'b0;
    else begin 
        case(calculation_counter)
            3: which_month <= 4'b1 + !month[1][25] + !month[2][25];
            4: which_month <= which_month + !month[3][25] + !month[4][25] + !month[5][25];
            5: which_month <= which_month + !month[6][25] + !month[7][25] + !month[8][25];
            6: which_month <= which_month + !month[9][25] + !month[10][25] + !month[11][25];
        endcase
    end
end

// day_stamp
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) day_stamp <= 22'b0;
    else begin 
        case(calculation_counter)
            6: day_stamp <= month[11][21:0];
        endcase
    end
end

assign day0 = (day_stamp > 'd1382399)? day_stamp - 'd1382400 : {1'b1, day_stamp[20:0]};
assign day1 = (day0[20:0] > 'd691199)? day0[20:0] - 'd691200 : {1'b1, day0[19:0]};
assign day2 = (day1[19:0] > 'd345599)? day1[19:0] - 'd345600 : {1'b1, day1[18:0]};

// more8
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[8] <= 32'b0;
    else begin 
        case(calculation_counter)
            7: more[8] <= day2;
        endcase
    end
end

assign day3 = (more[8][18:0] > 'd172799)? more[8][18:0] - 'd172800 : {1'b1, more[8][17:0]};
assign day4 = (day3[17:0] > 'd86399)? day3[17:0] - 'd86400 : {1'b1, day3[16:0]};

assign day_16 = (!day0[21])? 'd16 : 0;
assign day_8 = (!day1[20])? 'd8 : 0;

assign day_4 = (!more[8][19])? 'd4 : 0;
assign day_2 = (!day3[18])? 'd2 : 0;
assign day_1 = (!day4[17])? 'd1 : 0;

// which_day
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) which_day <= 5'b0;
    else begin 
        case(calculation_counter)
            7: which_day <= 'd1 + day_16 + day_8;
            8: which_day <= which_day + day_4 + day_2 + day_1;
        endcase
    end
end

// hour_stamp
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) hour_stamp <= 17'b0;
    else begin 
        case(calculation_counter)
            8: hour_stamp <= day4[16:0];
        endcase
    end
end

assign hour0 = (hour_stamp > 'd57599)? hour_stamp - 'd57600 : {1'b1, hour_stamp[15:0]};
assign hour1 = (hour0[15:0] > 'd28799)? hour0[15:0] - 'd28800 : {1'b1, hour0[14:0]};
assign hour2 = (hour1[14:0] > 'd14399)? hour1[14:0] - 'd14400 : {1'b1, hour1[13:0]};

// more9
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[9] <= 32'b0;
    else begin 
        case(calculation_counter)
            9: more[9] <= hour2;
        endcase
    end
end

assign hour3 = (more[9][13:0] > 'd7199)? more[9][13:0] - 'd7200 : {1'b1, more[9][12:0]};
assign hour4 = (hour3[12:0] > 'd3599)? hour3[12:0] - 'd3600 : {1'b1, hour3[11:0]};

assign hour_16 = (!hour0[16])? 'd16 : 0;
assign hour_8 = (!hour1[15])? 'd8 : 0;

assign hour_4 = (!more[9][14])? 'd4 : 0;
assign hour_2 = (!hour3[13])? 'd2 : 0;
assign hour_1 = (!hour4[12])? 'd1 : 0;

// which_hour
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) which_hour <= 5'b0;
    else begin 
        case(calculation_counter)
            9: which_hour <= hour_16 + hour_8;
            10: which_hour <= which_hour + hour_4 + hour_2 + hour_1;
        endcase
    end
end

// minute_stamp
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) minute_stamp <= 12'b0;
    else begin 
        case(calculation_counter)
            10: minute_stamp <= hour4[11:0];
        endcase
    end
end

assign min0 = (minute_stamp > 'd1919)? minute_stamp - 'd1920 : {1'b1, minute_stamp[10:0]};
assign min1 = (min0[10:0] > 'd959)? min0[10:0] - 'd960 : {1'b1, min0[9:0]};
assign min2 = (min1[9:0] > 'd479)? min1[9:0] - 'd480 : {1'b1, min1[8:0]};

// more3
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[3] <= 32'b0;
    else begin 
        case(calculation_counter)
            11: more[3] <= min2;
        endcase
    end
end

assign min3 = (more[3][8:0] > 'd239)? more[3][8:0] - 'd240 : {1'b1, more[3][7:0]};
assign min4 = (min3[7:0] > 'd119)? min3[7:0] - 'd120 : {1'b1, min3[6:0]};
assign min5 = (min4[6:0] > 'd59)? min4[6:0] - 'd60 : {1'b1, min4[5:0]};

assign min_32 = (!min0[11])? 'd32 : 0;
assign min_16 = (!min1[10])? 'd16 : 0;

assign min_8 = (!more[3][9])? 'd8 : 0;
assign min_4 = (!min3[8])? 'd4 : 0;
assign min_2 = (!min4[7])? 'd2 : 0;
assign min_1 = (!min5[6])? 'd1 : 0;

// which_minute
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) which_minute <= 6'b0;
    else begin 
        case(calculation_counter)
            11: which_minute <= min_32 + min_16 ;
            12: which_minute <= which_minute + min_8 + min_4 + min_2 + min_1;
        endcase
    end
end

// which_second
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) which_second <= 6'b0;
    else begin 
        case(calculation_counter)
            12: which_second <= min5[5:0];
        endcase
    end
end

B2BCD_IP #(.WIDTH(11), .DIGIT(4)) IP_year (.Binary_code(which_year), .BCD_code(bcd_year)); // 3
B2BCD_IP #(.WIDTH(4), .DIGIT(2)) IP_month (.Binary_code(which_month), .BCD_code(bcd_month)); // 6
B2BCD_IP #(.WIDTH(5), .DIGIT(2)) IP_day (.Binary_code(which_day), .BCD_code(bcd_day)); // 7
B2BCD_IP #(.WIDTH(5), .DIGIT(2)) IP_hour (.Binary_code(which_hour), .BCD_code(bcd_hour)); // 8
B2BCD_IP #(.WIDTH(6), .DIGIT(2)) IP_minute (.Binary_code(which_minute), .BCD_code(bcd_minute)); // 10
B2BCD_IP #(.WIDTH(6), .DIGIT(2)) IP_second (.Binary_code(which_second), .BCD_code(bcd_second)); // 11

assign ans[0] = bcd_year[15:12];
assign ans[1] = bcd_year[11:8];
assign ans[2] = bcd_year[7:4];
assign ans[3] = bcd_year[3:0];
assign ans[4] = bcd_month[7:4];
assign ans[5] = bcd_month[3:0];
assign ans[6] = bcd_day[7:4];
assign ans[7] = bcd_day[3:0];
assign ans[8] = bcd_hour[7:4];
assign ans[9] = bcd_hour[3:0];
assign ans[10] = bcd_minute[7:4];
assign ans[11] = bcd_minute[3:0];
assign ans[12] = bcd_second[7:4];
assign ans[13] = bcd_second[3:0];

////////////// weekday ///////////////

assign week_0 = (timestamp > 'd1238630399)? timestamp - 'd1238630400 : timestamp;
assign week_1 = (week_0 > 'd619315199)? week_0 - 'd619315200 : week_0;
assign week_2 = (week_1 > 'd309657599)? week_1 - 'd309657600 : week_1;
assign week_3 = (week_2 > 'd154828799)? week_2 - 'd154828800 : week_2;
assign week_4 = (week_3 > 'd77414399)? week_3 - 'd77414400 : week_3;
// more4
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[4] <= 32'b0;
    else begin 
        case(calculation_counter)
            1: more[4] <= week_4;
        endcase
    end
end
assign week_5 = (more[4] > 'd38707199)? more[4] - 'd38707200 : more[4];
assign week_6 = (week_5 > 'd19353599)? week_5 - 'd19353600 : week_5;
assign week_7 = (week_6 > 'd9676799)? week_6 - 'd9676800 : week_6;
assign week_8 = (week_7 > 'd4838399)? week_7 - 'd4838400 : week_7;
assign week_9 = (week_8 > 'd2419199)? week_8 - 'd2419200 : week_8;

// more5
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) more[5] <= 32'b0;
    else begin 
        case(calculation_counter)
            2: more[5] <= week_9;
        endcase
    end
end

assign week_10 = (more[5] > 'd1209599)? more[5] - 'd1209600 : more[5];
assign week_11 = (week_10 > 'd604799)? week_10 - 'd604800 : week_10;
/*
// week_stamp
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) week_stamp <= 31'b0;
    else begin 
        case(calculation_counter)
            2: week_stamp <= week[11];
        endcase
    end    
end
*/
assign wday0 = (week_11 > 'd345599)? week_11 - 'd345600 : {1'b1, week_11[18:0]};
assign wday1 = (wday0[18:0] > 'd172799)? {1'b0, wday0[18:0] - 'd172800} : {1'b1, wday0[17:0]};
assign wday2 = (wday1[17:0] > 'd86399)? {1'b0, wday1[17:0] - 'd86400} : {1'b1, wday1[16:0]};

assign wday_4 = (!wday0[19])? 'd4 : 0;
assign wday_2 = (!wday1[18])? 'd2 : 0;
assign wday_1 = (!wday2[17])? 'd1 : 0;

assign which_weekday = (!wday0[19] || (!wday1[18] & !wday2[17]))? wday_4 + wday_2 + wday_1 - 3 : wday_4 + wday_2 + wday_1 + 4; 

////////////// OUTPUT ///////////////

// out_counter
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_counter <= 4'd0;
    else begin 
        case(n_state)
            OUTPUT: out_counter <= out_counter + 4'd1;
            default: out_counter <= 4'd0;
        endcase
    end
end

// out_valid
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_valid <= 1'b0;
    else begin 
        case(n_state)
            OUTPUT: out_valid <= 1'b1;
            default: out_valid <= 1'b0;
        endcase
    end
end

// out_display
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_display <= 4'd0;
    else begin 
        case(n_state)
            OUTPUT: out_display <= ans[out_counter];
            default: out_display <= 4'd0;
        endcase
    end
end

// out_day
always@(posedge clk or negedge rst_n) begin 
    if(!rst_n) out_day <= 3'd0;
    else begin 
        case(n_state)
            OUTPUT: out_day <= which_weekday;
            default: out_day <= 3'd0;
        endcase
    end
end

endmodule
