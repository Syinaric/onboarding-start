## How it works

This project implements an SPI-controlled PWM peripheral. It receives SPI transactions (Mode 0, 16 cycles per transaction) to write to 5 registers that control output enables and PWM settings across 16 output pins. The PWM signal runs at ~3 kHz derived from a 10 MHz clock.

## How to test

Send SPI transactions using SCLK (ui[0]), COPI (ui[1]), and nCS (ui[2]).
Write to the following registers:
- 0x00: Enable outputs on uo_out[7:0]
- 0x01: Enable outputs on uio_out[7:0]
- 0x02: Enable PWM on uo_out[7:0]
- 0x03: Enable PWM on uio_out[7:0]
- 0x04: Set PWM duty cycle (0x00=0%, 0xFF=100%)

## External hardware

None required.