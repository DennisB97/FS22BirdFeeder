--[[
This file is part of set of scripts enabling 3D pathfinding in FS22 (https://github.com/DennisB97/FS22FlyPathfinding)

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

]]

--- EDirections used when finding neighbours within the octree.
local EDirections = {X = 0, MINUSX = 1, Y = 2, MINUSY = 3, Z = 4, MINUSZ = 5}


---@class GridMap3DLatentMessage enable a function to be run in sec update tick delay.
GridMap3DLatentMessage = {}
GridMap3DLatentMessage_mt = Class(GridMap3DLatentMessage)
InitObjectClass(GridMap3DLatentMessage, "GridMap3DLatentMessage")

--- new creates a new GridMap3DLatentMessage.
--@param message, the MessageType message which to publish when delay reached.
--@param messageParameters is a table given some parameters if the message published needs any.
--@param delay is the delay in seconds to wait until message publish.
function GridMap3DLatentMessage.new(message,messageParameters,delay)
    local self = setmetatable({},GridMap3DLatentMessage_mt)
    self.latentMessage = message
    self.messageDelay = delay
    self.messageParameters = messageParameters or {}
    self.delayCounter = 0
    self.bFinished = false
    return self
end

--- run needs to be called when wanted from update to give deltaTime to it.
-- So that it will eventually call the message provided. Sets bFinished to true when it is done.
--@param dt is deltaTime that needs to be given each update to this function.
function GridMap3DLatentMessage:run(dt)
    self.delayCounter = self.delayCounter + dt
    if self.delayCounter >= self.messageDelay and not self.bFinished then
        if g_messageCenter ~= nil then
            g_messageCenter:publish(self.latentMessage,unpack(self.messageParameters))
        end
        self.delayCounter = 0
        self.bFinished = true
    end
end

---@class GridMap3DNode is one node of the octree.
GridMap3DNode = {}

--- new creates a new GridMap3DNode.
--@param x is the center x coordinate of node.
--@param y is the center y coordinate of node.
--@param z is the center z coordinate of node.
--@param parent is the lower resolution parent node, type GridMap3DNode table.
--@param size is full length of the square node.
function GridMap3DNode.new(x,y,z,parent,size)
    local self = setmetatable({},nil)
    self.positionX = x
    self.positionY = y
    self.positionZ = z
    self.size = size

    -- Links to neighbours and parents as references to the node tables.
    self.parent = parent
    self.children = nil
    self.xNeighbour = nil
    self.xMinusNeighbour = nil
    self.yNeighbour = nil
    self.yMinusNeighbour = nil
    self.zNeighbour = nil
    self.zMinusNeighbour = nil
    -- most highest resolution is done with two 32bits, so a 4x4x4 grid. Only within leaf node is something else than nil value.
    self.leafVoxelsBottom = nil
    self.leafVoxelsTop = nil
    return self
end

--- isNodeSolid checks if the provided node/leaf voxel is solid or not.
--@param gridNode is the node to be checked, type of table {GridMap3DNode,leaf voxel index -1 - 63}.
--@return true if the node or leaf voxel is solid.
function GridMap3DNode.isNodeSolid(gridNode)
    if gridNode == nil or gridNode[1] == nil then
        return false
    end

    if gridNode[1].children == nil and GridMap3DNode.isLeaf(gridNode[1]) then
        if gridNode[2] < 0 then

            if gridNode[1].leafVoxelsBottom ~= 0 or gridNode[1].leafVoxelsTop ~= 0 then
                return true
            else
                return false
            end

        else

            if gridNode[2] > 31 then
                -- as the top and bottom is split into two variables need to - 32 the top to get into 0-32 range too. But the index goes between 0-63.
                local bitState = bitAND(math.floor(gridNode[1].leafVoxelsTop / (math.pow(2,gridNode[2] - 32))), 1)
                if bitState ~= 0 then
                    return true
                end

            else

                local bitState = bitAND(math.floor(gridNode[1].leafVoxelsBottom / (math.pow(2,gridNode[2]))), 1)
                if bitState ~= 0 then
                    return true
                end
            end
            return false
        end
    elseif gridNode[1].children == nil then
        return false
    end

    return true
end


--- isUnderTerrain called to find out if the node is completely under the terrain.
-- For any node that is not a leaf node, has spare variables of the leaf node's voxels to use, so uses the leafVoxelsBottom and sets it to -1.
-- And the other is nil, which will mean the terrain is marked as under.
--@param node is the GridMap3DNode non-leaf node to be checked for if it is under terrain.
--@return bool value indicating if node is completely under terrain or not.
function GridMap3DNode.isUnderTerrain(node)
    if node == nil then
        return false
    end

    if node.leafVoxelsBottom == nil and node.leafVoxelsTop == -1 then
        return true
    end

    return false
end

--- isLeafFullSolid checks if the provided leaf node is fully solid.
--@param node is the node to be checked, type of GridMap3DNode table.
--@return true if the node was fully solid.
function GridMap3DNode.isLeafFullSolid(node)

    if node == nil and GridMap3DNode.isLeaf(node) == false then
        return false
    end

    -- all 32 LSB are 1, fully solid in this case
    local mask = 4294967295

    if node.leafVoxelsBottom == mask and node.leafVoxelsTop == mask then
        return true
    end

    return false
end

--- isLeaf checks if the provided node is a leaf node.
--@param node is the node to be checked from, type GridMap3DNode table.
--@return true if the node was a leaf.
function GridMap3DNode.isLeaf(node)
    if node == nil then
        return false
    end

    if node.children == nil then
        if node.leafVoxelsBottom ~= nil and node.leafVoxelsTop ~= nil then
            return true
        end
    end

    return false
end

--- checkAABBIntersection simple helper function to find if two boxes intersect.
-- aabb's provided as table as following , minX,minY,minZ,maxX,maxY,maxZ.
--@param aabb1 is the first bounding box.
--@param aabb2 is the second bounding box.
--@return true if two provided boxes intersect.
function GridMap3DNode.checkAABBIntersection(aabb1, aabb2)
    if aabb1 == nil or aabb2 == nil then
        return false
    end

    if aabb1[1] > aabb2[4] or aabb2[1] > aabb1[4] or aabb1[2] > aabb2[5] or aabb2[2] > aabb1[5] or aabb1[3] > aabb2[6] or aabb2[3] > aabb1[6] then
        return false
    else
        return true
    end
end

--- checkPointInAABB simple helper function to find if a point is inside box.
-- aabb provided as table as following , minX,minY,minZ,maxX,maxY,maxZ.
--@param point is the point's coordinates, given as {x=,y=,z=}.
--@param aabb is the bounding box.
--@return true if point is inside provided box.
function GridMap3DNode.checkPointInAABB(point, aabb)
    if point == nil or aabb == nil then
        return false
    end

    if point.x >= aabb[1] and point.x <= aabb[4] and point.y >= aabb[2] and point.y <= aabb[5] and point.z >= aabb[3] and point.z <= aabb[6] then
        return true
    else
        return false
    end
end

--- getRandomPoint is called to receive a random x,y,z location within the node provided.
--@param node is the node within a location is received.
--@return x,y,z in a hash table, coordinates of a point within the node.
function GridMap3DNode.getRandomPoint(node)

    if node == nil then
        return 0,0,0
    end

    local randomX = math.random(node.positionX - (node.size/2), node.positionX + (node.size/2))
    local randomY = math.random(node.positionY - (node.size/2), node.positionY + (node.size/2))
    local randomZ = math.random(node.positionZ - (node.size/2), node.positionZ + (node.size/2))

    return {x = randomX,y = randomY,z = randomZ}
end



---@class GridMap3DUpdate exists for creating an update table for the grid reacting to deletion or creation of a placeable.
GridMap3DUpdate = {}

--- new creates a new GridMap3DUpdate.
--@param id is the id of the placeable object sold or placed.
--@param x is the coordinate of the middle of the object.
--@param y is the coordinate of the middle of the object.
--@param z is the coordinate of the middle of the object.
--@param aabb is an box that contains the whole object, table constructed as minX,minY,minZ,maxX,maxY,maxZ.
--@param isDeletion is a boolean that states if the placeable object was deleted/sold or placed.
function GridMap3DUpdate.new(id,x,y,z,aabb,isDeletion)
    local self = setmetatable({},nil)
    self.positionX = x
    self.positionY = y
    self.positionZ = z
    self.id = id
    self.aabb = aabb
    self.bDeletion = (isDeletion ~= nil and {isDeletion} or {false})[1]
    return self
end


---@class GridMap3D.
--Custom object class for the 3d navigation grid.
GridMap3D = {}
GridMap3D_mt = Class(GridMap3D,Object)
InitObjectClass(GridMap3D, "GridMap3D")


--- new creates a new grid map 3d.
--@param customMt optional customized base table.
function GridMap3D.new(gridVersion)
    local self = Object.new(g_server ~= nil,g_client ~= nil, GridMap3D_mt)
    -- nodeTree will contain the root node of the octree which then has references to deeper nodes.
    self.gridVersion = gridVersion or "1.0.0"
    self.nodeTree = {}
    self.terrainSize = 2048
    -- contains all the states
    self.gridMap3DStates = {}
    self.EGridMap3DStates = {UNDEFINED = 0, PREPARE = 1, GENERATE = 2, DEBUG = 3, UPDATE = 4, IDLE = 5}
    self.currentGridState = self.EGridMap3DStates.UNDEFINED
    -- this bool is toggled by console command to true and false
    self.bOctreeDebug = false
    -- contains the ids of the objects which will be ignored and not marked as solid by the grid.
    self.objectIgnoreIDs = {}
    -- contains updates queued up and waiting to set to ready queue after a certain delay, as to not try to update the grid too fast as the collision might not be registered immediately.
    self.gridUpdateQueue = {}
    -- contains the updates that are ready to be updated in the grid.
    self.gridUpdateReadyQueue = {}
    -- contains the function events that should be notified after grid update has been increased
    self.onGridUpdateQueueIncreasedEvent = {}
    -- sets activated once the update has run once, so that any placeables that are placed while in loading screen won't be triggered to be updated in the grid.
    self.bActivated = false
    -- this contains the updates that are waiting a time before they are ready to be checked out.
    self.latentUpdates = {}
    -- used by the grid states to know if collision check was solid, set in the trace callback
    self.bTraceVoxelSolid = false
    self.bUnderTerrain = false
    self.bCenterUnderTerrain = false
    self.bBottomUnderTerrain = false
    self.collisionMask = CollisionFlag.STATIC_WORLD
    self.bGridGenerated = false
    self.defaultConfigFilename = "config/config.xml"
    self.configFilename = "flyPathfinding/config.xml"

    -- Need to find the highest value in the messagetype , as own inserted ones need to be higher
    local messageTypeCount = 0
    for _,message in pairs(MessageType) do
        if type(message) == "number" then
            if message > messageTypeCount then
                messageTypeCount = message
            end
        end
    end

    MessageType.GRIDMAP3D_GRID_GENERATED = messageTypeCount + 1
    MessageType.GRIDMAP3D_GRID_UPDATED = messageTypeCount + 2
    MessageType.GRIDMAP3D_GRID_UPDATEREADY = messageTypeCount + 3


    -- Appends to the finalizePlacement function which is called when a placeable is placed down.
    Placeable.finalizePlacement = Utils.appendedFunction(Placeable.finalizePlacement,
        function(...)
            self:onPlaceablePlaced(unpack({...}))
        end
    )
    -- prepends on to the onSell function of a placeable to get notified when a placeable has been sold/deleted
    Placeable.onSell = Utils.prependedFunction(Placeable.onSell,
        function(...)
            self:onPlaceableSold(unpack({...}))
        end
    )

    -- subscribe to the own UPDATEREADY message, so that the grid can be tried to be updated.
    g_messageCenter:subscribe(MessageType.GRIDMAP3D_GRID_UPDATEREADY,GridMap3D.onGridNeedUpdate,self)

    -- Creates all the needed states and changes to the prepare state initially.
    self.gridMap3DStates[self.EGridMap3DStates.PREPARE] = GridMap3DStatePrepare.new()
    self.gridMap3DStates[self.EGridMap3DStates.PREPARE]:init(self)
    self.gridMap3DStates[self.EGridMap3DStates.GENERATE] = GridMap3DStateGenerate.new()
    self.gridMap3DStates[self.EGridMap3DStates.GENERATE]:init(self)
    self.gridMap3DStates[self.EGridMap3DStates.DEBUG] = GridMap3DStateDebug.new()
    self.gridMap3DStates[self.EGridMap3DStates.DEBUG]:init(self)
    self.gridMap3DStates[self.EGridMap3DStates.UPDATE] = GridMap3DStateUpdate.new()
    self.gridMap3DStates[self.EGridMap3DStates.UPDATE]:init(self)

    registerObjectClassName(self, "GridMap3D")

    return self
end

--- init the grid.
-- changes the state to prepare.
function GridMap3D:init()

    if g_currentMission ~= nil then
        -- overlapBox seems to have some bug with non default sized maps.
        if getTerrainSize(g_currentMission.terrainRootNode) ~= 2048 then
            Logging.info("The fly pathfinding does not work on non-default sized maps!")
            self.currentGridState = self.EGridMap3DStates.UNDEFINED
            return false
        end
        self:loadConfig()
        self:changeState(self.EGridMap3DStates.PREPARE)
        return true
    end

    return false
end


--- getVersion called to get the version of pathfinding system.
--@return string value which indicates version.
function GridMap3D:getVersion()
    return self.gridVersion
end

--- loadConfig called to setup the necessary variables from config.xml if found.
function GridMap3D:loadConfig()

    -- Highest resolution leaf voxels in the octree, given in meters
    self.maxVoxelResolution = 1
    -- How many loops to do initially when loading into the game, helps to avoid creating the octree very long while the game is properly running.
    self.maxOctreePreLoops = 125000
    -- How many loops per update to generate the octree, HEAVILY affects performance.
    self.maxOctreeGenerationLoopsPerUpdate = 20
    -- ignoreTrees if the grid should not include trees as solid
    self.bIgnoreTrees = true
    -- ignoreWater if the grid should not include water as solid
    self.bIgnoreWater = true

    if not fileExists(g_modSettingsDirectory .. self.configFilename) then
        if fileExists(FlyPathfinding.modDir .. self.defaultConfigFilename) then
            local defaultConfig = loadXMLFile("TempXML", FlyPathfinding.modDir .. self.defaultConfigFilename)
            if getXMLString(defaultConfig, "Config.octreeConfig#maxVoxelResolution") ~= nil then
                self.maxVoxelResolution = getXMLFloat(defaultConfig,"Config.octreeConfig#maxVoxelResolution")
            end
            if getXMLString(defaultConfig, "Config.octreeConfig#maxOctreePreLoops") ~= nil then
                self.maxOctreePreLoops = getXMLInt(defaultConfig,"Config.octreeConfig#maxOctreePreLoops")
            end
            if getXMLString(defaultConfig, "Config.octreeConfig#maxOctreeGenerationLoopsPerUpdate") ~= nil then
                self.maxOctreeGenerationLoopsPerUpdate = getXMLInt(defaultConfig,"Config.octreeConfig#maxOctreeGenerationLoopsPerUpdate")
            end
            if getXMLString(defaultConfig, "Config.octreeConfig#ignoreTrees") ~= nil then
                self.bIgnoreTrees = getXMLBool(defaultConfig,"Config.octreeConfig#ignoreTrees")
            end
            if getXMLString(defaultConfig, "Config.octreeConfig#ignoreWater") ~= nil then
                self.bIgnoreWater = getXMLBool(defaultConfig,"Config.octreeConfig#ignoreWater")
            end
        end
        -- as the global grid settings has not been set in the modSettings directory then need to set defaults from within this mod zip and place the settings to easy accessible location.
        createFolder(g_modSettingsDirectory .. "flyPathfinding")
        local config = createXMLFile("xmlFile",g_modSettingsDirectory .. self.configFilename,"octreeConfig")
        setXMLFloat(config, "octreeConfig" .. '#maxVoxelResolution', self.maxVoxelResolution)
        setXMLInt(config, "octreeConfig" .. '#maxOctreePreLoops', self.maxOctreePreLoops)
        setXMLInt(config, "octreeConfig" .. '#maxOctreeGenerationLoopsPerUpdate', self.maxOctreeGenerationLoopsPerUpdate)
        setXMLBool(config, "octreeConfig" .. '#ignoreTrees', self.bIgnoreTrees)
        setXMLBool(config, "octreeConfig" .. '#ignoreWater', self.bIgnoreWater)
        saveXMLFile(config)
        delete(config)
    else

        local config = loadXMLFile("TempXML",g_modSettingsDirectory .. self.configFilename)
        if getXMLString(config, "octreeConfig#maxVoxelResolution") ~= nil then
            self.maxVoxelResolution = getXMLFloat(config,"octreeConfig#maxVoxelResolution")
        end
        if getXMLString(config, "octreeConfig#maxOctreePreLoops") ~= nil then
            self.maxOctreePreLoops = getXMLInt(config,"octreeConfig#maxOctreePreLoops")
        end
        if getXMLString(config, "octreeConfig#maxOctreeGenerationLoopsPerUpdate") ~= nil then
            self.maxOctreeGenerationLoopsPerUpdate = getXMLInt(config,"octreeConfig#maxOctreeGenerationLoopsPerUpdate")
        end
        if getXMLString(config, "octreeConfig#ignoreTrees") ~= nil then
            self.bIgnoreTrees = getXMLBool(config,"octreeConfig#ignoreTrees")
        end
        if getXMLString(config, "octreeConfig#ignoreWater") ~= nil then
            self.bIgnoreWater = getXMLBool(config,"octreeConfig#ignoreWater")
        end

    end

    -- leaf node is four times the size of the highest resolution, as leaf node contains the highest resolution in a 4x4x4 grid.
    self.leafNodeResolution = self.maxVoxelResolution * 4

    -- if water should not be ignored adds it to the default static collisionmask
    if not self.bIgnoreWater then
        self.collisionMask = self.collisionMask + CollisionFlag.WATER
    end

end

--- isAvailable can be called to check if there is an octree to be used.
--@return true if an octree has been already generated.
function GridMap3D:isAvailable()
    return self.bGridGenerated
end

--- addObjectToIgnore is for adding another object to be ignored from the grid as non-solid even if it has collision.
--@param id is the object id to be ignored.
function GridMap3D:addObjectIgnoreID(id)
    if id == nil or type(id) ~= "number" then
        return
    end

    self.objectIgnoreIDs[id] = true
end

--- removeObjectToIgnore is for removing another object that had been set to be ignored from the grid as non-solid even if it has collision.
--@param id is the object id to remove from ignore list.
function GridMap3D:removeObjectIgnoreID(id)
    if id == nil or type(id) ~= "number" then
        return
    end

    self.objectIgnoreIDs[id] = nil
end



--- onGridNeedUpdate is a callback function for when an update has been readied for the grid.
-- Prepares a grid update into the ready queue and calls forward to change to update state.
function GridMap3D:onGridNeedUpdate()
    if next(self.gridUpdateQueue) == nil then
        return
    end

    local _i, readyUpdate = next(self.gridUpdateQueue)
    self.gridUpdateReadyQueue[readyUpdate.id] = readyUpdate
    self.gridUpdateQueue[readyUpdate.id] = nil

    self:changeState(self.EGridMap3DStates.UPDATE)
end

--- delete function handles cleaning up the grid.
function GridMap3D:delete()

    self.isDeleted = true
    if self.gridMap3DStates[self.currentGridState] ~= nil then
        self.gridMap3DStates[self.currentGridState]:leave()
    end

    for _, state in pairs(self.gridMap3DStates) do

        if state ~= nil then
            state:destroy()
        end

    end

    if g_messageCenter ~= nil then
        g_messageCenter:unsubscribe(MessageType.GRIDMAP3D_GRID_UPDATEREADY,self)
    end

    self.gridMap3DStates = nil
    self.nodeTree = nil

    self.gridUpdateQueue = nil
    self.gridUpdateReadyQueue = nil
    self.onGridUpdateQueueIncreasedEvent = nil
    self.EGridMap3DStates = nil
    self.latentUpdates = nil

    GridMap3D:superClass().delete(self)

    unregisterObjectClassName(self)
end

--- changeState changes the grid's state.
--@param newState is the state to try change into. type of self.EGridMap3DStates table, where state is just a number.
function GridMap3D:changeState(newState)

    if newState == nil or type(newState) ~= "number" then
        Logging.warning("Not a valid state given to GridMap3D:changeState() _ ".. tostring(newState))
        return
    end

    if newState == 0 then
        Logging.info("GridMap3D is going to undefined state! Issue occured somewhere!")
        self.currentGridState = self.EGridMap3DStates.UNDEFINED
        return
    end

    if newState == self.currentGridState then
        return
    end

    -- can't change into update if it is still generating
    if newState == self.EGridMap3DStates.UPDATE and self.currentGridState == self.EGridMap3DStates.GENERATE then
        return
    -- if there is work queued when returning to idle should set to update state instead
    elseif newState == self.EGridMap3DStates.IDLE and next(self.gridUpdateReadyQueue) ~= nil then
        newState = self.EGridMap3DStates.UPDATE
    -- if debug is on then when returning to idle should set to debug state instead
    elseif newState == self.EGridMap3DStates.IDLE and self.bOctreeDebug then
        newState = self.EGridMap3DStates.DEBUG
    end

    -- leave current state if a valid state object
    if self.gridMap3DStates[self.currentGridState] ~= nil then
        self.gridMap3DStates[self.currentGridState]:leave()
    end

    self.currentGridState = newState

    if self.gridMap3DStates[self.currentGridState] ~= nil then
        self.gridMap3DStates[self.currentGridState]:enter()
    end

end

--- update as the GridMap3D is based on an FS22 Object, it has the update function which is called as long as raiseActive() is called on the object.
-- Here it forwards the update to valid current state, runs any latentUpdates if exists.
--@param dt is the deltaTime received every update.
function GridMap3D:update(dt)
    GridMap3D:superClass().update(self,dt)

    self:raiseActive()

    if self.bActivated == false then
        self.bActivated = true
    end

    for i = #self.latentUpdates, 1, -1 do
        if self.latentUpdates[i] ~= nil then
            self.latentUpdates[i]:run(dt / 1000)
            if self.latentUpdates[i].bFinished then
                table.remove(self.latentUpdates,i)
            end
        end
    end

    if self.gridMap3DStates[self.currentGridState] ~= nil then
         self.gridMap3DStates[self.currentGridState]:update(dt)
    end
end

--- QueueGridUpate is called to queue a grid update.
-- The grid update received is inserted into a latent update action.
--@param newWork is the created update prepared for the octree.
function GridMap3D:QueueGridUpdate(newWork)

    if newWork == nil then
        return
    end

    -- if the same object has been queued before, it means this time it has been deleted before the grid has been updated so deletes and returns
    if self.gridUpdateQueue[newWork.id] ~= nil then
        self.gridUpdateQueue[newWork.id] = nil
        return
    elseif self.gridUpdateReadyQueue[newWork.id] ~= nil then
        self.gridUpdateReadyQueue[newWork.id] = nil
        return
    end

    self.gridUpdateQueue[newWork.id] = newWork

    local newLatentUpdate = GridMap3DLatentMessage.new(MessageType.GRIDMAP3D_GRID_UPDATEREADY,nil,1)

    table.insert(self.latentUpdates,newLatentUpdate)
end

--- onPlaceablePlaced is appended into the Placeable:onFinalizePlacement function.
-- forwards the placeable ref to the function that handles creating an update for octree.
--@param placeable is the reference to the placeable which has been placed.
function GridMap3D:onPlaceablePlaced(placeable)
    self:onPlaceableModified(placeable,false)
end

--- onPlaceableSolid is prepended into the Placeable:onSell function.
-- forwards the placeable ref to the function that handles creating an update for octree.
--@param placeable is the reference to the placeable which is being sold.
function GridMap3D:onPlaceableSold(placeable)
    self:onPlaceableModified(placeable,true)
end

--- onPlaceableModified is called for when a placeable gets sold or placed in the game world.
-- Used to catch the information needed to update the octree with the new or removed placeable.
-- Needs to be checked if it is a fence and skipped as they are dumbly programmed, where they actually call finalizePlacement even without placing them...
--@param placeable is the self reference of the placeable sold or added.
--@param isDeletion is a bool indicating if it is being sold/deleted or placed.
function GridMap3D:onPlaceableModified(placeable,isDeletion)

    if not self.bActivated or placeable == nil or placeable.rootNode == nil or placeable.spec_fence ~= nil then
        return
    end

    local x,y,z = getTranslation(placeable.rootNode)
    local _rotX,rotY,_rotZ = getRotation(placeable.rootNode)
    -- Init a new grid queue update with the placeable's id and location, and intially has some values set which might change down below if spec_placement exists.
    local newWork = GridMap3DUpdate.new(placeable.rootNode,x,y,z,{x - 50, y - 50, z - 50, x + 50, y + 50, z + 50},isDeletion)


    if placeable.spec_placement ~= nil and placeable.spec_placement.testAreas ~= nil and next(placeable.spec_placement.testAreas) ~= nil then
        -- init beyond possible coordinate ranges
        local minX,minY,minZ,maxX,maxY,maxZ = 99999,99999,99999,-99999,-99999,-99999

        for _, area in ipairs(placeable.spec_placement.testAreas) do

            local startX,startY,startZ = getWorldTranslation(area.startNode)
            local endX,endY,endZ = getWorldTranslation(area.endNode)

            local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
            local normX, _, normZ = MathUtil.crossProduct(0, 1, 0, dirX, 0, dirZ)
            local centerXOffset = area.center.x
            local centerZOffset = area.center.z
            local centerX = x + dirX * centerZOffset + normX * centerXOffset
            local centerZ = z + dirZ * centerZOffset + normZ * centerXOffset

            local xDistance = math.abs(startX - endX)
            local zDistance = math.abs(startZ - endZ)
            local halfDistance = math.max(xDistance,zDistance) / 2
            local halfYDistance = math.abs(startY - endY) / 2
            minX = math.min(minX, centerX - halfDistance)
            minZ = math.min(minZ, centerZ - halfDistance)
            minY = math.min(minY, y - halfYDistance)

            maxX = math.max(maxX, centerX + halfDistance)
            maxZ = math.max(maxZ, centerZ + halfDistance)
            maxY = math.max(maxY, y + math.abs(startY - endY))

        end

        newWork.positionY = y + (math.abs(minY - maxY) / 2)
        newWork.positionX = (math.abs(minX - maxX) / 2)
        newWork.positionZ = (math.abs(minZ - maxZ) / 2)

        newWork.aabb = {minX,minY,minZ,maxX,maxY,maxZ}
    end

    self:QueueGridUpdate(newWork)

end

--- getNodeTreeLayer is a helper function to get which layer the current sized node is at.
-- Where layer 1 has only one node and is the root node of the octree.
--@return a number of octree layer between 1 - n
function GridMap3D:getNodeTreeLayer(size)
    if size < 1 or size == nil then
        return 1
    end

    local dividedBy = math.floor(self.terrainSize / size)
    -- + 1 as the layer 1 is the root
    return ((math.log(dividedBy)) / (math.log(2))) + 1
end

--- getNodeLocation called to get location of the given node either node location or leaf voxel location.
--@param gridNode is given as table of {GridMap3DNode,leaf voxel index (-1 - 63)}.
--@return table of {x=,y=,z=} representing the location of given node.
function GridMap3D:getNodeLocation(gridNode)
    if gridNode == nil or gridNode[1] == nil then
        return {x=0,y=0,z=0}
    end

    if gridNode[2] == -1 then
        return {x = gridNode[1].positionX, y = gridNode[1].positionY, z = gridNode[1].positionZ }
    end

    local startPositionX = gridNode[1].positionX - self.maxVoxelResolution - (self.maxVoxelResolution / 2)
    local startPositionY = gridNode[1].positionY - self.maxVoxelResolution - (self.maxVoxelResolution / 2)
    local startPositionZ = gridNode[1].positionZ - self.maxVoxelResolution - (self.maxVoxelResolution / 2)

    local yIndex = math.floor(gridNode[2] / 16)
    local zIndex = math.floor((gridNode[2] - (yIndex * 16)) / 4)
    local xIndex = gridNode[2] - (yIndex * 16) - (zIndex * 4)
    return {x = startPositionX + (self.maxVoxelResolution * xIndex),y = startPositionY + (self.maxVoxelResolution * yIndex),z = startPositionZ + (self.maxVoxelResolution * zIndex)}

end

--- getNodeSize called to get size of the given node either normal node or leaf voxel size.
--@param gridNode is given as table of {GridMap3DNode,leaf voxel index (-1 - 63)}.
--@return size as number.
function GridMap3D:getNodeSize(gridNode)
    if gridNode == nil or gridNode[1] == nil then
        return 0
    end

    if gridNode[2] == -1 then
        return gridNode[1].size
    else
        return self.maxVoxelResolution
    end

end

--- clampToGrid is used to clamp a given position into within the octree grid coordinates with a 10cm safe margin.
--@param position is the location what wants to be clamped to make sure it is within octree grid coordinates, given as {x=,y=,z=}
--@return returns the new position
function GridMap3D:clampToGrid(position)

    if self:isAvailable() == false then
        Logging.info("Could not clamp position to grid as grid is not yet ready")
        return position
    end

    if self.nodeTree == nil or self.nodeTree.children == nil then
        Logging.warning("GridMap3D:clampToGrid: encountered nil values!")
        printCallstack()
        return
    end

    local gridMinX = self.nodeTree.children[1].positionX - (self.nodeTree.children[1].size / 2) + 0.1
    local gridMinY = self.nodeTree.children[1].positionY - (self.nodeTree.children[1].size / 2) + 0.1
    local gridMinZ = self.nodeTree.children[1].positionZ - (self.nodeTree.children[1].size / 2) + 0.1
    local gridMaxX = self.nodeTree.children[2].positionX + (self.nodeTree.children[1].size / 2) - 0.1
    local gridMaxY = self.nodeTree.children[5].positionY + (self.nodeTree.children[1].size / 2) - 0.1
    local gridMaxZ = self.nodeTree.children[3].positionZ + (self.nodeTree.children[1].size / 2) - 0.1

    local newPosition = {}
    newPosition.x = MathUtil.clamp(position.x,gridMinX,gridMaxX)
    newPosition.y = MathUtil.clamp(position.y,gridMinY,gridMaxY)
    newPosition.z = MathUtil.clamp(position.z,gridMinZ,gridMaxZ)
    return newPosition
end


--- getGridNode is a function to find the node of the octree which given point resides in.
--@param position is the given location which should reside inside a grid node to be seeked, given as {x=,y=,z=}.
--@param returnNodeIfSolid is a bool that can be used to return {nil,-1} in a case where the position was a residing in a solid or completely under terrain node/leaf voxel.
--@param customRootNode if a custom start root node is given then it starts to look from within that octree node downwards instead of octree root.
--@return The GridMap3DNode of where the given point resides in, as it can be inside leaf node's voxels the return is given as {node,voxelIndex}.
function GridMap3D:getGridNode(position,returnNodeIfSolid,customRootNode)
    if position == nil or self.nodeTree == nil or self:isAvailable() == false then
        return {nil,-1}
    end

    local currentNode = customRootNode or self.nodeTree

    local aabbParentNode = {currentNode.positionX - (currentNode.size / 2), currentNode.positionY - (currentNode.size / 2), currentNode.positionZ - (currentNode.size / 2),currentNode.positionX + (currentNode.size / 2),
        currentNode.positionY + (currentNode.size / 2), currentNode.positionZ + (currentNode.size / 2) }

    if GridMap3DNode.checkPointInAABB(position,aabbParentNode) == false then
        DebugUtil.printTableRecursively(currentNode)
        Logging.info("aabbParentNode was minX:%f minY:%f minZ:%f maxX:%f maxY:%f maxZ:%f ",aabbParentNode[1],aabbParentNode[2],aabbParentNode[3],aabbParentNode[4],aabbParentNode[5],aabbParentNode[6])
        Logging.info("position was X:%f Y:%f Z:%f ",position.x,position.y,position.z)
        Logging.info("GridMap3D:getGridNode: Given position was not inside the grid!")
        return {nil,-1}
    end

    if currentNode.children == nil and GridMap3DNode.isUnderTerrain(currentNode) and returnNodeIfSolid == false then
        return {nil,-1}
    elseif currentNode.children == nil then
        return {currentNode,-1}
    end

    while true do

        -- need to check the voxels in 2 x 32 bits
        if currentNode.size == self.leafNodeResolution then
            if GridMap3DNode.isLeafFullSolid(currentNode) then
                if returnNodeIfSolid then
                    return {currentNode,-1}
                else
                    return {nil,-1}
                end
            elseif GridMap3DNode.isNodeSolid({currentNode,-1}) == false then
                return {currentNode,-1}
            end

            local nodeCornerOrigin = {}
            nodeCornerOrigin.x = currentNode.positionX - self.maxVoxelResolution * 2
            nodeCornerOrigin.y = currentNode.positionY - self.maxVoxelResolution * 2
            nodeCornerOrigin.z = currentNode.positionZ - self.maxVoxelResolution * 2

            local voxelIndexX = math.floor((position.x - nodeCornerOrigin.x) / self.maxVoxelResolution)
            local voxelIndexY = math.floor((position.y - nodeCornerOrigin.y) / self.maxVoxelResolution) * 16
            local voxelIndexZ = math.floor((position.z - nodeCornerOrigin.z) / self.maxVoxelResolution) * 4
            local voxelIndex = voxelIndexX + voxelIndexY + voxelIndexZ

            if GridMap3DNode.isNodeSolid({currentNode,voxelIndex}) and returnNodeIfSolid == false then
                return {nil,-1}

            else
                return {currentNode,voxelIndex}
            end

        elseif currentNode.children == nil and GridMap3DNode.isUnderTerrain(currentNode) and returnNodeIfSolid == false then
            return {nil,-1}
        elseif currentNode.children == nil then
            return {currentNode,-1}
        end

        for _ ,childNode in pairs(currentNode.children) do

            aabbChildNode = {childNode.positionX - (childNode.size / 2), childNode.positionY - (childNode.size / 2), childNode.positionZ - (childNode.size / 2),childNode.positionX + (childNode.size / 2),
            childNode.positionY + (childNode.size / 2), childNode.positionZ + (childNode.size / 2) }

            if GridMap3DNode.checkPointInAABB(position,aabbChildNode) == true then
                currentNode = childNode
                break
            end

        end

    end

    return {nil,-1}
end

--- Function is used to find the smallest octree node which contains all the given positions.
--@param positionsTable is given positions to find node which encomppasess these, given as table of table {x=,y=,z=}.
--@return returns the GridMap3DNode which encomppasses all the given positions.
function GridMap3D:getGridNodeEncomppasingPositions(positionsTable)
    if self.nodeTree == nil or positionsTable == nil then
        return {nil,-1}
    end

    local currentNode = self.nodeTree

    local aabbParentNode = {currentNode.positionX - (currentNode.size / 2), currentNode.positionY - (currentNode.size / 2), currentNode.positionZ - (currentNode.size / 2),currentNode.positionX + (currentNode.size / 2),
        currentNode.positionY + (currentNode.size / 2), currentNode.positionZ + (currentNode.size / 2) }


    for _, position in ipairs(positionsTable) do
        if GridMap3DNode.checkPointInAABB(position,aabbParentNode) == false then
            return {nil,-1}
        end
    end

    if currentNode.children == nil then
        return {currentNode,-1}
    end


    while true do
        local bAllExists = true

        if currentNode.size == self.leafNodeResolution then

            for i = 0, 63 do

                local leafPosition = self:getNodeLocation({currentNode,i})
                local aabbLeafVoxelNode = {leafPosition.x - (self.maxVoxelResolution / 2), leafPosition.y - (self.maxVoxelResolution / 2), leafPosition.z - (self.maxVoxelResolution / 2),
                    leafPosition.x + (self.maxVoxelResolution / 2), leafPosition.y + (self.maxVoxelResolution / 2), leafPosition.z + (self.maxVoxelResolution / 2) }

                for _, position in ipairs(positionsTable) do
                    bAllExists = true
                    if GridMap3DNode.checkPointInAABB(position,aabbLeafVoxelNode) == false then
                        bAllExists = false
                        break
                    end
                end
                -- if all positions were within the leaf voxel then this is the smallest node that encomppasses all given positions.
                if bAllExists == true then
                    return {currentNode,i}
                end

            end
            -- if all points weren't within a leaf voxel then the leaf node itself is the smallest node that contains all given positions.
            return {currentNode,-1}


        elseif currentNode.children == nil then
            return {currentNode,-1}
        end

        local newInnerNode = nil
        for _ ,childNode in pairs(currentNode.children) do
            bAllExists = true
            aabbChildNode = {childNode.positionX - (childNode.size / 2), childNode.positionY - (childNode.size / 2), childNode.positionZ - (childNode.size / 2),childNode.positionX + (childNode.size / 2),
            childNode.positionY + (childNode.size / 2), childNode.positionZ + (childNode.size / 2) }

            for _, position in ipairs(positionsTable) do
                if GridMap3DNode.checkPointInAABB(position,aabbChildNode) == false then
                    bAllExists = false
                    break
                end
            end

            if bAllExists == true then
                newInnerNode = childNode
                break
            end

        end

        -- A child node was found that contained all the given positions can proceed to look into that node.
        if newInnerNode ~= nil then
            currentNode = newInnerNode
        else
            -- if no child node contained all the positions then this current node is the wanted node that contains all the given positions.
            return {currentNode,-1}
        end

    end

end


--- voxelOverlapCheck is called when a new node/leaf voxel need to be checked for collision.
-- first it checks the terrain height, if the terrain is higher than the node's y extent then can skip wasting time to collision check as it can be counted as non-solid.
--@param x is the center coordinate of node/leaf voxel to be checked.
--@param y is the center coordinate of node/leaf voxel to be checked.
--@param z is the center coordinate of node/leaf voxel to be checked.
--@param extentRadius is the radius of the node/leaf voxel to be checked.
--@return true if was a collision on checked location
function GridMap3D:voxelOverlapCheck(x,y,z, extentRadius)
    self.bTraceVoxelSolid = false
    self.bUnderTerrain = false
    self.bCenterUnderTerrain = false
    self.bBottomUnderTerrain = false

    local terrainHeight = 0
    if g_currentMission.terrainRootNode ~= nil then
        terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,x,y,z)
    end

    if y + extentRadius < terrainHeight then
        self.bUnderTerrain = true
        return
    end

    if y <= terrainHeight then
        self.bCenterUnderTerrain = true
    end

    if y - extentRadius < terrainHeight then
        self.bBottomUnderTerrain = true
    end


    overlapBox(x,y,z,0,0,0,extentRadius,extentRadius,extentRadius,"voxelOverlapCheckCallback",self,self.collisionMask,false,true,true,false)

end

--- voxelOverlapCheckCallback is callback function for the overlapBox.
-- preferably would ignore roads and other thin objects close to terrain level but not sure if possible...
-- Checks if there was any object id found, or if it was the terrain or if it was the boundary then can ignore those.
-- If it wasn't any of the above then it checks if it has the ClassIds.SHAPE, if it does then it is counted as solid.
--@param hitObjectId is the id of collided thing.
function GridMap3D:voxelOverlapCheckCallback(hitObjectId)

    if hitObjectId < 1 or hitObjectId == g_currentMission.terrainRootNode or self.objectIgnoreIDs[hitObjectId] then
        return true
    end

    if getHasClassId(hitObjectId,ClassIds.SHAPE) then

        if bitAND(getCollisionMask(hitObjectId),CollisionFlag.TREE) == CollisionFlag.TREE and self.bIgnoreTrees then
            return true
        end

        self.bTraceVoxelSolid = true
        return false
    end

    return true
end


--- createLeafVoxels is called when layer index is reached for the leaf nodes.
-- the leaftvoxels are 4x4x4 voxels within the leaf node.
-- Because of limited bit manipulation, the FS bitOR&bitAND works up to 32bits.
-- So the voxels were divided into to variables, bottom 32 voxels into one, and the top 32 voxels into another.
-- Where each bit indicates if it is a solid or empty.
--@param parent node which owns these leaf voxels.
function GridMap3D:createLeafVoxels(parent)

    if parent == nil then
        return
    end


    parent.leafVoxelsBottom = 0
    parent.leafVoxelsTop = 0

    -- early check if no collision for whole leaf node and not below terrain then no inner 64 voxels need to be checked
    self:voxelOverlapCheck(parent.positionX,parent.positionY,parent.positionZ,parent.size / 2)
    if self.bTraceVoxelSolid == false and self.bUnderTerrain == false and self.bBottomUnderTerrain == false then
        return
    end

    for i = 0, 31 do

        local leafPosition = self:getNodeLocation({parent,i})
        self:voxelOverlapCheck(leafPosition.x,leafPosition.y,leafPosition.z,self.maxVoxelResolution / 2)
        -- if voxel was solid then set the bit to 1
        if self.bTraceVoxelSolid == true or self.bBottomUnderTerrain == true or self.bUnderTerrain == true then
            parent.leafVoxelsBottom = bitOR(parent.leafVoxelsBottom,( 1 * 2^i))
        end
    end

    for i = 32, 63 do
        local leafPosition = self:getNodeLocation({parent,i})
        self:voxelOverlapCheck(leafPosition.x,leafPosition.y,leafPosition.z,self.maxVoxelResolution / 2)
        -- if voxel was solid then set the bit to 1
        if self.bTraceVoxelSolid == true or self.bBottomUnderTerrain == true or self.bUnderTerrain == true then
            parent.leafVoxelsTop = bitOR(parent.leafVoxelsTop,( 1 * 2^(i-32)))
        end
    end

end

--- findNeighbours looks for the possible neighbours that the current childNumber can reach.
--@param node is the which needs its neighbours assigned.
--@param childNumber is the number of child, to know which location it is within the parent node.
function GridMap3D:findNeighbours(node,childNumber)

    if node == nil or childNumber == nil or childNumber < 1 or childNumber > 8 then
        return
    end

    if childNumber == 1 then
        self:findOutsideNeighbours(2,EDirections.MINUSX,node)
        self:findOutsideNeighbours(3,EDirections.MINUSZ,node)
        self:findOutsideNeighbours(5,EDirections.MINUSY,node)

    elseif childNumber == 2 then
        node.xMinusNeighbour = node.parent.children[1]
        node.parent.children[1].xNeighbour = node

        self:findOutsideNeighbours(4,EDirections.MINUSZ,node)
        self:findOutsideNeighbours(1,EDirections.X,node)
        self:findOutsideNeighbours(6,EDirections.MINUSY,node)

    elseif childNumber == 3 then
        node.zMinusNeighbour = node.parent.children[1]
        node.parent.children[1].zNeighbour = node

        self:findOutsideNeighbours(4,EDirections.MINUSX,node)
        self:findOutsideNeighbours(1,EDirections.Z,node)
        self:findOutsideNeighbours(7,EDirections.MINUSY,node)

    elseif childNumber == 4 then
        node.zMinusNeighbour = node.parent.children[2]
        node.parent.children[2].zNeighbour = node

        node.xMinusNeighbour = node.parent.children[3]
        node.parent.children[3].xNeighbour = node

        self:findOutsideNeighbours(8,EDirections.MINUSY,node)
        self:findOutsideNeighbours(2,EDirections.Z,node)
        self:findOutsideNeighbours(3,EDirections.X,node)



    elseif childNumber == 5 then
        node.yMinusNeighbour = node.parent.children[1]
        node.parent.children[1].yNeighbour = node

        self:findOutsideNeighbours(6,EDirections.MINUSX,node)
        self:findOutsideNeighbours(7,EDirections.MINUSZ,node)
        self:findOutsideNeighbours(1,EDirections.Y,node)

    elseif childNumber == 6 then
        node.yMinusNeighbour = node.parent.children[2]
        node.parent.children[2].yNeighbour = node

        node.xMinusNeighbour = node.parent.children[5]
        node.parent.children[5].xNeighbour = node

        self:findOutsideNeighbours(8,EDirections.MINUSZ,node)
        self:findOutsideNeighbours(5,EDirections.X,node)
        self:findOutsideNeighbours(2,EDirections.Y,node)



    elseif childNumber == 7 then
        node.yMinusNeighbour = node.parent.children[3]
        node.parent.children[3].yNeighbour = node

        node.zMinusNeighbour = node.parent.children[5]
        node.parent.children[5].zNeighbour = node


        self:findOutsideNeighbours(8,EDirections.MINUSX,node)
        self:findOutsideNeighbours(3,EDirections.Y,node)
        self:findOutsideNeighbours(5,EDirections.Z,node)

    elseif childNumber == 8 then
        node.yMinusNeighbour = node.parent.children[4]
        node.parent.children[4].yNeighbour = node

        node.xMinusNeighbour = node.parent.children[7]
        node.parent.children[7].xNeighbour = node

        node.zMinusNeighbour = node.parent.children[6]
        node.parent.children[6].zNeighbour = node

        self:findOutsideNeighbours(4,EDirections.Y,node)
        self:findOutsideNeighbours(6,EDirections.Z,node)
        self:findOutsideNeighbours(7,EDirections.X,node)

    end

end

--- findOutsideNeighbours tries to link the same resolution nodes from the parent's neighbours children.
-- if it fails to find same resolution it sets the neighbour as the lower resolution/bigger node parent's neighbour.
-- Also sets the outside neighbours opposite direction neighbour as the currently checked node.
--@param neighbourChildNumber is the child number which is suppose to be linked to the node.
--@param direction is the direction the neighbour is being checked from.
--@param node is the current node which has its neighbours linked, type of GridMap3DNode table.
function GridMap3D:findOutsideNeighbours(neighbourChildNumber,direction,node)

    if node == nil or direction == nil or neighbourChildNumber < 1 or neighbourChildNumber > 8 then
        return
    end

    local parentNode = node.parent

    if direction ==  EDirections.MINUSX then

        if parentNode.xMinusNeighbour ~= nil then

            local neighbourNode = parentNode.xMinusNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.xMinusNeighbour = neighbourNode
                return
            end

            node.xMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].xNeighbour = node
            return
        end

    elseif direction == EDirections.MINUSY then

        if parentNode.yMinusNeighbour ~= nil then

            local neighbourNode = parentNode.yMinusNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.yMinusNeighbour = neighbourNode
                return
            end

            node.yMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].yNeighbour = node
            return
        end


    elseif direction == EDirections.MINUSZ then

        if parentNode.zMinusNeighbour ~= nil then

            local neighbourNode = parentNode.zMinusNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.zMinusNeighbour = neighbourNode
                return
            end

            node.zMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].zNeighbour = node
            return
        end

    elseif direction == EDirections.X then

        if parentNode.xNeighbour ~= nil then

            local neighbourNode = parentNode.xNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.xNeighbour = neighbourNode
                return
            end

            node.xNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].xMinusNeighbour = node
            return
        end


    elseif direction == EDirections.Y then

        if parentNode.yNeighbour ~= nil then

            local neighbourNode = parentNode.yNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.yNeighbour = neighbourNode
                return
            end

            node.yNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].yMinusNeighbour = node
            return
        end

    elseif direction == EDirections.Z then

        if parentNode.zNeighbour ~= nil then

            local neighbourNode = parentNode.zNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.zNeighbour = neighbourNode
                return
            end

            node.zNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].zMinusNeighbour = node
            return
        end
    end
end


--- octreeDebugToggle is function bound to debugging console command.
-- Toggles the bOctreeDebug, which then when state goes to idle replcaes idle state with debug state.
function GridMap3D:octreeDebugToggle()

    if AStar.debugObject ~= nil or CatmullRomSplineCreator.debugObject ~= nil then
        Logging.info("Can't turn on octree debug at same time as AStarFlyPathfinding or CatmullRom debug mode!")
        return
    end

    self.bOctreeDebug = not self.bOctreeDebug

    if self.bOctreeDebug and self.currentGridState == self.EGridMap3DStates.IDLE then
        self:changeState(self.EGridMap3DStates.DEBUG)
    elseif not self.bOctreeDebug and self.currentGridState == self.EGridMap3DStates.DEBUG then
        self:changeState(self.EGridMap3DStates.IDLE)
    end


end














