#include <stdio.h>
#include "xil_io.h"
#include "xparameters.h"

// Ganti alamat ini sesuai yang ada di Address Editor Vivado
#define UART_BASE_ADDR 0x44A00000 

int main() {
    print("--- RISC-V UART Test ---\n\r");

    while(1) {
        // 1. Tulis Karakter 'Z' ke UART lewat AXI
        Xil_Out32(UART_BASE_ADDR, 0x5A); // 0x5A = 'Z'
        
        // Kasih delay biar nggak menuhin buffer
        for(int i=0; i<1000000; i++); 

        // 2. Baca status (cek apakah ada data masuk)
        uint32_t status = Xil_In32(UART_BASE_ADDR + 4);
        
        if (!(status & 0x01)) { // Jika RX Empty == 0 (artinya ada data)
            uint32_t data = Xil_In32(UART_BASE_ADDR);
            printf("RISC-V nerima data: %c\n", (char)data);
        }
    }
    return 0;
}