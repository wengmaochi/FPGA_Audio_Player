module Top (
	input i_rst_n,
	input i_clk,
	input i_key_0, // start/stop
	input i_key_1, // pause/resume
	input i_key_2, // speed
	input [3:0] i_speed, // SW[3:0]
	input i_slow_0,   //SW[4]
	input i_slow_1,   //SW[5]
	input i_fast,     //SW[6]
	input i_reverse, //SW[7]
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK, //inout
	inout  i_AUD_BCLK,    //inout 
	inout  i_AUD_DACLRCK, //inou
	output o_AUD_DACDAT,

	// SEVENDECODER (optional display)
	// output [5:0] o_record_time,
	// output [5:0] o_play_time,
	output [5:0] o_state,
	output [5:0] debugg,
	output [5:0] debug_left,
	output [5:0] debug_right,
	// LCD (optional display)
	input        i_clk_800k
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON,

	// LED
	// output  [8:0] o_ledg,
	// output [17:0] o_ledr
);

// design the FSM and states as you like
parameter S_IDLE       = 0;
parameter S_I2C        = 1;
parameter S_RECD       = 2;
parameter S_RECD_PAUSE = 3;
parameter S_PLAY       = 4;
parameter S_PLAY_PAUSE = 5;
parameter S_Ready = 6;
parameter clk_limit = 26'd12_000_000;
parameter num_limit = 6'd32;
logic i2c_oen;
wire i2c_sdat;
logic [19:0] addr_record, addr_play;
logic [15:0] data_record, data_play, dac_data;
logic [2:0] state_w, state_r; 
logic [26-1:0] rec_counter_w, rec_counter_r;
logic [6-1:0] rec_num_w, rec_num_r;
logic i2c_finish_w, i2c_finish_r;
logic start_rec_w, start_rec_r;
logic start_play_w, start_play_r;
logic start_init_w, start_init_r;
logic pause_rec_w, pause_rec_r;
logic stop_rec_w, stop_rec_r;
logic pause_play_w, pause_play_r;
logic stop_play_w, stop_play_r;
logic [19:0] sram_final_pos_w, sram_final_pos_r;

logic [5:0] play_num;
logic [2:0] state_test ;
logic [1:0] debgg;
logic bit21 ;
// assign debugg = {3'd0, state_test};


assign debug_left = {2'd0,i_speed} + 6'd1; // 00 __ __ __ 

// assign debugg = {1'b0, dac_data[15:11]}; // __ 00 __ __ 

assign debugg = play_num;

assign debug_right = rec_num_r; // __ __ 00 __ 

assign o_state = {3'b0,state_r};  // __ __ __ 00


assign play_num = {1'b0,addr_play[19:15]};
//test
logic player_en ;
assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

assign o_SRAM_ADDR = (state_r == S_RECD) ? addr_record : addr_play[19:0];
assign io_SRAM_DQ  = (state_r == S_RECD) ? data_record : 16'dz; // sram_dq as output
assign data_play   = (state_r != S_RECD) ? io_SRAM_DQ : 16'd0; // sram_dq as input

assign o_SRAM_WE_N = (state_r == S_RECD) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;
 

// below is a simple example for module division
// you can design these as you like

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(start_init_r),
	.o_finished(i2c_finish_w),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen), // you are outputing (you are not outputing only when you are "ack"ing.)
	// .o_state()
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n(i_rst_n),
	.i_clk(i_AUD_BCLK),
	.i_start(start_play_r),
	.i_pause(pause_play_r),
	.i_stop(stop_play_r),
	.i_reverse(i_reverse),
	.i_fast(i_fast),
	.i_slow_0(i_slow_0), // constant interpolation
	.i_slow_1(i_slow_1), // linear interpolation
	.i_daclrck(i_AUD_DACLRCK),
	.i_speed_scale(i_speed),
	.i_sram_data(data_play),
	.i_end_addr(sram_final_pos_r),
	.o_player_en(player_en),
	.o_dac_data(dac_data),
	.o_sram_addr(addr_play),
	.o_rev_finish(rev_finish),

	.o_state(state_test),
	.o_bit21(bit21)
);

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n(i_rst_n),
	.i_bclk(i_AUD_BCLK),
	.i_daclrck(i_AUD_DACLRCK),
	.i_en(player_en), // enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data(dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM

AudRecorder recorder0(
	.i_rst_n(i_rst_n), 
	.i_clk(i_AUD_BCLK),
	.i_lrc(i_AUD_ADCLRCK),
	.i_start(start_rec_r),
	.i_pause(pause_rec_r),
	.i_stop(stop_rec_r),
	.i_data(i_AUD_ADCDAT),
	.o_address(addr_record),
	.o_data(data_record),
	.o_debug_state(debgg)
);

always_comb begin
	// design your control here
	state_w = state_r;
	rec_counter_w = rec_counter_r;
	rec_num_w = rec_num_r;
	start_play_w = start_play_r;
	start_rec_w = start_rec_r;
	start_init_w = start_init_r;
	stop_rec_w = stop_rec_r;
	stop_play_w = 0 ;
	pause_play_w = pause_play_r;
	pause_rec_w = pause_rec_r;
	sram_final_pos_w = sram_final_pos_r;
	case(state_r)

		S_IDLE : begin //0
			rec_counter_w = 0;
			rec_num_w = 0;
			if( i_key_0 ) begin
				start_init_w = (i2c_finish_r) ? 0 : 1;
				state_w = (i2c_finish_r) ? S_RECD : S_I2C;
				start_rec_w = (i2c_finish_r) ? 1 : 0;
			end
			else begin
				start_init_w = 0;
				state_w = state_r;
				start_rec_w = 0;
			end

		end

		S_I2C : begin //1
			state_w = state_r;
			start_init_w = start_init_r;
			if(i2c_finish_r) begin
				state_w = S_IDLE;
				start_init_w = 0;
			end
		end

		S_RECD : begin //2
			start_rec_w = 1;
			stop_rec_w = 0;
			sram_final_pos_w = addr_record;
			if(i_key_1) begin       //pause
				state_w = S_RECD_PAUSE;
				rec_counter_w = rec_counter_r;
				rec_num_w = rec_num_r;
				pause_rec_w = 1;
			end
			else if(i_key_0 || addr_record == 20'hfffff) begin   //stop
				stop_rec_w = 1;
				state_w = S_Ready;
				rec_counter_w = rec_counter_r;
				rec_num_w = rec_num_r;
				pause_rec_w = 0;
			end
			else if(rec_counter_r == clk_limit) begin
				state_w = state_r;
				rec_counter_w = 26'd0;
				rec_num_w = rec_num_r + 6'd1;
				pause_rec_w = 0;
			end
			else begin
				state_w = state_r;
				rec_counter_w = rec_counter_r + 26'd1;
				rec_num_w = rec_num_r;
				pause_rec_w = 0;
			end
		end
		S_RECD_PAUSE : begin //3
			start_rec_w = 1;
			stop_rec_w = 0;
			sram_final_pos_w = addr_record;
			if(i_key_1) begin //resume
				state_w = S_RECD;
				rec_counter_w = rec_counter_r;
				rec_num_w = rec_num_r;
				pause_rec_w = 1;
			end
			else if(i_key_0) begin //stop
				stop_rec_w = 1;
				state_w = S_Ready;
				rec_counter_w = rec_counter_r;
				rec_num_w = rec_num_r;
				pause_rec_w = 0;
			end
			else begin
				state_w = state_r;
				rec_counter_w = rec_counter_r;
				rec_num_w = rec_num_r;
				pause_rec_w = 0;
			end
		end

		S_Ready : begin //6
			start_rec_w = 0;
			if(i_key_0) begin
				state_w = S_PLAY;
				start_play_w = 1;
			end
			else if(i_key_2) begin
				state_w = S_IDLE;
				start_rec_w = 1;
			end
			else begin
				start_rec_w = 0;
				state_w = state_r;
				start_play_w = 0;
				stop_play_w = 1 ;
			end
		end

		S_PLAY : begin //4
			rec_num_w = rec_num_r;
			start_play_w = 0;
			pause_play_w = 0;
			state_w = state_r;
			if(i_key_0 || addr_play >= sram_final_pos_r || rev_finish ) begin //STOP, jump to  ready
				state_w = S_Ready;
				stop_play_w = 1 ;
			end
			else if(i_key_1) begin
				pause_play_w = 1;
				state_w = S_PLAY_PAUSE;
			end
			// else if( { 1'b0, addr_play } >= 21'b0_0000_1000_0000_0000_0000 * { 15'b0, ( play_num_r + 6'd1 ) }  ) begin
			// 	state_w = state_r;
			// end
			else begin
				state_w = state_r;
			end
		end

		S_PLAY_PAUSE : begin //5
			state_w = state_r;
			if(i_key_0) begin //stop
				stop_play_w = 1 ;
				pause_play_w = 0;
				state_w = S_Ready;
			end
			else if(i_key_1) begin //resume
				pause_play_w = 0;
				state_w = S_PLAY;
			end
			else begin
				pause_play_w = 1;
				state_w = state_r;
			end
		end

	default : begin
		rec_counter_w  = 0;
		rec_num_w  = 0;
		start_play_w = 0;
		start_rec_w = 0;
		start_init_w = 0;
		stop_rec_w = 0;
		stop_play_w = 0;
		pause_play_w = 0;
		pause_rec_w = 0;
		sram_final_pos_w = 0;
		state_w = S_IDLE;
	end

	endcase	

end

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		rec_counter_r <= 0;
		rec_num_r <= 0;
		state_r <= S_IDLE;
		i2c_finish_r <= 0;
		start_play_r <= 0;
		start_rec_r <= 0;
		start_init_r <= 0;
		stop_rec_r <= 0;
		stop_play_r <= 0;
		pause_play_r <= 0;
		pause_rec_r <= 0;
		sram_final_pos_r <= 0;
	end
	else begin
		rec_counter_r <= rec_counter_w;
		rec_num_r <= rec_num_w;
		state_r <= state_w;
		i2c_finish_r <= i2c_finish_w;
		start_play_r <= start_play_w;
		start_rec_r <= start_rec_w;
		start_init_r <= start_init_w;
		stop_rec_r <= stop_rec_w;
		stop_play_r <= stop_play_w;
		pause_play_r <= pause_play_w;
		pause_rec_r <= pause_rec_w;
		sram_final_pos_r <= sram_final_pos_w;
	end
end

endmodule