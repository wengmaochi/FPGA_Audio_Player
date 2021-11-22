// send / receive I2C data
module I2C (
    input	i_rst_n,
    input	i_clk,      
    input	i_start,            // control if start
    input   [6:0] i_addr,       // chip address (7 bit)
    input   i_rw,               // chip R/W (1'b0 | 1'b1)
    input   [15:0] i_reg_data,  // chip reg and data (7 + 9 bit)

    output	o_finished,
    output	o_sclk,     // s clock for i2c
    inout	o_sdat,     // data in / out
    output	o_oen       // you are outputing (you are not outputing only when you are "ack"ing.)
);

localparam S_IDLE     = 0;
localparam S_START    = 1;       // a start state for simple delay
localparam S_ADDR     = 2;       // sending slave addr
localparam S_RW       = 3;       // sending R/W
localparam S_REG_DATA_UPPER = 4; // sending register and data bits
localparam S_REG_DATA_LOWER = 5; // sending register and data bits
localparam S_ACK      = 6;       // ack state
localparam S_STOP     = 7;       // stop state

logic [2:0] state_r, state_w;
logic [2:0] prev_state_r, prev_state_w; // previous state for S_ACK to determine where to go next
logic sdat; // data on i2c
logic oen_r, oen_w; // open enable
logic [3:0] counter_r, counter_w; // counter, every 8 bits will jump to ack state and back
logic fin_r, fin_w; // finish

assign o_sclk = (state_r == S_IDLE || state_r == S_START || state_r == S_STOP) ? 1'b1 : ~i_clk; // if not idle, it's the clock, otherwise, should be 1
assign o_oen = oen_r;
assign o_sdat = oen_r ? sdat : 1'bz;
assign o_finished = fin_r;

always_comb begin
    state_w = state_r;
    prev_state_w = prev_state_r;
    oen_w = oen_r;
    counter_w = counter_r;
    fin_w = fin_r;
    sdat = 1'b1;
    case (state_r)
        // idle, not sending or reading from i2c
        S_IDLE: begin
            fin_w = 1'b0;
            sdat = 1'b1;
            if (i_start) begin // pull down o_sdat, pull up oen_r
                state_w = S_START;
                oen_w = 1'b1;
                counter_w = 4'b0;
            end
        end

        S_START: begin
            state_w = S_ADDR;
            sdat = 1'b0;
        end

        // sending address (only 7 bit)
        S_ADDR: begin
            sdat = i_addr[4'd6 - counter_r];
            counter_w = counter_r + 4'b1;
            if (counter_r == 6) state_w = S_RW;
        end

        // sending R/W (only 1 bit) to i2c, will jump to ack
        S_RW: begin
            sdat = i_rw;
            if (counter_r == 7) begin // will always be 7 in this case (S_ADDR send 7 bits)
                state_w = S_ACK;
                prev_state_w = S_RW;
                oen_w = 1'b0; // for ack, output enable is false
            end
        end

        // sending REG and DATA's upper 8 bit
        S_REG_DATA_UPPER: begin
            sdat = i_reg_data[4'd15 - counter_r];
            counter_w = counter_r + 4'b1;
            if (counter_r == 7) begin // go to ack
                state_w = S_ACK;
                prev_state_w = S_REG_DATA_UPPER;
                oen_w = 1'b0;
            end
        end

        // sending REG and DATA's lower 8 bit
        S_REG_DATA_LOWER: begin
            sdat = i_reg_data[4'd7 - counter_r];
            counter_w = counter_r + 4'b1;
            if (counter_r == 7) begin
                state_w = S_ACK;
                prev_state_w = S_REG_DATA_LOWER;
                oen_w = 1'b0;
            end
        end

        // stop, pull sdat from 0 to 1, indicate stop                              
        S_STOP: begin
            sdat = 1'b0; // to stop, make sdat 0 first, will be pulled up by S_STOP
            state_w = S_IDLE;
            fin_w = 1'b1;
        end

        S_ACK: begin
            // TODO: check ACK

            counter_w = 4'b0;
            if (prev_state_r == S_RW) begin
                state_w = S_REG_DATA_UPPER;
                oen_w = 1'b1; // go back to output 
            end
            else if (prev_state_r == S_REG_DATA_UPPER) begin
                state_w = S_REG_DATA_LOWER;
                oen_w = 1'b1;
            end
            else if (prev_state_r == S_REG_DATA_LOWER) begin
                // TODO: Stop, return to IDLE
                state_w = S_STOP;
                oen_w = 1'b1;
            end
        end
    endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        state_r <= S_IDLE;
        prev_state_r <= S_IDLE;
        oen_r <= 1'b1;
        counter_r <= 4'b0;
        fin_r <= 1'b0;
    end
   
    else begin
        state_r <= state_w;
        prev_state_r <= prev_state_w;
        oen_r <= oen_w;
        counter_r <= counter_w;
        fin_r <= fin_w;
    end
end

endmodule