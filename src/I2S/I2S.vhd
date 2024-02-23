-------------------------------------------------------------------------------
-- I2S for PMOD I2S2 
-- Author(s)     : Philip
-- File Name     : I2S.vhd
--
-- An I2S receiver and trasmitter for interfacing with the digilen PMOD I2S2 module.
-- Currently implemented in "Single Speed Mode" for a sampling frequency of
-- 44.1 KHz. The mclk must be 512 times this frequency, approximately 22.579 MHz.
-- For more information, refer to the Cirrus CS5343 and a Cirrus CS4344 data sheets.
--
-- Interface follows axi style ready/valid handshaking
-- rx data valid will be held high until rdy&&vld and rx data will remain stable
-- If rdy is not asserted within one LR sample period, data from the I2S module
-- will be dropped.
-- If tx data is not supplied, zeros will be shifted out on the output interface.
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity I2S is
  generic (
    G_BIT_DEPTH : natural := 24
    );
  port (
    clk : in std_logic;                 -- Master clk, frequency 22.579 MHz
    rst : in std_logic;

    o_i2s_tx_mclk : out std_logic;      -- master clock
    o_i2s_tx_sclk : out std_logic;      -- Serial clock
    o_i2s_tx_lrck : out std_logic;      -- Left right clock/word select
    o_i2s_tx_sd   : out std_logic;      -- Serial Data

    o_i2s_rx_mclk : out std_logic;  -- PMOD I2S2 in slave mode requires the sclk and lrck to be supplied
    o_i2s_rx_sclk : out std_logic;
    o_i2s_rx_lrck : out std_logic;
    i_i2s_rx_sd   : in  std_logic;

    --Handshaking and data signals - if these cross clock domains, they must be synchronised correctly!
    o_rx_data     : out std_logic_vector(G_BIT_DEPTH*2-1 downto 0);  -- 47 downto 24: left audio data, 23 downto 0: right audio data 
    o_rx_data_vld : out std_logic;
    i_rx_rdy      : in  std_logic;

    i_tx_data     : in  std_logic_vector(G_BIT_DEPTH*2-1 downto 0);  -- 47 downto 24: left audio data, 23 downto 0: right audio data
    i_tx_data_vld : in  std_logic;
    o_tx_rdy      : out std_logic

    );
end entity;

architecture rtl of I2S is
  constant C_LRCK_DIV_LOG2 : natural := 9;  --MCLK divide by 512 for lrck 
  constant C_SCK_DIV_LOG2  : natural := 3;  --MCLK divide by 8 for sck 

  signal sck  : std_logic := '0';
  signal mclk : std_logic := '0';
  signal lrck : std_logic := '0';

  signal sd_out                : std_logic := '0';
  signal clk_div_counter       : unsigned(C_LRCK_DIV_LOG2 - 1 downto 0);
  signal sck_rising_edge_tick  : std_logic := '0';
  signal sck_falling_edge_tick : std_logic := '0';
  signal tx_rdy                : std_logic := '0';

  signal tx_data : std_logic_vector(G_BIT_DEPTH*2-1 downto 0) := (others => '0');
  signal tx_sreg : std_logic_vector(64 - 1 - 1 downto 0)      := (others => '0');

  signal rx_data     : std_logic_vector(G_BIT_DEPTH*2-1 downto 0) := (others => '0');
  signal rx_sreg     : std_logic_vector(64-1 downto 0)            := (others => '0');
  signal rx_started  : std_logic                                  := '0';
  signal rx_data_vld : std_logic                                  := '0';

begin

  sck  <= clk_div_counter(C_SCK_DIV_LOG2 - 1);   -- divide by 8
  lrck <= clk_div_counter(C_LRCK_DIV_LOG2 - 1);  -- divide by 512

  -- A counter used to divide the master clock and then derive the slower clock
  -- (lrck and sck) to forward to the I2S2 pmod
  p_clk_counter : process (clk)
  begin
    if rising_edge(clk) then
      clk_div_counter <= clk_div_counter + 1;
      if clk_div_counter(C_SCK_DIV_LOG2-1 downto 0) = "010" then
        sck_rising_edge_tick <= '1';
      else
        sck_rising_edge_tick <= '0';
      end if;
      if clk_div_counter(C_SCK_DIV_LOG2-1 downto 0) = "110" then
        sck_falling_edge_tick <= '1';
      else
        sck_falling_edge_tick <= '0';
      end if;
      if rst = '1' then
        clk_div_counter <= (others => '0');
      end if;
    end if;
  end process;

  -- Latch data after we have finished sending one sample
  p_transmit : process(clk)
  begin
    if rising_edge(clk) then
      -- Register data when we are ready to recieve and the input data is valid
      if tx_rdy = '1' and i_tx_data_vld = '1' then
        tx_rdy  <= '0';
        tx_data <= i_tx_data;
      end if;

      if sck_falling_edge_tick = '1' then
        if clk_div_counter(clk_div_counter'high downto C_SCK_DIV_LOG2) = 0 then
          -- Sample tx_data onto output shift register and set first output,
          -- only if we have valid data, otherwise send out zeros
          if tx_rdy = '0' then          --tx_rdy 0 means we have valid data 
            -- Left data (except for top bit, which is sent, zero padding, right data,
            -- zero padding
            -- There is an extra 0 since data is sent one sck after lr ck transitions.
            tx_sreg <= tx_data(G_BIT_DEPTH*2-1 downto G_BIT_DEPTH) & "0000000" & "0" & tx_data(G_BIT_DEPTH - 1 downto 0) & "0000000";
            tx_rdy  <= '1';
          end if;
        else
          tx_sreg <= tx_sreg(tx_sreg'high-1 downto 0) & '0';
        end if;
      end if;

      if rst = '1' then
        tx_rdy <= '1';
      end if;

    end if;
  end process;

  p_receive : process(clk)
  begin
    if rising_edge(clk) then
      -- Transaction happens when output is vld and slave is ready
      if rx_data_vld = '1' and i_rx_rdy = '1' then
        rx_data_vld <= '0';
      end if;

      -- Sample on rising edge 
      if sck_rising_edge_tick = '1' then
        if clk_div_counter(clk_div_counter'high downto C_SCK_DIV_LOG2) = 0 then
          rx_started <= '1';
          -- Probably not essential, but there will be an erroneous rx valid at
          -- the beginning, since the counter starts at 0. Mask this first data
          -- to ensure it doesn't go out as a valid.
          if rx_data_vld = '0' and rx_started = '1' then
            rx_data     <= rx_sreg(rx_sreg'high-1 downto rx_sreg'high-G_BIT_DEPTH) & rx_sreg(G_BIT_DEPTH-1+7 downto 7);
            rx_data_vld <= '1';
          end if;
        end if;
        rx_sreg <= rx_sreg(rx_sreg'high-1 downto 0) & i_i2s_rx_sd;
      end if;

      if rst = '1' then
        rx_data_vld <= '0';
        rx_started  <= '0';
      end if;
    end if;
  end process;


  o_i2s_rx_mclk <= clk;  --Note: forward clock in top level with ODDR
  o_i2s_rx_sclk <= sck;
  o_i2s_rx_lrck <= lrck;

  o_i2s_tx_mclk <= clk;
  o_i2s_tx_sclk <= sck;
  o_i2s_tx_lrck <= lrck;
  o_i2s_tx_sd   <= tx_sreg(tx_sreg'high);

  o_tx_rdy      <= tx_rdy;
  o_rx_data_vld <= rx_data_vld;
  o_rx_data     <= rx_data;

end;
