-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Marek Gergel <xgerge01@stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0);  -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);   -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                     -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                     -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);    -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                       -- data platna
   IN_REQ    : out std_logic;                      -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);   -- zapisovana data
   OUT_BUSY : in std_logic;                        -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                        -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

	-- PC
	signal pc_reg : std_logic_vector (12 downto 0);
	signal pc_inc : std_logic;
	signal pc_dec : std_logic;
	-- PC

	-- PTR
	signal ptr_reg : std_logic_vector (12 downto 0);
	signal ptr_inc : std_logic;
	signal ptr_dec : std_logic;

	signal tmp_reg : std_logic_vector (12 downto 0);
	-- PTR

    -- CNT
	signal cnt_reg : std_logic_vector (12 downto 0);
	signal cnt_inc : std_logic;
	signal cnt_dec : std_logic;
	-- CNT

	-- MX1
	signal mx1_sel : std_logic_vector (0 downto 0) := (others => '0');
	-- MX

  	-- MX2
	signal mx2_sel : std_logic_vector (1 downto 0) := (others => '0');
	signal mx2_out : std_logic_vector (7 downto 0) := (others => '0');
	-- MX

  -- FSM
	type fsm_state_t is (
		state_start,
		state_fetch,
		state_decode,
		
		state_prog_inc,
		state_prog_dec,
		state_mx_inc,
		state_mx_dec,
		state_prog_end_inc,
		state_prog_end_dec,

		state_ptr_inc,
		state_ptr_dec,

		state_while_start,
		state_while_check,
		state_while_end,

		state_do_while_start,
		state_do_while_check,
		state_do_while_end,

		state_write,
		state_write_done,
		state_get,
		state_get_done,

		state_null
	);
	signal state      : fsm_state_t := state_start;
	signal state_next : fsm_state_t := state_start;
	-- FSM

begin

  	-- PC
	pc: process(CLK, RESET, pc_inc, pc_dec) is 
	begin
		if RESET = '1' then
			pc_reg <= (others => '0');
		elsif rising_edge(CLK) then
			if pc_inc = '1' then
				pc_reg <= pc_reg + 1;
			elsif pc_dec = '1' then
				pc_reg <= pc_reg - 1;
			end if;
		end if;
	end process;
	-- PC

  	-- PTR
	ptr: process(CLK, RESET, ptr_inc, ptr_dec) is 
	begin
		if RESET = '1' then
			ptr_reg <= x"1000";
			tmp_reg <= x"1000";
		elsif rising_edge(CLK) then
			if ptr_inc = '1' then
				ptr_reg <= ptr_reg + 1;
			elsif ptr_dec = '1' then
				ptr_reg <= ptr_reg - 1;
			end if;
		end if;
	end process;
	-- PTR

    -- MX1
	mx1: process(CLK, RESET, mx1_sel) is
	begin
		if RESET = '1' then
			DATA_ADDR <= (others => '0');
		elsif rising_edge(CLK) then
			case mx1_sel is
				when "0" => DATA_ADDR <= pc_reg;
				when "1" => DATA_ADDR <= ptr_reg;
			end case;
		end if;
	end process;
	-- MX1

    -- MX2
	mx2: process(CLK, RESET, mx2_sel) is
	begin
		if RESET = '1' then
			mx2_out <= (others => '0');
		elsif rising_edge(CLK) then
			case mx2_sel is
				when "00" => mx2_out <= IN_DATA;
				when "01" => mx2_out <= DATA_RDATA + '1';
				when "10" => mx2_out <= DATA_RDATA - '1';
				when others => mx2_out <= (others => '0'); 
			end case;
		end if;
	end process;
	DATA_WDATA <= mx2_out;
	-- MX2

  -- FSM
	state_logic: process(CLK, RESET, EN) is
	begin
		-- init
		if RESET = '1' then
			state <= state_start;
		elsif rising_edge(CLK) and EN = '1' then
			state <= state_next;
		end if;
	end process;

	fsm: process(state, OUT_BUSY, IN_VLD, DATA_RDATA) is
	begin

		-- clear
		pc_inc <= '0';
		pc_dec <= '0';
		ptr_inc <= '0';
		ptr_dec <= '0';
    	cnt_inc <= '0';
    	cnt_dec <= '0';
    	mx1_sel <= (others => '0');
		mx2_sel <= (others => '0');
		DATA_EN <= '0';
		DATA_RDWR <= '0';
		IN_REQ <= '0';
		OUT_WE <= '0';

		case state is

			when state_start => 
				state_next <= state_fetch;

			when state_fetch =>
        		-- TODO 
				DATA_EN <= '1';
				DATA_ADDR <= x"0000"; 
				state_next <= state_decode;

			when state_decode =>
				case DATA_RDATA is
          			-- >
					when x"3E" => state_next <= state_ptr_inc;
          			-- <
					when x"3C" => state_next <= state_ptr_dec;
          			-- +
					when x"2B" => state_next <= state_prog_inc;
          			-- -
					when x"2D" => state_next <= state_prog_dec;
          			-- [
					when x"5B" => state_next <= state_while_start;
          			-- ]
					when x"5D" => state_next <= state_while_check;
					-- (
					when x"28" => state_next <= state_do_while_start;
          			-- )
					when x"29" => state_next <= state_do_while_check;
          			-- .
					when x"2E" => state_next <= state_write;
          			-- ,
					when x"2C" => state_next <= state_get;
          			-- null
					when x"00" => state_next <= state_null;
					when others => 
						pc_inc <= '1';
						state_next <= state_fetch;
				end case;

			when state_ptr_inc =>
				pc_inc <= '1';
				ptr_inc <= '1';
				state_next <= state_fetch;

			when state_ptr_dec =>
				pc_inc <= '1';
				ptr_dec <= '1';
				state_next <= state_fetch;

			when state_prog_inc =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				state_next <= state_mx_inc;

			when state_mx_inc =>
				mx_sel <= "01";
				state_next <= state_prog_end_inc;

			when state_prog_end_inc =>
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				pc_inc <= '1';
				state_next <= state_fetch;

			when state_prog_dec =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				state_next <= state_mx_dec;

			when state_mx_dec =>
				mx_sel <= "10";
				state_next <= state_prog_end_dec;

			when state_prog_end_dec =>
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				pc_inc <= '1';
				state_next <= state_fetch;

			when state_write =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				state_next <= state_write_done;

			when state_write_done =>
				if OUT_BUSY = '1' then
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					state_next <= state_write_done;
				else 
					OUT_WE <= '1';
					OUT_DATA <= DATA_RDATA;
					pc_inc <= '1';
					state_next <= state_fetch;
				end if;
		
			when state_get =>
				IN_REQ <= '1';
				mx_sel <= "00";
				state_next <= state_get_done;
			
			when state_get_done =>
				if IN_VLD /= '1' then
					IN_REQ <= '1';
					mx_sel <= "00";
					state_next <= state_get_done;
				else 
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					pc_inc <= '1';
					state_next <= state_fetch;
				end if;

			when state_while_start =>
				pc_inc <= '1';
				ras_reg <= pc_reg + 1;
				state_next <= state_fetch;
	
			when state_while_end =>
				if DATA_RDATA = "00000000" then
					pc_inc <= '1';
					ras_reg <= (others => '0');
					state_next <= state_fetch;
				else
					pc_ld <= '1';
					state_next <= state_fetch;
				end if;

			when state_while_check =>
				DATA_RDWR <= '0';
				DATA_EN <= '1';
				state_next <= state_while_end;

			when state_do_while_start =>
				pc_inc <= '1';
				ras_reg <= pc_reg + 1;
				state_next <= state_fetch;
	
			when state_do_while_end =>
				if DATA_RDATA = "00000000" then
					pc_inc <= '1';
					ras_reg <= (others => '0');
					state_next <= state_fetch;
				else
					pc_ld <= '1';
					state_next <= state_fetch;
				end if;	

			when state_do_while_check =>
				DATA_RDWR <= '0';
				DATA_EN <= '1';
				state_next <= state_do_while_end;

			when state_null =>
				state_next <= state_null;
				
		end case;
	
	end process;
	-- FSM

end behavioral;

