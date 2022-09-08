-- msg_parser testbench 
-- read msg_parser input from "scenario.in"
-- write msg_parser output to "scenario.out"

library ieee;
library std;
library work;
use std.textio.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity testbench is
end entity testbench;

architecture tb of testbench is

constant MAX_MSG_BYTES : integer := 32;
constant RATIO : integer := 80; -- valid ratio

component msg_parser is
  generic (
	MAX_MSG_BYTES : integer := 32
  );
  port (
  s_tready : out std_logic;
  s_tvalid : in std_logic;
  s_tlast : in std_logic;
  s_tdata : in std_logic_vector(63 downto 0);
  s_tkeep : in std_logic_vector(7 downto 0);
  s_tuser : in std_logic; 		
  msg_valid : out std_logic;    	
  msg_length : out std_logic_vector(15 downto 0);  				
  msg_data : out std_logic_vector(8*MAX_MSG_BYTES-1 downto 0);   
  msg_error : out std_logic;   									 

  clk : in std_logic;
  rst : in std_logic
  );
end component;

signal clk : std_logic;
signal rst : std_logic;

-- input data from file
signal s_tvalid_i : std_logic;
signal s_tlast_i : std_logic;
signal s_terror_i : std_logic;
signal s_tdata_i : std_logic_vector(63 downto 0);
signal s_tkeep_i : std_logic_vector(7 downto 0);

-- input interface
signal s_tready : std_logic;
signal s_tvalid : std_logic;
signal s_tlast : std_logic;
signal s_terror : std_logic;
signal s_tdata : std_logic_vector(63 downto 0);
signal s_tkeep : std_logic_vector(7 downto 0);

-- output interface
signal msg_valid : std_logic;
signal msg_length : std_logic_vector(15 downto 0);
signal msg_data : std_logic_vector(8*MAX_MSG_BYTES-1 downto 0);

signal stop : boolean; -- stop simu

begin

  -- msg_parser inst
  DUT : msg_parser
  port map(
    s_tready => s_tready,
    s_tvalid => s_tvalid,
    s_tlast  => s_tlast,
    s_tdata  => s_tdata,
    s_tkeep  => s_tkeep,
    s_tuser  => '0',

    msg_valid  => msg_valid,
    msg_length => msg_length,
    msg_data   => msg_data,
    msg_error  => open,  					

    clk => clk,
    rst => rst
  );

  -- clock and reset
  process
  begin
    while not stop loop
      clk <= '0';
      wait for 0.5 ns;
      clk <= '1';
      wait for 0.5 ns;
    end loop;
    wait;
  end process;
  rst <= '1', '0' after 2 ns;
  
  -- clock input signals
  process (clk)
  begin
  	if rising_edge(clk) then
    	s_tvalid <= s_tvalid_i;
    	s_tdata <= s_tdata_i;
    	s_tkeep <= s_tkeep_i;
    	s_tlast <= s_tlast_i;
    end if;
  end process;
    	
  -- Read input file "scenario.in"
  -- "valid+ +last+ +data+ +keep+ +error"
  process is
    variable line_v : line;
    file read_file : text;
    variable valid_v : std_logic;
    variable last_v : std_logic;
    variable data_v : std_logic_vector(63 downto 0);
    variable keep_v : std_logic_vector(7 downto 0);
    variable error_v : std_logic;
	variable seed1 : positive;
	variable seed2 : positive;
	variable rand : real;

  begin
    file_open(read_file, "./scenario.in", read_mode);
    wait for 3.5 ns;
    while not endfile(read_file) loop
		if s_tready = '1' then
			uniform(seed1, seed2, rand);
			if integer(trunc(rand*100.0)) < RATIO then
				readline(read_file, line_v);
				read(line_v, valid_v);
				read(line_v, last_v);
				hread(line_v, data_v);
				hread(line_v, keep_v);
				read(line_v, error_v);
				report "data_v = " & to_hstring(data_v) & ", last_v = " & to_string(last_v);
				s_tvalid_i <= valid_v;
				s_tlast_i <= last_v;
				s_tdata_i <= data_v;
				s_tkeep_i <= keep_v;
				s_terror_i <= error_v;
			-- drop valid RATIO% of the time
			else
				s_tvalid_i <= '0';
			end if;
		end if;
		wait for 1 ns;
    end loop;
    assert false report "Test done." severity note;
    wait for 5 ns;
	stop <= TRUE;
    wait for 1 ns;
    file_close(read_file);
    wait; 
  end process;

  -- Write msg_parser output to "scenario.out"
  -- "msg_data+msg_length"
  process (clk) is
    variable line_v : line;
    file write_file : text open write_mode is "./scenario.out";
  begin
	if rising_edge(clk) then
    	if msg_valid = '1' then
            hwrite(line_v, msg_data, left, MAX_MSG_BYTES*2);
            hwrite(line_v, msg_length, left, 4);            
            report "write: " & to_string(line_v.all);

      		writeline(write_file, line_v);

        end if;
    end if;
    if stop = TRUE then
    	file_close(write_file);
    end if;
  end process;

end tb;
