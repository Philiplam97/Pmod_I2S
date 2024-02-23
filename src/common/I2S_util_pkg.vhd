-------------------------------------------------------------------------------
-- Title      : Util Package I2S
-- Project    : I2S
-------------------------------------------------------------------------------
-- File       : I2S_util_pkg.vhd
-- Author     : Philip  
-- Created    : 30-12-2022
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------

package I2S_util_pkg is

function ceil_log2 (num : natural)  return natural;

end package I2S_util_pkg;

package body I2S_util_pkg is
  
  function ceil_log2(num : natural) return natural is
  begin
    for i in 0 to 31 loop
      if num <= 2**i then
        return i;
      end if;
    end loop;
  end function;
  
end package body I2S_util_pkg;
