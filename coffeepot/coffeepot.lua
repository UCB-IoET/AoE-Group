require("svcd")
require("cord")

COFFEE_SERVICE = 0x3004
MKCOFFEE_ATTR = 0x4C0F

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
    storm.io.set(0, relay)
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
    lcd:clear()
    lcd:setCursor(0, 0)
    lcd:writeString("STATUS:")
    lcd:setCursor(1, 0)
    lcd:writeString(msg)
end

function make_coffee(time)
    storm.os.cancel(announcer)
    on()
    beep()
    local seconds = time / storm.os.SECOND
    local ret = "BREWING " .. (seconds / 60) .. ":" .. (seconds % 60)
    write_status(ret, 255, 192, 0)
end

function notify_done()
    beep()
    write_status("DONE. ENJOY <3", 0, 255, 0)
    cord.await(storm.os.invokeLater, 10*storm.os.SECOND)
    announcer = storm.os.invokePeriodically(20*storm.os.SECOND, SVCD.notify, COFFEE_SERVICE, MKCOFFEE_ATTR, "I love coffee!")
end

function on_svcd_init()
    -- Called when SVCD is ready to have services added
    SVCD.add_service(COFFEE_SERVICE)
    SVCD.add_attribute(COFFEE_SERVICE, MKCOFFEE_ATTR, function(payload, source_ip, source_port)
        cord.new(function()
            local args = storm.array.fromstr(payload)
            local time = args:get_as(storm.array.UINT16, 0)
            time = 2 * 60 * storm.os.SECOND
            make_coffee(time)
            cord.await(storm.os.invokeLater, time)
            notify_done()
        end)
    end)
end

SVCD.init("coffee", on_svcd_init)

cord.new(function ()
    lcd:init(2, 1)
    lcd:setBackColor(255, 255, 255)
    lcd:writeString("I LOVE COFFEE")
    lcd:setCursor(1, 0)
    lcd:writeString("COFFEE IS LOVE")
    announcer = storm.os.invokePeriodically(20*storm.os.SECOND, SVCD.notify, COFFEE_SERVICE, MKCOFFEE_ATTR, "I love coffee!")

--    cord.await(storm.os.invokeLater, 5*storm.os.SECOND)
--    make_coffee()
end)

cord.enter_loop()
