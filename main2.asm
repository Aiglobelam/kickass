/***********************************/
// Extensions => cmd + shift + x
// cmd + shift + p => kick...
// Build => cmd + shift + b
/***********************************/
BasicUpstart2(main)
    // Store code here in memory
    // The old notation ('.pc=$1000') from Kick Assembler 2.x and 3.x is still supported
    // 4000 dec = 16384 hex
    * = $4000 "Main Program"

.const BORDER_REGISTER = $d020
.const BACKGROUND_REGISTER = $d021

// mainOLD:
//     lda #1      // Immediate LDA => A9 #value  => a9 01
//     setBackgroundColor(7)   
//     setBorderColor(8)   
//     rts         // return to invoker           => 60

main:

// 8 bit
player_kills_first_monster:
    :player_kills_monster()

test_score_is_awarded_after_killing_first_monster:
    :assert_bytes_equal(score_after_killing_first_monster, score)

player_kills_second_monster:
    :player_kills_monster()

test_score_is_awarded_after_killing_second_monster:
    :assert_bytes_equal(score_after_killing_second_monster, score)

// 16 bit
player_kills_first_monster_16:
    :player_kills_monster_16()

test_score_is_awarded_after_killing_first_monster_16:
    :assert_bytes_equal(score_after_killing_first_monster_16, score_16)

player_kills_second_monster_16:
    :player_kills_monster_16()

test_score_is_awarded_after_killing_second_monster_16:
    :assert_words_equal(score_after_killing_second_monster_16, score_16)

//------------------
// Test logic engine
//------------------
test_result_render:
    lda test_result
    sta BORDER_REGISTER
    rts

test_result_fail:
    lda #2 //RED
    sta test_result
    jmp test_result_render

test_result:
    .byte GREEN //5=green

//---------
// MACROS
//---------

// .macro player_kills_monster_16 () {
//     clc
    
//     lda score_16
//     adc monster_kill_score_16
//     sta score_16

//     lda score_16+1
//     adc monster_kill_score_16+1
//     sta score_16+1
// }
// .macro player_kills_monster_16 () {
//     clc

//     .var byteNbr = 0
//     lda score_16 + byteNbr
//     adc monster_kill_score_16 + byteNbr
//     sta score_16 + byteNbr

//     .eval byteNbr = byteNbr + 1
//     lda score_16 + byteNbr
//     adc monster_kill_score_16 + byteNbr
//     sta score_16 + byteNbr
// }
// .macro player_kills_monster_16 () {
//     clc

//     .var byteNbr = 0
//     :add_bytes_with_offset(byteNbr, score_16, monster_kill_score_16, score_16)

//     .eval byteNbr = byteNbr + 1
//     :add_bytes_with_offset(byteNbr, score_16, monster_kill_score_16, score_16)
// }

.macro player_kills_monster () {
    // clc
    // lda score
    // adc monster_kill_score
    // sta score
    :add_integer(8, score, monster_kill_score, score)
}

.macro player_kills_monster_16 () {
    //clc
    // .for(var byteNbr = 0; byteNbr < 2; byteNbr = byteNbr + 1 ){
    //     :add_bytes_with_offset(byteNbr, score_16, monster_kill_score_16, score_16)
    // }
    :add_integer(16, score_16, monster_kill_score_16, score_16)
}

.macro add_bytes_with_offset (offset, a, b, result) {
    lda a + offset
    adc b + offset
    sta result + offset
}

.macro add_integer (bitsPrecision, a, b, result) {
    //.var nbrOfBytes = bitsPrecision / 8
    .var nbrOfBytes = bits_to_bytes(bitsPrecision)
    clc
    .for(var byteNbr = 0; byteNbr < nbrOfBytes; byteNbr = byteNbr + 1){
        :add_bytes_with_offset(byteNbr, a, b, result)
    }
}

.macro assert_bytes_equal (expected, actual) {
    // lda actual
    // cmp expected
    // bne test_result_fail
    assert_integers_equal(8, expected, actual)
}
     
.macro assert_words_equal (expected, actual) {
    // lda actual
    // cmp expected
    // bne test_result_fail

    // lda actual +1
    // cmp expected +1
    // bne test_result_fail
    assert_integers_equal(16, expected, actual)
}

.macro assert_integers_equal(bitsPrecision, expected, actual) {
    //.var nbrOfBytes = bitsPrecision / 8
    .var nbrOfBytes = bits_to_bytes(bitsPrecision)
    .for(var byteNbr = 0; byteNbr < nbrOfBytes; byteNbr = byteNbr + 1){
        lda actual + byteNbr
        cmp expected + byteNbr
        bne test_result_fail
    }   
}

// compile time meta programing (this will not be a jump to this code instruction)
.function bits_to_bytes(bits) {
    .return bits / 8
}

.macro add_words_abs (a, b, result) {
    .var bytes = 2
    clc
    .for(var byte = 0; byte < bytes; byte = byte + 1){
        lda a + byte
        adc b + byte
        sta result + byte
    }         
}


.macro add_words_imm (a, b, result) {
    .var bytes = 2
    clc
    .for(var byteNbr = 0; byteNbr < bytes; byteNbr++){
        lda a + byteNbr
        adc #extract_byte(b, byteNbr)
        sta result + byteNbr
    }           
}

.assert "add_words_imm generates actual code", {
    // actual code
    :add_words_imm($1000, $1122, $2000)
}, {
    // expected code
    clc // $18

    lda $1000 // LDA absolute  => ad 00 10
    //adc $22 // ADC zero page => 65 22
    adc #$22  // ADC immediate => 69 22
    sta $2000 // STA absolute  => 8d 00 20

    lda $1001 // LDA absolute  => ad 01 10
    //adc $11 // ADC zero page => 65 11
    adc #$11  // ADC immediate => 69 11
    sta $2001 // STA absolute  => 8d 01 20
}

.asserterror "add_words_imm does not accept string as first arg", {
    :add_words_imm("$1234", $1234, $2000)
}

.function extract_byte_OLD(value, byteNbr) {
    // kickass script built in extraction operators operate only on 16 bit
    .if (byteNbr == 0)
        .return <value // MSB
    else
        .return >value // LSB
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
    //                       0001 0001 0010 0010 0011 0011 0100 0100
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

.assert "extract_byte($1122, 0) extract LSB($22/0010.0010/34)", extract_byte($1122, 0), $22
.assert "extract_byte($1122, 1) extract MSB($11/0001.0001/17)", extract_byte($1122, 1), $11

.assert "extract_byte($11223344, 0) extract dword       LSB($44/68)", extract_byte($11223344, 0), $44
.assert "extract_byte($11223344, 1) extract dword 2nd byte ($33/51)", extract_byte($11223344, 1), $33
.assert "extract_byte($11223344, 2) extract dword 3rd byte ($22/34)", extract_byte($11223344, 2), $22
.assert "extract_byte($11223344, 3) extract dword      MSB ($11/17)", extract_byte($11223344, 3), $11

.asserterror "extract_byte does not accept string as first arg (value)", extract_byte("$1122", 0) 
.asserterror "extract_byte does not accept neg nbr as second arg (byteNbr) ", extract_byte($1122, -1) 
//---------------------
// more tests
//---------------------
// :assert_words_equal(word_a, word_b)
// :assert_words_equal(word_b, word_c)
// :assert_words_equal(word_c, word_a)

:assert_words_equal(word_a, word_a)
:assert_words_equal(word_b, word_b)
:assert_words_equal(word_c, word_c)

// hmm these can't be above code...!?


//--------------
// 8 bits
//--------------
monster_kill_score:
    .byte $01 // 0000 0001 = 1 dec

score:
    .byte $11 // 0001 0001 = 17 dec

score_after_killing_first_monster:
    .byte $12

score_after_killing_second_monster:
    .byte $13

//--------------
// 16 bits
//--------------
monster_kill_score_16:
    .word $0001

score_16:
    .word $1122 // 0001.0001.0010.0100 4386

score_after_killing_first_monster_16:
    .word $1122 + $01 // score_16 + monster_kill_score

score_after_killing_second_monster_16:
    .word $1122 + $0002

word_a:
    .word $1111 // 0001.0001.0001.0001 4369
     
word_b:
    .word $2211 // 0010.0010.0001.0001 8721
     
word_c:
    .word $1122 // 0001.0001.0010.0100 4386

/** MACRO
 * param: color
 * value: 1 - 15
 *  0=Black,  1=white,  2=red,        3=cyan 
 *  4=purple, 5=green,  6=blue,       7=yellow
 *  8=orange, 9=brown, 10=light red, 11=dark grey
 * 12=grey,  13=light gren
 * 14=light blue, 15=light grey 
 */
// .macro setBackgroundColor (color) {
//     lda #color
//     sta BACKGROUND_REGISTER // Absolute  STA => 8D address => 8d 21 d0
// }

// .macro setBorderColor (color) {
//     lda #color
//     sta BORDER_REGISTER     // Absolute  STA => 8D address => 8d 20 d0
// }