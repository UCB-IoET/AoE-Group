require "cord"
sh = require "stormsh"
sh.start()

require "svcd"

coffee_machine = nil

cord.new(function()
  cord.await(SVCD.init, "coffee_client")
  SVCD.advert_received = function(pay, srcip, srcprt)
    local adv = storm.mp.unpack(pay)
    for k,v in pairs(adv) do
      if k == 0x3004 then
        coffee_machine = srcip
      end
    end
  end
end)

function make_coffee(time)
  if not coffee_machine then
    return
  end
  cord.new(function()
    local cmd = storm.array.create(1, storm.array.UINT8)
    cmd:set(1,time)
    SVCD.write(coffee_machine, 0x3004, 0x4c0f, cmd:as_str(), 300)
  end)
end

function clean()
  if not coffee_machine then
    return
  end
  cord.new(function()
    SVCD.write(coffee_machine, 0x3004, 0x4caf, "0", 300)
  end)
end

cord.enter_loop()
