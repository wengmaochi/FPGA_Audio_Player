`timescale 1ns/100ps

`include "I2cInitializer.sv"
module tb_I2c_Init;
    /*
    This tb act as WM8731, which should be the receiver of I2cInitializer.
    */
    /////======= localparam =======/////
    localparam  CLK = 10;
    localparam  HCLK = CLK/2;

    localparam start = 2'b00;
    localparam blue = 2'b01;
    localparam green = 2'b10;
    localparam acknowledge = 2'b11;

    /////======= logics & integers =======/////
    logic   i_rst_n;
	logic   clk;
	logic   i_start;
	logic   o_finished;
	logic   o_sclk; //SCL
    wire   o_sdat; //SDA
    reg   a;
    logic   o_oen; 
    logic [1:0]state;

    assign o_sdat = o_oen ? 1'bz : a;

    integer i, j, counter;

    logic [23:0] data[6:0]; 
    initial begin
        data[0]  <= 24'b0011_0100_000_1111_0_0000_0000;
        data[1]  <= 24'b0011_0100_000_0100_0_0001_0101;
        data[2]  <= 24'b0011_0100_000_0101_0_0000_0000;
        data[3]  <= 24'b0011_0100_000_0110_0_0000_0000;
        data[4]  <= 24'b0011_0100_000_0111_0_0100_0010;
        data[5]  <= 24'b0011_0100_000_1000_0_0001_1001;
        data[6]  <= 24'b0011_0100_000_1001_0_0000_0001;
    end

    logic [23:0] i_data[6:0]; 
    initial begin
        i_data[0]  <= 24'b0000_0000_000_0000_0_0000_0000;
        i_data[1]  <= 24'b0000_0000_000_0000_0_0000_0000;
        i_data[2]  <= 24'b0000_0000_000_0000_0_0000_0000;
        i_data[3]  <= 24'b0000_0000_000_0000_0_0000_0000;
        i_data[4]  <= 24'b0000_0000_000_0000_0_0000_0000;
        i_data[5]  <= 24'b0000_0000_000_0000_0_0000_0000;
        i_data[6]  <= 24'b0000_0000_000_0000_0_0000_0000;
    end
    

    /////======= clk setting =======/////
    initial clk = 0;
    always #HCLK clk = ~clk;
    

    /////======= module instantiation =======/////
    I2cInitializer i2c0(
       .i_rst_n(i_rst_n),
        .i_clk(clk),
        .i_start(i_start),
        .o_finished(o_finished),
        .o_sclk(o_sclk),
        .o_sdat(o_sdat),
        .o_oen(o_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
    );

    /////======= input setting =======/////
    initial begin
        #0 i_rst_n = 1'b1;
        #(HCLK) i_rst_n = 1'b0;
        #(2*HCLK) i_rst_n = 1'b1;
    end

    initial begin
        #0 i_start = 1'b0;
        #(7*HCLK) i_start = 1'b0;
        #(8*HCLK) i_start = 1'b1;
    end

    /////======= input setting =======/////
    initial begin
        $fsdbDumpfile("tb_I2cInit.fsdb");
        $fsdbDumpvars;
        // fp_input = $fopen("./test_input_recoder.dat","rb")

        #0 i = 0; j = 0; counter = 0; a = 1; state = 0;
        $display("Tb Start");
        #(8*HCLK);

        @(posedge o_finished) #10;
        $display("Tb end.");
        $finish;
    
    end


    initial begin
        #(2000*HCLK)
        $finish;
    end
endmodule