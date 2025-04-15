

// 3 digit score module, 8x8 pixel digits

module score #(parameter xloc=40,
	      parameter yloc=40)
   (
    input	clk, // 100 MHz system clock
    input	pixpulse, // every 4 clocks for 25MHz pixel rate
    input	rst,
    input [9:0]	hcount, // x-location where we are drawing
    input [9:0]	vcount, // y-location where we are drawing
    input [7:0]	score,
    output	draw_score 
    );

   reg [2:0]	row;
   reg [3:0]	digit;
   wire [11:0]	score_bcd;
   
   (*rom_style = "block" *) reg [7:0] chr_pix;
   
   always @(posedge clk)
     begin
	case ({1'b0,digit,row})  // each digit is 8 rows, 8 bits each row
	  8'h00: chr_pix <= 8'b00000000;
	  8'h01: chr_pix <= 8'b00111100;
	  8'h02: chr_pix <= 8'b01000010;
	  8'h03: chr_pix <= 8'b01000010;
	  8'h04: chr_pix <= 8'b01000010;
	  8'h05: chr_pix <= 8'b01000010;
	  8'h06: chr_pix <= 8'b01000010;
	  8'h07: chr_pix <= 8'b00111100;
	  8'h08: chr_pix <= 8'b00000000;
	  8'h09: chr_pix <= 8'b00110000;
	  8'h0a: chr_pix <= 8'b01010000;
	  8'h0b: chr_pix <= 8'b00010000;
	  8'h0c: chr_pix <= 8'b00010000;
	  8'h0d: chr_pix <= 8'b00010000;
	  8'h0e: chr_pix <= 8'b00010000;
	  8'h0f: chr_pix <= 8'b01111100;
	  
	  // fill in the values for the rest of the numbers
	  
	endcase // case ({digit,row})
     end
	  
   assign draw_score_100 = ;  // when we are in the 100's digit region, use chr_pix[?] to draw the pixels
   
   assign draw_score_10 = ;  // when we are in the 10's digit region, use chr_pix[?] to draw the pixels
		       
   assign draw_score_1 = ; // when we are in the 1's digit region, use chr_pix[?] to draw the pixels

   assign draw_score = draw_score_100 | draw_score_10 | draw_score_1;  // draw all of the score pixels

   doubdab_8bits udd (.b_in (score), .bcd_out (score_bcd));

   // hcount goes from 0=left to 640=right
   // vcount goes from 0=top to 480=bottom
   always @(posedge clk or posedge rst)
     begin
	if (rst) begin
	   digit <= 0;
	   row <= 0;
	end else if (pixpulse) begin  // only make changes when pixpulse is high
	      if (vcount >= yloc-7 && vcount <= yloc) begin
	      // update row and digit as we scan through the region that has the score
		 row <= 7 - (yloc - vcount); 
		 if (hcount == xloc)
		   digit <= score_bcd[11:8]; // when we reach xloc, set the digit to the 100's place
		 else if (hcount == xloc + 8)
		   digit <= score_bcd[7:4]; // when we reach xloc+8, set the digit to the 10's place
		 else if (hcount == xloc + 16)
		   digit <= score_bcd[3:0]; // when we reach xloc+16, set the digit to the 1's place
	      end
	end
     end	      
   
endmodule // score
