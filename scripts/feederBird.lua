--[[
This file is part of Bird feeder mod (https://github.com/DennisB97/FS22BirdFeeder)
MIT License
Copyright (c) 2023 Dennis B

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

This mod is for personal use only and is not affiliated with GIANTS Software or endorsed by the game developer.
Selling or distributing this mod for a fee or any other form of consideration is prohibited by the game developer's terms of use and policies.
Please refer to the game developer's website for more information.
]]


--- Custom object class for the bird object.
---@class FeederBird.
FeederBird = {}
FeederBird.className = "FeederBird"
FeederBird.xmlSchema = nil
FeederBird_mt = Class(FeederBird,Object)
InitObjectClass(FeederBird, "FeederBird")

---new bird being created.
--@param inOwner is the feeder these birds belong to.
--@param isServer if is server the owner.
--@param isClient if client is owner.
--@return created FeederBird object.
function FeederBird.new(inOwner,isServer, isClient)
    local self = Object.new(isServer, isClient, FeederBird_mt)
    self.owner = inOwner
    self.isServer = isServer
    self.isClient = isClient
    self.i3dFilename = nil
    self.xmlFilename = nil
    self.sharedLoadRequestId = nil
    self.rootNode = nil
    self.isDeleted = false
    self.forcedClipDistance = 80
    self.networkTimeInterpolator = InterpolationTime.new(1.2)
    registerObjectClassName(self, "FeederBird")

    self.stateDirtyFlag = self:getNextDirtyFlag()
    self.birdDirtyFlag = self:getNextDirtyFlag()

    return self
end

--- delete bird cleanup animation and the I3D file and the rest.
function FeederBird:delete()

    if self.isDeleted then
        return
    end

    self.isDeleted = true

    if self.birdStates[self.currentState] ~= nil then
        self.birdStates[self.currentState]:leave()
    end

    if self.samples ~= nil and self.samples.sing ~= nil then
        g_soundManager:deleteSample(self.samples.sing)
        self.samples = nil
    end

    if self.sharedLoadRequestId ~= nil then

        if self.animations.flyBird[self.EBirdAnimations.FLY] ~= nil and self.animations.flyBird[self.EBirdAnimations.FLY] > -1 then
            disableAnimTrack(self.animations.flyBird.animationSets,self.EBirdAnimations.FLY)
            clearAnimTrackClip(self.animations.flyBird.animationSets,self.EBirdAnimations.FLY)
        end

        if self.animations.standBird[self.EBirdAnimations.EAT] ~= nil and self.animations.standBird[self.EBirdAnimations.EAT] > -1 then
            disableAnimTrack(self.animations.standBird.animationSets,self.EBirdAnimations.EAT)
            clearAnimTrackClip(self.animations.standBird.animationSets,self.EBirdAnimations.EAT)
        end

        if self.animations.standBird[self.EBirdAnimations.IDLE] ~= nil and self.animations.standBird[self.EBirdAnimations.IDLE] > -1 then
            disableAnimTrack(self.animations.standBird.animationSets,self.EBirdAnimations.IDLE)
            clearAnimTrackClip(self.animations.standBird.animationSets,self.EBirdAnimations.IDLE)
        end

        g_i3DManager:releaseSharedI3DFile(self.sharedLoadRequestId)
        self.sharedLoadRequestId = nil
        delete(self.rootNode)
    end

    if self.pathfinder ~= nil then
        self.pathfinder:delete()
    end

    if self.splineCreator ~= nil then
        self.splineCreator:delete()
    end

    self.currentPath = nil
    self.bufferPath = nil

    unregisterObjectClassName(self)
    g_messageCenter:unsubscribeAll(self)

    self.birdStates = nil
    self.components = nil
    self.EBirdStates = nil
    self.EBirdAnimations = nil
    self.currentPath = nil
    self.bufferPath = nil

    FeederBird:superClass().delete(self)
end

--- createXMLSchema create xml for bird and register som xml paths that bird requires.
function FeederBird.createXMLSchema()
    if FeederBird.xmlSchema ~= nil then
        return
    end
    local schema = XMLSchema.new("bird")
    local basePath = "bird"
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".general#birdNode", "root Node of bird")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".general#standBirdNode", "Node of bird standing mesh")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".general#flyBirdNode", "Node of bird flying mesh")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".general#birdSkeleton", "Node of bird skeleton")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".general#birdFlySkeleton", "Node of bird fly skeleton")
    schema:register(XMLValueType.STRING,      basePath .. ".animations#flyAnimation",   "Animation name for flying", "fly")
    schema:register(XMLValueType.STRING,      basePath .. ".animations#eatAnimation",   "Animation name for eating", "eat")
    schema:register(XMLValueType.STRING,      basePath .. ".animations#idleAnimation",   "Animation name for idling", "idle")
    schema:register(XMLValueType.FLOAT,      basePath .. ".general#eatPerHour",   "Amount of seeds eaten per h in g", "4")
    schema:register(XMLValueType.INT,      basePath .. ".general#minLandTryTime",   "Minimum seconds before try land while in idlefly state", "120")
    schema:register(XMLValueType.INT,      basePath .. ".general#maxLandTryTime",   "Maxmimum seconds before try land while in idlefly state", "240")
    schema:register(XMLValueType.INT,      basePath .. ".general#minPathLength",   "Minimum length of one path in meters to generate before assigning to buffer or currentpath", "150")
    schema:register(XMLValueType.INT,      basePath .. ".general#minSingDelay",   "Minimum delay for bird to sing once in seconds", "20")
    schema:register(XMLValueType.INT,      basePath .. ".general#maxSingDelay",   "Maximum delay for bird to sing once in seconds", "260")
    schema:register(XMLValueType.INT,      basePath .. ".general#singNightLimitStart",   "clock time when to stop bird from singing at night/evening", "20")
    schema:register(XMLValueType.INT,      basePath .. ".general#singNightLimitEnd",   "clock time when to enable bird to sing again", "7")
    I3DUtil.registerI3dMappingXMLPaths(schema, basePath)
    FeederBird.xmlSchema = schema
    SoundManager.registerSampleXMLPaths(schema, basePath .. ".sounds", "sing")
end

--- load called separately after creating a bird object.
-- loads the model and animations, audio and prepares states.
--@param xmlFilename is the bird's xml filename/path to load.
--@param i3dFilename is the model's i3d filename/path to load.
function FeederBird:load(xmlFilename,i3dFilename)

    if self:createNode(xmlFilename,i3dFilename) == false then
        Logging.warning("FeederBird:load: Issue loading bird")
        return
    end

    local x, y, z = getTranslation(self.rootNode)
    local xRot, yRot, zRot = getRotation(self.rootNode)
    self.sendPosX, self.sendPosY, self.sendPosZ = x, y, z
    self.sendRotX, self.sendRotY, self.sendRotZ = xRot, yRot, zRot

    if self.isClient then
        self.samples = {}
        self.samples.sing = g_soundManager:loadSampleFromXML(self.xmlFile, "bird.sounds", "sing", self.baseDirectory, self.components, 1, AudioGroup.ENVIRONMENT, self.i3dMappings, self)

        local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(xRot, yRot, zRot)
        self.positionInterpolator = InterpolatorPosition.new(x, y, z)
        self.quaternionInterpolator = InterpolatorQuaternion.new(quatX, quatY, quatZ, quatW)
    end

    self.EBirdStates = {UNDEFINED = 0 , IDLEFLY = 1 ,LEAVEFLY = 2 , EAT = 3, FEEDERLAND = 4, HIDDEN = 5 }
    self.EBirdAnimations = {FLY = 0, EAT = 1, IDLE = 2}
    self.birdStates = {}
    self.spawnPosition = nil
    self.minSingDelay = MathUtil.clamp(Utils.getNoNil(self.xmlFile:getValue("bird.general#minSingDelay"),20),10,1000)
    self.minSingDelay = self.minSingDelay * 1000 -- to ms which timer uses.
    self.maxSingDelay = MathUtil.clamp(Utils.getNoNil(self.xmlFile:getValue("bird.general#maxSingDelay"),260),10,1000)
    self.maxSingDelay = self.maxSingDelay * 1000 -- to ms which timer uses.
    self.singNightLimitStart = Utils.getNoNil(self.xmlFile:getValue("bird.general#singNightLimitStart"),20)
    self.singNightLimitEnd = Utils.getNoNil(self.xmlFile:getValue("bird.general#singNightLimitEnd"),7)

    if self.isServer and FS22_FlyPathfinding ~= nil then
        self.pathfinder = FS22_FlyPathfinding.AStar.new(self.isServer,self.isClient)
        self.pathfinder:register(true)

        self.splineCreator = FS22_FlyPathfinding.CatmullRomSplineCreator.new(self.isServer,self.isClient)
        self.splineCreator:register(true)

        -- later set the AABB area birds can fly in as {minX,minY,minZ,maxX,maxY,maxZ}
        self.flyAreaAABB = nil
        -- and the octree node which contains at least whole fly area aabb
        self.octreeNode = nil
        self.previousFlyPoint = nil
        self.bInterpolate = false
        -- in radians (= 40 degrees)
        self.maxPitch = 0.69813
        self.maxVelocity = 4
        self.currentPath = nil
        self.bufferPath = nil
        self.currentDistance = 0
        self.eatPerHour = math.abs(Utils.getNoNil(self.xmlFile:getValue("bird.general#eatPerHour"),4))
        -- min length in meters
        self.minPathLength = MathUtil.clamp(Utils.getNoNil(self.xmlFile:getValue("bird.general#minPathLength"),150),80,1000)
        -- in seconds received from xml file
        self.minLandTryTime = MathUtil.clamp(Utils.getNoNil(self.xmlFile:getValue("bird.general#minLandTryTime"),120),10,1000)
        self.maxLandTryTime = MathUtil.clamp(Utils.getNoNil(self.xmlFile:getValue("bird.general#maxLandTryTime"),240),10,1000)
        self.minLandTryTime = self.minLandTryTime * 1000 -- set to ms which timer uses.
        self.maxLandTryTime = self.maxLandTryTime * 1000 -- set to ms which timer uses.
    end

    self.skeletonNode = self.xmlFile:getValue("bird.general#birdSkeleton",nil,self.components,self.i3dMappings)
    self.flySkeletonNode = self.xmlFile:getValue("bird.general#birdFlySkeleton",nil,self.components,self.i3dMappings)
    self.standBirdNode = self.xmlFile:getValue("bird.general#standBirdNode",nil,self.components,self.i3dMappings)
    self.flyBirdNode = self.xmlFile:getValue("bird.general#flyBirdNode",nil,self.components,self.i3dMappings)
    self.animations = {}
    self.animations.standBird = {}
    self.animations.flyBird = {}

    if self.skeletonNode ~= nil and self.flySkeletonNode ~= nil then
        self.animations.standBird.animationSets = getAnimCharacterSet(self.skeletonNode)
        self.animations.flyBird.animationSets = getAnimCharacterSet(self.flySkeletonNode)

        self.animations.flyBird[self.EBirdAnimations.FLY] = getAnimClipIndex(self.animations.flyBird.animationSets, self.xmlFile:getValue("bird.animations#flyAnimation"))
        if self.animations.flyBird[self.EBirdAnimations.FLY] ~= nil and self.animations.flyBird[self.EBirdAnimations.FLY] > -1 then
            assignAnimTrackClip(self.animations.flyBird.animationSets, self.EBirdAnimations.FLY, self.animations.flyBird[self.EBirdAnimations.FLY])
            setAnimTrackLoopState(self.animations.flyBird.animationSets,self.EBirdAnimations.FLY,true)
            setAnimTrackSpeedScale(self.animations.flyBird.animationSets, self.EBirdAnimations.FLY, 2.0)
        end

        self.animations.standBird[self.EBirdAnimations.IDLE] = getAnimClipIndex(self.animations.standBird.animationSets, self.xmlFile:getValue("bird.animations#idleAnimation"))
        if self.animations.standBird[self.EBirdAnimations.IDLE] ~= nil and self.animations.standBird[self.EBirdAnimations.IDLE] > -1 then
            assignAnimTrackClip(self.animations.standBird.animationSets, self.EBirdAnimations.IDLE, self.animations.standBird[self.EBirdAnimations.IDLE])
            setAnimTrackLoopState(self.animations.standBird.animationSets,self.EBirdAnimations.IDLE,true)
        end

        self.animations.standBird[self.EBirdAnimations.EAT] = getAnimClipIndex(self.animations.standBird.animationSets, self.xmlFile:getValue("bird.animations#eatAnimation"))
        if self.animations.standBird[self.EBirdAnimations.EAT] ~= nil and self.animations.standBird[self.EBirdAnimations.EAT] > -1 then
            assignAnimTrackClip(self.animations.standBird.animationSets, self.EBirdAnimations.EAT, self.animations.standBird[self.EBirdAnimations.EAT])
            setAnimTrackLoopState(self.animations.standBird.animationSets,self.EBirdAnimations.EAT,true)
        end
    end

    -- client will also have the bird states
    self.birdStates[self.EBirdStates.IDLEFLY] = BirdStateIdleFly.new()
    self.birdStates[self.EBirdStates.IDLEFLY]:init(self,self.owner,self.isServer,self.isClient)
    self.birdStates[self.EBirdStates.LEAVEFLY] = BirdStateLeaveFly.new()
    self.birdStates[self.EBirdStates.LEAVEFLY]:init(self,self.owner,self.isServer,self.isClient)
    self.birdStates[self.EBirdStates.EAT] = BirdStateEat.new()
    self.birdStates[self.EBirdStates.EAT]:init(self,self.owner,self.isServer,self.isClient)
    self.birdStates[self.EBirdStates.FEEDERLAND] = BirdStateFeederLand.new()
    self.birdStates[self.EBirdStates.FEEDERLAND]:init(self,self.owner,self.isServer,self.isClient)
    self.birdStates[self.EBirdStates.HIDDEN] = BirdStateHidden.new()
    self.birdStates[self.EBirdStates.HIDDEN]:init(self,self.owner,self.isServer,self.isClient)
    self.currentState = self.EBirdStates.UNDEFINED
    self:changeState(self.EBirdStates.HIDDEN)

    return true
end

--- update function called every frame when bird not eating/idle.
--@param dt is deltatime in ms.
function FeederBird:update(dt)

    if BirdFeederMod.bDebug then
        self:debugRender(dt)
    end

    -- if currentState is valid then forward update to state's update
    if self.birdStates ~= nil and self.birdStates[self.currentState] ~= nil then
        self.birdStates[self.currentState]:update(dt)
    end

    -- on server will follow spline, but client will just get position and rotation synced.
    if self.isServer then
        self:steer(dt)
    else
        if self.networkTimeInterpolator:isInterpolating() then
            self.networkTimeInterpolator:update(dt)
            local interpolationAlpha = self.networkTimeInterpolator:getAlpha()
            local posX, posY, posZ = self.positionInterpolator:getInterpolatedValues(interpolationAlpha)
            local quatX, quatY, quatZ, quatW = self.quaternionInterpolator:getInterpolatedValues(interpolationAlpha)
            setTranslation(self.rootNode, posX, posY, posZ)
            setQuaternion(self.rootNode, quatX, quatY, quatZ, quatW)
        end
    end
end

--- getUpdatePriority part of object function. Taken how it works in PhysicsObject.
function FeederBird:getUpdatePriority(skipCount, x, y, z, coeff, connection, isGuiVisible)
    local x1, y1, z1 = getWorldTranslation(self.rootNode)
    local dist = math.sqrt((x1-x)*(x1-x) + (y1-y)*(y1-y) + (z1-z)*(z1-z))
    local clipDist = math.min(getClipDistance(self.rootNode)*coeff, self.forcedClipDistance)
    return (1-dist/clipDist)* 0.8 + 0.5*skipCount * 0.2
end

--- debugRender is a debugging function to render some information about the bird.
--@param dt is deltatime in ms, forwarded from update function.
function FeederBird:debugRender(dt)

    self:raiseActive()
    local positionX, positionY, positionZ = getWorldTranslation(self.rootNode)

    renderText3D(positionX - 1, positionY + 0.3, positionZ,0,0,0,0.25,"Current state:")
    renderText3D(positionX + 1.5, positionY + 0.3, positionZ,0,0,0,0.25,tostring(self.currentState))
    renderText3D(positionX - 1, positionY + 0.60, positionZ,0,0,0,0.25,"Current distance:")
    renderText3D(positionX + 1.5, positionY + 0.60, positionZ,0,0,0,0.25,tostring(self.currentDistance))
    renderText3D(positionX - 1, positionY + 0.90, positionZ,0,0,0,0.25,"currentPath:")
    renderText3D(positionX + 1.5, positionY + 0.90, positionZ,0,0,0,0.25,tostring(self.currentPath))
    renderText3D(positionX - 1, positionY + 1.20, positionZ,0,0,0,0.25,"bufferPath:")
    renderText3D(positionX + 1.5, positionY + 1.20, positionZ,0,0,0,0.25,tostring(self.bufferPath))

    if self.currentPath ~= nil then
        local length = self.currentPath:getSplineLength()
        renderText3D(positionX - 1, positionY + 1.50, positionZ,0,0,0,0.25,"Current path length:")
        renderText3D(positionX + 2, positionY + 1.50, positionZ,0,0,0,0.25,tostring(length))
    end

    DebugUtil.drawSimpleDebugCube(positionX, positionY, positionZ, 1, 1, 0, 0)
end

--- steer function is used to make bird follow the spline.
-- server only.
--@param dt is deltatime forwarded from update function.
function FeederBird:steer(dt)

    if self.isServer and self.currentPath ~= nil then
        self.currentDistance = self.currentDistance + ((dt/1000) * self.maxVelocity)
        local splineLength = self.currentPath:getSplineLength()
        local difference = math.abs(splineLength - self.currentDistance)
        local endPosition,endDirection,_,_ = self.currentPath:getSplineInformationAtDistance(splineLength)
        if self.currentDistance >= self.currentPath:getSplineLength() then
            self.currentPath = self.bufferPath
            self.bufferPath = nil
            self.currentDistance = difference
        end

        if self.currentPath ~= nil then
            local position,forwardDirection,_ = self.currentPath:getSplineInformationAtDistance(self.currentDistance)
            self:alignBirdWithSpline(position,forwardDirection)

        else
            self.currentDistance = 0
            self:alignBirdWithSpline(endPosition,endDirection)

            if self.currentState == self.EBirdStates.LEAVEFLY then
                if self.spawnPosition.x == endPosition.x and self.spawnPosition.y == endPosition.y and self.spawnPosition.z == endPosition.z then
                    self:changeState(self.EBirdStates.HIDDEN)
                end
            elseif self.currentState == self.EBirdStates.FEEDERLAND then
                self:changeState(self.EBirdStates.EAT)
            end
        end
    end
end

--- alignBirdWithSpline called to adjust the bird's rotation and location to current spline position.
-- server only.
--@param position is the current position on spline, given as {x=,y=,z=}.
--@param direction is the current forward vector on spline, given as {x=,y=,z=}.
function FeederBird:alignBirdWithSpline(position,direction)
    if position == nil or direction == nil then
        return
    end

    local newYRot = MathUtil.getYRotationFromDirection(direction.x,direction.z)
    local _,_,rotZ = getRotation(self.rootNode)

    local angle = MathUtil.dotProduct(direction.x,0,direction.z,direction.x,direction.y,direction.z)
    angle = math.acos(angle)

    local cross = {}
    cross.x, cross.y, cross.z = MathUtil.crossProduct(0,0,1,0,direction.y,1)

    if cross.x < 0 then
        angle = angle * -1
    end

    angle = MathUtil.clamp(angle,self.maxPitch * -1,self.maxPitch)

    self:setPositionAndRotation(position,{x=angle,y=newYRot,z=rotZ},false)
end

--- setPositionAndRotation handles changing the rotation and position of bird, also on clients and can be chosen to interpolate to directly set on clients.
--@param position is the position to be changed to given as {x=,y=,z=}.
--@param rotation is the euler angles to change to given as {x=,y=,z=}.
--@param shouldInterpolate is bool indicating if the client should have the new position or rotation interpolated or not.
function FeederBird:setPositionAndRotation(position,rotation,shouldInterpolate)

    if self.isClient and shouldInterpolate and self.positionInterpolator ~= nil and self.quaternionInterpolator ~= nil and self.networkTimeInterpolator ~= nil then
        if position ~= nil then
            self.positionInterpolator:setTargetPosition(position.x, position.y, position.z)
        end
        if rotation ~= nil then
            local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(rotation.x,rotation.y,rotation.z)
            self.quaternionInterpolator:setTargetQuaternion(quatX, quatY, quatZ, quatW)
        end

        self.networkTimeInterpolator:startNewPhaseNetwork()
    else
        if position ~= nil then
            setTranslation(self.rootNode, position.x, position.y, position.z)
        end
        if rotation ~= nil then
            setRotation(self.rootNode,rotation.x,rotation.y,rotation.z)
        end

        if self.isClient and self.positionInterpolator ~= nil and self.quaternionInterpolator ~= nil and self.networkTimeInterpolator ~= nil then
            if rotation ~= nil then
                local quatX, quatY, quatZ, quatW = mathEulerToQuaternion(rotation.x,rotation.y,rotation.z)
                self.quaternionInterpolator:setQuaternion(quatX, quatY, quatZ, quatW)
            end
            if position ~= nil then
                self.positionInterpolator:setPosition(position.x,position.y,position.z)
            end

            self.networkTimeInterpolator:reset()
        end

    end

end

--- updateTick called every network tick if raiseactive
--@param is deltatime in ms.
function FeederBird:updateTick(dt)

    if self.isServer then
        self:updateMove()
    end

    FeederBird:superClass().updateTick(self, dt)
end

--- updateMove sets the interpolation loc and rot to send for client if moved enough since last send, to avoid very tiny jitter movement.
-- server only.
function FeederBird:updateMove()
    local x, y, z = getWorldTranslation(self.rootNode)
    local xRot, yRot, zRot = getWorldRotation(self.rootNode)
    local hasMoved = math.abs(self.sendPosX-x)>0.005 or math.abs(self.sendPosY-y)>0.005 or math.abs(self.sendPosZ-z)>0.005 or
                     math.abs(self.sendRotX-xRot)>0.02 or math.abs(self.sendRotY-yRot)>0.02 or math.abs(self.sendRotZ-zRot)>0.02
    if hasMoved then
        self:raiseDirtyFlags(self.birdDirtyFlag)
        self.bInterpolate = true
        self.sendPosX, self.sendPosY, self.sendPosZ = x, y ,z
        self.sendRotX, self.sendRotY, self.sendRotZ = xRot, yRot, zRot
    end
    return hasMoved
end

--- readStream initial receive at start from server these variables.
function FeederBird:readStream(streamId, connection)

    if connection:getIsServer() then
        local state = streamReadInt8(streamId)
        self:changeState(state)
        local x = streamReadFloat32(streamId)
        local y = streamReadFloat32(streamId)
        local z = streamReadFloat32(streamId)
        local xRot = NetworkUtil.readCompressedAngle(streamId)
        local yRot = NetworkUtil.readCompressedAngle(streamId)
        local zRot = NetworkUtil.readCompressedAngle(streamId)
        self:setPositionAndRotation({x=x,y=y,z=z},{x=xRot,y=yRot,z=zRot},false)
    end
    FeederBird:superClass().readStream(self, streamId, connection)
end

--- writeStream initial sync at start from server to client these variables.
function FeederBird:writeStream(streamId, connection)

    if not connection:getIsServer() then
        streamWriteInt8(streamId,self.currentState)
        local x,y,z = getWorldTranslation(self.rootNode)
        local xRot,yRot,zRot = getWorldRotation(self.rootNode)
        streamWriteFloat32(streamId, x)
        streamWriteFloat32(streamId, y)
        streamWriteFloat32(streamId, z)
        NetworkUtil.writeCompressedAngle(streamId, xRot)
        NetworkUtil.writeCompressedAngle(streamId, yRot)
        NetworkUtil.writeCompressedAngle(streamId, zRot)
    end
    FeederBird:superClass().writeStream(self, streamId, connection)
end

--- readUpdateStream receives from server these variables when dirty raised on server.
function FeederBird:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then

        if streamReadBool(streamId) then
            local state = streamReadInt8(streamId)
            self:changeState(state)
        end

        if streamReadBool(streamId) then
            local bInterpolate = streamReadBool(streamId)
            local x = streamReadFloat32(streamId)
            local y = streamReadFloat32(streamId)
            local z = streamReadFloat32(streamId)
            local xRot = NetworkUtil.readCompressedAngle(streamId)
            local yRot = NetworkUtil.readCompressedAngle(streamId)
            local zRot = NetworkUtil.readCompressedAngle(streamId)
            self:setPositionAndRotation({x=x,y=y,z=z},{x=xRot,y=yRot,z=zRot},bInterpolate)
        end
    end

    FeederBird:superClass().readUpdateStream(self, streamId, timestamp, connection)
end

--- writeUpdateStream syncs from server to client these variabels when dirty raised.
function FeederBird:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then

        if streamWriteBool(streamId,bitAND(dirtyMask,self.stateDirtyFlag) ~= 0) then
            streamWriteInt8(streamId,self.currentState)
        end

        if streamWriteBool(streamId,bitAND(dirtyMask,self.birdDirtyFlag) ~= 0) then
            streamWriteBool(streamId,self.bInterpolate)
            streamWriteFloat32(streamId, self.sendPosX)
            streamWriteFloat32(streamId, self.sendPosY)
            streamWriteFloat32(streamId, self.sendPosZ)
            NetworkUtil.writeCompressedAngle(streamId, self.sendRotX)
            NetworkUtil.writeCompressedAngle(streamId, self.sendRotY)
            NetworkUtil.writeCompressedAngle(streamId, self.sendRotZ)
        end
    end

    FeederBird:superClass().writeUpdateStream(self, streamId, connection, dirtyMask)
end

--- createNode creates the model node by loading the i3d file.
--@param xmlFilename is the bird's xml filename/path to load.
--@param i3dFilename is the model's i3d filename/path to load.
function FeederBird:createNode(xmlFilename,i3dFilename)

    xmlFilename = Utils.getFilename(xmlFilename, BirdFeederMod.modDir)
    local xmlFile = XMLFile.load("bird", xmlFilename, FeederBird.xmlSchema)
    if xmlFile == nil then
        Logging.warning("XML file for bird was nil!")
        return false
    end
    self.xmlFile = xmlFile
    self.baseDirectory = BirdFeederMod.modDir
    i3dFilename = Utils.getFilename(i3dFilename, BirdFeederMod.modDir)
    local node, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(i3dFilename, false, false)
    self.sharedLoadRequestId = sharedLoadRequestId
    self.components = {}
    self.i3dMappings = {}

    if node ~= nil then
        I3DUtil.loadI3DComponents(node,self.components)
        I3DUtil.loadI3DMapping(xmlFile, "bird", self.components, self.i3dMappings)
        link(getRootNode(),node)
        self.rootNode = getChildAt(node,0)

        return true
    end

    return false
end

--- prepareBird is called to give the spawn, flyareaAABB and octreeNode which contains the aabb.
-- server only.
function FeederBird:prepareBird(spawnPosition,flyAreaAABB,octreeNodePivot)
    self.spawnPosition = spawnPosition
    self.flyAreaAABB = flyAreaAABB
    self.octreeNode = octreeNodePivot
    self:setPositionAndRotation(self.spawnPosition,nil,false)
    self.bInterpolate = false
    local x, y, z = getTranslation(self.rootNode)
    local xRot, yRot, zRot = getRotation(self.rootNode)
    self.sendPosX, self.sendPosY, self.sendPosZ = x, y, z
    self.sendRotX, self.sendRotY, self.sendRotZ = xRot, yRot, zRot
    self:raiseDirtyFlags(self.birdDirtyFlag)
end

--- changeState is called to change the bird state.
function FeederBird:changeState(newState)

    if newState == nil or self.currentState == newState then
        return
    end

    if self.birdStates[self.currentState] ~= nil then
        self.birdStates[self.currentState]:leave()
    end

    self.currentState = newState

    if self.birdStates[self.currentState] ~= nil then
        self.birdStates[self.currentState]:enter()
    end

    if self.isServer then
        self:raiseDirtyFlags(self.stateDirtyFlag)
    end

end

--- getRandomFlyAreaPoint is used to get a random position to fly to within flyAreaAABB.
-- server only
--@return a position to pathfind to, given as {x=,y=,z=}.
function FeederBird:getRandomFlyAreaPoint()

    if self.flyAreaAABB == nil or self.octreeNode == nil or g_currentMission == nil then
        return nil
    end

    local foundNode = {nil,-1}
    local flyPoint = {}
    local tryLimit = 500
    local currentTries = 0

    while foundNode[1] == nil do

        if currentTries >= tryLimit then
            return nil
        end


        flyPoint.x = math.random(self.flyAreaAABB[1],self.flyAreaAABB[4])
        flyPoint.y = math.random(self.flyAreaAABB[2],self.flyAreaAABB[5])
        flyPoint.z = math.random(self.flyAreaAABB[3],self.flyAreaAABB[6])
        flyPoint.x = MathUtil.clamp(flyPoint.x,self.flyAreaAABB[1],self.flyAreaAABB[4])
        flyPoint.y = MathUtil.clamp(flyPoint.y,self.flyAreaAABB[2],self.flyAreaAABB[5])
        flyPoint.z = MathUtil.clamp(flyPoint.z,self.flyAreaAABB[3],self.flyAreaAABB[6])

        local terrainHeight = 0
        if g_currentMission.terrainRootNode ~= nil then
            terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,flyPoint.x,flyPoint.y,flyPoint.z)
        end

        -- clamp y so that it is 2m from ground that it can fly to at minimum, grid path might get lower though.
        flyPoint.y = MathUtil.clamp(flyPoint.y,terrainHeight + 2,self.flyAreaAABB[5])

        foundNode = FS22_FlyPathfinding.g_GridMap3D:getGridNode(flyPoint,false,self.octreeNode[1])

        -- Check that the found fly point is not too close to previous node
        if foundNode[1] ~= nil and self.previousFlyPoint ~= nil then
            local distance = MathUtil.vector3Length(flyPoint.x - self.previousFlyPoint.x, flyPoint.y - self.previousFlyPoint.y, flyPoint.z - self.previousFlyPoint.z)
            if distance < 8 then
                foundNode = {nil,-1}
            end
        elseif self.currentPath == nil and self.bufferPath == nil then
            local birdPosition = {}
            birdPosition.x, birdPosition.y, birdPosition.z = getTranslation(self.rootNode)
            local distance = MathUtil.vector3Length(flyPoint.x - birdPosition.x, flyPoint.y - birdPosition.y, flyPoint.z - birdPosition.z)
            if distance < 8 then
                foundNode = {nil,-1}
            end
        end

        currentTries = currentTries + 1
    end
    self.previousFlyPoint = flyPoint
    return flyPoint
end

--- getBirdNextStartPosition gets the next start position for next path start point.
-- server only.
--@return a position from to start pathfinding, given as {x=,y=,z=}.
function FeederBird:getBirdNextStartPosition()

    if self.bufferPath ~= nil then
        local position,_,_,_ = self.bufferPath:getSplineInformationAtDistance(self.bufferPath:getSplineLength())
        return {x=position.x,y=position.y,z=position.z}
    elseif self.currentPath ~= nil then
        local position,_,_,_ = self.currentPath:getSplineInformationAtDistance(self.currentPath:getSplineLength())
        return {x=position.x,y=position.y,z=position.z}
    else
        local birdPosition = {}
        birdPosition.x, birdPosition.y, birdPosition.z = getTranslation(self.rootNode)
        return {x=birdPosition.x,y=birdPosition.y,z=birdPosition.z}
    end

end

--- setAnimation used to set the animation of bird.
--@param eAnimation is the animation to change to from the self.EBirdAnimations.
function FeederBird:setAnimation(eAnimation)
    if eAnimation == nil then
        return
    end

    -- hides the standing mesh if using fly animation and also enables the aniamtion on correct animation character set.
    if eAnimation == self.EBirdAnimations.FLY and self.animations.flyBird[eAnimation] ~= nil then
        setVisibility(self.standBirdNode,false)
        setVisibility(self.flyBirdNode,true)
        enableAnimTrack(self.animations.flyBird.animationSets, eAnimation)
    elseif self.animations.standBird[eAnimation] ~= nil then
        setVisibility(self.flyBirdNode,false)
        setVisibility(self.standBirdNode,true)
        enableAnimTrack(self.animations.standBird.animationSets, eAnimation)
    end

end


--- onActive is called when feeder has received some food to tell bird to activate.
-- server only.
function FeederBird:onActive()
    if self.spawnPosition == nil then
        return
    end

    if self.currentState ~= self.EBirdStates.EAT and self.currentState ~= self.EBirdStates.FEEDERLAND then
        self:changeState(self.EBirdStates.IDLEFLY)
    end
end

--- onInActive is called when feeder has no food to tell bird to leave.
-- server only.
function FeederBird:onInActive()

    if self.currentState ~= self.EBirdStates.LEAVEFLY and self.currentState ~= self.EBirdStates.HIDDEN then
        self:changeState(self.EBirdStates.LEAVEFLY)
    end

end

--- getLastSplineDirectionAndP0 used to get last spline's direction and suitable p0 for the next spline.
function FeederBird:getLastSplineDirectionAndP0()

    local customP0 = nil
    local lastDirection = nil

    if self.owner.bufferPath ~= nil then
        local lastSegment = self.owner.bufferPath.segments[#self.owner.bufferPath.segments]
        customP0.x,customP0.y,customP0.z = lastSegment.p1.x, lastSegment.p1.y, lastSegment.p1.z
        lastDirection = {}
        lastDirection.x, lastDirection.y, lastDirection.z = MathUtil.vector3Normalize(lastSegment.p2.x - lastSegment.p1.x,lastSegment.p2.y - lastSegment.p1.y, lastSegment.p2.z - lastSegment.p1.z)
    elseif self.owner.currentPath ~= nil then
        local lastSegment = self.owner.currentPath.segments[#self.owner.currentPath.segments]
        customP0.x,customP0.y,customP0.z = lastSegment.p1.x, lastSegment.p1.y, lastSegment.p1.z
        lastDirection = {}
        lastDirection.x, lastDirection.y, lastDirection.z = MathUtil.vector3Normalize(lastSegment.p2.x - lastSegment.p1.x,lastSegment.p2.y - lastSegment.p1.y, lastSegment.p2.z - lastSegment.p1.z)
    end

    return lastDirection, customP0
end




