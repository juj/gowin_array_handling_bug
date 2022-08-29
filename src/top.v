module top(
  input clk,
  output [3:0] hdmi_tx_n, // HDMI output pins: ch0, ch1, ch2 and clock
  output [3:0] hdmi_tx_p
);

  wire hdmi_clk;      // 25.2MHz. (HDMI pixel clock for 640x480@60Hz would ideally be 25.175MHz)
  wire hdmi_clk_5x;   // 126MHz. 5x pixel clock for 10:1 DDR serialization
  wire hdmi_clk_lock; // true when PLL lock has been established

  PLLVR #(
    .FCLKIN("27"),
    .FBDIV_SEL(13), .IDIV_SEL(2), .ODIV_SEL(8) // 126MHz:       640x480@60Hz
  )hdmi_pll(/*unused pins:*/.CLKOUTP(), .CLKOUTD(), .CLKOUTD3(), .RESET(1'b0), .RESET_P(1'b0), .CLKFB(1'b0), .FBDSEL(6'b0), .IDSEL(6'b0), .ODSEL(6'b0), .PSDA(4'b0), .DUTYDA(4'b0), .FDLY(4'b0),
    .VREN(1'b1),
    .CLKIN(clk),
    .CLKOUT(hdmi_clk_5x),
    .LOCK(hdmi_clk_lock)
  );

  CLKDIV #(.DIV_MODE("5"), .GSREN("false")) hdmi_clock_div(.CLKOUT(hdmi_clk), .HCLKIN(hdmi_clk_5x), .RESETN(hdmi_clk_lock), .CALIB(1'b1));

  wire signed [12:0] x;        // horizontal and vertical screen position (signed), -4096 - +4095
  wire signed [11:0] y;        // horizontal and vertical screen position (signed), -2048 - +2047
  wire [2:0] hve_sync;         // pack the image sync signals to one vector: { display enable, vsync, hsync }

  // Generate a display sync signal on top of the HDMI pixel clock.
  display_signal ds(
    .i_pixel_clk(hdmi_clk),
    .o_hvesync(hve_sync),
    .o_x(x),
    .o_y(y)
  );

  reg [7:0] font[256*16];
  initial begin
    $readmemb("font.txt", font);
  end

  // divide screen pixel resolution up to a text grid, text_x/y give the text coordinate
  wire [6:0] text_x = x[9:3];

  // inside a specific text character, read which pixel of the text font to access.
  wire [2:0] font_x = x[2:0];
  wire [3:0] font_y = y[3:0];

  reg color;

  // Print "Hello, world!" text:
  // BUG? The following prints out garbage:

  // String // "Hello, world!"
  wire [7:0] text_string[13] = { 8'h48, 8'h65, 8'h6C, 8'h6C, 8'h6F, 8'h2C, 8'h20, 8'h77, 8'h6F, 8'h72, 8'h6C, 8'h64, 8'h21 };
  always @(posedge hdmi_clk) begin
    color <= font[{text_string[text_x],font_y}][font_x];
  end

/*
  // But oddly, the bug can be worked around with:
  // String "Hello, world!" but with each ASCII char subtracted by one to accommodate for bug workaround
  wire [7:0] text_string[13] = { 8'h47, 8'h64, 8'h6B, 8'h6B, 8'h6E, 8'h2B, 8'h1F, 8'h76, 8'h6E, 8'h71, 8'h6B, 8'h63, 8'h20 };
  always @(posedge hdmi_clk) begin
    color <= font[{text_string[text_x]+1,font_y}][font_x]; // Note the silly +1 to the ASCII char value
  end
*/

  // Produce HDMI output
  hdmi hdmi_out(
    .hdmi_clk(hdmi_clk),
    .hdmi_clk_5x(hdmi_clk_5x),
    .reset(~hdmi_clk_lock),
    .hve_sync(hve_sync),
    .rgb({24{color}}),
    .hdmi_tx_n(hdmi_tx_n),
    .hdmi_tx_p(hdmi_tx_p));
endmodule
