--- --- --- --- --- BIRD FEEDER SYSTEM/HANDLER STATES --- --- --- --- ---
-- All states are on server only.

--- BASE SYSTEM STATE CLASS ---
BirdSystemStateBase = {}
BirdSystemStateBase_mt = Class(BirdSystemStateBase)
InitObjectClass(BirdSystemStateBase, "BirdSystemStateBase")

function BirdSystemStateBase.new(customMt)
    local self = setmetatable({}, customMt or BirdSystemStateBase_mt)
    self.owner = nil
    self.isServer = nil
    self.isClient = nil
    return self
end

function BirdSystemStateBase:init(inOwner,isServer,isClient)
    self.owner = inOwner
    self.isServer = isServer
    self.isClient = isClient
end

function BirdSystemStateBase:enter()
end

function BirdSystemStateBase:leave()
end

function BirdSystemStateBase:update(dt)
end

--- PREPARE ARRIVE SYSTEM STATE CLASS ---
--- BirdSystemPrepareArriveState is state where the feeder waits of random hours until it tries then to send the birds to fly towards feeder.
BirdSystemPrepareArriveState = {}
BirdSystemPrepareArriveState_mt = Class(BirdSystemPrepareArriveState,BirdSystemStateBase)
InitObjectClass(BirdSystemPrepareArriveState, "BirdSystemPrepareArriveState")

--- new creates a new prepare arrive state.
--@param customMt optional custom metatable.
function BirdSystemPrepareArriveState.new(customMt)
    local self = BirdSystemPrepareArriveState:superClass().new(customMt or BirdSystemPrepareArriveState_mt)
    self.targetHours = -1
    self.currentHours = 0
    return self
end

--- enter is called when state changes into this state.
-- used for subscribing to hour changed and setting the target hours after state should change.
function BirdSystemPrepareArriveState:enter()
    BirdSystemPrepareArriveState:superClass().enter(self)

    if self.owner ~= nil and g_messageCenter ~= nil then

        self.targetHours = math.random(1,self.owner.spec_placeableFeeder.maxHoursToSpawn)
        g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)
    end

end

--- leave is called when state is changing.
-- used for cleaning up the state.
function BirdSystemPrepareArriveState:leave()
    BirdSystemPrepareArriveState:superClass().leave(self)

    if self.owner ~= nil and g_messageCenter ~= nil then
        g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED,self)
    end

    self.targetHours = -1
    self.currentHours = 0
end

--- onHourChanged in bound to when hour changes in game.
-- if hour accumulates over target then changes feeder to active state.
function BirdSystemPrepareArriveState:onHourChanged()

    self.currentHours = self.currentHours + 1
    if self.currentHours >= self.targetHours and self.owner ~= nil then

        SpecializationUtil.raiseEvent(self.owner,"onPlaceableFeederBecomeActive")
    end

end


--- PREPARE LEAVE SYSTEM STATE CLASS ---
--- BirdSystemPrepareLeaveState is used for when food runs out of feeder.
-- waits a random amount of hours and then feeder becomes inactive and tells birds to leave by changing their state.
BirdSystemPrepareLeaveState = {}
BirdSystemPrepareLeaveState_mt = Class(BirdSystemPrepareLeaveState,BirdSystemStateBase)
InitObjectClass(BirdSystemPrepareLeaveState, "BirdSystemPrepareLeaveState")

--- new creates a new prepare leave state.
--@param customMt optional custom metatable.
function BirdSystemPrepareLeaveState.new(customMt)
    local self = BirdSystemPrepareLeaveState:superClass().new(customMt or BirdSystemPrepareLeaveState_mt)
    self.targetHours = -1
    self.currentHours = 0
    return self
end

--- enter is called when state changes into this state.
-- used for subscribing to hour changed and setting the target hours after state should change.
function BirdSystemPrepareLeaveState:enter()
    BirdSystemPrepareLeaveState:superClass().enter(self)

    if self.owner ~= nil and g_messageCenter ~= nil then

        self.targetHours = math.random(1,self.owner.spec_placeableFeeder.maxHoursToLeave)
        g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)
    end

end

--- leave is called when state is changing.
-- used for cleaning up the state.
function BirdSystemPrepareLeaveState:leave()
    BirdSystemPrepareLeaveState:superClass().leave(self)

    if self.owner ~= nil and g_messageCenter ~= nil then
        g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED,self)
    end

    self.targetHours = -1
    self.currentHours = 0
end

--- onHourChanged in bound to when hour changes in game.
-- if hour accumulates over target then changes feeder to inactive state.
function BirdSystemPrepareLeaveState:onHourChanged()

    self.currentHours = self.currentHours + 1
    if self.currentHours >= self.targetHours and self.owner ~= nil then

        SpecializationUtil.raiseEvent(self.owner,"onPlaceableFeederBecomeInActive")
    end

end

--- IN ACTIVE SYSTEM STATE CLASS ---
--- BirdSystemInActiveState is state used for when feeder is inactive and has no food.
BirdSystemInActiveState = {}
BirdSystemInActiveState_mt = Class(BirdSystemInActiveState,BirdSystemStateBase)
InitObjectClass(BirdSystemInActiveState, "BirdSystemInActiveState")

--- new creates a new in active state.
--@param customMt optional custom metatable.
function BirdSystemInActiveState.new(customMt)
    local self = BirdSystemInActiveState:superClass().new(customMt or BirdSystemInActiveState_mt)
    return self
end

--- enter is called when state changes into this state.
-- Makes sure to change the fillplane of feeder to hidden as it has no food anymore.
function BirdSystemInActiveState:enter()
    BirdSystemInActiveState:superClass().enter(self)

    if self.owner ~= nil then
        setVisibility(self.owner.spec_placeableFeeder.fillPlaneId,false)
    end
end


--- ACTIVE SYSTEM STATE CLASS ---
--- BirdSystemActiveState is state used for when the feeder has food and there is birds active.
BirdSystemActiveState = {}
BirdSystemActiveState_mt = Class(BirdSystemActiveState,BirdSystemStateBase)
InitObjectClass(BirdSystemActiveState, "BirdSystemActiveState")


--- new is called to create a new active state.
--@param customMt is optional custom metatable.
function BirdSystemActiveState.new(customMt)
    local self = BirdSystemActiveState:superClass().new(customMt or BirdSystemActiveState_mt)
    return self
end










