require "cord" -- scheduler / fiber library
require "storm"

n = 17
col_array = storm.array.create(3 * n, storm.array.UINT8)

colors = {"off", "white", "red", "green", "blue", "cyan", "magenta", "yellow"}
rgb_vals = {0x000000, 0xFFFFFF, 0xFF0000, 0x00FF00, 0x0000FF, 0x00FFFF, 0xFF00FF, 0xFFFF00}

function set_color(color)
    for i = 0, n-1 do
        col_array:set(i*3 + 1, bit.band(bit.rshift(color, 8), 0xFF))
        col_array:set(i*3 + 2, bit.band(bit.rshift(color, 16), 0xFF))
        col_array:set(i*3 + 3, bit.band(color, 0xFF))
    end
    storm.n.neopixel(col_array)
end

storm.io.set_mode(storm.io.INPUT, storm.io.D3)
storm.io.set_pull(storm.io.PULL_UP, storm.io.D3)

function listen_rising()
   storm.io.watch_single(storm.io.RISING, storm.io.D3, function()
                            set_color(rgb_vals[6])
							--storm.n.neopixel(blue)
							listen_falling()
                        end)
end

function listen_falling()
   storm.io.watch_single(storm.io.FALLING, storm.io.D3, function()
                            set_color(rgb_vals[4])
							--storm.n.neopixel(offish)
							listen_rising()
                        end)
end

--listen_rising()

function demo_colors()
    while 1 do
        for i = 2, 8 do
            set_color(rgb_vals[i])
            for i = 1, 100000 do end
        end
    end
end

demo_colors()

-- enable a shell
sh = require "stormsh"
sh.start()
cord.enter_loop() -- start event/sleep loop
