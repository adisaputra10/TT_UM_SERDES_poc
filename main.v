// Penjumlah 4-bit
// Menjumlahkan dua angka 4-bit.
// a dan b adalah angka input, hasil adalah jawaban.

module penjumlah_4bit (
  input  [3:0] a,   // Angka pertama (0–15)
  input  [3:0] b,   // Angka kedua (0–15)
  output [4:0] hasil  // Jawaban (5-bit, karena 15+15=30 butuh 5 bit)
);

  assign hasil = a + c;

endmodule
