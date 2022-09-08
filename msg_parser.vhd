LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;


entity msg_parser is
    generic (
        MAX_MSG_BYTES : integer := 32
    );
    port (
        s_tready   : out std_logic;
        s_tvalid   : in std_logic;
        s_tlast    : in std_logic;
        s_tdata    : in std_logic_vector(63 downto 0);
        s_tkeep    : in std_logic_vector(7 downto 0);
        s_tuser    : in std_logic;                                      -- Used as an error input signal, valid on tlast

        msg_valid  : out std_logic;                                     -- High for one clock to output a message
        msg_length : out std_logic_vector(15 downto 0);                 -- Length of the message
        msg_data   : out std_logic_vector(8*MAX_MSG_BYTES-1 downto 0);  -- Data with the LSB on [0]
        msg_error  : out std_logic;                                     -- Output if issue with the message

        clk        : in std_logic;
        rst        : in std_logic
    );
end entity;


architecture rtl_msg_parser of msg_parser is 


    -------------------------------
    -- Stage 0 (sync with input) --
    -------------------------------
    signal s_tready_i                 : std_logic;
    signal sop                        : std_logic;                                       -- start of packet 
    signal msg_length_s0              : std_logic_vector(15 downto 0);
    signal msg_count_s0               : std_logic_vector(15 downto 0);
    signal consumed_bytes             : integer range 0 to MAX_MSG_BYTES;                -- number of msg data bytes since beginning of the message
    signal avail_data_bytes           : integer range 0 to 2*8;                          -- number of available msg data bytes (no msg count and no msg length bytes)
    signal leftover_bytes             : integer range 0 to 2*8;                          -- number of leftover bytes from last word of previous message 
	signal s_tdata_max_msg_bytes      : std_logic_vector(8*MAX_MSG_BYTES+32-1 downto 0); -- MSB is 64 bits input data and rest is 0s

    -------------
    -- Stage 1 --
    -------------
    signal s_tdata_buff               : std_logic_vector(63 downto 0);                    -- buffer last word of message
	signal s_tdata_buff_max_msg_bytes : std_logic_vector(8*MAX_MSG_BYTES+32-1 downto 0);
    signal avail_data                 : std_logic_vector(8*MAX_MSG_BYTES-1 downto 0);     -- store available msg data
    signal calc_msg_length            : std_logic;                                        -- trigger the calculation of msg length 
    signal msg_count_s1               : std_logic_vector(15 downto 0);
    signal msg_length_s1              : std_logic_vector(15 downto 0);
    signal consumed_bytes_s1          : integer range 0 to MAX_MSG_BYTES;
    signal pkt_count                  : unsigned(31 downto 0);
    signal pkt_length                 : unsigned(31 downto 0);

	 -------------
    -- Stage 2 --
    -------------
	 signal msg_data_s2               : std_logic_vector(8*MAX_MSG_BYTES-1 downto 0);
	 signal msg_valid_s2              : std_logic;
	 signal msg_length_s2             : std_logic_vector(15 downto 0);

begin

    s_tready         <= s_tready_i;

    msg_count_s0     <=      s_tdata(15 downto 0) when sop = '1'
                        else msg_count_s1;
                 
    msg_length_s0    <=      s_tdata(31 downto 16)                                                     when sop = '1'
                        else s_tdata(15 downto 0)                                                      when calc_msg_length = '1' and leftover_bytes = 0
                        else s_tdata(7 downto 0) & s_tdata_buff(63 downto 63 - 8 + 1)                  when calc_msg_length = '1' and leftover_bytes = 1
                        else s_tdata_buff(63 - 8*leftover_bytes + 16 downto 63 - 8*leftover_bytes + 1) when calc_msg_length = '1' and leftover_bytes > 1
                        else msg_length_s1;

    
    -- current available data bytes number (no msg length and no msg count info)
    avail_data_bytes <=      4                                                    when sop = '1'
                        else 6 + leftover_bytes                                   when calc_msg_length = '1' and unsigned(msg_length_s0) > 6 + leftover_bytes -- 8 bytes + leftover bytes - 2 bytes of msg length
                        else to_integer(unsigned(msg_length_s0))                  when calc_msg_length = '1'
                        else 8                                                    when unsigned(msg_length_s0) - consumed_bytes > 8
                        else to_integer(unsigned(msg_length_s0)) - consumed_bytes;

    -- output signals
    process (clk) is
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                msg_valid_s2 <= '0';
                msg_length_s2 <= (others => '0');
                msg_data_s2 <= (others => '0');
            else

                msg_valid_s2 <= '0';
                if calc_msg_length = '1' and s_tready_i = '0' then
                    msg_valid_s2 <= '1';
                end if;
                msg_length_s2 <= msg_length_s1;

                -- reset msg_data for new message
                if calc_msg_length = '1' and s_tready_i = '1'then
                    msg_data_s2 <= (others => '0');
                -- shift avail_data by number of already consumed bytes and OR it with previous value of msg data
                else
                    msg_data_s2 <= msg_data_s2 or std_logic_vector(shift_left(unsigned(avail_data), 8*consumed_bytes_s1));
                end if;
			end if;
        end if;
    end process;
	msg_data <= msg_data_s2;
	msg_valid <= msg_valid_s2;
	msg_length <= msg_length_s2;
       
	-- main process
    process (clk) is
    begin 
        if rising_edge(clk) then
            if (rst = '1') then
                sop <= '1'; 
                s_tready_i <= '0';
                calc_msg_length <= '0';
                consumed_bytes <= 0;
                leftover_bytes <= 0;
                avail_data <= (others => '0');
            else
            
                -- ready only drops one cycle after reading last word of message
                if s_tready_i = '0' then
                    s_tready_i <= '1';
                end if;
                
                if s_tvalid = '1' and s_tready_i = '1' then
                
                    -- detect start of packets
                    if s_tlast = '1' then
                        sop <= '1';
                    else
                        sop <= '0';
                    end if;
                        
                    msg_count_s1 <= msg_count_s0;
                    msg_length_s1 <= msg_length_s0;

                    consumed_bytes <= consumed_bytes + avail_data_bytes;

                    -- sync with avail_data to calculate msg_data
                    consumed_bytes_s1 <= consumed_bytes;

                    leftover_bytes <= 0;
                    calc_msg_length <= '0';

					-- last word reached
                    if unsigned(msg_length_s0) = consumed_bytes + avail_data_bytes then
						-- also last word of packet
                        if s_tlast = '1' then
                            leftover_bytes <= 0;
						-- not last message of packet
                        else
							-- buffer last word of message and calculate leftover bytes to be used in next message
                            s_tdata_buff <= s_tdata;
                            if leftover_bytes = 0 then
                                leftover_bytes <= 8 - avail_data_bytes;
                            else
                                leftover_bytes <= 8 + leftover_bytes - avail_data_bytes - 2;
                            end if;
                        end if;
                        calc_msg_length <= '1';
                        consumed_bytes <= 0;
                        s_tready_i <= '0';
                    end if;
                    
                    -- Fill avail_data with current available message data only (no msg count nor msg length), byte per byte starting from LSB
                    avail_data <= (others => '0');
                    for I in 1 to MAX_MSG_BYTES loop
                        -- Stop when all available bytes have been written
                        if I <= avail_data_bytes then
                            -- At start of packet, 4 MSB bytes are available
                            if sop = '1' then
                                avail_data(8*I-1 downto 8*(I-1)) <= s_tdata_max_msg_bytes(8*I+32-1 downto 8*(I-1)+32);
                            -- Same message
                            elsif calc_msg_length = '0' then
                                avail_data(8*I-1 downto 8*(I-1)) <= s_tdata_max_msg_bytes(8*I-1 downto 8*(I-1));
                            -- Next message
                            else
                                -- No extra bytes from previous word (2 LSB bytes are not data)
                                if leftover_bytes = 0 then
                                    avail_data(8*I-1 downto 8*(I-1)) <= s_tdata_max_msg_bytes(8*I+16-1 downto 8*(I-1)+16);
                                -- 1 extra byte from previous word (1 LSB byte is not data)
                                elsif leftover_bytes = 1 then
                                    avail_data(8*I-1 downto 8*(I-1)) <= s_tdata_max_msg_bytes(8*I+8-1 downto 8*(I-1)+8);
                                -- Extra bytes from previous word have full msg length info and 0 or more data bytes
                                else
                                    -- data from extra bytes without msg length
                                    if I <= (leftover_bytes-2) then
                                        avail_data(8*I-1 downto 8*(I-1)) <= s_tdata_buff_max_msg_bytes(63 + 8*I - 8*(leftover_bytes-2) downto 63 + 8*(I-1) - 8*(leftover_bytes-2) + 1);
                                    -- data bytes from current word
                                    else
                                        avail_data(8*I-1 downto 8*(I-1)) <= s_tdata_max_msg_bytes(8*(I-(leftover_bytes-2))-1 downto 8*(I-1-(leftover_bytes-2)));
                                    end if;
                                end if;    
                            end if;
                        end if;
                    end loop;

                end if;
            end if;
        end if;
    end process;
	
	-- LSB is input data
	s_tdata_max_msg_bytes(63 downto 0) <= s_tdata; 
	s_tdata_max_msg_bytes (MAX_MSG_BYTES*8-1 downto 64) <= (others => '0');
	-- LSB is buffered input data
    s_tdata_buff_max_msg_bytes(63 downto 0) <= s_tdata_buff; 
	s_tdata_buff_max_msg_bytes(MAX_MSG_BYTES*8-1 downto 64) <= (others => '0');

    -- asserts
    process (clk) is
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                pkt_count <= (others => '0');
				pkt_length <= (others => '0');
            else

                -- packet counter
                if s_tready_i = '1' and s_tvalid = '1' then
                    if sop = '1' then
                        pkt_count <= pkt_count + 1;
                        pkt_length <= pkt_length + 8;
                    end if;
                    if s_tlast = '1' then
                        pkt_length <= (others => '0');
                    end if;
                end if;

                if msg_valid_s2 = '1' then
                    assert (unsigned(msg_length_s2) >= 8)
                    report "> ERROR : message length is lower than 8"
                    severity failure;

                    assert (unsigned(msg_length_s2) <= 32) 
                    report "> ERROR : message length is greater than 32"
                    severity failure;
                end if;

                if s_tvalid = '1' and s_tready = '1' then
                    if s_tlast = '1' then
                        assert shift_left(to_unsigned(1, 8), avail_data_bytes) /= unsigned(s_tkeep)
                        report "> ERROR: mismatch between available data bytes and s_tkeep"
                        severity failure;
                    end if;
                end if;

                assert pkt_length <= 1500
                report "> ERROR: packet length greater than 1500 bytes"
                severity note;
            end if;
        end if;
    end process;
    
    
end architecture rtl_msg_parser;
    
