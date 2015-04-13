LED = require "led"
require "cord"
require "svcd"

-- Actuate the relay like an LED
button = LED:new("D8")
power = LED:new("D7")

COFFEE_SERVICE = 0x3004
MKCOFFEE_ATTR = 0x4C0F
CLNSELF_ATTR = 0x4CAF

function reset()
   print("resetting coffee machine...")
   power:off() -- cuts power
   cord.await(storm.os.invokeLater, 5 * storm.os.SECOND)
   power:on() -- turns on power
   cord.await(storm.os.invokeLater, 5 * storm.os.SECOND)
   button:on()
   cord.await(storm.os.invokeLater, 300 * storm.os.MILLISECOND)
   button:off()
   cord.await(storm.os.invokeLater, 20 * storm.os.SECOND) -- to warm up
end

cord.new(function ()
	    cord.await(SVCD.init, "THE NETWORKED COFFEE MAKER")
	    SVCD.add_service(COFFEE_SERVICE)
	    SVCD.add_attribute(COFFEE_SERVICE, MKCOFFEE_ATTR, function (payload, source_ip, source_port)
				  cord.new (function ()
					       local args = storm.array.fromstr(payload)
					       reset()
					       local time = args:get_as(storm.array.UINT16, 0)
					       print("making coffee " .. time .. "...")
					       button:on()
					       cord.await(storm.os.invokeLater, 17 * storm.os.SECOND + (time * 10) * storm.os.MILLISECOND)
					       button:off()
					       print("finished making coffee")
					    end)
				  			      end)
	    SVCD.add_attribute(COFFEE_SERVICE, CLNSELF_ATTR, function (payload, source_ip, source_port)
				  cord.new(function ()
					      reset()
					      local i
					      for i = 1, 3 do
						 button:on()
						 cord.await(storm.os.invokeLater, 300 * storm.os.MILLISECOND)
						 button:off()
						 cord.await(storm.os.invokeLater, 300 * storm.os.MILLISECOND)
					      end
					      print("cleaning coffee machine")
					   end)
							      end)
	    --[[while true do
	       SVCD.notify(COFFEE_SERVICE, MKCOFFEE_ATTR, "I can make coffee!")
	       cord.await(storm.os.invokeLater, 100 * storm.os.MILLISECOND)
	       SVCD.notify(COFFEE_SERVICE, CLNSELF_ATTR, "I can clean myself!")
	       cord.await(storm.os.invokeLater, 100 * storm.os.MILLISECOND)
	       end]]--
	 end)

cord.enter_loop()
