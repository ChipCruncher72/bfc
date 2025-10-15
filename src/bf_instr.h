/*
Copyright 2025 ChipCruncher72

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
#ifndef _BF_INSTR_
#define _BF_INSTR_

#ifndef __cplusplus
#include <stdio.h>
#include <stddef.h>

#define STD_PREFIX(value) value
#define _init_bf(N) int main(void){byte tape[N]={0};size_t ptr=0;
#else
#include <cstdio>
#include <cstddef>

#define STD_PREFIX(value) std::value
#define _init_bf(N) int main(){byte tape[N]={0};std::size_t ptr=0;
#endif

#define _end_bf() return 0;}
#define _incr_tape() tape[ptr]++;
#define _decr_tape() tape[ptr]--;
#define _incr_ptr() ptr=(ptr==TAPE_LENGTH-1)?0:ptr+1;
#define _decr_ptr() ptr=(ptr==0)?TAPE_LENGTH-1:ptr-1;
#define _begin_loop() while(tape[ptr]) {
#define _end_loop() }
#define _write() ((void)STD_PREFIX(fputc(tape[ptr],stdout)));
#define _read() {int tmp;tape[ptr]=((tmp=STD_PREFIX(fgetc(stdin)))!=EOF)?((byte)tmp):tape[ptr];}

#define TAPE_LENGTH sizeof(tape)
typedef unsigned char byte;

#endif

/* End of MIT licensed code */

