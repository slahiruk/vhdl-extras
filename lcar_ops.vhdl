--------------------------------------------------------------------
--  _    __ __  __ ____   __   =                                  --
-- | |  / // / / // __ \ / /   =                                  --
-- | | / // /_/ // / / // /    =    .__  |/ _/_  .__   .__    __  --
-- | |/ // __  // /_/ // /___  =   /___) |  /   /   ) /   )  (_ ` --
-- |___//_/ /_//_____//_____/  =  (___  /| (_  /     (___(_ (__)  --
--                           =====     /                          --
--                            ===                                 --
-----------------------------  =  ----------------------------------
--# lcar_ops.vhdl - Linear Cellular Automata Registers
--# $Id: lcar_ops.vhdl,v 3e6683f29597 2010/11/23 04:26:40 vhdl $
--# Freely available from VHDL-extras (http://vhdl-extras.org)
--#
--# Copyright � 2010 Kevin Thibedeau
--#
--# Permission is hereby granted, free of charge, to any person obtaining a
--# copy of this software and associated documentation files (the "Software"),
--# to deal in the Software without restriction, including without limitation
--# the rights to use, copy, modify, merge, publish, distribute, sublicense,
--# and/or sell copies of the Software, and to permit persons to whom the
--# Software is furnished to do so, subject to the following conditions:
--#
--# The above copyright notice and this permission notice shall be included in
--# all copies or substantial portions of the Software.
--#
--# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
--# DEALINGS IN THE SOFTWARE.
--#
--# DEPENDENCIES: none
--#
--# DESCRIPTION:
--#  This package provides a component that implements the Wolfram Linear
--#  Cellular Automata Register (LCAR) as described in "Statistical Mechanics
--#  of Cellular Automata", Wolfram 1983. The LCAR implemented in wolfram_lcar
--#  uses rules 90 and 150 for each cell as defined by an input Rule_map where
--#  a '0' indicates rule 90 and '1' indicates rule 150 for the corresponding
--#  cell in the State register.
--#
--#  The LCAR using rules 90 and 150 can produce output equivalent to maximal
--#  length LFSRs but with the advantage of less correlation between bits of
--#  the state register. This makes the LCAR more suitable for pseudo-random
--#  number generation. The predefined LCAR_* constants provide rule maps for
--#  maximal length sequences.
--#
--#  For basic pseudo-random state generation it is sufficient to tie the
--#  Left_in and Right_in inputs to '0'.
--------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package lcar_ops is

  --## Determine the next state of the LCAR defined by the Rule_map
  function next_wolfram_lcar(State, Rule_map : std_ulogic_vector;
    Left_in, Right_in : std_ulogic := '0' ) return std_ulogic_vector;

  --## Lookup a predefined rule set from the table  
  function lcar_rule( Size : positive ) return std_ulogic_vector;
  

  component wolfram_lcar is
    generic (
      RESET_ACTIVE_LEVEL : std_ulogic := '1'
    );
    port (
      Clock  : in std_ulogic;
      Reset  : in std_ulogic; -- Asynchronous reset
      Enable : in std_ulogic; -- Synchronous enable

      Left_in  : in std_ulogic; -- Left side input to LCAR
      Right_in : in std_ulogic; -- Right side input to LCAR

      Rule_map : in std_ulogic_vector; -- Rules for each cell '1' -> 150, '0' -> 90
      State    : out std_ulogic_vector -- The state of each cell
    );
  end component;

end package;


library ieee;
use ieee.std_logic_1164.all;

library extras;
use extras.lcar_ops.next_wolfram_lcar;

entity wolfram_lcar is
  generic (
    RESET_ACTIVE_LEVEL : std_ulogic := '1'
  );
  port (
    Clock  : in std_ulogic;
    Reset  : in std_ulogic; -- Asynchronous reset
    Enable : in std_ulogic; -- Synchronous enable

    Left_in  : in std_ulogic; -- Left side input to LCAR
    Right_in : in std_ulogic; -- Right side input to LCAR

    Rule_map : in std_ulogic_vector; -- Rules for each cell '1' -> 150, '0' -> 90
    State    : out std_ulogic_vector -- The state of each cell
  );
end entity;

architecture rtl of wolfram_lcar is
  signal sr : std_ulogic_vector(1 to State'length);
begin

  process(Clock, Reset) is
  begin
    if Reset = RESET_ACTIVE_LEVEL then
      sr <= (others => '1');
    elsif rising_edge(Clock) then
      if Enable = '1' then
        sr <= next_wolfram_lcar(sr, Rule_map, Left_in, Right_in);
      end if;
    end if;
  end process;

  State <= sr;
end architecture;



package body lcar_ops is

  -- Wolfram LCAR structure:
  --               __     __     __         __
  --   Left_in -->[RC]-->[RC]-->[RC]--...->[RC]
  --              [__]<--[__]<--[__]<-...--[__]<-- Right_in
  --
  --
  --                  <<Rule 150 Cell>>
  --
  --                    .----------<- right neighbor
  --                    |  .-<----.
  --                    |  |      |
  --                    v  v      |
  --   left neighbor ->-X--X--[R]-+-> to neighbors
  --                              |
  --                 <------------'
  --
  --
  --                  <<Rule 90 Cell>>
  --
  --                    .----------<- right neighbor
  --                    |
  --                    v
  --   left neighbor ->-X-----[R]-.-> to neighbors
  --                              |
  --                 <------------'
  --
  --
  --                  <<Rule 150/90 Cell>>
  --
  --                    .----------<- right neighbor
  --                    |  .-<----.
  --                    |  |      *-rm(n)
  --                    v  v      |
  --   left neighbor ->-X--X--[R]-+-> to neighbors
  --                              |
  --                 <------------'
  --
  --   [RC] = Rule x Cell   X = XOR   * = AND   [R] = register state bit   rm(n) = rule_map bit-n


  --## Determine the next state of the LCAR defined by the Rule_map
  function next_wolfram_lcar(State, Rule_map : std_ulogic_vector;
    Left_in, Right_in : std_ulogic := '0' ) return std_ulogic_vector is

    alias sr : std_ulogic_vector(1 to State'length) is State;
    variable fb : std_ulogic_vector(sr'range);
  begin
   fb := sr and Rule_map; -- '1' -> rule 150, '0' -> rule 90
   return (Left_in & sr(1 to sr'high-1)) xor (sr(2 to sr'high) & Right_in) xor fb;
  end function;


  -- Predefined constants corresponding to maximal length cellular automata.
  -- These constants can be used as the Rule_map parameter for an lcar
  -- instance. They will produce a maximal length sequence when Left_in and
  -- Right_in are fixed at '0'.
  -- These are taken from "Tables of linear cellular automata for minimal
  -- weight primitive polynomials of degrees up to 300", Cattel and Muzio,
  -- 1993. They define corresponding CA of primitive polynomials listed in
  -- "Built-in Test for VLSI: Pseudorandom Techniques" Bardell, McAnney, and
  -- Savir 1987. The corresponding LFSR polynomials from [Bardell] are provided
  -- as constants in lfsr_ops.

  -- NOTE: These constants were taken from a PDF that showed signs of being OCR
  -- generated. Many 1's were listed as l's and a 0 was shown as a G. There may
  -- be other latent errors.
  
  -- The rules in the table have been padded out with '-' to make all strings
  -- the same length. Use the lcar_rule(Size) function to index and strip the
  -- don't cares from these predefined rules.

  subtype lcar_table_entry is std_ulogic_vector(1 to 100);
  type lcar_rule_list is array( natural range <> ) of lcar_table_entry;

  constant LCAR_RULE_TABLE : lcar_rule_list(2 to 100) := (
    "10--------------------------------------------------------------------------------------------------", -- 2
    "110-------------------------------------------------------------------------------------------------", -- 3
    "0101------------------------------------------------------------------------------------------------", -- 4
    "01111-----------------------------------------------------------------------------------------------", -- 5
    "000110----------------------------------------------------------------------------------------------", -- 6
    "1011001---------------------------------------------------------------------------------------------", -- 7
    "01001011--------------------------------------------------------------------------------------------", -- 8
    "010011100-------------------------------------------------------------------------------------------", -- 9
    "1111000011------------------------------------------------------------------------------------------", -- 10
    "01000011010-----------------------------------------------------------------------------------------", -- 11
    "100101010011----------------------------------------------------------------------------------------", -- 12
    "0111001110110---------------------------------------------------------------------------------------", -- 13
    "01000111001111--------------------------------------------------------------------------------------", -- 14
    "100000011000001-------------------------------------------------------------------------------------", -- 15
    "0001111001001000------------------------------------------------------------------------------------", -- 16
    "10011000110011001-----------------------------------------------------------------------------------", -- 17
    "110001000000010011----------------------------------------------------------------------------------", -- 18
    "1101011101101001011---------------------------------------------------------------------------------", -- 19
    "01101011100001010110--------------------------------------------------------------------------------", -- 20
    "010010011001010010010-------------------------------------------------------------------------------", -- 21
    "0100011010101101100010------------------------------------------------------------------------------", -- 22
    "01011010101100101011010-----------------------------------------------------------------------------", -- 23
    "110100111100100111001011----------------------------------------------------------------------------", -- 24
    "1010000011111011100000101---------------------------------------------------------------------------", -- 25
    "11001101111101111010110011--------------------------------------------------------------------------", -- 26
    "000110100110001011101011000-------------------------------------------------------------------------", -- 27
    "0101101110000001100111011010------------------------------------------------------------------------", -- 28
    "01001000100101111100100010010-----------------------------------------------------------------------", -- 29
    "101000100111001101101010000101----------------------------------------------------------------------", -- 30
    "1111101101100001100011011011111---------------------------------------------------------------------", -- 31
    "00001100010001110000110000000110--------------------------------------------------------------------", -- 32
    "111001011001000110000100110100111-------------------------------------------------------------------", -- 33
    "1000111110101101001101000011110001------------------------------------------------------------------", -- 34
    "11101000101110011110001110100010111-----------------------------------------------------------------", -- 35
    "010010010001100001011111000010010010----------------------------------------------------------------", -- 36
    "1000100010110100000000110010100010001---------------------------------------------------------------", -- 37
    "11111011011100010000010000111011011111--------------------------------------------------------------", -- 38
    "010101110100111100011111111001011101010-------------------------------------------------------------", -- 39
    "1100110000011000000100010100000100110011------------------------------------------------------------", -- 40
    "01111100100100001011101010000100100111110-----------------------------------------------------------", -- 41
    "111011101111111010101100010101000001110111----------------------------------------------------------", -- 42
    "0011010100010100011001100000010100010101100---------------------------------------------------------", -- 43
    "01110101111100010000011101010110010000101110--------------------------------------------------------", -- 44
    "001110001110111111010011100111111011100011100-------------------------------------------------------", -- 45
    "0111101000001010000001110111001101100001011110------------------------------------------------------", -- 46
    "10010110101010000110110111101100001010101101001-----------------------------------------------------", -- 47
    "010100000001111101000100101101111001111000001010----------------------------------------------------", -- 48
    "1000010000010010101101111011011010100100000100001---------------------------------------------------", -- 49
    "01111110111111111101000010011111011010001101111110--------------------------------------------------", -- 50
    "110001111110101000010000101100101110101011111100011-------------------------------------------------", -- 51
    "0011110000011110100111101101111110010111100000111100------------------------------------------------", -- 52
    "01111100111100100001000000110011011100100111100111110-----------------------------------------------", -- 53
    "100111001111101110101100101100110011010000101010111001----------------------------------------------", -- 54
    "0111101101101110011100110010001111011111011011011011110---------------------------------------------", -- 55
    "10101011011101011111000110101111010101001010111011010101--------------------------------------------", -- 56
    "110100111001011011010110100110001011010110110100111001011-------------------------------------------", -- 57
    "1000110011001110111011000100101100110010110111001100110001------------------------------------------", -- 58
    "01110100000011000100001010010000110111111000011000000101110-----------------------------------------", -- 59
    "111001111010010111010000101111001101000010111010010111100111----------------------------------------", -- 60
    "1010010010111011110100111100100000100101010111101110100100101---------------------------------------", -- 61
    "10110111010110111010110111010111011010110111010110111010110111--------------------------------------", -- 62
    "100000000000000000000000000000011000000000000000000000000000001-------------------------------------", -- 63
    "1001110101001101111011011001100100111001101101111011001010111001------------------------------------", -- 64
    "10000011110010010001111001101111001100101101110001001001111000001-----------------------------------", -- 65
    "001110000110010010101001101000111001011101100101010010011000011100----------------------------------", -- 66
    "0000011001011000010011010101111101100100010101100100001101001100000---------------------------------", -- 67
    "10101100000100001111111101011101101101101010111111110000100000110101--------------------------------", -- 68
    "110000110011100111110111110100110111111001011111011111001110011000011-------------------------------", -- 69
    "0011001111111111110001010001000011000000110100101000111111111111001100------------------------------", -- 70
    "10010110111101100111111000000010111010111000000011111100110111101101001-----------------------------", -- 71
    "101111101110011010101010101011110110000101111100000000001110000001111101----------------------------", -- 72
    "0111111100000011110100010010111101001101011110100100010111100000011111110---------------------------", -- 73
    "01101010011010010101011101000000111011010011110010111010101001011001010110--------------------------", -- 74
    "001010000000010110000000110010110001101110001010011000000011010000000010100-------------------------", -- 75
    "0111100111110100001100111101101110000011110101111111101001000010111110011110------------------------", -- 76
    "11110100001101110101011111011100001110000011110101001101010101110110000101111-----------------------", -- 77
    "100100101101101010100001101101010101111110101101011101100001010101101101001001----------------------", -- 78
    "0111011100100111111111001101101000010101110100001011011001111111110010011101110---------------------", -- 79
    "01010110010000100000101000110011101111011110101011011101111000000100001001101010--------------------", -- 80
    "001000100010010111000011011111011010000010010010110111110110000111010010001000100-------------------", -- 81
    "0100001100100011011111111000011100001010100101010001001100101111101100010011000010------------------", -- 82
    "11011110000000000111111110101101011110011011111111000110110010010000000000001111011-----------------", -- 83
    "110010110110100011010000100100110110011011011110101011001001000010110001011011010011----------------", -- 84
    "1001100100000101011101111110100111101101111011100001001011111111011101010000010011001---------------", -- 85
    "01110100100111101111001010010011100101111101000010000111001001010011110111100100101110--------------", -- 86
    "101001000100011010000101100010111001001100110001100100111010001101000010110001000100101-------------", -- 87
    "0001101101011111110001111011001100100100111001011001000110011110110101000000000001011000------------", -- 88
    "00010101110100010000010001101011001000110011110000111010100101001001000001000101110101000-----------", -- 89
    "100010001110000000100011100010010101100110101011111101011010010001110001000000011100010001----------", -- 90
    "0101000100001111101011101010110011111101100110010000111111111000101101100010111011010101110---------", -- 91
    "01010111100000011000010100000100101000001111100001010100010100100000101000011000000111101010--------", -- 92
    "000010010010010001110001101101011011111111010100110111111110110101101100011100010010010010000-------", -- 93
    "1110110101101110111111001001100111110111110100110101110001011110011001001111110111011010110111------", -- 94
    "01001010010001101011000000000001100111110101010111010101111100110000000000011010110001001010010-----", -- 95
    "111101111011000000100010011011011101011001000110111000110101001100101011100001000000110111101111----", -- 96
    "0011111111001010001101000011100010000001111001010111101111000000100011100001011000101001111111100---", -- 97
    "10111101100100110001111011100110010001101011011010101010010110001001100111011110001100100110111101--", -- 98
    "100011001111010110010110110010110101110101001000001100100101011101011010011011010011010111100110001-", -- 99
    "1111111110010000000111100101111111000110101100111010011111001000011100111010011110000000100111111111"  -- 100
  );


  --## Lookup a predefined rule set from the table
  function lcar_rule( Size : positive ) return std_ulogic_vector is
    variable result : std_ulogic_vector(1 to Size);
  begin
    assert (Size >= LCAR_RULE_TABLE'low) and (Size <= LCAR_RULE_TABLE'high)
      report "Size is out of range for predefined LCAR rules"
      severity failure;
    
    result := LCAR_RULE_TABLE(Size)(1 to Size); -- Slice off all don't-cares
    return result;
  end function;

end package body;
