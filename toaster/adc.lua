REG = require("reg")
require("storm")
require("cord")

ADDR_ADC121             = 0x55*2

REG_ADDR_RESULT         = 0x00
REG_ADDR_ALERT          = 0x01
REG_ADDR_CONFIG         = 0x02
REG_ADDR_LIMITL         = 0x03
REG_ADDR_LIMITH         = 0x04
REG_ADDR_HYST           = 0x05
REG_ADDR_CONVL          = 0x06
REG_ADDR_CONVH          = 0x07

local adc = {}

function adc:new()
   local obj = {port=storm.i2c.EXT, addr = ADDR_ADC121,
                reg=REG:new(storm.i2c.EXT, ADDR_ADC121)}
   setmetatable(obj, self)
   self.__index = self
   return obj
end


function adc:init()
    rv = self.reg:w(REG_ADDR_CONFIG, 0x20);
	print ("return value", rv)
	if (rv == storm.i2c.OK) then
	   return 0
	else
	   return 1
	end
end

function adc:get()
   local arr, val
   arr = self.reg:r(REG_ADDR_RESULT, 2)
   if (arr == nil) then
	  print("Failed to get ADC")
	  return 0
   end
   val = (arr:get(1) * 256) + (arr:get(2))
   return val
end
return adc
