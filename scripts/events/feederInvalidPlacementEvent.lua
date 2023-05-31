


--- FeederInvalidPlacementEvent is used for signaling farm members of their bird feeder being badly placed.
FeederInvalidPlacementEvent = {}
FeederInvalidPlacementEvent_mt = Class(FeederInvalidPlacementEvent,Event)
InitEventClass(FeederInvalidPlacementEvent, "FeederInvalidPlacementEvent")

--- emptyNew creates new empty event.
function FeederInvalidPlacementEvent.emptyNew()
    local self = Event.new(FeederInvalidPlacementEvent_mt)
    return self
end
--- new creates a new event and saves object received as param.
--@param object is the bird feeder object.
function FeederInvalidPlacementEvent.new(object)
    local self = FeederInvalidPlacementEvent.emptyNew()
    self.object = object
    return self
end
--- readStream syncs the object to clients.
function FeederInvalidPlacementEvent:readStream(streamId, connection)
    self.object = NetworkUtil.readNodeObject(streamId)
    self:run(connection)
end
--- writeStream writes to object to clients.
function FeederInvalidPlacementEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.object)
end
--- run calls the invalidPlacement of birdfeeder object.
function FeederInvalidPlacementEvent:run(connection)
    if self.object ~= nil then
        self.object:invalidPlacement()
    end
end
--- sendEvent called when event wants to be sent.
-- server only.
--@param feeder is the feeder that wants to have event called.
--@noEventSend is a bool to indicate if no event should be sent, not used in this event though.
function FeederInvalidPlacementEvent.sendEvent(feeder, noEventSend)
    if feeder ~= nil and not noEventSend and g_server ~= nil then
        g_server:broadcastEvent(FeederInvalidPlacementEvent.new(feeder), nil, nil, feeder)
    end
end