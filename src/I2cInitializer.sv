// `include "I2C.sv"

module I2cInitializer (
	input   i_rst_n,
	        i_clk,
	        i_start,
	output  o_finished,
	        o_sclk, //SCL
	inout   o_sdat, //SDA
   output  o_oen // you are outputing (you are not outputing only when you are "ack"ing.)
	// output  [2:0] o_state

);

logic [ 2:0] state_r, state_w;
logic [ 2:0] counter_r, counter_w; 
logic        sdat_r,  sdat_w;
logic        sclk_r, sclk_w;
logic [23:0] setting_data_r, setting_data_w;
logic        oen_r, oen_w;
logic [ 3:0] cnt_r, cnt_w; 
logic [ 1:0] byte_counter_r, byte_counter_w;
logic        fin_r, fin_w;


// FSM States
localparam Start = 3'b000;
localparam Data_Set = 3'b001;
localparam Data_Transfer = 3'b010;
localparam Transfer_Send = 3'b011;
localparam Acknowledge = 3'b100;
localparam Pause_Transfer = 3'b101;
localparam EoT = 3'b110;

// 7 DATA State
localparam Reset = 3'b000;
localparam AAPC = 3'b001;
localparam DAPC = 3'b010;
localparam PDC = 3'b011;
localparam DAIF = 3'b100;
localparam SC = 3'b101;
localparam AC = 3'b110;


// 7 Settings
localparam Setting_Reset = 24'b0011_0100_000_1111_0_0000_0000;
localparam Setting_AAPC  = 24'b0011_0100_000_0100_0_0001_0101;
localparam Setting_DAPC  = 24'b0011_0100_000_0101_0_0000_0000;
localparam Setting_PDC   = 24'b0011_0100_000_0110_0_0000_0000;
localparam Setting_DAIF  = 24'b0011_0100_000_0111_0_0100_0010;
localparam Setting_SC    = 24'b0011_0100_000_1000_0_0001_1001;
localparam Setting_AC    = 24'b0011_0100_000_1001_0_0000_0001;

//I2C
// I2C i0(
// 	.i_rst_n(i_rst_n),
// 	.i_clk(i_clk),
// 	.i_start(start_r),
//     .i_setting(setting_data_r),
// 	.o_finished(i2c_fin),
// 	.o_sclk(sclk_w),
// 	.o_sdat(o_sdat_pre),
// 	.o_oen(oen_w) // you are outputing (you are not outputing only when you are "ack"ing.)
// );

assign o_oen = oen_r;
assign o_sdat = o_oen ? sdat_r : 1'bz;
assign o_sclk = sclk_r;
assign o_finished = fin_r;
// assign o_state = state_r;

always_comb begin
    oen_w = oen_r;
    counter_w = counter_r;
    state_w = state_r;
    sdat_w = sdat_r;
    sclk_w = sclk_r;
    setting_data_w = setting_data_r;
    cnt_w = cnt_r;
    byte_counter_w =  byte_counter_r;
    fin_w = fin_r;


    case(state_r)
        Start: begin
            if(i_start) begin
                sdat_w = 0;
                sclk_w = 1;
                counter_w = 0;
                state_w = Data_Set;
                $display("Start");
            end 
            else begin
                sdat_w = 1;
                sclk_w = 1;
                oen_w = 1;
                state_w = Start;
                $display("WAIT.....");
            end
        end 
        Data_Set: begin  //input : SDA == 1; SCL == 1;
            $display("Data_Set");
            if(counter_r < 3'b111) begin
                case(counter_r)
                    Reset : setting_data_w = Setting_Reset;
                    AAPC : setting_data_w = Setting_AAPC;
                    DAPC : setting_data_w = Setting_DAPC;
                    PDC : setting_data_w = Setting_PDC;
                    DAIF : setting_data_w = Setting_DAIF;
                    SC : setting_data_w = Setting_SC;
                    AC : setting_data_w = Setting_AC;
                    default : setting_data_w = 24'b0;
                endcase
                state_w = Acknowledge;
                cnt_w = 0;
                byte_counter_w = 2'b00;
                sclk_w = 1;
                sdat_w = 0;
            end
            else begin
                counter_w = 3'b000;
                byte_counter_w = 2'b00;
                cnt_w = 0;
                sdat_w = 0;
                sclk_w = 1;
                //oen_w = 1;
                state_w = EoT;
            end
            
        end

        Data_Transfer: begin   // Blue
            $display("Data_Transfer");
            if(cnt_r < 4'b1000) begin
                oen_w = 1;
                sclk_w = 0;
                sdat_w = setting_data_r[23 - byte_counter_r * 8 - cnt_r];
                state_w = Transfer_Send;
            end
            else begin
                cnt_w = 4'b0000;
                byte_counter_w = byte_counter_r + 1;
                oen_w = 0;
                sclk_w = 0;
                sdat_w = 0;
                state_w = Acknowledge;
            end
            counter_w = counter_r;
        end


        Transfer_Send: begin  // Green
            sclk_w = 1;
            cnt_w = cnt_r + 1'b1;
            state_w = Data_Transfer;
        end

        Acknowledge: begin
             //$display("Acknowledge");
            if(byte_counter_r == 2'b00) begin
                //cnt_w = 4'b0000;
                sclk_w = 1;
                oen_w = 1;
                state_w = Data_Transfer;
            end
            else if(byte_counter_r == 2'b01 ) begin // && o_sdat == 1'b0
                //cnt_w = 4'b0000;
                sclk_w = 1;
                oen_w = 1;
                state_w = Data_Transfer;
            end
            else if(byte_counter_r == 2'b10 ) begin // && o_sdat == 1'b0
                //cnt_w = 4'b0000;
                sclk_w = 1;
                oen_w = 1;
                state_w = Data_Transfer;
            end
            else if(byte_counter_r == 2'b11 ) begin // && o_sdat == 1'b0
                //cnt_w = 4'b0000;
                sclk_w = 1;
                sdat_w = 0;
                oen_w = 1;
                counter_w = counter_r + 1;
                state_w = Pause_Transfer;
            end
            else begin
                state_w = Acknowledge;
                sclk_w = 1;
            end
        end

        Pause_Transfer: begin
            sdat_w = 1;
            sclk_w = 1;
            state_w = Data_Set;
        end

        EoT: begin
            sdat_w = 1;
            sclk_w = 1;
            oen_w = 1;
            //state_w = Start;
            fin_w = 1;
        end
    endcase
end

always_ff @( posedge i_clk , negedge i_rst_n) begin
    if(!i_rst_n) begin
        counter_r <= 3'b000;
        state_r <= Start;
        sdat_r <= 1'b1;
        sclk_r <= 1'b1;
        setting_data_r <= 24'b0;
        oen_r <= 0;
        cnt_r <= 0;
        byte_counter_r <= 0;
        fin_r <= 0;
    end
    else begin
        counter_r <= counter_w;
        state_r <= state_w;
        sdat_r <= sdat_w;
        sclk_r <= sclk_w;
        setting_data_r <= setting_data_w;
        oen_r <= oen_w;
        cnt_r <= cnt_w;
        byte_counter_r <= byte_counter_w;
        fin_r <= fin_w;
    end
    
end

endmodule