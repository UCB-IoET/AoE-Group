---- IMPORTANT: be sure to use hotplate-svcd.lua instead of svcd.lua
require("svcd")
require "cord" -- scheduler / fiber library
Toaster = require "toaster"

HOTPLATE_SERVICE = 0x3020
ON_ATTR = 0x4001
SETPOINT_ATTR = 0x4b00
TEMP_ATTR = 0x4b01

function on_svcd_init()
    -- Called when SVCD is ready to have services added
    SVCD.add_service(HOTPLATE_SERVICE)
    SVCD.add_attribute(HOTPLATE_SERVICE, ON_ATTR, function(payload, source_ip, source_port)
        cord.new(function()
                     local on, args
                     if type(payload) ~= "string" then
                         on = payload
                     else
                         args = storm.array.fromstr(payload)
                         on = args:get_as(storm.array.UINT8, 0)
                     end

                     if (on and on ~= 0) then
                         toaster:on()
                     else
                         toaster:off()
                     end

        end)
    end)

    storm.os.invokePeriodically(20*storm.os.SECOND, function() cord.new(do_notify) end)
end

do_notify = function()
    local data = storm.array.create(1, storm.array.UINT8)

    if toaster:getState() then
        data:set(1, 1)
    else
        data:set(1, 0)
    end
    SVCD.notify(HOTPLATE_SERVICE, ON_ATTR, data:as_str())
end

cord.new(function()
             storm.io.set_mode(storm.io.OUTPUT, storm.io.GP0)

             toaster = Toaster:new("D6")
             toaster:init()

             SVCD.init("hotplate", on_svcd_init)
         end)

cord.enter_loop() -- start event/sleep loop
