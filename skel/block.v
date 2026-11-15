

// breakable block -- works with the scanned collision bus
//
// The block watches the ball's perimeter scan: if the
// ball's scanner touches this block (i.e. the ball is adjacent to it),
// the block breaks on the next move pulse -- the same pulse on which the
// ball bounces off it.

module block #(parameter xloc        = 120,
               parameter yloc        = 100,
               parameter xsize_div_2 = 20,
               parameter ysize_div_2 = 10)
   (
    input       clk,         // 100 MHz system clock
    input       pixpulse,    // every 4 clocks for 25MHz pixel rate
    input       rst,
    // Paint ports (raster)
    input [9:0] hcount,
    input [9:0] vcount,
    // Collision ports (shared scan bus)
    input [9:0] hcount_col,
    input [9:0] vcount_col,
    input       probe,       // the ball's scanner currently owns the bus
    input       move,        // one-cycle pulse: update the status of the block
    input       frame_start, // one-pixpulse pulse at start of vblank
    input       unbreak,     // reset the block
    output      draw_block,     // paint this pixel as block
    output      draw_block_col, // is the block at the collision scan coords?
    output reg  broken          // is this block broken
    );

   reg hit;        // ball's scanner touched us since the last move
   reg disp_broken; // broken, latched once per frame for painting

   assign draw_block = (hcount <= xloc+xsize_div_2) & (hcount >= xloc-xsize_div_2) &
                       (vcount <= yloc+ysize_div_2) & (vcount >= yloc-ysize_div_2) & ~disp_broken;

   assign draw_block_col = (hcount_col <= xloc+xsize_div_2) & (hcount_col >= xloc-xsize_div_2) &
                           (vcount_col <= yloc+ysize_div_2) & (vcount_col >= yloc-ysize_div_2) & ~broken;

   always @(posedge clk or posedge rst) begin
      if (rst) begin
         broken      <= 1'b0;
         hit         <= 1'b0;
         disp_broken <= 1'b0;
      end else if (pixpulse) begin
         if (frame_start)
           disp_broken <= broken;

         if (move) begin
            if (hit)
              broken <= 1'b1;
            hit <= 1'b0;
         end else if (probe & draw_block_col) begin
            hit <= 1'b1;
         end

         if (unbreak) begin
            broken <= 1'b0;
            hit    <= 1'b0;
         end
      end
   end

endmodule
