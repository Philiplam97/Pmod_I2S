-------------------------------------------------------------------------------
-- Title      : I2S Passthrough
-- Project    : I2
-------------------------------------------------------------------------------
-- File       : arty_top.vhd
-- Author     : Philip
-------------------------------------------------------------------------------
-- Description: 
-- 
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

library unisim;
use unisim.vcomponents.BUFG;
use unisim.vcomponents.MMCME2_BASE;
use unisim.vcomponents.ODDR;

entity arty_top is
  port (
    clk_100MHz : in std_logic;  -- System clock, 100MHz on Arty
    rst_btn_n  : in std_logic;  -- asynchronous active low

    o_i2s_tx_mclk : out std_logic;  -- Master clock
    o_i2s_tx_sclk : out std_logic;  -- Serial clock
    o_i2s_tx_lrck : out std_logic;  -- Left right clock/word select
    o_i2s_tx_sd   : out std_logic;  -- Serial Data

    o_i2s_rx_mclk : out std_logic;  --PMOD I2S2 in slave mode requires the sclk and lrck to be supplied
    o_i2s_rx_sclk : out std_logic;
    o_i2s_rx_lrck : out std_logic;
    i_i2s_rx_sd   : in  std_logic
    );
end entity;

architecture rtl of arty_top is
  signal rst_n_clk_100MHz : std_logic := '0';
  signal rst_clk_100MHz   : std_logic := '0';

  signal clk_feedback       : std_logic := '0';
  signal clk_I2S_unbuffered : std_logic := '0';
  signal rst_n_clk_I2S      : std_logic := '0';
  signal rst_clk_I2S        : std_logic := '0';
  signal clk_I2S            : std_logic := '0';

  signal mmcm_locked         : std_logic := '0';
  signal mmcm_locked_clk_I2S : std_logic := '0';

  signal rx_data     : std_logic_vector(47 downto 0) := (others => '0');
  signal rx_data_vld : std_logic                     := '0';
  signal rx_rdy      : std_logic                     := '0';

  signal tx_data     : std_logic_vector(47 downto 0) := (others => '0');
  signal tx_data_vld : std_logic                     := '0';
  signal tx_rdy      : std_logic                     := '0';

  signal i2s_tx_mclk : std_logic := '0';
  signal i2s_rx_mclk : std_logic := '0';

begin

  -- Generate the I2S master clock with frequency 22.5792
  MMCME2_BASE_inst : MMCME2_BASE
    generic map (
      BANDWIDTH          => "OPTIMIZED",  -- Jitter programming (OPTIMIZED, HIGH, LOW)
      CLKFBOUT_MULT_F    => 63.250,  -- Multiply value for all CLKOUT (2.000-64.000).
      CLKFBOUT_PHASE     => 0.0,  -- Phase offset in degrees of CLKFB (-360.000-360.000).
      CLKIN1_PERIOD      => 10.0,  -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
-- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
      CLKOUT1_DIVIDE     => 1,
      CLKOUT2_DIVIDE     => 1,
      CLKOUT3_DIVIDE     => 1,
      CLKOUT4_DIVIDE     => 1,
      CLKOUT5_DIVIDE     => 1,
      CLKOUT6_DIVIDE     => 1,
      CLKOUT0_DIVIDE_F   => 31.125,  -- Divide amount for CLKOUT0 (1.000-128.000).
-- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
      CLKOUT0_DUTY_CYCLE => 0.5,
      CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5,
      CLKOUT3_DUTY_CYCLE => 0.5,
      CLKOUT4_DUTY_CYCLE => 0.5,
      CLKOUT5_DUTY_CYCLE => 0.5,
      CLKOUT6_DUTY_CYCLE => 0.5,
-- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
      CLKOUT0_PHASE      => 0.0,
      CLKOUT1_PHASE      => 0.0,
      CLKOUT2_PHASE      => 0.0,
      CLKOUT3_PHASE      => 0.0,
      CLKOUT4_PHASE      => 0.0,
      CLKOUT5_PHASE      => 0.0,
      CLKOUT6_PHASE      => 0.0,
      CLKOUT4_CASCADE    => false,  -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
      DIVCLK_DIVIDE      => 9,    -- Master division value (1-106)
      REF_JITTER1        => 0.0,  -- Reference input jitter in UI (0.000-0.999).
      STARTUP_WAIT       => false  -- Delays DONE until MMCM is locked (FALSE, TRUE)
      )
    port map (
-- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0   => clk_I2S_unbuffered,    -- 1-bit output: CLKOUT0
      CLKOUT0B  => open,          -- 1-bit output: Inverted CLKOUT0
      CLKOUT1   => open,          -- 1-bit output: CLKOUT1
      CLKOUT1B  => open,          -- 1-bit output: Inverted CLKOUT1
      CLKOUT2   => open,          -- 1-bit output: CLKOUT2
      CLKOUT2B  => open,          -- 1-bit output: Inverted CLKOUT2
      CLKOUT3   => open,          -- 1-bit output: CLKOUT3
      CLKOUT3B  => open,          -- 1-bit output: Inverted CLKOUT3
      CLKOUT4   => open,          -- 1-bit output: CLKOUT4
      CLKOUT5   => open,          -- 1-bit output: CLKOUT5
      CLKOUT6   => open,          -- 1-bit output: CLKOUT6
-- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT  => clk_feedback,  -- 1-bit output: Feedback clock
      CLKFBOUTB => open,          -- 1-bit output: Inverted CLKFBOUT
-- Status Ports: 1-bit (each) output: MMCM status ports
      LOCKED    => mmcm_locked,   -- 1-bit output: LOCK
-- Clock Inputs: 1-bit (each) input: Clock input
      CLKIN1    => clk_100MHz,    -- 1-bit input: Clock
-- Control Ports: 1-bit (each) input: MMCM control ports
      PWRDWN    => '0',           -- 1-bit input: Power-down
      RST       => '0',           -- 1-bit input: Reset
-- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN   => clk_feedback   -- 1-bit input: Feedback clock
      );

  bufg_clk_I2S : BUFG
    port map (
      i => clk_I2S_unbuffered,
      o => clk_I2S
      );

  sync_mmcm_locked : entity work.sync_ff
    generic map (
      G_REGISTER_STAGES => 4,
      G_RESET_POL       => '0',
      G_RESET_VAL       => '1')
    port map (
      clk   => clk_I2S,
      rst   => mmcm_locked,
      i_bit => '1',
      o_bit => mmcm_locked_clk_I2S);

  debouncer_1 : entity work.button_debouncer
    generic map(
      G_N_CLKS_MAX => 1128960  --50ms with 22.5792 clk
      )
    port map (
      clk    => clk_I2S,
      i_din  => rst_btn_n,
      o_dout => rst_n_clk_I2S);

  process(clk_I2S)
  begin
    if rising_edge(clk_I2S) then
      rst_clk_I2S <= (not rst_n_clk_I2S) or (not mmcm_locked_clk_I2S);
    end if;
  end process;

  I2S_1 : entity work.I2S
    port map (
      clk => clk_I2S,
      rst => rst_clk_I2S,

      o_i2s_tx_mclk => i2s_tx_mclk,
      o_i2s_tx_sclk => o_i2s_tx_sclk,
      o_i2s_tx_lrck => o_i2s_tx_lrck,
      o_i2s_tx_sd   => o_i2s_tx_sd,

      o_i2s_rx_mclk => i2s_rx_mclk,
      o_i2s_rx_sclk => o_i2s_rx_sclk,
      o_i2s_rx_lrck => o_i2s_rx_lrck,
      i_i2s_rx_sd   => i_i2s_rx_sd,

      o_rx_data     => rx_data,
      o_rx_data_vld => rx_data_vld,
      i_rx_rdy      => rx_rdy,

      i_tx_data     => tx_data,
      i_tx_data_vld => tx_data_vld,
      o_tx_rdy      => tx_rdy);

  process(clk_I2S)
  begin
    if rising_edge(clk_I2S) then
      if rx_rdy = '1' and rx_data_vld = '1' then
        rx_rdy      <= '0';
        tx_data     <= rx_data;
        tx_data_vld <= '1';
      end if;

      if tx_data_vld = '1' and tx_rdy = '1' then
        tx_data_vld <= '0';
        rx_rdy      <= '1';
      end if;

      if rst_clk_I2S = '1' then
        rx_rdy      <= '1';
        tx_data_vld <= '0';
      end if;

    end if;
  end process;

  -- Forward mclk for I2s module  with ODDR
  ODDR_tx_mclk : ODDR
    generic map(
      DDR_CLK_EDGE => "OPPOSITE_EDGE",  -- "OPPOSITE_EDGE" or "SAME_EDGE"
      INIT         => '0',  -- Initial value for Q port ('1' or '0')
      SRTYPE       => "SYNC")           -- Reset Type ("ASYNC" or "SYNC")
    port map (
      Q  => o_i2s_tx_mclk,  -- 1-bit DDR output
      C  => i2s_tx_mclk,    -- 1-bit clock input
      CE => '1',            -- 1-bit clock enable input
      D1 => '1',            -- 1-bit data input (positive edge)
      D2 => '0',            -- 1-bit data input (negative edge)
      R  => '0',            -- 1-bit reset input
      S  => '0'             -- 1-bit set input
      );

  -- Forward mclk for I2s module  with ODDR
  ODDR_rx_mclk : ODDR
    generic map(
      DDR_CLK_EDGE => "OPPOSITE_EDGE",  -- "OPPOSITE_EDGE" or "SAME_EDGE"
      INIT         => '0',  -- Initial value for Q port ('1' or '0')
      SRTYPE       => "SYNC")           -- Reset Type ("ASYNC" or "SYNC")
    port map (
      Q  => o_i2s_rx_mclk,  -- 1-bit DDR output
      C  => i2s_rx_mclk,    -- 1-bit clock input
      CE => '1',            -- 1-bit clock enable input
      D1 => '1',            -- 1-bit data input (positive edge)
      D2 => '0',            -- 1-bit data input (negative edge)
      R  => '0',            -- 1-bit reset input
      S  => '0'             -- 1-bit set input
      );

end;
