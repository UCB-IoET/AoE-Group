
-- SVCD is a simple service daemon designed to allow service advertisements over UDP and BLE
-- without requiring user code to know that this is being done
-- Advertisements are done on UDP port 2525
-- Writes are done on UDP port 2526
-- Notifications are done on UDP port 2527
-- Write source port is 2528
-- Notification source port is 2529

-- singleton
SVCD = {
    OK=1,
    TIMEOUT=2,
    ivkid = 0,
    manifest_map = {},
    blsmap = {},
    blamap = {},
    oursubs = {},
    subscribers = {},
    handlers = {},
}


-- Dispatch writes to attributes
SVCD.wdispatch = function(payload, src_ip, src_port)
    local t = storm.mp.unpack(payload)
    local svc_id = t[1]
    local attr_id = t[2]
    local ivk_id = t[3]
    local payload = t[4]
    local svc = SVCD.manifest_map[svc_id]
    if svc == nil then
        print "[SVCD] Attempt to access nonexistent service"
        return
    end
    local attr = svc[attr_id]
    if attr == nil then
        print "[SVCD] Attempt to access nonexistent attribute"
        return
    end
    -- acknowledge the write, before we execute it
    storm.net.sendto(SVCD.ssock, storm.mp.pack(ivk_id), src_ip, src_port)
    -- execute the write trigger
    cord.new(function() attr(payload, src_ip, src_port) end)
end

-- Dispatch an advertisement
-- This is left as an exercise for the reader, come up with a good
-- method of collating advertisements
SVCD.advert_received = function(pay, srcip, srcport)
    return
    -- local adv = storm.mp.unpack(pay)
    -- print (string.format("Service advertisment %s", srcip))
    -- for k,v in pairs(adv) do
    --     if k == "id" then
    --         print ("ID="..v)
    --     else
    --         print (string.format("  0x%04x:",k))
    --         for kk,vv in pairs(v) do
    --             print (string.format("   >%d: 0x%04x", kk, vv))
    --         end
    --     end
    -- end
end

-- BLE connection changed function
-- not currently used, override if you want access to it
SVCD.cchanged = function ()
end


-- initialises the SVCD. If id is not null, then it also starts advertising
SVCD.init = function(id, onready)
   SVCD.id = id
   -- Advertisements
   SVCD.asock = storm.net.udpsocket(2525, function(...) SVCD.advert_received(...) end )
   -- writes
   SVCD.ssock = storm.net.udpsocket(2526, SVCD.wdispatch)
   -- notification socket
   SVCD.nsock = storm.net.udpsocket(2527, SVCD.ndispatch)
   -- write client socket
   SVCD.wcsock = storm.net.udpsocket(2528, SVCD.wcdispatch)
   -- notification client socket
   SVCD.ncsock = storm.net.udpsocket(2529, SVCD.ncdispatch)
   -- subscription socket
   SVCD.subsock = storm.net.udpsocket(2530, SVCD.subdispatch)
   SVCD.manifest = {id=id }
   if id ~= nil then
       storm.os.invokePeriodically(3*storm.os.SECOND, function()
            storm.net.sendto(SVCD.asock, storm.mp.pack(SVCD.manifest), "ff02::1", 2525)
        end)
       -- storm.bl.enable(id, SVCD.cchanged, onready)
       onready()
   end

end

SVCD.wcdispatch = function(pay, srcip, srcport)
    local ivkid = storm.mp.unpack(pay)
    if SVCD.handlers[ivkid] ~= nil then
        SVCD.handlers[ivkid](SVCD.OK)
        SVCD.handlers[ivkid] = nil
    end
end

SVCD.write = function (targetip, svcid, attrid, payload, timeout_ms, on_done)
    local ivkid = SVCD.ivkid
    SVCD.ivkid = SVCD.ivkid + 1
    if SVCD.ivkid > 65535 then
        SVCD.ivkid = 0
    end
    SVCD.handlers[ivkid] = on_done
    storm.os.invokeLater(timeout_ms*storm.os.MILLISECOND, function()
        if SVCD.handlers[ivkid] ~= nil then
            SVCD.handlers[ivkid](SVCD.TIMEOUT)
            SVCD.handlers[ivkid] = nil
        end
    end)
    storm.net.sendto(SVCD.wcsock, storm.mp.pack({svcid, attrid, ivkid, payload}), targetip, 2526)
end

-- Add a new service to the service daemon
-- this must be called before SVCD.advertise()
SVCD.add_service = function(svc_id)
    -- SVCD.blsmap[svc_id] = storm.bl.addservice(svc_id)
    -- SVCD.blamap[svc_id] = {}
    SVCD.manifest[svc_id] = {}
    SVCD.manifest_map[svc_id] = {}
end
-- Add a new attribute to a service in the service daemon
SVCD.add_attribute = function(svc_id, attr_id, write_fn)
    -- SVCD.blamap[svc_id][attr_id] = storm.bl.addcharacteristic(SVCD.blsmap[svc_id], attr_id, write_fn)
    table.insert(SVCD.manifest[svc_id], attr_id)
    SVCD.manifest_map[svc_id][attr_id] = write_fn
end

SVCD.subdispatch = function(pay, srcip, srcport)
    local parr = storm.array.fromstr(pay)
    local cmd = parr:get(1)
    local svc_id = parr:get_as(storm.array.UINT16,1)
    local attr_id = parr:get_as(storm.array.UINT16,3)
    local ivkid = parr:get_as(storm.array.UINT16, 5)
    if cmd == 1 then --subscribe command
        if SVCD.subscribers[svc_id] == nil then
            SVCD.subscribers[svc_id] = {}
        end
        if SVCD.subscribers[svc_id][attr_id] == nil then
            SVCD.subscribers[svc_id][attr_id] = {}
        end
        SVCD.subscribers[svc_id][attr_id][srcip] = ivkid
    elseif cmd == 2 then --unsubscribe command
        if SVCD.subscribers[svc_id] == nil then
            return
        end
        if SVCD.subscribers[svc_id][attr_id] == nil then
            return
        end
        SVCD.subscribers[svc_id][attr_id][srcip] = nil
    end
end

SVCD.ndispatch = function(pay, srcip, srcport)
    -- dispatch an incoming notification
    local msg = storm.array.fromstr(pay)
    local ivkid = msg:get_as(storm.array.UINT16, 0)
    if SVCD.oursubs[ivkid] ~= nil then
        SVCD.oursubs[ivkid](string.sub(pay,3))
    end
end

SVCD.ncdispatch = function()
    --if notifies had a reply we would use this
end

SVCD.notify = function(svc_id, attr_id, value)
    print "[SVCD] notifying"
    -- storm.bl.notify(SVCD.blamap[svc_id][attr_id], value)
    if SVCD.subscribers[svc_id] == nil then
        print "[SVCD] no service subscribers"
        return
    end
    if SVCD.subscribers[svc_id][attr_id] == nil then
        print "[SVCD] no attr subscribers"
        return
    end
    cord.new(function()
        for k, v in pairs(SVCD.subscribers[svc_id][attr_id]) do
            local header = storm.array.create(1, storm.array.UINT16)
            header:set(1, v)
            storm.net.sendto(SVCD.ncsock, header:as_str()..value, k, 2527)
            cord.await(storm.os.invokeLater, 70*storm.os.MILLISECOND)
        end
    end)
end

SVCD.subscribe = function(targetip, svcid, attrid, on_notify)
    local msg = storm.array.create(7,storm.array.UINT8)
    local ivkid = SVCD.ivkid
    SVCD.ivkid = SVCD.ivkid + 1
    if SVCD.ivkid > 65535 then
        SVCD.ivkid = 0
    end
    SVCD.oursubs[ivkid] = on_notify
    msg:set(1, 1)
    msg:set_as(storm.array.UINT16, 1, svcid)
    msg:set_as(storm.array.UINT16, 3, attrid)
    msg:set_as(storm.array.UINT16, 5, ivkid)
    storm.net.sendto(SVCD.ncsock, msg:as_str(), targetip, 2530)
    return ivkid
end

SVCD.unsubscribe = function(targetip, svcid, attrid, ivkid)
    local msg = storm.array.create(7,storm.array.UINT8)
    SVCD.oursubs[ivkid] = nil
    msg:set(1, 0)
    msg:set_as(storm.array.UINT16, 1, svcid)
    msg:set_as(storm.array.UINT16, 3, attrid)
    msg:set_as(storm.array.UINT16, 5, ivkid)
    storm.net.sendto(SVCD.ncsock, msg:as_str(), targetip, 2530)
end
