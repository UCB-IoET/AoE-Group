adc = require "adc"
a = adc:new()
active = false

cord.new(function()
  print "Initializing..."
  rv = a:init()
  if (rv ~= 0) then
	 print "Error initializing"
  else
	 print "Done"
	 active = true
  end
  end)

cord.new(function()
			local i = 0
			while(active == false) do
			   cord.await(storm.os.invokeLater,1*storm.os.SECOND)
			end
			while(active) do
			   temperature = a:get()
			   print(i, "Temp:", temperature)
			   cord.await(storm.os.invokeLater,1*storm.os.SECOND)
			   i = i + 1
			end
		 end)


-- enable a shell
sh = require "stormsh"
sh.start()
cord.enter_loop() -- start event/sleep loop
