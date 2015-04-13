buzzer = storm.io.D3
relay = storm.io.D2
coffee_on = 0
storm.io.set_mode(storm.io.OUTPUT, buzzer, relay)

LCD = require "lcd"
lcd = LCD:new(storm.i2c.EXT, 0x7c, storm.i2c.EXT, 0xc4)

debug_delay = 1000*storm.os.MILLISECOND

function on()
    storm.io.set(1, relay)
    cord.await(storm.os.invokeLater, 300*storm.os.MILLISECOND)
    coffee_on = 1
end

function beep(delay)
    storm.io.set(1, buzzer)
    cord.await(storm.os.invokeLater, delay or 500*storm.os.MILLISECOND)
    storm.io.set(0, buzzer)
end

function write_status(msg, r, g, b)
    if r and g and b then
        lcd:setBackColor(r, g, b)
    end
    lcd:setCursor(0, 0)
    lcd:writeString("STATUS:        ")
    lcd:setCursor(1, 0)
    lcd:writeString(msg)
end

function onconnect(state)
    if tmrhandle ~= nil then
        storm.os.cancel(tmrhandle)
        tmrhandle = nil
    end
    storm.os.invokePeriodically(1*storm.os.SECOND, function()
        tmrhandle = storm.bl.notify(char_handle,
        string.format("coffee: %d", coffee_on))
    end)
end

storm.bl.enable("unused", onconnect, function()
    print "I was executed, yay"
   local svc_handle = storm.bl.addservice(0x1245)
   char_handle = storm.bl.addcharacteristic(svc_handle, 0x1246, function(x)
        if x == "coffee: 1" then
            on()
            beep()
            write_status("BREWING COFFEE", 255, 255, 0)
        end
   end)
end)

cord.new(function ()
    lcd:init(2, 1)
    lcd:setBackColor(255, 255, 255)
    lcd:writeString("I LOVE COFFEE")
    lcd:setCursor(1, 0)
    lcd:writeString("COFFEE IS LOVE")

    cord.await(storm.os.invokeLater, 5*storm.os.SECOND)
    on()
    beep()
    write_status("BREWING COFFEE", 255, 255, 0)
end)

cord.enter_loop()
