--- --- --- --- --- BIRD SYSTEM/HANDLER STATES --- --- --- --- ---

--- BASE SYSTEM STATE CLASS ---
BirdSystemStateBase = {}
BirdSystemStateBase_mt = Class(BirdSystemStateBase)
InitObjectClass(BirdSystemStateBase, "BirdSystemStateBase")

function BirdSystemStateBase.new(customMt)
    local self = setmetatable({}, customMt or BirdSystemStateBase_mt)

    return self
end

function BirdSystemStateBase:init(inOwner)
    self.owner = inOwner
end

function BirdSystemStateBase:enter()

end

function BirdSystemStateBase:leave()

end

function BirdSystemStateBase:update(dt)

end



--- IN ACTIVE SYSTEM STATE CLASS ---
BirdSystemInActiveState = {}
BirdSystemInActiveState_mt = Class(BirdSystemInActiveState,BirdSystemStateBase)
InitObjectClass(BirdSystemInActiveState, "BirdSystemInActiveState")

function BirdSystemInActiveState.new(customMt)
    local self = BirdSystemInActiveState:superClass().new(customMt or BirdSystemInActiveState_mt)

    return self
end

function BirdSystemInActiveState:enter()
    BirdSystemInActiveState:superClass().enter(self)

end

function BirdSystemInActiveState:leave()
    BirdSystemInActiveState:superClass().leave(self)

end

function BirdSystemInActiveState:update(dt)
    BirdSystemInActiveState:superClass().update(self,dt)

end



--- RETURN SYSTEM STATE CLASS ---
BirdSystemReturnState = {}
BirdSystemReturnState_mt = Class(BirdSystemReturnState,BirdSystemStateBase)
InitObjectClass(BirdSystemReturnState, "BirdSystemReturnState")

function BirdSystemReturnState.new(customMt)
    local self = BirdSystemReturnState:superClass().new(customMt or BirdSystemReturnState_mt)

    return self
end

function BirdSystemReturnState:enter()
    BirdSystemReturnState:superClass().enter(self)

end

function BirdSystemReturnState:leave()
    BirdSystemReturnState:superClass().leave(self)

end

function BirdSystemReturnState:update(dt)
    BirdSystemReturnState:superClass().update(self,dt)

end



--- LEAVE SYSTEM STATE CLASS ---
BirdSystemLeaveState = {}
BirdSystemLeaveState_mt = Class(BirdSystemLeaveState,BirdSystemStateBase)
InitObjectClass(BirdSystemLeaveState, "BirdSystemLeaveState")

function BirdSystemLeaveState.new(customMt)
    local self = BirdSystemLeaveState:superClass().new(customMt or BirdSystemLeaveState_mt)

    return self
end

function BirdSystemLeaveState:enter()
    BirdSystemLeaveState:superClass().enter(self)

end

function BirdSystemLeaveState:leave()
    BirdSystemLeaveState:superClass().leave(self)

end

function BirdSystemLeaveState:update(dt)
    BirdSystemLeaveState:superClass().update(self,dt)

end



--- ACTIVE SYSTEM STATE CLASS ---
BirdSystemActiveState = {}
BirdSystemActiveState_mt = Class(BirdSystemActiveState,BirdSystemStateBase)
InitObjectClass(BirdSystemActiveState, "BirdSystemActiveState")


function BirdSystemActiveState.new(customMt)
    local self = BirdSystemActiveState:superClass().new(customMt or BirdSystemActiveState_mt)

    return self
end


function BirdSystemActiveState:enter()
    BirdSystemActiveState:superClass().enter(self)

end

function BirdSystemActiveState:leave()
    BirdSystemActiveState:superClass().leave(self)

end

function BirdSystemActiveState:update(dt)
    BirdSystemActiveState:superClass().update(self,dt)

end








--- --- --- --- --- BIRD STATES --- --- --- --- ---

--- BASE STATE CLASS ---
BirdStateBase = {}
BirdStateBase_mt = Class(BirdStateBase)
InitObjectClass(BirdStateBase, "BirdStateBase")

function BirdStateBase.new(customMt)
    local self = setmetatable({}, customMt or BirdStateBase_mt)

    return self
end

function BirdStateBase:init(inOwner, inFeeder)
    self.owner = inOwner
    self.feeder = inFeeder

end

function BirdStateBase:enter()

end

function BirdStateBase:leave()

end

function BirdStateBase:update(dt)

end


--- IDLE FLY STATE CLASS ---
BirdStateIdleFly = {}
BirdStateIdleFly_mt = Class(BirdStateIdleFly,BirdStateBase)
InitObjectClass(BirdStateIdleFly, "BirdStateIdleFly")


function BirdStateIdleFly.new(customMt)
    local self = BirdStateIdleFly:superClass().new(customMt or BirdStateIdleFly_mt)

    return self
end


function BirdStateIdleFly:enter()
    BirdStateIdleFly:superClass().enter(self)

    if self.owner ~= nil then
        enableAnimTrack(self.owner.meshAnimChar, self.owner.EBirdAnimations.FLY)
    end


end

function BirdStateIdleFly:leave()
    BirdStateIdleFly:superClass().leave(self)

end

function BirdStateIdleFly:update(dt)
    BirdStateIdleFly:superClass().update(self,dt)

    if self.owner ~= nil then
        self.owner:raiseActive()
        DebugUtil.drawSimpleDebugCube(self.owner.flyPivotLocationX, self.owner.flyPivotLocationY, self.owner.flyPivotLocationZ, 1, 0, 1, 0)
    end

end



--- RETURN FLY STATE CLASS ---
BirdStateReturnFly = {}
BirdStateReturnFly_mt = Class(BirdStateReturnFly,BirdStateBase)
InitObjectClass(BirdStateReturnFly, "BirdStateReturnFly")


function BirdStateReturnFly.new(customMt)
    local self = BirdStateReturnFly:superClass().new(customMt or BirdStateReturnFly_mt)

    return self
end


function BirdStateReturnFly:enter()
    BirdStateReturnFly:superClass().enter(self)

end

function BirdStateReturnFly:leave()
    BirdStateReturnFly:superClass().leave(self)

end

function BirdStateReturnFly:update(dt)
    BirdStateReturnFly:superClass().update(self,dt)

end



--- LEAVE FLY STATE CLASS ---
BirdStateLeaveFly = {}
BirdStateLeaveFly_mt = Class(BirdStateLeaveFly,BirdStateBase)
InitObjectClass(BirdStateLeaveFly, "BirdStateLeaveFly")


function BirdStateLeaveFly.new(customMt)
    local self = BirdStateLeaveFly:superClass().new(customMt or BirdStateLeaveFly_mt)

    return self
end


function BirdStateLeaveFly:enter()
    BirdStateLeaveFly:superClass().enter(self)

end

function BirdStateLeaveFly:leave()
    BirdStateLeaveFly:superClass().leave(self)

end

function BirdStateLeaveFly:update(dt)
    BirdStateLeaveFly:superClass().update(self,dt)

end



--- EAT STATE CLASS ---
BirdStateEat = {}
BirdStateEat_mt = Class(BirdStateEat,BirdStateBase)
InitObjectClass(BirdStateEat, "BirdStateEat")


function BirdStateEat.new(customMt)
    local self = BirdStateEat:superClass().new(customMt or BirdStateEat_mt)

    return self
end


function BirdStateEat:enter()
    BirdStateEat:superClass().enter(self)

end

function BirdStateEat:leave()
    BirdStateEat:superClass().leave(self)

end

function BirdStateEat:update(dt)
    BirdStateEat:superClass().update(self,dt)

end

--- BIRD FEEDER LAND STATE CLASS ---
BirdStateFeederLand = {}
BirdStateFeederLand_mt = Class(BirdStateFeederLand,BirdStateBase)
InitObjectClass(BirdStateFeederLand, "BirdStateFeederLand")


function BirdStateFeederLand.new(customMt)
    local self = BirdStateFeederLand:superClass().new(customMt or BirdStateFeederLand_mt)

    return self
end


function BirdStateFeederLand:enter()
    BirdStateFeederLand:superClass().enter(self)

end

function BirdStateFeederLand:leave()
    BirdStateFeederLand:superClass().leave(self)

end

function BirdStateFeederLand:update(dt)
    BirdStateFeederLand:superClass().update(self,dt)

end


--- BIRD FEEDER LEAVE STATE CLASS ---
BirdStateFeederLeave = {}
BirdStateFeederLeave_mt = Class(BirdStateFeederLeave,BirdStateBase)
InitObjectClass(BirdStateFeederLeave, "BirdStateFeederLeave")


function BirdStateFeederLeave.new(customMt)
    local self = BirdStateFeederLeave:superClass().new(customMt or BirdStateFeederLeave_mt)

    return self
end


function BirdStateFeederLeave:enter()
    BirdStateFeederLeave:superClass().enter(self)

end

function BirdStateFeederLeave:leave()
    BirdStateFeederLeave:superClass().leave(self)

end

function BirdStateFeederLeave:update(dt)
    BirdStateFeederLeave:superClass().update(self,dt)

end