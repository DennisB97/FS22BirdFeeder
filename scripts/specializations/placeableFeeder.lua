---Bird Feeder specialization for placeables

---@class PlaceableFeeder
PlaceableFeeder = {}
PlaceableFeeder.className = "PlaceableFeeder"




function PlaceableFeeder.initSpecialization()
    -- TEMP DEBUG
    addConsoleCommand('pfRemoveSeeds', 'removes seeds', 'removeSeeds', self)
end


---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function PlaceableFeeder.prerequisitesPresent(specializations)
    return true;
end



---Register all needed FS events
function PlaceableFeeder.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onPlaceableFeederFillLevelChanged",PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onPlaceableFeederBecomeActive",PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onPlaceableFeederBecomeInActive",PlaceableFeeder)

end

---Register new functions
function PlaceableFeeder.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "getBirdSeedCapacity",PlaceableFeeder.getBirdSeedCapacity)
    SpecializationUtil.registerFunction(placeableType, "getBirdSeedFillLevel",PlaceableFeeder.getBirdSeedFillLevel)
    SpecializationUtil.registerFunction(placeableType, "onAddedStorageToUnloadingStation", PlaceableFeeder.onAddedStorageToUnloadingStation)
    SpecializationUtil.registerFunction(placeableType, "onRemovedStorageFromUnloadingStation", PlaceableFeeder.onRemovedStorageFromUnloadingStation)
    SpecializationUtil.registerFunction(placeableType, "removeSeeds", PlaceableFeeder.removeSeeds)
    SpecializationUtil.registerFunction(placeableType, "consoleCommandRaycastCallback", PlaceableFeeder.consoleCommandRaycastCallback)
    SpecializationUtil.registerFunction(placeableType, "changeState", PlaceableFeeder.changeState)
    SpecializationUtil.registerFunction(placeableType, "createBirds", PlaceableFeeder.createBirds)
    SpecializationUtil.registerFunction(placeableType, "getRandomBirdSpawn", PlaceableFeeder.getRandomBirdSpawn)
    SpecializationUtil.registerFunction(placeableType, "getBirdSpawnOverlapCallback", PlaceableFeeder.getBirdSpawnOverlapCallback)
    SpecializationUtil.registerFunction(placeableType, "testCheck", PlaceableFeeder.testCheck)
end

---Register new events
function PlaceableFeeder.registerEvents(placeableType)
    SpecializationUtil.registerEvent(placeableType, "onPlaceableFeederFillLevelChanged")
    SpecializationUtil.registerEvent(placeableType, "onPlaceableFeederBecomeActive")
    SpecializationUtil.registerEvent(placeableType, "onPlaceableFeederBecomeInActive")
end

---Register overwritten functions
function PlaceableFeeder.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", PlaceableFeeder.collectPickObjectsOW)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", PlaceableFeeder.updateInfoPlaceableFeeder)
end


---On loading creates the unloading station and storage and creates some states for bird management
function PlaceableFeeder:onLoad(savegame)
	--- Registering the spec
	self.spec_placeableFeeder = self["spec_FS22_BirdFeeder.placeableFeeder"]
    local xmlFile = self.xmlFile
    local spec = self.spec_placeableFeeder
    -- Set the title of the to be displayed on tiny UI box when player overlaps
    spec.info = {title=g_i18n:getText("fillType_birdSeed"), text=""}
    -- get max number birds possible specified in xml file, hardcap of 10 coded in though.
    spec.maxNumberBirds = Utils.getNoNil(xmlFile:getValue("placeable.placeableFeeder.birds#maxNumberBirds"),5)
    spec.EBirdSystemStates = {UNDEFINED = 0 , INACTIVE = 1 , RETURN = 2 , LEAVE = 3 , ACTIVE = 4 }
    spec.birds = {}
    spec.birdStates = {}
    spec.birdSpawnAreaX = nil
    spec.birdSpawnAreaY = nil
    spec.birdSpawnAreaZ = nil
    -- Declare a radius the birds spawn in above the feeder
    spec.birdSpawnAreaRadius = 1
    -- TEMP LOW VALUE, how high up the birds spawn when food is inserted
    spec.birdSpawnHeight = 5
    -- Boolean used to know if this feeder has a clear spawn area above in the sky
    spec.birdSpawnAreaClear = false

    -- Create the bird system states and init them, giving this feeder ref to the states
    table.insert(spec.birdStates,BirdSystemInActiveState.new())
    spec.birdStates[spec.EBirdSystemStates.INACTIVE]:init(self)
    table.insert(spec.birdStates,BirdSystemReturnState.new())
    spec.birdStates[spec.EBirdSystemStates.RETURN]:init(self)
    table.insert(spec.birdStates,BirdSystemLeaveState.new())
    spec.birdStates[spec.EBirdSystemStates.LEAVE]:init(self)
    table.insert(spec.birdStates,BirdSystemActiveState.new())
    spec.birdStates[spec.EBirdSystemStates.ACTIVE]:init(self)

    -- The become active or become inactive function will handle later setting the initial state
    spec.currentState = spec.EBirdSystemStates.UNDEFINED

    -- Get random number of birds to use, hard cap of 10.
    spec.maxNumberBirds = math.random(1,math.min(math.max(spec.maxNumberBirds,1),10))

    -- Create a storage and load it
    spec.storage = Storage.new(self.isServer, self.isClient)
    if not spec.storage:load(self.components, xmlFile, "placeable.placeableFeeder.storage", self.i3dMappings) then
        spec.storage:delete()
        Logging.xmlError(xmlFile, "Failed to load storage")
        self:setLoadingState(Placeable.LOADING_STATE_ERROR)
        return
    end

    -- Create a unloadingStation
    if xmlFile:hasProperty("placeable.placeableFeeder.unloadingStation") then
        spec.unloadingStation = UnloadingStation.new(self.isServer, self.isClient)
        if spec.unloadingStation:load(self.components, xmlFile, "placeable.placeableFeeder.unloadingStation", self.customEnvironment, self.i3dMappings, self.components[1].node) then
            spec.unloadingStation.owningPlaceable = self
            spec.unloadingStation.hasStoragePerFarm = false
        else
            spec.unloadingStation:delete()
            Logging.xmlError(xmlFile, "Failed to load unloading station")
            self:setLoadingState(Placeable.LOADING_STATE_ERROR)
            return
        end
    end

    -- Create a function callback which raises the event for when fill level in storage has changed
    spec.fillLevelChangedCallback = function(fillType, delta)
        SpecializationUtil.raiseEvent(self, "onPlaceableFeederFillLevelChanged", fillType, delta)
    end




end

---When placeable feeder deleted, clean up the unloading station and storage and birds
function PlaceableFeeder:onDelete()

    local spec = self.spec_placeableFeeder
    local storageSystem = g_currentMission.storageSystem


    if spec.unloadingStation ~= nil then
        storageSystem:removeStorageFromUnloadingStations(spec.storage, {spec.unloadingStation})
        storageSystem:removeUnloadingStation(spec.unloadingStation, self)
        spec.unloadingStation:delete()
        spec.unloadingStation = nil
    end

    if spec.storage ~= nil then
        storageSystem:removeStorage(spec.storage)
        spec.storage:delete()
        spec.storage = nil
    end

    if #spec.birds ~= 0 then
        for _, bird in pairs(spec.birds) do
            if bird ~= nil then
                bird:delete()
            end
        end
    end

    spec.birds = nil

    g_messageCenter:unsubscribe(MessageType.STORAGE_ADDED_TO_UNLOADING_STATION, self)
    g_messageCenter:unsubscribe(MessageType.STORAGE_REMVOED_FROM_UNLOADING_STATION, self)

end

---Update function, called when raiseActive called and initially
function PlaceableFeeder:onUpdate(dt)
    local spec = self.spec_placeableFeeder

--     self:raiseActive()
--     local PlayerX, PlayerY, PlayerZ = getWorldTranslation(g_currentMission.player.rootNode);
--     print(string.format("X: %f, Y: %f, Z: %f",PlayerX,PlayerY,PlayerZ))
--

    -- Forward update to current state if valid
    if spec.birdStates[spec.currentState] ~= nil then
        spec.birdStates[spec.currentState]:update()
    end



end


---Event on finalizing the placement of this bird feeder
function PlaceableFeeder:onFinalizePlacement()
    local spec = self.spec_placeableFeeder

    local storage = spec.storage
    local unloadingStation = spec.unloadingStation
    local storageSystem = g_currentMission.storageSystem
    local farmId = self:getOwnerFarmId()

    g_messageCenter:subscribe(MessageType.STORAGE_ADDED_TO_UNLOADING_STATION, self.onAddedStorageToUnloadingStation, self)
    g_messageCenter:subscribe(MessageType.STORAGE_REMOVED_FROM_UNLOADING_STATION, self.onRemovedStorageFromUnloadingStation, self)

    if unloadingStation ~= nil then
        unloadingStation:setOwnerFarmId(farmId, true)
        unloadingStation:register(true)
        storageSystem:addUnloadingStation(unloadingStation, self)
    end

    if storage ~= nil then
        storage:setOwnerFarmId(farmId, true)
        storage:register(true)
        storageSystem:addStorage(storage)
        if unloadingStation ~= nil then
            storageSystem:addStorageToUnloadingStation(storage, unloadingStation)
        end
    end

end

---Registering placeable feeder's xml paths and its objects
function PlaceableFeeder.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("PlaceableFeeder")
    schema:register(XMLValueType.INT,        basePath .. ".placeableFeeder.birds#maxNumberBirds", "Maximum number of birds")
    schema:register(XMLValueType.NODE_INDEX,    basePath .. ".placeableFeeder.birds#node", "Feeder node, used for locating the food and spawning birds.")
    Storage.registerXMLPaths(schema,            basePath .. ".placeableFeeder.storage")
    UnloadingStation.registerXMLPaths(schema, basePath .. ".placeableFeeder.unloadingStation")
    FeederBird.registerXMLPaths(schema,basePath .. ".placeableFeeder.birds.bird")
end

---Registering placeable feeder's savegame xml paths
function PlaceableFeeder.registerSavegameXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("PlaceableFeeder")
    Storage.registerSavegameXMLPaths(schema, basePath .. ".storage")
    schema:setXMLSpecializationType()
end

---On saving, save existing storage to xml file
function PlaceableFeeder:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_placeableFeeder

    if spec.storage ~= nil then
        spec.storage:saveToXMLFile(xmlFile, key .. ".storage", usedModNames)
    end
end

---On loading, load storage from xml file
function PlaceableFeeder:loadFromXMLFile(xmlFile, key)
    local spec = self.spec_placeableFeeder
    if not spec.storage:loadFromXMLFile(xmlFile, key .. ".storage") then
        return false
    end

    -- Raise the event on load so that the feeder can be set to active or load depending on storage situation
    SpecializationUtil.raiseEvent(self, "onPlaceableFeederFillLevelChanged", FillType.BIRDFEED, 0)
    return true
end

--- Network read stream
function PlaceableFeeder:onReadStream(streamId, connection)
    local spec = self.spec_placeableFeeder
    if spec.unloadingStation ~= nil then
        local unloadingStationId = NetworkUtil.readNodeObjectId(streamId)
        spec.unloadingStation:readStream(streamId, connection)
        g_client:finishRegisterObject(spec.unloadingStation, unloadingStationId)
    end

    if spec.storage ~= nil then
        local storageId = NetworkUtil.readNodeObjectId(streamId)
        spec.storage:readStream(streamId, connection)
        g_client:finishRegisterObject(spec.storage, storageId)
    end

end

--- Network write stream
function PlaceableFeeder:onWriteStream(streamId, connection)
    local spec = self.spec_placeableFeeder
    if spec.unloadingStation ~= nil then
        NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.unloadingStation))
        spec.unloadingStation:writeStream(streamId, connection)
        g_server:registerObjectInStream(connection, spec.unloadingStation)
    end

    if spec.storage ~= nil then
        NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(spec.storage))
        spec.storage:writeStream(streamId, connection)
        g_server:registerObjectInStream(connection, spec.storage)
    end

end


---Get seed capacity from existing storage
-- @return number of seed capacity
function PlaceableFeeder:getBirdSeedCapacity()

    if self.spec_placeableFeeder.storage ~= nil then
        return Utils.getNoNil(self.spec_placeableFeeder.storage.capacity,0)
    end

    return 0
end

---Get the current seed fill level from existing storage
-- @return number of seed in storage
function PlaceableFeeder:getBirdSeedFillLevel()

    if self.spec_placeableFeeder.storage ~= nil then
        return Utils.getNoNil(self.spec_placeableFeeder.storage.fillLevels[FillType.BIRDSEED],0)
    end

    return 0
end

---Event function for when seed level has changed in storage
function PlaceableFeeder:onPlaceableFeederFillLevelChanged(fillType,delta)
    local spec = self.spec_placeableFeeder
    local currentFillLevel = self:getBirdSeedFillLevel()

    -- Check if fill level has become over 0, and state is inactive in some way, then needs to be activated for birds to come eat.
    if spec.currentState == spec.EBirdSystemStates.INACTIVE and currentFillLevel > 0 or spec.currentState == spec.EBirdSystemStates.UNDEFINED and currentFillLevel > 0
        or spec.currentState == spec.EBirdSystemStates.LEAVING and currentFillLevel > 0 then
            SpecializationUtil.raiseEvent(self,"onPlaceableFeederBecomeActive")
    -- In case where filllevel is 0 and is still active , then need to raise inactive event so birds will go away, no food.
    elseif spec.currentState == spec.EBirdSystemStates.ACTIVE and currentFillLevel == 0 or spec.currentState == spec.EBirdSystemStates.UNDEFINED and currentFillLevel == 0 then
        SpecializationUtil.raiseEvent(self,"onPlaceableFeederBecomeInActive")
    end

end


function PlaceableFeeder:onPlaceableFeederBecomeActive()
    local spec = self.spec_placeableFeeder

    if #spec.birds == 0 then
        -- No birds still created, need to create them and then set state to birds returning state
        self:createBirds()
    end

    self:changeState(spec.EBirdSystemStates.RETURN)

end

function PlaceableFeeder:onPlaceableFeederBecomeInActive()
    local spec = self.spec_placeableFeeder


    if #spec.birds ~= 0 then
        -- If birds exists need to make system to leave them away
        self:changeState(spec.EBirdSystemStates.LEAVE)
    else
        -- If there is no birds then can simply make the system inactive to wait for food
        self:changeState(spec.EBirdSystemStates.INACTIVE)
    end

end


---Add a function callback to storage fill level changed event
function PlaceableFeeder:onAddedStorageToUnloadingStation(storage, unloadingStation)
    local spec = self.spec_placeableFeeder
    if spec.unloadingStation ~= nil and spec.unloadingStation == unloadingStation then
        storage:addFillLevelChangedListeners(spec.fillLevelChangedCallback)
    end
end

---Remove function callback to storage fill level changed event
function PlaceableFeeder:onRemovedStorageFromUnloadingStation(storage, unloadingStation)
    local spec = self.spec_placeableFeeder
    if spec.unloadingStation ~= nil and spec.unloadingStation == unloadingStation then
        storage:removeFillLevelChangedListeners(spec.fillLevelChangedCallback)
    end
end



---Overridden updateInfo function, to show seed level and capacity when overlapping trigger box
function PlaceableFeeder:updateInfoPlaceableFeeder(superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_placeableFeeder

    local capacity = self:getBirdSeedCapacity()
    local fillLevel = self:getBirdSeedFillLevel()
	spec.info.text = string.format("%d", fillLevel) .. " / " .. string.format("%d g", capacity)
	table.insert(infoTable, spec.info)
end

---Overriden function for collecting pickable objects, avoiding error for trigger node getting added twice
function PlaceableFeeder:collectPickObjectsOW(superFunc,node)
    local spec = self.spec_placeableFeeder
    local bExists = false

    if spec == nil then
        superFunc(self,node)
        return
    end

    if getRigidBodyType(node) ~= RigidBodyType.NONE then
       for _, loadTrigger in ipairs(spec.unloadingStation.unloadTriggers) do
            if node == loadTrigger.exactFillRootNode then
                bExists = true
                break
            end
        end
    end

    if not bExists then
        superFunc(self,node)
    end

end

-- TEMP DEBUG FUNCTION
function PlaceableFeeder:consoleCommandRaycastCallback(actorId, x,y,z, distance, nx,ny,nz, subShapeIndex, shapeId, isLast)

    if actorId ~= 0 then
        local object = g_currentMission:getNodeObject(actorId)
        if object ~= nil then
            if object.target.owningPlaceable.spec_placeableFeeder.storage ~= nil then
            object.target.owningPlaceable.spec_placeableFeeder.storage:setFillLevel(0,FillType.BIRDSEED,nil)
            end
        return true
        end

    end
    return false
end

-- TEMP DEBUG FUNCTION
function PlaceableFeeder.removeSeeds()

    local x,y,z = getWorldTranslation(getCamera(0))
    raycastAll(x,y,z, 0, 1, 0, "consoleCommandRaycastCallback", 110, self)

end

-- Function for changing the state of bird system states
function PlaceableFeeder:changeState(newState)
    local spec = self.spec_placeableFeeder

    -- check if newState is a valid state
    if spec.birdStates[newState] == nil then
        Logging.warning(string.format(PlaceableFeeder.className .. "changeState() Can't change PlaceableFeeder birdSystemState to state: %d",newState))
        return
    end

    -- if same as current just return
    if spec.currentState == newState then
        return
    end

    -- If current undefined then can't leave undefined state
    if spec.currentState ~= spec.EBirdSystemStates.UNDEFINED then
        spec.birdStates[spec.currentState]:leave()
    end

    -- set new current state and enter the state
    spec.currentState = newState
    spec.birdStates[spec.currentState]:enter()

end

-- Function for creating the bird objects with a random spawn location up in the sky
function PlaceableFeeder:createBirds()
    local spec = self.spec_placeableFeeder


    for i = 1, spec.maxNumberBirds, 1 do
        local x,y,z = self:getRandomBirdSpawn(getWorldTranslation(getChildAt(self.rootNode,0)))
        local bird = FeederBird.new(self,self.isServer, self.isClient)
        bird:load(self.xmlFile,Utils.getFilename("bird.i3d",self.baseDirectory),x,y,z,0,0,0)
        bird:register(true)
        bird:changeState(bird.EBirdStates.IDLEFLY)
        table.insert(spec.birds,bird)
    end


end

function PlaceableFeeder:testCheck(hitObjectId)

    print("testing collision checking: id was: " .. tostring(hitObjectId))
    print("entity exists: " .. tostring(entityExists(hitObjectId)))
    print("node object: " .. tostring(g_currentMission:getNodeObject(hitObjectId)))
    print("has geometry classID: " .. tostring(getHasClassId(hitObjectId,ClassIds.GEOMETRY)))
    print("has shape classID: " .. tostring(getHasClassId(hitObjectId,ClassIds.SHAPE)))

    return true
end


-- A function that returns a random x y z coordinates up in the sky above the bird feeder which is clear of obstacles
function PlaceableFeeder:getRandomBirdSpawn(feederLocationX,feederLocationY,feederLocationZ)
    local spec = self.spec_placeableFeeder
    feederLocationY = feederLocationY + spec.birdSpawnHeight
    local x,y,z = feederLocationX,feederLocationY,feederLocationZ


    local collisionMask = CollisionFlag.STATIC_OBJECT + CollisionFlag.STATIC_OBJECTS + CollisionFlag.DYNAMIC_OBJECT +
        CollisionFlag.TRACTOR + CollisionFlag.TREE + CollisionFlag.WATER + CollisionFlag.VEHICLE + CollisionFlag.FILLABLE

    local maxTries = 30
    local currentTries = 0

    while spec.birdSpawnAreaX == nil do
        overlapSphere(x,y,z,spec.birdSpawnAreaRadius,"getBirdSpawnOverlapCallback",self,collisionMask,true,true,false,false)

        if spec.birdSpawnAreaClear == true then
            spec.birdSpawnAreaX = x
            spec.birdSpawnAreaY = y
            spec.birdSpawnAreaZ = z
        else
            x = x + 1
            y = y + 1
        end
        currentTries = currentTries + 1

        if currentTries == maxTries then
            return 0,300,0
        end
    end


    x = Utils.randomFloat(spec.birdSpawnAreaX - spec.birdSpawnAreaRadius,spec.birdSpawnAreaX + spec.birdSpawnAreaRadius)
    y = Utils.randomFloat(spec.birdSpawnAreaY - spec.birdSpawnAreaRadius,spec.birdSpawnAreaY + spec.birdSpawnAreaRadius)
    z = Utils.randomFloat(spec.birdSpawnAreaZ - spec.birdSpawnAreaRadius,spec.birdSpawnAreaZ + spec.birdSpawnAreaRadius)

    return x,y,z
end

-- Tracing callback for above function's raycast, sets birdSpawnAreaClear if trace did not overlap any obstacle
function PlaceableFeeder:getBirdSpawnOverlapCallback(hitObjectId)

    if hitObjectId == 0 or hitObjectId == g_currentMission.terrainRootNode then
        self.spec_placeableFeeder.birdSpawnAreaClear = true
    else
        self.spec_placeableFeeder.birdSpawnAreaClear = false
    end

end
















