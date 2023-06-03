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

--- Bird Feeder specialization for placeables.
---@class PlaceableFeeder.
PlaceableFeeder = {}
-- To limit one decorational bird feeder per farm this will be filled with farm id's that already have one created.
PlaceableFeeder.owners = {}


--- prerequisitesPresent checks if all prerequisite specializations are loaded, none needed in this case.
--@param table specializations specializations.
--@return boolean hasPrerequisite true if all prerequisite specializations are loaded.
function PlaceableFeeder.prerequisitesPresent(specializations)
    return true;
end


--- registerEventListeners registers all needed FS events.
function PlaceableFeeder.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", PlaceableFeeder)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableFeeder)
    if g_server ~= nil then
        SpecializationUtil.registerEventListener(placeableType, "onPlaceableFeederFillLevelChanged",PlaceableFeeder)
        SpecializationUtil.registerEventListener(placeableType, "onPlaceableFeederBecomeActive",PlaceableFeeder)
        SpecializationUtil.registerEventListener(placeableType, "onPlaceableFeederBecomeInActive",PlaceableFeeder)
    end

end

--- registerFunctions registers new functions.
function PlaceableFeeder.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "getBirdSeedCapacity",PlaceableFeeder.getBirdSeedCapacity)
    SpecializationUtil.registerFunction(placeableType, "getBirdSeedFillLevel",PlaceableFeeder.getBirdSeedFillLevel)
    SpecializationUtil.registerFunction(placeableType, "onAddedStorageToUnloadingStation", PlaceableFeeder.onAddedStorageToUnloadingStation)
    SpecializationUtil.registerFunction(placeableType, "onRemovedStorageFromUnloadingStation", PlaceableFeeder.onRemovedStorageFromUnloadingStation)
    SpecializationUtil.registerFunction(placeableType, "removeSeeds", PlaceableFeeder.removeSeeds)
    SpecializationUtil.registerFunction(placeableType, "removeSeedsCallback", PlaceableFeeder.removeSeedsCallback)
    SpecializationUtil.registerFunction(placeableType, "changeState", PlaceableFeeder.changeState)
    SpecializationUtil.registerFunction(placeableType, "createBirds", PlaceableFeeder.createBirds)
    SpecializationUtil.registerFunction(placeableType, "getRandomBirdSpawn", PlaceableFeeder.getRandomBirdSpawn)
    SpecializationUtil.registerFunction(placeableType, "onGridMapGenerated", PlaceableFeeder.onGridMapGenerated)
    SpecializationUtil.registerFunction(placeableType, "prepareBirds", PlaceableFeeder.prepareBirds)
    SpecializationUtil.registerFunction(placeableType, "getRandomLandPosition", PlaceableFeeder.getRandomLandPosition)
    SpecializationUtil.registerFunction(placeableType, "scareBirds", PlaceableFeeder.scareBirds)
    SpecializationUtil.registerFunction(placeableType, "checkFeederAccess", PlaceableFeeder.checkFeederAccess)
    SpecializationUtil.registerFunction(placeableType, "checkFeederAccessNonInitCallback", PlaceableFeeder.checkFeederAccessNonInitCallback)
    SpecializationUtil.registerFunction(placeableType, "checkFeederAccessInitCallback", PlaceableFeeder.checkFeederAccessInitCallback)
    SpecializationUtil.registerFunction(placeableType, "prepareFlyArea", PlaceableFeeder.prepareFlyArea)
    SpecializationUtil.registerFunction(placeableType, "invalidPlacement", PlaceableFeeder.invalidPlacement)
    SpecializationUtil.registerFunction(placeableType, "initializeFeeder", PlaceableFeeder.initializeFeeder)
    SpecializationUtil.registerFunction(placeableType, "onScareTriggerCallback", PlaceableFeeder.onScareTriggerCallback)
    SpecializationUtil.registerFunction(placeableType, "birdLandEvent", PlaceableFeeder.birdLandEvent)
    SpecializationUtil.registerFunction(placeableType, "isLandable", PlaceableFeeder.isLandable)
    SpecializationUtil.registerFunction(placeableType, "seedEaten", PlaceableFeeder.seedEaten)
    SpecializationUtil.registerFunction(placeableType, "debugRender", PlaceableFeeder.debugRender)
end

--- registerEvents registers new events.
function PlaceableFeeder.registerEvents(placeableType)
    SpecializationUtil.registerEvent(placeableType, "onPlaceableFeederFillLevelChanged")
    SpecializationUtil.registerEvent(placeableType, "onPlaceableFeederBecomeActive")
    SpecializationUtil.registerEvent(placeableType, "onPlaceableFeederBecomeInActive")
end

--- registerOverwrittenFunctions register overwritten functions.
function PlaceableFeeder.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "collectPickObjects", PlaceableFeeder.collectPickObjectsOW)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", PlaceableFeeder.updateInfoPlaceableFeeder)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "canBuy", PlaceableFeeder.canBuy)
end

--- onLoad loading creates the unloading station and storage and scare trigger.
--@param savegame loaded savegame.
function PlaceableFeeder:onLoad(savegame)
	--- Register the spec
	self.spec_placeableFeeder = self["spec_FS22_BirdFeeder.placeableFeeder"]
    local xmlFile = self.xmlFile
    local spec = self.spec_placeableFeeder
    -- Set the title of the to be displayed on tiny UI box when player overlaps
    spec.info = {title=g_i18n:getText("fillType_birdSeed"), text=""}
    spec.fillPlaneId = xmlFile:getValue("placeable.placeableFeeder#fillPlaneNode",nil,self.components,self.i3dMappings)
    spec.birds = {}
    spec.isPlaced = false
    spec.bInvalidPlaced = false

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

    --  A trigger for making birds scared away or not able to land on feeder if a player is nearby.
    spec.birdScareTrigger = xmlFile:getValue("placeable.placeableFeeder#scareTriggerNode", nil, self.components, self.i3dMappings)
    if spec.birdScareTrigger ~= nil then
        if not CollisionFlag.getHasFlagSet(spec.birdScareTrigger, CollisionFlag.TRIGGER_PLAYER) then
            Logging.xmlWarning(self.xmlFile, "Bird scare trigger collison mask is missing bit 'TRIGGER_PLAYER' (%d)", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER))
        end
    end

end

--- onDelete when placeable feeder deleted, clean up the unloading station and storage and birds and others.
function PlaceableFeeder:onDelete()

    local spec = self.spec_placeableFeeder
    local storageSystem = g_currentMission.storageSystem

    if spec.isPlaced then
        local farmId = self:getOwnerFarmId()
        PlaceableFeeder.owners[farmId] = nil

        if self.isServer and FlyPathfinding.bPathfindingEnabled and g_currentMission.gridMap3D ~= nil then
            for _,pickObject in pairs(spec.pickObjects) do
                g_currentMission.gridMap3D:removeObjectIgnoreID(pickObject)
            end

            if spec.accessTester ~= nil then
                spec.accessTester:delete()
            end
        end

        if self.isServer and spec.birdFeederStates[spec.currentState] ~= nil then
            spec.birdFeederStates[spec.currentState]:leave()
        end
    end

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

    if spec.birdScareTrigger ~= nil then
        removeTrigger(spec.birdScareTrigger)
        spec.birdScareTrigger = nil
    end

    if g_messageCenter ~= nil then
        g_messageCenter:unsubscribe(MessageType.STORAGE_ADDED_TO_UNLOADING_STATION, self)
        g_messageCenter:unsubscribe(MessageType.STORAGE_REMVOED_FROM_UNLOADING_STATION, self)

        if next(spec.birds) ~= nil and self.isServer then
            g_messageCenter:unsubscribe(MessageType.GRIDMAP3D_GRID_GENERATED,self)
        end
    end

    if next(spec.birds) ~= nil then
        for _, bird in pairs(spec.birds) do
            if bird ~= nil then
                bird:delete()
            end
        end
    end

    spec.birds = nil
end

--- onUpdate update function, called when raiseActive called and initially.
-- In feeder mainly used in case debug is turned on loading screen.
function PlaceableFeeder:onUpdate(dt)
    local spec = self.spec_placeableFeeder

    if BirdFeederMod.bDebug then
        self:debugRender(dt)
    end

    if self.isServer then
        -- Forward update to current state if valid
        if spec.birdFeederStates[spec.currentState] ~= nil then
            spec.birdFeederStates[spec.currentState]:update()
        end
    end

end

--- debugRender if debug is on for mod then debug renders some feeder variables.
--@param dt is deltatime received from update function.
function PlaceableFeeder:debugRender(dt)
    if not self.isServer then
        return
    end

    local spec = self.spec_placeableFeeder

    self:raiseActive()
    local positionX, positionY, positionZ = getWorldTranslation(self.rootNode)

    renderText3D(positionX - 1, positionY + 1.65, positionZ + 0.8,0,0,0,0.25,"Birds used:")
    renderText3D(positionX + 1.7, positionY + 1.65, positionZ + 0.8,0,0,0,0.25,tostring(spec.numberBirds))
    renderText3D(positionX - 1, positionY + 1.95, positionZ + 0.8,0,0,0,0.25,"Current state:")
    renderText3D(positionX + 1.7, positionY + 1.95, positionZ + 0.8,0,0,0,0.25,tostring(spec.currentState))
    renderText3D(positionX - 1, positionY + 2.30, positionZ + 0.8,0,0,0,0.25,"Invalid placement:")
    renderText3D(positionX + 1.7, positionY + 2.30, positionZ + 0.8,0,0,0,0.25,tostring(spec.bInvalidPlaced))
    renderText3D(positionX - 1, positionY + 2.60, positionZ + 0.8,0,0,0,0.25,"Player nearby")
    renderText3D(positionX + 1.7, positionY + 2.60, positionZ + 0.8,0,0,0,0.25,tostring(next(self.spec_placeableFeeder.playersNearFeeder) ~= nil))

    renderText3D(positionX - 1, positionY + 2.90, positionZ + 0.8,0,0,0,0.25,"Feeder position")
    renderText3D(positionX + 1, positionY + 2.90, positionZ + 0.8,0,0,0,0.25,"X:")
    renderText3D(positionX + 1.3, positionY + 2.90, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(positionX * 1000) / 1000))
    renderText3D(positionX + 2.5, positionY + 2.90, positionZ + 0.8,0,0,0,0.25,"Y:")
    renderText3D(positionX + 2.8, positionY + 2.90, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(positionY * 1000) / 1000))
    renderText3D(positionX + 4.0, positionY + 2.90, positionZ + 0.8,0,0,0,0.25,"Z:")
    renderText3D(positionX + 4.3, positionY + 2.90, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(positionZ * 1000) / 1000))

    if spec.flyAreaAABB ~= nil then
        renderText3D(positionX - 1, positionY + 3.20, positionZ + 0.8,0,0,0,0.25,"fly aabb")
        renderText3D(positionX + 1, positionY + 3.20, positionZ + 0.8,0,0,0,0.25,"MinX:")
        renderText3D(positionX + 1.6, positionY + 3.20, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(spec.flyAreaAABB[1] * 1000) / 1000))
        renderText3D(positionX + 2.5, positionY + 3.20, positionZ + 0.8,0,0,0,0.25,"MinY:")
        renderText3D(positionX + 3.1, positionY + 3.20, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(spec.flyAreaAABB[2] * 1000) / 1000))
        renderText3D(positionX + 4.0, positionY + 3.20, positionZ + 0.8,0,0,0,0.25,"MinZ:")
        renderText3D(positionX + 4.6, positionY + 3.20, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(spec.flyAreaAABB[3] * 1000) / 1000))

        renderText3D(positionX - 1, positionY + 3.50, positionZ + 0.8,0,0,0,0.25,"fly aabb")
        renderText3D(positionX + 1, positionY + 3.50, positionZ + 0.8,0,0,0,0.25,"MaxX:")
        renderText3D(positionX + 1.6, positionY + 3.50, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(spec.flyAreaAABB[4] * 1000) / 1000))
        renderText3D(positionX + 2.5, positionY + 3.50, positionZ + 0.8,0,0,0,0.25,"MaxY:")
        renderText3D(positionX + 3.1, positionY + 3.50, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(spec.flyAreaAABB[5] * 1000) / 1000))
        renderText3D(positionX + 4.0, positionY + 3.50, positionZ + 0.8,0,0,0,0.25,"MaxZ:")
        renderText3D(positionX + 4.6, positionY + 3.50, positionZ + 0.8,0,0,0,0.25,tostring(math.floor(spec.flyAreaAABB[6] * 1000) / 1000))
    end
end

--- canBuy is overriden function which checks if a feeder can be bought and placed.
-- feeder is limited to one per farm so checks if one is already owned by current farm id.
--@param superFunc is the original function.
--@return returns true if can buy and place feeder.
function PlaceableFeeder:canBuy(superFunc)

    local bCanBuy, warning = superFunc(self)
    if not bCanBuy then
        return false, warning
    end

    if PlaceableFeeder.owners[self:getOwnerFarmId()] then
        return false, g_i18n:getText("warning_onlyOneOfThisItemAllowedPerFarm")
    end
    return true, nil
end

--- Event on finalizing the placement of this bird feeder.
-- used to create the birds and feeder states and other variables initialized.
function PlaceableFeeder:onFinalizePlacement()
    local spec = self.spec_placeableFeeder
    local xmlFile = self.xmlFile

    spec.birdI3dFilePath = xmlFile:getValue("placeable.placeableFeeder.birds.files#i3dFilePath")
    spec.birdXmlFilePath = xmlFile:getValue("placeable.placeableFeeder.birds.files#xmlFilePath")

    if self.isServer then
        local birdEatPosition1Id = xmlFile:getValue("placeable.placeableFeeder.birds#eatPosition1",nil,self.components,self.i3dMappings)
        local birdEatPosition2Id = xmlFile:getValue("placeable.placeableFeeder.birds#eatPosition2",nil,self.components,self.i3dMappings)
        local birdEatPosition3Id = xmlFile:getValue("placeable.placeableFeeder.birds#eatPosition3",nil,self.components,self.i3dMappings)

        spec.eatArea = {}

        local birdEatPosition1 = {}
        if birdEatPosition1Id ~= nil and birdEatPosition1Id > 0 then
            birdEatPosition1.x,birdEatPosition1.y,birdEatPosition1.z = getWorldTranslation(birdEatPosition1Id)
        end

        local birdEatPosition2 = {}
        if birdEatPosition2Id ~= nil and birdEatPosition2Id > 0 then
            birdEatPosition2.x,birdEatPosition2.y,birdEatPosition2.z = getWorldTranslation(birdEatPosition2Id)
        end

        local birdEatPosition3 = {}
        if birdEatPosition3Id ~= nil and birdEatPosition3Id > 0 then
            birdEatPosition3.x,birdEatPosition3.y,birdEatPosition3.z = getWorldTranslation(birdEatPosition3Id)
        end

        -- variables used for getting random position on the feed area plane to have birds land in it.
        spec.eatArea.corner1 = birdEatPosition1
        spec.eatArea.corner2 = birdEatPosition2
        spec.eatArea.corner3 = birdEatPosition3
        spec.eatArea.side1 = {}
        spec.eatArea.side2 = {}
        spec.eatArea.side1.x = birdEatPosition2.x - birdEatPosition1.x
        spec.eatArea.side1.y = birdEatPosition2.y - birdEatPosition1.y
        spec.eatArea.side1.z = birdEatPosition2.z - birdEatPosition1.z
        spec.eatArea.side2.x = birdEatPosition3.x - birdEatPosition2.x
        spec.eatArea.side2.y = birdEatPosition3.y - birdEatPosition2.y
        spec.eatArea.side2.z = birdEatPosition3.z - birdEatPosition2.z


        if spec.birdScareTrigger ~= nil then
            addTrigger(spec.birdScareTrigger, "onScareTriggerCallback", self)
        end

        -- Keeps in check if any players are nearby the feeder with their id
        spec.playersNearFeeder = {}
        -- Keeps in check if any birds are in feeder
        spec.birdsInFeeder = {}

        -- set a limit how complex location the bird feeder can be by adjusting how many closed nodes A* pathfinding can close before should stop search for a path to feeder.
        spec.maxAccessClosedNodes = 2000
        -- adjust how fast it should A* pathfind to see if feeder can be accessed
        spec.accessSearchLoops = 10

        spec.birdFlyRadius = MathUtil.clamp(Utils.getNoNil(xmlFile:getValue("placeable.placeableFeeder.birds#flyRadius"),40),5,100)

        -- later set the AABB area birds can fly in as {minX,minY,minZ,maxX,maxY,maxZ}
        spec.flyAreaAABB = nil
        -- and the octree node which contains whole fly area aabb
        spec.octreeNode = nil

        -- get random number of birds, hoursToSpawn and hoursToLeave, within range declared in xml.
        spec.numberBirds = math.random(1,Utils.getNoNil(xmlFile:getValue("placeable.placeableFeeder.birds#maxNumberBirds"),3))
        spec.maxHoursToSpawn = MathUtil.clamp(Utils.getNoNil(xmlFile:getValue("placeable.placeableFeeder.birds#maxHoursToSpawn"),30),1,30)
        spec.maxHoursToLeave = MathUtil.clamp(Utils.getNoNil(xmlFile:getValue("placeable.placeableFeeder.birds#maxHoursToLeave"),5),1,30)

        spec.EBirdSystemStates = {UNINTIALIZED = -1,INITIALIZED = 0, INACTIVE = 1 , PREPAREARRIVE = 2 , PREPARELEAVE = 3 , ACTIVE = 4}
        spec.birdFeederStates = {}

        -- Create the bird system states and init them, giving this feeder ref to the states. Only on server
        spec.birdFeederStates[spec.EBirdSystemStates.INACTIVE] = BirdSystemInActiveState.new()
        spec.birdFeederStates[spec.EBirdSystemStates.INACTIVE]:init(self,self.isServer,self.isClient)
        spec.birdFeederStates[spec.EBirdSystemStates.ACTIVE] = BirdSystemActiveState.new()
        spec.birdFeederStates[spec.EBirdSystemStates.ACTIVE]:init(self,self.isServer,self.isClient)
        spec.birdFeederStates[spec.EBirdSystemStates.PREPAREARRIVE] = BirdSystemPrepareArriveState.new()
        spec.birdFeederStates[spec.EBirdSystemStates.PREPAREARRIVE]:init(self,self.isServer,self.isClient)
        spec.birdFeederStates[spec.EBirdSystemStates.PREPARELEAVE] = BirdSystemPrepareLeaveState.new()
        spec.birdFeederStates[spec.EBirdSystemStates.PREPARELEAVE]:init(self,self.isServer,self.isClient)
        spec.currentState = spec.EBirdSystemStates.UNINTIALIZED

        if FlyPathfinding.bPathfindingEnabled and g_currentMission.gridMap3D ~= nil then
            -- Need to create birds for the feeder
            self:createBirds()

            -- create pathfinding class that will be used to check if the location of this feeder is good after gridmap becomes available
            spec.accessTester = AStar.new(self.isServer,self.isClient)
            spec.accessTester:register(true)

             -- add this bird feeder to be ignored by the navigation grid as non solid.
            for _,pickObject in pairs(spec.pickObjects) do
                g_currentMission.gridMap3D:addObjectIgnoreID(pickObject)
            end

            if next(spec.birds) ~= nil and g_currentMission.gridMap3D:isAvailable() then
                self:initializeFeeder()
            end
        else
            spec.numberBirds = 0
        end

    end

    -- Create a function callback which raises the event for when fill level in storage has changed
    spec.fillLevelChangedCallback = function(fillType, delta)
        SpecializationUtil.raiseEvent(self, "onPlaceableFeederFillLevelChanged", fillType, delta)
    end


    local storage = spec.storage
    local unloadingStation = spec.unloadingStation
    local storageSystem = g_currentMission.storageSystem
    local farmId = self:getOwnerFarmId()
    PlaceableFeeder.owners[farmId] = true
    spec.isPlaced = true

    if g_messageCenter ~= nil then
        g_messageCenter:subscribe(MessageType.STORAGE_ADDED_TO_UNLOADING_STATION, self.onAddedStorageToUnloadingStation, self)
        g_messageCenter:subscribe(MessageType.STORAGE_REMOVED_FROM_UNLOADING_STATION, self.onRemovedStorageFromUnloadingStation, self)

        if next(spec.birds) ~= nil and self.isServer then
            g_messageCenter:subscribe(MessageType.GRIDMAP3D_GRID_GENERATED, self.onGridMapGenerated, self)
        end

    end

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

--- Registering placeable feeder's xml paths and its objects.
function PlaceableFeeder.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("PlaceableFeeder")
    schema:register(XMLValueType.INT,        basePath .. ".placeableFeeder.birds#maxNumberBirds", "Maximum number of birds")
    schema:register(XMLValueType.FLOAT,        basePath .. ".placeableFeeder.birds#flyRadius", "Radius of the birds can fly around the feeder")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder.birds#eatPosition1", "first node of eat area")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder.birds#eatPosition2", "second node of eat area")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder.birds#eatPosition3", "third node of eat area")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder#fillPlaneNode", "seed fillplane node")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".placeableFeeder#scareTriggerNode", "scare trigger node")
    schema:register(XMLValueType.STRING,        basePath .. ".placeableFeeder.birds.files#xmlFilePath", "xml file path for bird object")
    schema:register(XMLValueType.STRING,        basePath .. ".placeableFeeder.birds.files#i3dFilePath", "i3d file path for bird object")
    schema:register(XMLValueType.INT,      basePath .. ".placeableFeeder.birds#maxHoursToSpawn",   "Hour value until the birds start to arrive if food in feeder", 5)
    schema:register(XMLValueType.INT,      basePath .. ".placeableFeeder.birds#maxHoursToLeave",   "Hour value until the birds leave if no food in feeder", 5)
    Storage.registerXMLPaths(schema,            basePath .. ".placeableFeeder.storage")
    UnloadingStation.registerXMLPaths(schema, basePath .. ".placeableFeeder.unloadingStation")
end

--- Registering placeable feeder's savegame xml paths.
function PlaceableFeeder.registerSavegameXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("PlaceableFeeder")
    Storage.registerSavegameXMLPaths(schema, basePath .. ".storage")
    schema:setXMLSpecializationType()
end

--- On saving, save existing storage to xml file.
function PlaceableFeeder:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_placeableFeeder

    if spec.storage ~= nil then
        spec.storage:saveToXMLFile(xmlFile, key .. ".storage", usedModNames)
    end
end

--- On loading, load storage from xml file.
function PlaceableFeeder:loadFromXMLFile(xmlFile, key)
    local spec = self.spec_placeableFeeder
    if not spec.storage:loadFromXMLFile(xmlFile, key .. ".storage") then
        return false
    end

    return true
end

--- onReadStream initial receive at start from server these variables.
function PlaceableFeeder:onReadStream(streamId, connection)

    if connection:getIsServer() then
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

        -- first reads from server how many birds needs to be created
        spec.numberBirds = streamReadInt8(streamId)

        if next(spec.birds) == nil then
            -- creates birds for the feeder on client
            self:createBirds()
        end

        for i, bird in pairs(spec.birds) do
            local birdId = NetworkUtil.readNodeObjectId(streamId)
            bird:readStream(streamId,connection)
            g_client:finishRegisterObject(bird, birdId)
        end

        spec.bInvalidPlaced = streamReadBool(streamId)
        if spec.bInvalidPlaced then
            self:invalidPlacement()
        end
    end
end

--- onWriteStream initial sync at start from server to client these variables.
function PlaceableFeeder:onWriteStream(streamId, connection)

    if not connection:getIsServer() then
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

        -- sends amount of birds needed to client
        streamWriteInt8(streamId,spec.numberBirds)

        for i, bird in pairs(spec.birds) do
            local birdId = NetworkUtil.getObjectId(bird)
            NetworkUtil.writeNodeObjectId(streamId, birdId)
            bird:writeStream(streamId,connection)
            g_server:registerObjectInStream(connection, bird)
        end

        streamWriteBool(streamId,spec.bInvalidPlaced)
    end
end

--- getRandomLandPosition is a function used to get a position within the plane of bird feeder food area.
-- server only.
--@return a position given as {x=,y=,z=}, or nil if no position was able to be given.
function PlaceableFeeder:getRandomLandPosition()
    local spec = self.spec_placeableFeeder
    if spec.eatArea.corner1 == nil then
        return nil
    end

    local iterations = 0
    while iterations < 300 do

        local u = {x=math.random(),y=math.random(),z=math.random()}
        local v = {x=math.random(),y=math.random(),z=math.random()}

        local point = {x = spec.eatArea.corner1.x + u.x * spec.eatArea.side1.x + v.x * spec.eatArea.side2.x,
            y = spec.eatArea.corner1.y, z = spec.eatArea.corner1.z + u.z * spec.eatArea.side1.z + v.z * spec.eatArea.side2.z };

        local bNearbyBird = false

        -- loop almost not needed as birds might not yet be there when requests position so they might still land inside each other in some cases.
        for _,position in pairs(spec.birdsInFeeder) do
            local distance = MathUtil.vector3Length(position.x - point.x, position.y - point.y, position.z - point.z)
            -- 8cm from each other if there is already a bird in the feeder
            if distance < 0.08 then
                bNearbyBird = true
                break
            end
        end

        if not bNearbyBird then
            return point
        end

        iterations = iterations + 1
    end

    return nil
end

--- onScareTriggerCallback is called when player enters larger trigger around the feeder.
-- signals birds that are on feeder to start idle fly around again.
-- server only.
--@param triggerId is the trigger's id.
--@param otherId is the id of the one triggering the trigger.
--@param onEnter is bool indicating if entered.
--@param onLeave is indicating if left the trigger.
--@param onStay indicates if staying on the trigger.
function PlaceableFeeder:onScareTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    local spec = self.spec_placeableFeeder
    local player = g_currentMission.players[otherId]

    if player ~= nil then
        if onEnter then
            spec.playersNearFeeder[otherId] = true
            self:scareBirds()
        else
            spec.playersNearFeeder[otherId] = nil
        end
    end
end

--- birdLandEvent is called from birds on landing on feeder and when leaving on feeder.
-- used to make sure the feeder knows the ID's of the birds currently in the feeder.
-- server only.
--@param birdID id of the bird that landed or leaving.
--@param isLeaving is a bool to indicate if bird was leaving or landed.
function PlaceableFeeder:birdLandEvent(birdID,isLeaving)
    if birdID == nil or isLeaving == nil then
        return
    end

    local spec = self.spec_placeableFeeder

    -- sets the bird id in the hash table, if landed then sets the position of bird as value of the hash table.
    if isLeaving then
        spec.birdsInFeeder[birdID] = nil
    else
        local birdPosition = {}
        birdPosition.x, birdPosition.y, birdPosition.z = getWorldTranslation(birdID)
        spec.birdsInFeeder[birdID] = birdPosition
    end

end

--- scareBirds is used to change state of every bird in the feeder to idlefly.
-- called when player comes near feeder.
-- server only.
function PlaceableFeeder:scareBirds()
    local spec = self.spec_placeableFeeder

    for id,_ in pairs(spec.birdsInFeeder) do
        spec.birds[id]:changeState(spec.birds[id].EBirdStates.IDLEFLY)
    end

end

--- isLandable is used to check if a bird can land on the feeder or stay in the feeder.
-- depending on if a player is near feeder or not.
--@returns true if no player is nearby feeder.
function PlaceableFeeder:isLandable()
    return next(self.spec_placeableFeeder.playersNearFeeder) == nil
end

--- seedEaten is a function called from birds randomly when they are in the feeder to eat and lower amount of seeds.
-- server only.
--@param amount is the amount of seeds eaten.
--@return true if is eaten empty.
function PlaceableFeeder:seedEaten(amount)
    amount = amount or 1

    if self.spec_placeableFeeder.storage ~= nil then
        local newAmount = self:getBirdSeedFillLevel() - amount
        self.spec_placeableFeeder.storage:setFillLevel(newAmount,FillType.BIRDSEED,nil)
    end

    if self:getBirdSeedFillLevel() <= 0 then
        return true
    end

    return false
end

--- getBirdSeedCapacity called to get seed max capacity from existing storage
-- @return amount of seed capacity
function PlaceableFeeder:getBirdSeedCapacity()

    if self.spec_placeableFeeder.storage ~= nil then
        return Utils.getNoNil(self.spec_placeableFeeder.storage.capacity,0)
    end

    return 0
end

--- getBirdSeedFillLevel called to get current seed level from existing storage
-- @return number of seeds in storage
function PlaceableFeeder:getBirdSeedFillLevel()

    if self.spec_placeableFeeder.storage ~= nil then
        return Utils.getNoNil(self.spec_placeableFeeder.storage.fillLevels[FillType.BIRDSEED],0)
    end

    return 0
end

--- onPlaceableFeederFillLevelChanged bound event function for when seed level has changed in storage
-- bound only on server.
--@param fillType is type with feeder filled with.
--@param delta is delta by how much fill level changed.
function PlaceableFeeder:onPlaceableFeederFillLevelChanged(fillType,delta)
    local spec = self.spec_placeableFeeder

    -- check to make sure in a correct state and grid is ready.
    if spec.currentState == spec.EBirdSystemStates.UNINITIALIZED or next(spec.birds) == nil or FlyPathfinding.bPathfindingEnabled == false or g_currentMission.gridMap3D == nil or g_currentMission.gridMap3D:isAvailable() == false or spec.bInvalidPlaced then
        return
    end

    local currentFillLevel = self:getBirdSeedFillLevel()

    -- Check if fill level has become over 0, and state is inactive or initialized, then needs to prepare to be activated
    if (spec.currentState == spec.EBirdSystemStates.INACTIVE and currentFillLevel > 0) or (spec.currentState == spec.EBirdSystemStates.INITIALIZED and currentFillLevel > 0) then
        self:changeState(spec.EBirdSystemStates.PREPAREARRIVE)

    -- check if fill level has become 0, and state is active, then needs to prepare to be inactivated
    elseif spec.currentState == spec.EBirdSystemStates.ACTIVE and currentFillLevel == 0 then
        self:changeState(spec.EBirdSystemStates.PREPARELEAVE)

    -- if fill level has become 0 and only initialized, then no birds need to be inactivated so can put feeder straight as inactive
    elseif spec.currentState == spec.EBirdSystemStates.INITIALIZED and currentFillLevel == 0 then
        self:changeState(spec.EBirdSystemStates.INACTIVE)

    -- in a special case where debug function empties the feeder while waiting to activate birds just leaves prepare and back to inactive state
    elseif spec.EBirdSystemStates.PREPAREARRIVE == spec.currentState and currentFillLevel == 0 then
        self:changeState(spec.EBirdSystemStates.INACTIVE)

    -- in a case where preparing to leave but gets filled back up, then can just directly set feeder back as active
    elseif spec.EBirdSystemStates.PREPARELEAVE == spec.currentState and currentFillLevel > 0 then
        self:changeState(spec.EBirdSystemStates.ACTIVE)
    end

end

--- onPlaceableFeederBecomeActive is event called when feeder becomes active and birds are set active.
function PlaceableFeeder:onPlaceableFeederBecomeActive()
    local spec = self.spec_placeableFeeder
    self:changeState(spec.EBirdSystemStates.ACTIVE)

    for _, bird in pairs(spec.birds) do
        bird:onActive()
    end

end

--- onPlaceableFeederBecomeInActive is event called when feeder becomes inactive and birds are set to leave.
function PlaceableFeeder:onPlaceableFeederBecomeInActive()
    local spec = self.spec_placeableFeeder
    self:changeState(spec.EBirdSystemStates.INACTIVE)

    for _, bird in pairs(spec.birds) do
        bird:onInActive()
    end

end

--- onAddedStorageToUnloadingStation a function callback for when storage was attached to the unloading station.
function PlaceableFeeder:onAddedStorageToUnloadingStation(storage, unloadingStation)
    local spec = self.spec_placeableFeeder
    if spec.unloadingStation ~= nil and spec.unloadingStation == unloadingStation then
        storage:addFillLevelChangedListeners(spec.fillLevelChangedCallback)
    end
end

--- onRemovedStorageFromUnloadingStation a function callback for when storage was removed from the unloading station.
function PlaceableFeeder:onRemovedStorageFromUnloadingStation(storage, unloadingStation)
    local spec = self.spec_placeableFeeder
    if spec.unloadingStation ~= nil and spec.unloadingStation == unloadingStation then
        storage:removeFillLevelChangedListeners(spec.fillLevelChangedCallback)
    end
end

--- updateInfoPlaceableFeeder overridden updateInfo function, to show seed level and capacity when overlapping trigger box.
--@param superFunc is the original function.
--@param infoTable is the info table containing what to show.
function PlaceableFeeder:updateInfoPlaceableFeeder(superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_placeableFeeder

    local capacity = self:getBirdSeedCapacity()
    local fillLevel = self:getBirdSeedFillLevel()
	spec.info.text = string.format("%d", fillLevel) .. " / " .. string.format("%d g", capacity)
    if spec.bInvalidPlaced then
        local noAccessText = {title=g_i18n:getText("birdFeeder_infoNoAccessTitle"), text=g_i18n:getText("birdFeeder_infoNoAccess")}
        table.insert(infoTable,noAccessText)
    else
        table.insert(infoTable, spec.info)
    end

end

--- collectPickObjectsOW overriden function for collecting pickable objects, avoiding error for trigger node getting added twice.
--@param superFunc original function.
--@param trigger node
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

--- removeSeedsCallback is callback from removeSeeds->overlapbox a debug function to find nearby bird feeder and empty it from seeds.
--@param actorId is the id of the thing which was overlapped by the test box.
--@returns false to stop going through the found overlap results if was feeder.
function PlaceableFeeder:removeSeedsCallback(actorId)

    if actorId ~= 0 then
        local object = g_currentMission:getNodeObject(actorId)
        if object ~= nil and object:isa(Placeable) then
            if object.spec_placeableFeeder ~= nil and object.spec_placeableFeeder.storage ~= nil then
                object.spec_placeableFeeder.storage:setFillLevel(0,FillType.BIRDSEED,nil)
            end
            return false
        end
    end

    return true
end

--- removeSeeds is a debug console command that tries to remove seeds from birdfeeder next to player.
function PlaceableFeeder.removeSeeds()

    if g_currentMission ~= nil then
        local x,y,z = getWorldTranslation(g_currentMission.player.rootNode)
        overlapBox(x,y + 0.5,z, 0, 0, 0,1,1,1, "removeSeedsCallback",PlaceableFeeder,CollisionFlag.STATIC_WORLD,false,true,true,false)
    end
end

--- changeState is called for changing the state of bird system states
-- server only.
function PlaceableFeeder:changeState(newState)
    local spec = self.spec_placeableFeeder

    if self.isServer == false then
        return
    end

    -- check if newState is a valid state
    if newState == nil or newState == spec.currentState then
        return
    end

    -- If current state doesn't exist as state class can't leave from it
    if  spec.birdFeederStates[spec.currentState] ~= nil then
        spec.birdFeederStates[spec.currentState]:leave()
    end

    -- set new current state and enter the state
    spec.currentState = newState

    if spec.birdFeederStates[spec.currentState] ~= nil then
        spec.birdFeederStates[spec.currentState]:enter()
    end

end

--- onGridMapGenerated bound function to the broadcast when gridmap has been generated.
-- server only.
function PlaceableFeeder:onGridMapGenerated()
    self:initializeFeeder()
end

--- initializeFeeder is called when a grid is ready and needs to initialize the feeder with things that requires the grid.
--server only
function PlaceableFeeder:initializeFeeder()

    local callback = function(aStarSearch) self:checkFeederAccessInitCallback(aStarSearch) end
    self:checkFeederAccess(callback)

end

--- checkFeederAccess uses AStar pathfinder to check that the feeder is placed in a relatively open space.
-- server only.
--@param callback is the callback to call when AStar is done pathfinding with result.
--@return true if could check feeder access which would mean it is not invalid placed already.
function PlaceableFeeder:checkFeederAccess(callback)
    if callback == nil or self.spec_placeableFeeder.bInvalidPlaced then
        return false
    end

    local spec = self.spec_placeableFeeder

    if FlyPathfinding.bPathfindingEnabled and spec.accessTester ~= nil and spec.accessTester:isPathfinding() == false then
        -- pathfind down from the sky to the feeder.
        if spec.accessTester:find({x=0,y=2000,z=0},spec.eatArea.corner1,false,true,false,callback,nil,spec.accessSearchLoops,spec.maxAccessClosedNodes) == false then
            callback({nil,false})
        end
    end
    return true
end

--- checkFeederAccessNonInitCallback a non initializing callback for the checkFeederAccess, used when bird runs into an issue for getting to feeder.
-- server only.
--@param aSearchResult is the result received from AStar class as type {path array of (x=,y=,z=},bWasGoal}.
function PlaceableFeeder:checkFeederAccessNonInitCallback(aSearchResult)
    if self.spec_placeableFeeder.bInvalidPlaced then
        return
    end

    -- second value is bool indicating if goal(feeder) was reached or not
    if not aSearchResult[2] then
        self:invalidPlacement()
        for _,bird in pairs(self.spec_placeableFeeder.birds) do
            -- Try make the birds leave
            bird:changeState(bird.EBirdStates.LEAVEFLY)
        end

        return
    end
end

--- checkFeederAccessInitCallback is callback used for checking feeder access when initializing feeder after grid is available.
-- server only.
--@param aSearchResult is the result received from AStar class as type {path array of (x=,y=,z=},bWasGoal}.
function PlaceableFeeder:checkFeederAccessInitCallback(aSearchResult)
    local spec = self.spec_placeableFeeder

    -- second value is bool indicating if goal(feeder) was reached or not
    if not aSearchResult[2] then
        self:invalidPlacement()
        return
    end

    self:prepareBirds()

    self:changeState(spec.EBirdSystemStates.INITIALIZED)
    SpecializationUtil.raiseEvent(self, "onPlaceableFeederFillLevelChanged", FillType.BIRDFEED, 0)

end

--- prepareFlyArea makes an AABB around the area of feeder and finds the octree node which also contains all nodes.
-- server only.
--@return flyAreaAABB, octreeNode the fly area aabb and octree node containing the aabb at least.
function PlaceableFeeder:prepareFlyArea()
    if FlyPathfinding.bPathfindingEnabled == false or g_currentMission.gridMap3D == nil then
        return
    end

    local spec = self.spec_placeableFeeder

    local feederPosition = {}
    feederPosition.x,feederPosition.y,feederPosition.z = getTranslation(self.rootNode)

    local minExtents = {}
    minExtents.x = feederPosition.x - spec.birdFlyRadius
    minExtents.y = feederPosition.y
    minExtents.z = feederPosition.z - spec.birdFlyRadius

    minExtents = g_currentMission.gridMap3D:clampToGrid(minExtents)

    local maxExtents = {}
    maxExtents.x = feederPosition.x + spec.birdFlyRadius
    maxExtents.y = feederPosition.y + spec.birdFlyRadius
    maxExtents.z = feederPosition.z + spec.birdFlyRadius

    maxExtents = g_currentMission.gridMap3D:clampToGrid(maxExtents)

    local flyAreaAABB = {minExtents.x,minExtents.y,minExtents.z,maxExtents.x,maxExtents.y,maxExtents.z}

    local octreeNode = g_currentMission.gridMap3D:getGridNodeEncomppasingPositions({minExtents,maxExtents})
    spec.flyAreaAABB = flyAreaAABB

    return flyAreaAABB, octreeNode
end

--- invalidPlacement is function called when feeder was confirmed to be in bad location.
-- sets bool to indicate badly placed and sends a side notification text.
-- only called directly from server, which then sends event to all clients which will run same function.
function PlaceableFeeder:invalidPlacement()
    local spec = self.spec_placeableFeeder

    FeederInvalidPlacementEvent.sendEvent(self)

    if g_currentMission ~= nil and g_currentMission.player ~= nil and g_currentMission.player.farmId == self:getOwnerFarmId() then
        g_currentMission.hud.sideNotifications:addNotification(g_i18n:getText("birdFeeder_noAccess"),{1,0,0,1},30000)
    end

    spec.bInvalidPlaced = true
end


--- createBirds called to create the bird objects.
function PlaceableFeeder:createBirds()
    local spec = self.spec_placeableFeeder

    if spec.birdXmlFilePath == nil or spec.birdI3dFilePath == nil then
        return
    end

    for i = 1, spec.numberBirds do
        local bird = FeederBird.new(self,self.isServer, self.isClient)
        bird:load(spec.birdXmlFilePath,spec.birdI3dFilePath)
        bird:register(true)
        spec.birds[bird.rootNode] = bird
    end

end

--- prepareBirds gets a random default appear location up in the sky for the birds and gives it to bird.
-- server only.
function PlaceableFeeder:prepareBirds()
    local spec = self.spec_placeableFeeder

    for _, bird in pairs(spec.birds) do
        local spawnPosition = self:getRandomBirdSpawn()
        if spawnPosition ~= nil then
            bird:prepareBird(spawnPosition,self:prepareFlyArea())
        end
    end

end


--- getRandomBirdSpawn called to return a random x y z coordinates up in the sky above the bird feeder which is clear of obstacles.
-- server only.
--@return a position as {x=,y=,z=} in the sky, nil if no position was able to be made.
function PlaceableFeeder:getRandomBirdSpawn()
    if FlyPathfinding.bPathfindingEnabled == false or g_currentMission.gridMap3D == nil then
        return nil
    end

    local possiblePosition = {}
    possiblePosition.x,possiblePosition.y,possiblePosition.z = getTranslation(self.rootNode)
    -- first a large increase so it is decent distance from the feeder, random distance upward
    possiblePosition.y = possiblePosition.y + math.random(50,70)

    local xSign = math.random(1,2)
    local zSign = math.random(1,2)

    if xSign == 1 then
        possiblePosition.x = possiblePosition.x + math.random(40,60)
    else
        possiblePosition.x = possiblePosition.x - math.random(40,60)
    end

    if zSign == 1 then
        possiblePosition.z = possiblePosition.z + math.random(40,60)
    else
        possiblePosition.z = possiblePosition.z - math.random(40,60)
    end


    local foundNode = {nil,-1}
    local tryLimit = 300
    local currentTries = 0
    while foundNode[1] == nil do

        if currentTries >= tryLimit then
            return nil
        end

        possiblePosition = g_currentMission.gridMap3D:clampToGrid(possiblePosition)

        foundNode = g_currentMission.gridMap3D:getGridNode(possiblePosition,false)

        currentTries = currentTries + 1

        if foundNode[1] == nil then
            xSign = math.random(1,2)
            zSign = math.random(1,2)

            if xSign == 1 then
                possiblePosition.x = possiblePosition.x + math.random(1,10)
            else
                possiblePosition.x = possiblePosition.x - math.random(1,10)
            end

            if zSign == 1 then
                possiblePosition.z = possiblePosition.z + math.random(1,10)
            else
                possiblePosition.z = possiblePosition.z - math.random(1,10)
            end

            possiblePosition.y = possiblePosition.y + math.random(1,10)

        end

    end

    return possiblePosition
end

















