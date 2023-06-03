--[[
This file is part of Bird feeder mod (https://github.com/DennisB97/FS22BirdFeeder)

Copyright (c) 2023 Dennis B

Permission is hereby granted, free of charge, to any person obtaining a copy
of this mod and associated files, to copy, modify ,subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

This mod is for personal use only and is not affiliated with GIANTS Software.
Sharing or distributing FS22_BirdFeeder mod in any form is prohibited except for the official ModHub (https://www.farming-simulator.com/mods).
Selling or distributing FS22_BirdFeeder mod for a fee or any other form of consideration is prohibited by the game developer's terms of use and policies,
Please refer to the game developer's website for more information.
]]

--- --- --- --- --- BIRD STATES --- --- --- --- ---
---@class BirdStateBase.
BirdStateBase = {}
BirdStateBase_mt = Class(BirdStateBase)
InitObjectClass(BirdStateBase, "BirdStateBase")

--- new creates a new base state class.
function BirdStateBase.new(customMt)
    local self = setmetatable({}, customMt or BirdStateBase_mt)
    return self
end

--- init called to give the bird states reference to owner,feeder and if they are server or client state.
--@param inOwner the bird owner of the state.
--@param inFeeder the feeder that owns the bird.
--@param isServer if state owned by server.
--@param isClient if state owned by client.
function BirdStateBase:init(inOwner,inFeeder,isServer,isClient)
    self.owner = inOwner
    self.feeder = inFeeder
    self.isServer = isServer
    self.isClient = isClient
    self.errorCallback = function(aSearchResult) self.feeder:checkFeederAccessNonInitCallback(aSearchResult) end
end

--- enter called when changing into a state.
function BirdStateBase:enter()
    if self.owner ~= nil then
        self.owner:raiseActive()
    end
end

--- leave called when changing to another state.
function BirdStateBase:leave()

    if self.owner ~= nil and self.owner.pathfinder ~= nil then
        self.owner.pathfinder:interrupt()
    end

    if self.owner ~= nil and self.owner.splineCreator ~= nil then
        self.owner.splineCreator:interrupt()
    end

    self:clean()
end

--- clean takes care of cleaning up variables used to generated paths in the base state.
function BirdStateBase:clean()
    self.callback = nil
    self.pathfindSpeed = nil
    self.pathfindLimit = nil
    self.splineLengthLimit = nil
    self.spline = nil
    self.findClosest = nil
end

--- update forwarded from owner if owner is in a valid bird state.
--@param dt is deltatime in ms.
function BirdStateBase:update(dt)
end

--- createPath is used to create a path between given start and end, if with a specified minimum length then keeps combining and generating splines until length is reached.
---@param startPosition is from where to start the path, given as {x=,y=,z=}.
--@param endPosition is the final end position of path, given as {x=,y=,z=}.
--@param pathfindSpeed is the pathfinding speed to use on AStar class.
--@param pathfindLimit is the closed node search limit for the AStar class to be used.
--@param splineLengthLimit is used for the random paths, if first start -> end, does not reach the splinelengthlimit then continues creating splines with a random fly end position.
--@param findClosest is a bool to indicate if the AStar should return a path to closest available if the position was unreachable, because of pathfindLimit or something else.
function BirdStateBase:createPath(startPosition,endPosition,callback,pathfindSpeed,pathfindLimit,splineLengthLimit,findClosest)
    if self.owner == nil or self.owner.pathfinder == nil or self.owner.pathfinder:isPathfinding() then
        return false
    end

    -- relatively low&slow defaults if no custom value specified.
    self.pathfindSpeed = pathfindSpeed or 5
    self.pathfindLimit = pathfindLimit or 200
    self.splineLengthLimit = splineLengthLimit or 0
    self.callback = callback
    self.findClosest = (findClosest ~= nil and {findClosest} or {true})[1]

    local pathfindDoneCallback = function(aStarSearchResult) self:onAStarDone(aStarSearchResult) end

    if self.owner.pathfinder:find(startPosition,endPosition,self.findClosest,false,false,pathfindDoneCallback,nil,pathfindSpeed,pathfindLimit) == false then
        -- if was an issue immediately checking the access to feeder, if leavefly and an issue occured then changes bird to hidden state.
        if self.feeder:checkFeederAccess(self.errorCallback) == false and self == self.owner.birdStates[self.owner.EBirdStates.LEAVEFLY] then
            self.owner:changeState(self.owner.EBirdStates.HIDDEN)
        end
        return false
    end

    return true
end

--- onAStarDone is the callback when AStar has completed a path.
--@param aStarSearchResult is the result from AStar, given as {path array {x=,y=,z=},bool if goal was reached}
function BirdStateBase:onAStarDone(aStarSearchResult)
    if self.owner == nil or self.feeder == nil then
        return
    end

    if aStarSearchResult[1] == nil then
        if self.feeder:checkFeederAccess(self.errorCallback) == false and self == self.owner.birdStates[self.owner.EBirdStates.LEAVEFLY] then
            self.owner:changeState(self.owner.EBirdStates.HIDDEN)
        end
        return
    end

    local lastDirection, customP0 = self.owner:getLastSplineDirectionAndP0()

    -- if self.spline is not nil then means the to be created spline will be joined no need to try smooth it at beginning
    if self.spline ~= nil then
        lastDirection = nil
        customP0 = nil
    end

    local callback = function(spline) self:onSplineDone(spline) end
    self.owner.splineCreator:createSpline(aStarSearchResult[1],callback,customP0,nil,lastDirection)
end

--- onSplineDone is callback when astar path has been made into a catmull-rom spline.
--@param spline is the CatmullRomSpline completed.
function BirdStateBase:onSplineDone(spline)
    if spline == nil or self.owner == nil or self.feeder == nil then
        return
    end

    -- if no previous spline already created then no need to combine
    if self.spline == nil then
        self.spline = spline
        self:checkSpline(self.spline)
    else -- if already has one spline saved, then needs to combine this new spline to the end of the existing spline.
        local callback = function(newSpline) self:checkSpline(newSpline) end
        self.owner.splineCreator:combineSplinesAtDistance(self.spline,spline,self.spline:getSplineLength(),callback)
    end

end

--- checkSpline is used to check the generated or combined spline if it is long enough to be returned to the state that started generation.
--@param spline newly created or combined CatmullRomSpline.
function BirdStateBase:checkSpline(spline)
    if spline == nil or self.owner == nil then
        return
    end

    if self.spline:getSplineLength() >= self.splineLengthLimit then
        local callback = self.callback
        local doneSpline = self.spline
        self:clean()
        callback(doneSpline)
    else
        local position,_,_,_ = self.spline:getSplineInformationAtDistance(self.spline:getSplineLength())
        self:createPath(position,self.owner:getRandomFlyAreaPoint(),self.callback,self.pathfindSpeed,self.pathfindLimit,self.splineLengthLimit,self.findClosest)
    end

end



--- IDLE FLY STATE CLASS ---
---@class BirdStateIdleFly.
BirdStateIdleFly = {}
BirdStateIdleFly_mt = Class(BirdStateIdleFly,BirdStateBase)
InitObjectClass(BirdStateIdleFly, "BirdStateIdleFly")

--- new creates a new idlefly state.
function BirdStateIdleFly.new()
    local self = BirdStateIdleFly:superClass().new(BirdStateIdleFly_mt)
    self.bGenerating = false
    self.landTimer = nil
    self.generatedSpline = nil
    return self
end

--- enter on entering idlefly state starts fly animation, starts path creation and timer for checking to land.
function BirdStateIdleFly:enter()
    BirdStateIdleFly:superClass().enter(self)

    if self.owner ~= nil and self.isClient then
        self.owner:setAnimation(self.owner.EBirdAnimations.FLY)
    end

    if self.isServer and self.owner ~= nil then
        self:setLandTimer()
        self:makeNewPath()
    end
end

--- leave idlefly state cleans up the timer and base state leave the pathfinder and splinecreator.
function BirdStateIdleFly:leave()
    BirdStateIdleFly:superClass().leave(self)
    self.bGenerating = false

    if self.landTimer ~= nil then
        self.landTimer:delete()
    end
    self.landTimer = nil
    self.generatedSpline = nil
end

--- update idlefly calls raiseactive on the bird as idlefly will have path that the bird needs to follow.
-- also checks if bufferpath becomes empty and possible to create a new path.
function BirdStateIdleFly:update(dt)
    BirdStateIdleFly:superClass().update(self,dt)

    if self.owner ~= nil then
        self.owner:raiseActive()
        if self.isServer and self.owner.bufferPath == nil and self.generatedSpline ~= nil then
            self.owner.bufferPath = self.generatedSpline
            self.generatedSpline = nil
        elseif self.isServer and self.owner.bufferPath == nil and self.bGenerating == false then
            self:makeNewPath()
        end
    end

end

--- setLandTimer used to set a new oneshot timer for checking if possible to start land on feeder.
function BirdStateIdleFly:setLandTimer()
    if self.owner == nil then
        return
    end

    local callback = function() self:onLandRequest() end
    self.landTimer = Timer.createOneshot(math.random(self.owner.minLandTryTime,self.owner.maxLandTryTime),callback)
end

--- onLandRequest is callback to the timer, checks if can land then changes to feederland, else timer again.
function BirdStateIdleFly:onLandRequest()
    self.landTimer = nil

    if self.feeder ~= nil and self.owner ~= nil then
        if self.feeder:isLandable() then
            self.owner:changeState(self.owner.EBirdStates.FEEDERLAND)
        else
            self:setLandTimer()
        end
    end
end

--- splienDoneCallback is called when random fly path has been generated, either placed in as current,buffer or saved for later.
--@param spline is the generated spline of type CatmullRomSpline.
function BirdStateIdleFly:splineDoneCallback(spline)
    if spline == nil then
        return
    end
    self.bGenerating = false
    if self.owner.currentPath == nil then
        self.owner.currentPath = spline
    elseif self.owner.bufferPath == nil then
        self.owner.bufferPath = spline
        self.owner.currentPath.segments[#self.owner.currentPath.segments].p3 = spline.segments[1].p2
    else
        self.generatedSpline = spline
    end
end

--- makeNewPath is used to start creating a new path from last path's last position or if no path exists then bird current position, to a random position within fly area.
function BirdStateIdleFly:makeNewPath()

    if self.isServer and self.owner ~= nil and self.owner.pathfinder ~= nil and not self.bGenerating then
        local callback = function(spline) self:splineDoneCallback(spline) end
        if BirdStateIdleFly:superClass().createPath(self,self.owner:getBirdNextStartPosition(),self.owner:getRandomFlyAreaPoint(),callback,5,200,self.owner.minPathLength) == false then
            return
        end
        self.bGenerating = true
    end
end

--- LEAVE FLY STATE CLASS ---
---@class BirdStateLeaveFly.
BirdStateLeaveFly = {}
BirdStateLeaveFly_mt = Class(BirdStateLeaveFly,BirdStateBase)
InitObjectClass(BirdStateLeaveFly, "BirdStateLeaveFly")

--- new creates a new leave fly state, used for generating a path back to the bird's start position.
function BirdStateLeaveFly.new()
    local self = BirdStateLeaveFly:superClass().new(BirdStateLeaveFly_mt)
    self.generatedSpline = nil
    return self
end

--- enter will set the animation to fly animation and start generating the path back to start position.
function BirdStateLeaveFly:enter()
    BirdStateLeaveFly:superClass().enter(self)

    if self.owner ~= nil and self.isClient then
        self.owner:setAnimation(self.owner.EBirdAnimations.FLY)
    end

    if self.owner ~= nil and self.feeder ~= nil and self.isServer and FlyPathfinding.bPathfindingEnabled then
        local goalPosition = self.owner.spawnPosition
        local startPosition = self.owner:getBirdNextStartPosition()
        local callback = function(spline) self:splineDoneCallback(spline) end
        BirdStateIdleFly:superClass().createPath(self,startPosition,goalPosition,callback,5,4000,0,false)
    end
end

--- leave will cleanup the generated spline in case the state changes before the path is needed.
function BirdStateLeaveFly:leave()
    BirdStateLeaveFly:superClass().leave(self)
    self.generatedSpline = nil
end

--- update used to check if bufferPath has become available and the leave path can be put in.
--@param dt is deltatime forwarded from the bird's update function, given in ms.
function BirdStateLeaveFly:update(dt)
    BirdStateLeaveFly:superClass().update(self,dt)

    if self.owner ~= nil then
        self.owner:raiseActive()
    end

    if self.generatedSpline ~= nil and self.owner ~= nil and self.owner.bufferPath == nil then
        self.owner.bufferPath = self.generatedSpline
        self.generatedSpline = nil
    end

end

--- splineDoneCallback is called when the leavefly path has been generated, will place it on currentPath, bufferPath or save it for later.
--@param spline is the generated spline of type CatmullRomSpline.
function BirdStateLeaveFly:splineDoneCallback(spline)
    if spline == nil then
        return
    end

    if self.owner.currentPath == nil then
        self.owner.currentPath = spline
    elseif self.owner.bufferPath == nil then
        self.owner.bufferPath = spline
    else
        self.generatedSpline = spline
    end

end


--- EAT STATE CLASS ---
---@class BirdStateEat.
BirdStateEat = {}
BirdStateEat_mt = Class(BirdStateEat,BirdStateBase)
InitObjectClass(BirdStateEat, "BirdStateEat")

--- new creates a new eat state, which used when bird is staying on the feeder and eating or idling if no food.
function BirdStateEat.new()
    local self = BirdStateEat:superClass().new(BirdStateEat_mt)
    self.soundTimer = nil
    self.generatedSpline = nil
    return self
end

--- enter prepares an "escape" path if player comes nearby to more quickly leave.
-- if a player is already nearby feeder when entering state immediately changes to idlefly again.
-- sets also a timer for playing a bird sing sound, while also subscribing to hour changed so that bird can eat hourly.
function BirdStateEat:enter()
    BirdStateEat:superClass().enter(self)
    if self.owner == nil or self.feeder == nil then
        return
    end

    if self.isServer then
        self.feeder:birdLandEvent(self.owner.rootNode,false)

        if not self.feeder:isLandable() then
            self.owner:changeState(self.owner.EBirdStates.IDLEFLY)
            return
        end

        -- slowly generated a "escape" path ready so when player comes near can immediately fly away and not spend time generating first.
        local goalPosition = self.owner:getRandomFlyAreaPoint()
        local startPosition = self.owner:getBirdNextStartPosition()
        local callback = function(spline) self:splineDoneCallback(spline) end
        BirdStateIdleFly:superClass().createPath(self,startPosition,goalPosition,callback,2,200,self.owner.minPathLength)

        g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)
    end

    -- if client and interpolating then making sure the position also gets set, as it could be not at target.
    local position = nil
    if self.isClient and self.owner.positionInterpolator ~= nil and self.owner.positionInterpolator.targetPositionX ~= nil then
        position = {}
        position.x, position.y, position.z = self.owner.positionInterpolator.targetPositionX, self.owner.positionInterpolator.targetPositionY, self.owner.positionInterpolator.targetPositionZ
    end

    self.owner:setPositionAndRotation(position,{x=0,y=math.random(-180,180),z=0},false)

    if self.isClient then
        self:setAnimation()
        local callback = function() self:soundTimerCallback() end
        self.soundTimer = Timer.createOneshot(math.random(self.owner.minSingDelay,self.owner.maxSingDelay),callback)
    end

end

--- leave on leaving the state the timer gets deleted and cleaning up other stuff.
function BirdStateEat:leave()
    BirdStateEat:superClass().leave(self)

    if self.soundTimer ~= nil then
        self.soundTimer:delete()
        self.soundTimer = nil
    end

    if self.isClient and self.owner ~= nil and self.owner.samples ~= nil and self.owner.samples.sing ~= nil then
        g_soundManager:stopSample(self.owner.samples.sing)
    end

    if self.isServer and self.owner ~= nil and self.feeder ~= nil then
        self.feeder:birdLandEvent(self.owner.rootNode,true)
        g_messageCenter:unsubscribe(MessageType.HOUR_CHANGED,self)
    end

    -- as this is the eat state the bird does not have any path currently, so can set the generated "escape" path to currentpath.
    if self.generatedSpline ~= nil then
        self.owner.currentPath = self.generatedSpline
        self.generatedSpline = nil
    end
end

--- soundTimerCallback is callback used for playing sing audio, afterwards sets a new timer again.
function BirdStateEat:soundTimerCallback()
    self.landTimer = nil

    if g_currentMission ~= nil and g_soundManager ~= nil and self.owner ~= nil and self.owner.samples ~= nil and self.owner.samples.sing ~= nil  then
        if g_currentMission.environment.currentHour < self.owner.singNightLimitStart and g_currentMission.environment.currentHour > self.owner.singNightLimitEnd then
            g_soundManager:playSample(self.owner.samples.sing)
        end
    end

    local callback = function() self:soundTimerCallback() end
    self.soundTimer = Timer.createOneshot(math.random(self.owner.minSingDelay,self.owner.maxSingDelay),callback)
end

--- onHourChanged is callback for each hour change, used to lower the amount of seed in feeder, if no food changes animation.
function BirdStateEat:onHourChanged()
    if self.owner == nil or self.feeder == nil then
        return
    end

    if self.feeder:seedEaten(self.owner.eatPerHour) == true then
        self:setAnimation()
    end

end

--- setAnimation used to set animation of bird in feeder depending on if there is seeds or not.
function BirdStateEat:setAnimation()
    if self.owner == nil or self.feeder == nil then
        return
    end

    local seedAmount = self.feeder:getBirdSeedFillLevel()
    if seedAmount > 0 then
        self.owner:setAnimation(self.owner.EBirdAnimations.EAT)
    else
        self.owner:setAnimation(self.owner.EBirdAnimations.IDLE)
    end
end

--- splienDoneCallback is callback for when "escape" path is generated, sets it aside, to use when leaving this state.
--@param spline is the generated spline of type CatmullRomSpline.
function BirdStateEat:splineDoneCallback(spline)
    self.generatedSpline = spline
end

--- BIRD FEEDER LAND STATE CLASS ---
---@class BirdStateFeederLand.
BirdStateFeederLand = {}
BirdStateFeederLand_mt = Class(BirdStateFeederLand,BirdStateBase)
InitObjectClass(BirdStateFeederLand, "BirdStateFeederLand")

--- new creates a new feederland state, which used to generate a path to the feeder to land.
function BirdStateFeederLand.new()
    local self = BirdStateFeederLand:superClass().new(BirdStateFeederLand_mt)
    self.generatedSpline = nil
    return self
end

--- enter on entering the feeder state a new path to feeder will be starting to be generated.
function BirdStateFeederLand:enter()
    BirdStateFeederLand:superClass().enter(self)

    if self.owner ~= nil and self.feeder ~= nil and self.isServer and FlyPathfinding.bPathfindingEnabled then
        local goalPosition = self.feeder:getRandomLandPosition()
        local startPosition = self.owner:getBirdNextStartPosition()
        local callback = function(spline) self:splineDoneCallback(spline) end
        BirdStateIdleFly:superClass().createPath(self,startPosition,goalPosition,callback,10,4000,0,false)
    end
end

--- leave on leaving the feederland if a path has been waiting to be swapped with bufferpath, but did not get swapped will nil the generated path.
function BirdStateFeederLand:leave()
    BirdStateFeederLand:superClass().leave(self)
    self.generatedSpline = nil
end

--- update will be checking if the bufferPath will become nil so that the ready path to feeder can be added, also keeps bird's update active.
--@param dt is deltatime forwarded from the bird's update function, given in ms.
function BirdStateFeederLand:update(dt)
    BirdStateFeederLand:superClass().update(self,dt)

    if self.owner ~= nil then
        self.owner:raiseActive()
    end

    if self.generatedSpline ~= nil and self.owner ~= nil and self.owner.bufferPath == nil then
        self.owner.bufferPath = self.generatedSpline
        self.generatedSpline = nil
    end

end

--- splineDoneCallback will be called when path to feeder is completely done, if currentPath or bufferPath is not nil then will set the path aside for waiting bufferPath becoming nil.
--@param spline is the generated spline of type CatmullRomSpline.
function BirdStateFeederLand:splineDoneCallback(spline)
    if spline == nil then
        return
    end

    if self.owner.currentPath == nil then
        self.owner.currentPath = spline
    elseif self.owner.bufferPath == nil then
        self.owner.bufferPath = spline
    else
        self.generatedSpline = spline
    end

end


--- BIRD FEEDER HIDDEN STATE CLASS ---
---@class BirdStateHidden.
BirdStateHidden = {}
BirdStateHidden_mt = Class(BirdStateHidden,BirdStateBase)
InitObjectClass(BirdStateHidden, "BirdStateHidden")

--- new creates a new hidden state used for hiding and unhiding the bird when feeder not active.
function BirdStateHidden.new()
    local self = BirdStateHidden:superClass().new(BirdStateHidden_mt)
    return self
end

--- enter on entering the hidden state will set the visibility of bird to false.
function BirdStateHidden:enter()
    BirdStateHidden:superClass().enter(self)

    if self.owner ~= nil then
        setVisibility(self.owner.rootNode,false)
    end

end

--- leave on leaving the hidden state will change the visibility to true of the bird.
function BirdStateHidden:leave()
    BirdStateHidden:superClass().leave(self)

    if self.owner ~= nil then
        setVisibility(self.owner.rootNode,true)
    end

end

