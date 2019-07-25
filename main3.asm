:BasicUpstart2(main)

// Default location: $0400-$07E7  1024 - 2023
// The screen consits of 25 rows with 40 columns each => 1000 positions
// Each position is 8 bits wide, value 0-255
// 1000 postions * 8 bits = 8000 bits to fill screen
.const SCREEN_MEM = $0400 // Default: $04, $0400, 1024
.const COLOR_MEM = $d800
.const FILL_CHAR = 160 // $A0, 1010.0000 (char with all bits set)

// OLD WAY => .pc = $1000 "Main Program"
* = $1000 "Main Program"
main:

//-----------------------------------
// fill screen with char
//-----------------------------------
// Wasting 5000 bytes of program code mem to fill screen
// .for(var i=0; i<1000; i++){
//     lda #FILL_CHAR     // lda #$A0  => (2 bytes) a9 a0      (immediate) 1000 times => 2000 bytes
//     sta SCREEN_MEM + i // sta $0400 => (3 bytes) 8d $00 $04 (absolute)  1000 times => 3000 bytes
// }

// optimization do lda only once waisting only 3002 bytes
// Need to choose between mem usage and execution speed
// This is actually the fastest way to fill screen with chars
// lda #FILL_CHAR // lda #$A0  => (2 bytes) a9 a0 (immediate) 1 time => 2 bytes
// .for(var i=0; i<1000; i++){
//     // sta $0400 => (3 bytes) 8d $00 $04 (absolute)  1000 times => 3000 byte
//     sta SCREEN_MEM + i
// }

//-----------------------------------
// Fill color mem that chars use 
//-----------------------------------
// =============
// = First try =
// =============
//This code use 6000 bytes... ouch
// .for(var i=0; i<1000; i++){
//     lda image + i
//     sta COLOR_MEM + i
// }

// ==============
// = Second try =
// ==============
// // Optimization using indexed mode (we want to loop over 1000 positions)
// // x,y reg => 8 bit registers, max value 255
// // ldx #45 // (Immidiate) => a2 2d (45 <=> 0010.1101 <=> $2d)
//     ldy #0
// loopOuterY:
//     ldx #0 // (Immidiate) => a2 2d (45 <=> 0000.0000 <=> $00)
// loopInnerX:
// lda_start:
//     // Indexed Mode - Absolute,X
//     // contents of X should be added to address "image" to give the effective address
//     // lda $4000, $2d => $bd $00 $40 => (3 bytes)
//     lda image, X
// sta_start:
//     // Indexed Mode - Absolute,X
//     // contents of X should be added to address "COLOR_MEM" to give the effective address
//     // sta $d800, $2d => $9d $00 $d8 => (3 bytes)
//     sta COLOR_MEM, X
//     // INX (INcrement X) $E8 => (1 byte)
//     // obs x start at 45... max value can be 255... 
//     // so cmp 253 on next line will be reached quite fast...
//     inx
//     // Immediate CMP #253 => c9 fd => (2 bytes)
//     // Immediate CPX #253 => e0 fd => (2 bytes)
//     // Immediate CPY #253 => c0 fd => (2 bytes)
//     //cpx #253   // 1111.1101 <=> fd <=> 253
//     cpx #250     // 1111.1010 <=> fa <=> 250
//     // BNE (Branch on Not Equal) relative mode => $d0 $loopx-address
//     bne loopInnerX // => d0 .. => (2 bytes)
    
//     // MAKE USE OF SELF MODYFING CODE TO LOOP OVER ALL POSITIONS !!!!
//     // add_words_imm (a_word, b_word, result)
//     //                a_word => address in memory where the first  word begins
//     //                b_word => address in memory where the second word begins
//     // label "lda_start" => address for where first byte of instruction "lda image, X" takes place
//     // "lda"     => $bd => One byte identifier
//     // "$00 $40" => 2 byte adress (16 bits aka word) => where to load data from
//     :add_words_imm(lda_start + 1, 250, lda_start + 1)
//     // lda_start + 1 => $00 $40 => value $4000 that is where our image data is stored
//     // add 250 to value $4000 = 16384 + 250 = 16635 = $40fa 
//     // store value $40fa at adress "lda_start + 1" 
//     // that is our next laap in our loop starts with a new address $40fa... where new image data is
//     // THEN Do the same for COLOR_MEM
//     :add_words_imm(sta_start + 1, 250, sta_start + 1)

//     iny
//     cpy #4
//     bne loopOuterY

// end:
//     jmp end

// =============
// = Third try =
// =============
//----------------------------------
// Above used self modyfing code, 
// we cant do that if code is for ex
// inside a cartridge in static mem.
//----------------------------------
//     ldx #0 // (Immidiate) => a2 2d (45 <=> 0000.0000 <=> $00)
// loopX:
//     // Repeat instructions 4 times
//     // // first 250
//     // lda image, X
//     // sta COLOR_MEM, X

//     // // next 250
//     // lda image + 250, X
//     // sta COLOR_MEM + 250, X

//     // // next 250
//     // lda image + 500, X
//     // sta COLOR_MEM + 500, X
    
//     // // next 250
//     // lda image + 750, X
//     // sta COLOR_MEM + 750, X

//     // OR WE CAN DO META PROGRAMMING IN Kickassembler
//     // which will create that code for us
//     .for(var i=0; i<4; i++) {
//         lda image + i*250, X
//         sta COLOR_MEM +i*250, X
//     }

//     // INX (INcrement X) $E8 => (1 byte)
//     // obs X max value can be 255... 
//     inx
//     // Immediate CMP #253 => c9 fd => (2 bytes)
//     // Immediate CPX #253 => e0 fd => (2 bytes)
//     // Immediate CPY #253 => c0 fd => (2 bytes)
//     cpx #250     // 1111.1010 <=> fa <=> 250
//     // BNE (Branch on Not Equal) relative mode => $d0 $loopx-address
//     bne loopX // => d0 .. => (2 bytes)

// end:
//     jmp end


// ==============
// = Fourth try =
// ==============
//     ldx #0
//     // move lda FILL_CHAR outside loop to save 249 more instructions?
//     // => wont work lda us used in COLOR_MEM for loop...
//     // lda #FILL_CHAR
//     // TRY Y-REG instead of A-REG???? => change to ldy? works but... see sty below...
//     ldy #FILL_CHAR
// loopX:
//     // FILL_CHAR does not change we do not need it in loop
//     // now it will be run 250 times instead of 1000
//     // lda #FILL_CHAR
//     .for(var i=0; i<4; i++) {
//         // lda #FILL_CHAR 
//         // sta SCREEN_MEM +i*250, X
//         // TRY Y-REG ???? => 'sty' doesn't support ABSOLUTEX mode
//         // sty SCREEN_MEM +i*250, X
//         // SOLUTION use tya transfer y to a
//         // "tya" (require 2 machine cycles) is faster than "absolut indexed lda" (require 4+ machine cycles)
//         // so we almost half the amount of machine cycles using tya instead of lda
//         tya
//         sta SCREEN_MEM +i*250, X
//     }

//     .for(var i=0; i<4; i++) {
//         lda image + i*250, X
//         sta COLOR_MEM +i*250, X
//     }

//     inx
//     cpx #250
//     bne loopX

// end:
//     jmp end

// ==============
// = Fifth try = (inverted loop)
// ==============
//     // ldx #0
//     ldx #250 // start at 250 and end at 1 (as 0 finish loop see "dex" set Z flag when x is 0)
//     ldy #FILL_CHAR
// loopX:
//     .for(var i=0; i<4; i++) {
//         tya
//         sta SCREEN_MEM +i*250 - 1, X // fix inverted loop by add - 1
//     }

//     .for(var i=0; i<4; i++) {
//         lda image + i*250 - 1, X // fix inverted loop by add - 1
//         sta COLOR_MEM +i*250 - 1, X // fix inverted loop by add - 1
//     }

//     // inx
//     dex // => set Z flag when x reraaches zero
//     // cpx #250 // cpx will become redundant since dex set x flag when x is 0
//     bne loopX

// end:
//     jmp end

// =============
// = Sixth try = double loops, a bit slower program but more flexible
// =============
    //ldx #250
    ldx #200 // more laps in foor loop required
    // ldy #FILL_CHAR
    lda #FILL_CHAR
loopX_1:
    // .for(var i=0; i<4; i++) {
    //     // tya => we get rid of tya becaause we use lda again
    //     sta SCREEN_MEM +i*250 - 1, X
    // }
    .for(var i=0; i<5; i++) {
        // we will use 5 => sta SCREEN_MEM +i*200 - 1, X
        // => code will require 3 bytes more memory, but it will run faster becuse we get les dex, bne
        // => dex, bne, will be invoked only 200 times instead of 250 when we did ldx #250 =)
        sta SCREEN_MEM +i*200 - 1, X
    }

    // dex and bne rer execuded more times now, double the amount since we use them twice
    dex
    // OBS bne can only jump 127 instructions up/down
    // So if above for loop shoule generaate more thaan 127 bytes of instructions
    // as would be caase if i=100 and i*10 instead of i*200 => bne will not work...
    // we could fix that by using "beq" and absoulute mode "jmp" instruction
    
    bne loopX_1
    // beq end1
    // jmp loopx1
// end1:

    ldx #250
loopX_2:
    .for(var i=0; i<4; i++) {
        lda image + i*250 - 1, X
        sta COLOR_MEM +i*250 - 1, X
    }
    dex
    bne loopX_2
end:
    jmp end

* = $4000 "Data"
image: 
// Colors for each CHAR we should put on screen
//  0=Black,  1=white,  2=red,        3=cyan 
//  4=purple, 5=green,  6=blue,       7=yellow
//  8=orange, 9=brown, 10=light red, 11=dark grey
// 12=grey,  13=light gren
// 14=light blue, 15=light grey 
.byte 14,14,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,14,14
.byte 14,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,9,9,14
.byte 9,9,9,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,9,9,9
.byte 9,9,9,9,9,9,9,9,9,9,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9,1,1,1,1,9,9,9,9,9,9,9,9,9,9,9
.byte 9,9,9,8,8,8,8,8,8,1,1,1,1,1,1,1,1,1,8,8,8,8,8,8,1,1,12,1,1,12,8,8,8,8,8,8,8,9,9,9
.byte 9,9,9,8,8,8,8,8,1,1,12,12,12,12,12,12,1,1,12,8,8,8,8,1,1,12,8,1,1,12,8,8,8,8,8,8,8,9,9,9
.byte 9,9,9,9,9,9,9,9,1,1,11,9,9,9,9,9,9,11,11,9,9,9,1,1,11,9,9,1,1,11,9,9,9,9,9,9,9,9,9,9
.byte 9,9,9,7,7,7,7,7,1,1,15,1,1,1,1,1,1,7,7,7,7,1,1,15,7,7,7,1,1,15,7,7,7,7,7,7,7,9,9,9
.byte 9,9,9,7,7,7,7,7,1,1,1,1,1,1,1,1,1,1,7,7,1,1,15,7,7,7,7,1,1,15,7,7,7,7,7,7,7,9,9,9
.byte 9,9,9,9,9,9,9,9,1,1,11,11,11,11,11,11,1,1,11,9,1,1,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9
.byte 9,9,9,5,5,5,5,5,1,1,12,5,5,5,5,5,1,1,12,5,1,1,1,1,1,1,1,1,1,1,1,12,5,5,5,5,5,9,9,9
.byte 9,9,9,5,5,5,5,5,1,1,1,1,1,1,1,1,1,1,12,5,5,12,12,12,12,12,12,1,1,12,12,12,5,5,5,5,5,9,9,9
.byte 9,9,9,9,9,9,9,9,9,1,1,1,1,1,1,1,1,11,11,9,9,9,9,9,9,9,9,1,1,11,9,9,9,9,9,9,9,9,9,9
.byte 9,9,9,6,6,6,6,6,6,6,12,12,12,12,12,12,12,12,6,6,6,6,6,6,6,6,6,6,12,12,6,6,6,6,6,6,6,9,9,9
.byte 9,9,9,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,9,9,9
.byte 9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
.byte 9,9,9,9,1,9,9,9,9,9,9,9,1,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
.byte 9,9,9,9,1,9,9,9,9,9,9,9,9,9,9,9,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9
.byte 9,9,9,9,1,9,1,1,1,9,9,9,1,9,9,1,1,1,1,1,9,9,9,1,1,1,1,9,9,9,1,1,1,1,1,9,9,9,9,9
.byte 9,9,9,9,1,1,9,9,1,1,9,9,1,1,9,9,1,9,9,9,9,9,1,9,9,9,1,1,9,1,1,9,9,9,9,9,9,9,9,9
.byte 9,9,9,9,1,9,9,9,9,1,9,9,1,1,9,9,1,9,9,9,9,1,1,1,1,1,1,1,9,1,1,1,1,1,1,1,9,9,9,9
.byte 9,9,9,9,1,1,9,9,1,1,9,9,1,1,9,9,1,9,9,1,9,9,1,9,9,9,9,9,9,9,9,9,9,9,1,1,9,9,9,9
.byte 9,9,9,9,1,9,1,1,1,9,9,9,1,1,9,9,1,1,1,1,9,9,9,1,1,1,1,9,9,9,1,1,1,1,1,9,9,9,9,9
.byte 14,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,14
.byte 14,14,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,14,14  

.macro add_words_imm (a_word, b_word, result) {
    .var bytes = 2
    clc
    .for(var byteNbr = 0; byteNbr < bytes; byteNbr++){
        lda a_word + byteNbr
        adc #extract_byte(b_word, byteNbr)
        sta result + byteNbr
    }           
}

// dword safe
.function extract_byte(value, byteNbr) {
    .if(byteNbr < 0) .error "byteNbr cannot be negative"
    .var nbrOfBitsToShiftToRight = byteNbr * 8
    //---------
    // 2nd byte
    //---------
    // Shift value 8 bits to the right filling in with 0s from left...
    //                       ex value =  11223344
    //                       11        22        33        44
    //                       0001 0001 0010 0010 0011 0011 0100 0100         44
    // shift right 8 bits => 0000 0000 0001 0001 0010 0010 0011 0011 (cut of 0100 0100)
    .eval value = value >> nbrOfBitsToShiftToRight
    //---------
    // LSB
    //---------
    // zero out part that is NOT LSB
    // ex value =  11223344
    //             11        22        33        44
    //             0001 0001 0010 0010 0011 0011 0100 0100
    //         AND 0000 0000 0000 0000 0000 0000 1111 1111 (255 dec)
    //         -------------------------------------------
    //             0000 0000 0000 0000 0000 0000 0100 0100 => $44 => 68 decimal
   .return value & 255
}