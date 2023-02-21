---Custom object class for the bird object

---@class FeederBird
FeederBird = {}
FeederBird.className = "FeederBird"
FeederBird_mt = Class(FeederBird,Object)
InitObjectClass(FeederBird, "FeederBird")

---new bird being created
function FeederBird.new(inOwner,isServer, isClient, customMt)
    local self = Object.new(isServer, isClient, customMt or FeederBird_mt)
    self.owner = inOwner
    self.i3dFilename = nil
    self.sharedLoadRequestId = nil
    self.rootID = nil
    self.flyPivotLocationX = 0
    self.flyPivotLocationY = 0
    self.flyPivotLocationZ = 0
    registerObjectClassName(self, "FeederBird")

    self.dirtyFlag = self:getNextDirtyFlag()
    return self
end

-- on deleting bird cleanup animation and the I3D file and the rest
function FeederBird:delete()

    if self.sharedLoadRequestId ~= nil then
        if self.flyAnimationIndex > -1 then
            disableAnimTrack(self.meshAnimChar,self.EBirdAnimations.FLY)
            clearAnimTrackClip(self.meshAnimChar,self.EBirdAnimations.FLY)
        end

        if self.eatAnimationIndex > -1 then
            disableAnimTrack(self.meshAnimChar,self.EBirdAnimations.EAT)
            clearAnimTrackClip(self.meshAnimChar,self.EBirdAnimations.EAT)
        end
        g_i3DManager:releaseSharedI3DFile(self.sharedLoadRequestId)
        self.sharedLoadRequestId = nil
        delete(self.rootID)
    end
    unregisterObjectClassName(self)
    g_messageCenter:unsubscribeAll(self)

    self.birdStates = nil
    self.components = nil
    self.EBirdStates = nil
    self.EBirdAnimations = nil

    FeederBird:superClass().delete(self)

end

function FeederBird.registerXMLPaths(schema, basePath)
    schema:register(XMLValueType.STRING,      basePath .. "#index",   "Node index id", "")
    schema:register(XMLValueType.STRING,      basePath .. "#flyAnimation",   "Animation name for flying", "")
    schema:register(XMLValueType.STRING,      basePath .. "#eatAnimation",   "Animation name for eating", "")
    schema:register(XMLValueType.INT,      basePath .. "#maxFlyRadius",   "A radius in which the bird can fly within of the feeder", 10)
    schema:register(XMLValueType.INT,      basePath .. "#leaveDistance",   "Distance until the birds have left and can delete them", 100)
    schema:register(XMLValueType.INT,      basePath .. "#noFoodHoursLeave",   "Hour value until the birds leave if no food in feeder", 5)


end

function FeederBird:update(dt)

    -- if currentState is valid then forward update to state's update
    if self.birdStates[self.currentState] ~= nil then
        self.birdStates[self.currentState]:update(dt)
    end


end

function FeederBird:readStream(streamId, connection)
    FeederBird:superClass().readStream(self, streamId, connection)

end

function FeederBird:writeStream(streamId, connection)
    FeederBird:superClass().writeStream(self, streamId, connection)

end

-- Creating the node by loading the i3d file
function FeederBird:createNode(i3dFilename)
    self.i3dFilename = i3dFilename
    self.customEnvironment, self.baseDirectory = Utils.getModNameAndBaseDirectory(i3dFilename)
    local node, sharedLoadRequestId = g_i3DManager:loadSharedI3DFile(i3dFilename, false, false)
    self.sharedLoadRequestId = sharedLoadRequestId
    self.components = {}

    if node ~= nil then
        I3DUtil.loadI3DComponents(node,self.components)
        link(getRootNode(),node)
        self.rootID = getChildAt(node,0)
    end

end


function FeederBird:load(xmlFile,i3dFilename, x,y,z, rx,ry,rz)
    self:createNode(i3dFilename)
    self.flyPivotLocationX, self.flyPivotLocationY, self.flyPivotLocationZ = x,y,z
    setTranslation(self.rootID, x, y, z)
    setRotation(self.rootID, rx, ry, rz)
    self.EBirdStates = {UNDEFINED = 0 , IDLEFLY = 1 , RETURNFLY = 2 , LEAVEFLY = 3 , EAT = 4, FEEDERLAND = 5, FEEDERLEAVE = 6 }
    self.EBirdAnimations = {FLY = 0, EAT = 1}
    self.birdStates = {}

    self.maxFlyRadius = Utils.getNoNil(xmlFile:getValue("placeable.placeableFeeder.birds.bird#maxFlyRadius"),10)
    self.leaveDistance = Utils.getNoNil(xmlFile:getValue("placeable.placeableFeeder.birds.bird#leaveDistance"),100)
    self.noFoodHoursLeave = Utils.getNoNil(xmlFile:getValue("placeable.placeableFeeder.birds.bird#noFoodHoursLeave"),5)

    self.skeletonID = I3DUtil.indexToObject(self.components,xmlFile:getValue("placeable.placeableFeeder.birds.bird#index"))
    self.meshAnimChar = getAnimCharacterSet(self.skeletonID)
    self.flyAnimationIndex = getAnimClipIndex(self.meshAnimChar, xmlFile:getValue("placeable.placeableFeeder.birds.bird#flyAnimation"))
    if self.flyAnimationIndex > -1 then
        assignAnimTrackClip(self.meshAnimChar, self.EBirdAnimations.FLY, self.flyAnimationIndex)
        setAnimTrackLoopState(self.meshAnimChar,self.EBirdAnimations.FLY,true)
    end

    self.eatAnimationIndex = getAnimClipIndex(self.meshAnimChar, xmlFile:getValue("placeable.placeableFeeder.birds.bird#eatAnimation"))
    if self.eatAnimationIndex > -1 then
        assignAnimTrackClip(self.meshAnimChar, self.EBirdAnimations.EAT, self.eatAnimationIndex)
        setAnimTrackLoopState(self.meshAnimChar,self.EBirdAnimations.EAT,true)
    end

    table.insert(self.birdStates,BirdStateIdleFly.new())
    self.birdStates[self.EBirdStates.IDLEFLY]:init(self,self.owner)
    table.insert(self.birdStates,BirdStateReturnFly.new())
    self.birdStates[self.EBirdStates.RETURNFLY]:init(self,self.owner)
    table.insert(self.birdStates,BirdStateLeaveFly.new())
    self.birdStates[self.EBirdStates.LEAVEFLY]:init(self,self.owner)
    table.insert(self.birdStates,BirdStateEat.new())
    self.birdStates[self.EBirdStates.EAT]:init(self,self.owner)
    table.insert(self.birdStates,BirdStateFeederLand.new())
    self.birdStates[self.EBirdStates.FEEDERLAND]:init(self,self.owner)
    table.insert(self.birdStates,BirdStateFeederLeave.new())
    self.birdStates[self.EBirdStates.FEEDERLEAVE]:init(self,self.owner)

    self.currentState = self.EBirdStates.UNDEFINED

    return true
end

function FeederBird:changeState(newState)

    if self.birdStates[newState] == nil then
        Logging.warning(string.format(FeederBird.className .. "changeState() Can't change FeederBird birdState to state: %d",newState))
        return
    end

    if self.currentState == newState then
        return
    end


    if self.currentState ~= self.EBirdStates.UNDEFINED then
        self.birdStates[self.currentState]:leave()
    end

    self.currentState = newState
    self.birdStates[self.currentState]:enter()

end


