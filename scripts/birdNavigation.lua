
--[[
This file is part of Bird Feeder Mod (https://github.com/DennisB97/FS22BirdFeeder)
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
]]

---@class BirdNavigationGrid.
--Custom object class for the bird navigation grid
BirdNavigationGrid = {}
BirdNavigationGrid.className = "BirdNavigationGrid"
BirdNavigationGrid_mt = Class(BirdNavigationGrid,Object)
InitObjectClass(BirdNavigationGrid, "BirdNavigationGrid")

BirdNavNode = {}

function BirdNavNode.new(x,y,z,parent,size)
    local self = setmetatable({},nil)
    self.positionX = x
    self.positionY = y
    self.positionZ = z
    self.size = size
    self.parent = parent
    self.children = nil
    self.xNeighbour = nil
    self.xMinusNeighbour = nil
    self.yNeighbour = nil
    self.yMinusNeighbour = nil
    self.zNeighbour = nil
    self.zMinusNeighbour = nil
    self.leafVoxelsBottom = nil
    self.leafVoxelsTop = nil
    return self
end

function BirdNavNode.isSolid(node)
    if node == nil then
        return true
    end


    if node.children == nil then
        if (node.leafVoxelsBottom ~= nil and node.leafVoxelsBottom ~= 0) or (node.leafVoxelsTop ~= nil and node.leafVoxelsTop ~= 0) then
            return true
        else
            return false
        end
    end

    return true
end

function BirdNavNode.isLeaf(node)
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
--@return true if two provided boxes intersect.
function BirdNavNode.checkAABBIntersection(aabb1, aabb2)
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
--@return true if point is inside provided box.
function BirdNavNode.checkPointInAABB(px, py, pz, aabb)
    if px == nil or py == nil or pz == nil or aabb == nil then
        return false
    end

    if px >= aabb[1] and px <= aabb[4] and py >= aabb[2] and py <= aabb[5] and pz >= aabb[3] and pz <= aabb[6] then
        return true
    else
        return false
    end
end


BirdNavigationGridUpdate = {}

function BirdNavigationGridUpdate.new(id,x,y,z,aabb)
    local self = setmetatable({},nil)
    self.positionX = x
    self.positionY = y
    self.positionZ = z
    self.id = id
    self.aabb = aabb
    return self
end

function BirdNavigationGrid:QueueGridUpdate(newWork)

    if newWork == nil then
        return
    end

    -- if the same object has been queued before, it means this time it has been deleted before the grid has been updated so deletes and returns
    for i,gridUpdate in ipairs(self.gridUpdateQueue) do

        if gridUpdate.id == newWork.id then
            table.remove(self.gridUpdateQueue,i)
            return
        end
    end

    table.insert(self.gridUpdateQueue,newWork)

    local newLatentUpdate = BirdFeederLatentUpdateAction.new(self,
        function()
            for _, eventFunction in pairs(self.onGridUpdateQueueIncreasedEvent) do
                eventFunction.callbackFunction(eventFunction.owner)
            end
        end
    ,5)

    table.insert(self.latentUpdates,newLatentUpdate)

end


function BirdNavigationGrid:onPlaceableModified(placeable)

    if not self.bActivated or placeable == nil or placeable.rootNode == nil or placeable.spec_fence ~= nil then
        return
    end

    local x,y,z = getTranslation(placeable.rootNode)

    -- Init a new grid queue update with the placeable's id and location, and intially has some values set which might change down below if spec_placement exists.
    local newWork = BirdNavigationGridUpdate.new(placeable.rootNode,x,y,z,{x - 50, y - 50, z - 50, x + 50, y + 50, z + 50})


    if placeable.spec_placement ~= nil and placeable.spec_placement.testAreas ~= nil then
        -- init beyond possible coordinate ranges
        local minX,minY,minZ,maxX,maxY,maxZ = 99999,99999,99999,-99999,-99999,-99999

        for _, area in ipairs(placeable.spec_placement.testAreas) do

            local startX,startY,startZ = getWorldTranslation(area.startNode)
            local endX,endY,endZ = getWorldTranslation(area.endNode)

            minX = math.min(startX,minX)
            minX = math.min(endX,minX)
            minY = math.min(startY,minY)
            minY = math.min(endY,minY)
            minZ = math.min(startZ,minZ)
            minZ = math.min(endZ,minZ)

            maxX = math.max(startX,maxX)
            maxX = math.max(endX,maxX)
            maxY = math.max(startY,maxY)
            maxY = math.max(endY,maxY)
            maxZ = math.max(startZ,maxZ)
            maxZ = math.max(endZ,maxZ)
        end

        newWork.positionX = (minX + maxX) / 2
        newWork.positionY = (minY + maxY) / 2
        newWork.positionZ = (minZ + maxZ) / 2

        newWork.aabb = {minX,minY,minZ,maxX,maxY,maxZ}
    end

    self:QueueGridUpdate(newWork)

end

function BirdNavigationGrid:getNodeTreeLayer(size)
    if size < 1 or size == nil then
        return 1
    end

    local dividedBy = self.terrainSize / size
    -- + 1 as the layer 1 is the root
    return ((math.log(dividedBy)) / (math.log(2))) + 1
end


--- voxelOverlapCheck is called when a new node/leaf voxel need to be checked for collision.
-- first it checks the terrain height, if the terrain is higher than the node's y extent then can skip wasting time to collision check as it can be counted as non-solid.
--@param x is the center coordinate of node/leaf voxel to be checked.
--@param y is the center coordinate of node/leaf voxel to be checked.
--@param z is the center coordinate of node/leaf voxel to be checked.
--@param extentRadius is the radius of the node/leaf voxel to be checked.
--@return true if was a collision on checked location
function BirdNavigationGrid:voxelOverlapCheck(x,y,z, extentRadius)
    self.bTraceVoxelSolid = false

    local terrainHeight = 0
    if g_currentMission.terrainRootNode ~= nil then
        terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode,x,y,z)
    end

    if y + extentRadius < terrainHeight then
        return
    end


    overlapBox(x,y,z,0,0,0,extentRadius,extentRadius,extentRadius,"voxelOverlapCheckCallback",self,self.collisionMask,false,true,true,false)

end

--- voxelOverlapCheckCallback is callback function for the overlapBox.
-- Checks if there was any object id found, or if it was the terrain or if it was the boundary then can ignore those.
-- If it wasn't any of the above then it checks if it has the ClassIds.SHAPE, if it does then it is counted as solid.
--@param hitObjectId is the id of collided thing.
function BirdNavigationGrid:voxelOverlapCheckCallback(hitObjectId)

    if hitObjectId < 1 or hitObjectId == g_currentMission.terrainRootNode or self.mapBoundaryIDs[hitObjectId] then
        return true
    end


    if getHasClassId(hitObjectId,ClassIds.SHAPE) and bitAND(getCollisionMask(hitObjectId),CollisionFlag.TREE) ~= CollisionFlag.TREE  then
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
function BirdNavigationGrid:createLeafVoxels(parent)

    if parent == nil then
        return
    end


    parent.leafVoxelsBottom = 0
    parent.leafVoxelsTop = 0

    -- early check if no collision for whole leaf node then no inner 64 voxels need to be checked
    self:voxelOverlapCheck(parent.positionX,parent.positionY,parent.positionZ,parent.size / 2)
    if self.bTraceVoxelSolid == false then
        return
    end


    local startPositionX = parent.positionX - self.maxVoxelResolution - (self.maxVoxelResolution / 2)
    local startPositionY = parent.positionY - self.maxVoxelResolution - (self.maxVoxelResolution / 2)
    local startPositionZ = parent.positionZ - self.maxVoxelResolution - (self.maxVoxelResolution / 2)

    local count = 0
    for y = 0, 1 do
        for z = 0 , 3 do
            for x = 0, 3 do
                local currentPositionX = startPositionX + (self.maxVoxelResolution * x)
                local currentPositionY = startPositionY + (self.maxVoxelResolution * y)
                local currentPositionZ = startPositionZ + (self.maxVoxelResolution * z)
                self:voxelOverlapCheck(currentPositionX,currentPositionY,currentPositionZ,self.maxVoxelResolution / 2)

                -- if voxel was solid then set the bit to 1
                if self.bTraceVoxelSolid == true then
                    parent.leafVoxelsBottom = bitOR(parent.leafVoxelsBottom,( 1 * 2^count))
                end

                count = count + 1
            end
        end
    end


    count = 0
    for y = 2, 3 do
        for z = 0 , 3 do
            for x = 0, 3 do
                local currentPositionX = startPositionX + (self.maxVoxelResolution * x)
                local currentPositionY = startPositionY + (self.maxVoxelResolution * y)
                local currentPositionZ = startPositionZ + (self.maxVoxelResolution * z)
                self:voxelOverlapCheck(currentPositionX,currentPositionY,currentPositionZ,self.maxVoxelResolution / 2)

                -- if voxel was solid then set the bit to 1
                if self.bTraceVoxelSolid == true then
                    parent.leafVoxelsTop = bitOR(parent.leafVoxelsTop,( 1 * 2^count))
                end

                count = count + 1

            end
        end
    end

end

--- findNeighbours looks for the possible neighbours that the current childNumber can reach.
--@param node is the which needs its neighbours assigned.
--@param childNumber is the number of child, to know which location it is within the parent node.
function BirdNavigationGrid:findNeighbours(node,childNumber)

    if self.owner == nil or node == nil or childNumber < 1 or childNumber > 8 then
        return
    end


    if childNumber == 1 then
        self:findOutsideNeighbours(2,self.EDirections.MINUSX,node)
        self:findOutsideNeighbours(3,self.EDirections.MINUSZ,node)
        self:findOutsideNeighbours(5,self.EDirections.MINUSY,node)

    elseif childNumber == 2 then
        node.xMinusNeighbour = node.parent.children[1]
        node.parent.children[1].xNeighbour = node

        self:findOutsideNeighbours(4,self.EDirections.MINUSZ,node)
        self:findOutsideNeighbours(1,self.EDirections.X,node)
        self:findOutsideNeighbours(6,self.EDirections.MINUSY,node)

    elseif childNumber == 3 then
        node.zMinusNeighbour = node.parent.children[1]
        node.parent.children[1].zNeighbour = node

        self:findOutsideNeighbours(4,self.EDirections.MINUSX,node)
        self:findOutsideNeighbours(1,self.EDirections.Z,node)
        self:findOutsideNeighbours(7,self.EDirections.MINUSY,node)

    elseif childNumber == 4 then
        node.zMinusNeighbour = node.parent.children[2]
        node.parent.children[2].zNeighbour = node

        node.xMinusNeighbour = node.parent.children[3]
        node.parent.children[3].xNeighbour = node

        self:findOutsideNeighbours(8,self.EDirections.MINUSY,node)
        self:findOutsideNeighbours(2,self.EDirections.Z,node)
        self:findOutsideNeighbours(3,self.EDirections.X,node)



    elseif childNumber == 5 then
        node.yMinusNeighbour = node.parent.children[1]
        node.parent.children[1].yNeighbour = node

        self:findOutsideNeighbours(6,self.EDirections.MINUSX,node)
        self:findOutsideNeighbours(7,self.EDirections.MINUSZ,node)
        self:findOutsideNeighbours(1,self.EDirections.Y,node)

    elseif childNumber == 6 then
        node.yMinusNeighbour = node.parent.children[2]
        node.parent.children[2].yNeighbour = node

        node.xMinusNeighbour = node.parent.children[5]
        node.parent.children[5].xNeighbour = node

        self:findOutsideNeighbours(8,self.EDirections.MINUSZ,node)
        self:findOutsideNeighbours(5,self.EDirections.X,node)
        self:findOutsideNeighbours(2,self.EDirections.Y,node)



    elseif childNumber == 7 then
        node.yMinusNeighbour = node.parent.children[3]
        node.parent.children[3].yNeighbour = node

        node.zMinusNeighbour = node.parent.children[5]
        node.parent.children[5].zNeighbour = node


        self:findOutsideNeighbours(8,self.EDirections.MINUSX,node)
        self:findOutsideNeighbours(3,self.EDirections.Y,node)
        self:findOutsideNeighbours(5,self.EDirections.Z,node)

    elseif childNumber == 8 then
        node.yMinusNeighbour = node.parent.children[4]
        node.parent.children[4].yNeighbour = node

        node.xMinusNeighbour = node.parent.children[7]
        node.parent.children[7].xNeighbour = node

        node.zMinusNeighbour = node.parent.children[6]
        node.parent.children[6].zNeighbour = node

        self:findOutsideNeighbours(4,self.EDirections.Y,node)
        self:findOutsideNeighbours(6,self.EDirections.Z,node)
        self:findOutsideNeighbours(7,self.EDirections.X,node)

    end




end

--- findOutsideNeighbours tries to link the same resolution nodes from the parent's neighbours children.
-- if it fails to find same resolution it sets the neighbour as the lower resolution/bigger node parent's neighbour.
-- Also sets the outside neighbours opposite direction neighbour as the currently checked node.
--@param neighbourChildNumber is the child number which is suppose to be linked to the node.
--@param direction is the direction the neighbour is being checked from.
--@param node is the current node which has its neighbours linked.
function BirdNavigationGrid:findOutsideNeighbours(neighbourChildNumber,direction,node)

    local parentNode = node.parent

    if direction ==  self.EDirections.MINUSX then

        if parentNode.xMinusNeighbour ~= nil then

            local neighbourNode = parentNode.xMinusNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.xMinusNeighbour = neighbourNode
                return
            end

            node.xMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber] = node.xNeighbour
            return
        end

    elseif direction == self.EDirections.MINUSY then

        if parentNode.yMinusNeighbour ~= nil then

            local neighbourNode = parentNode.yMinusNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.yMinusNeighbour = neighbourNode
                return
            end

            node.yMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber] = node.yNeighbour
            return
        end


    elseif direction == self.EDirections.MINUSZ then

        if parentNode.zMinusNeighbour ~= nil then

            local neighbourNode = parentNode.zMinusNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.zMinusNeighbour = neighbourNode
                return
            end

            node.zMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber] = node.zNeighbour
            return
        end

    elseif direction == self.EDirections.X then

        if parentNode.xNeighbour ~= nil then

            local neighbourNode = parentNode.xNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.xNeighbour = neighbourNode
                return
            end

            node.xNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber] = node.xMinusNeighbour
            return
        end


    elseif direction == self.EDirections.Y then

        if parentNode.yNeighbour ~= nil then

            local neighbourNode = parentNode.yNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.yNeighbour = neighbourNode
                return
            end

            node.yNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber] = node.yMinusNeighbour
            return
        end

    elseif direction == self.EDirections.Z then

        if parentNode.zNeighbour ~= nil then

            local neighbourNode = parentNode.zNeighbour
            -- if no children then setting the neighbour as the parents neighbour lower resolution.
            if neighbourNode.children == nil then
                node.zNeighbour = neighbourNode
                return
            end

            node.zNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber] = node.zMinusNeighbour
            return
        end


    end



end




---new bird navigation being created
function BirdNavigationGrid.new(customMt)

    local self = Object.new(true,false, customMt or BirdNavigationGrid_mt)
    self.nodeTree = {}
    self.terrainSize = 2048
    self.maxVoxelResolution = 2 -- in meters
    self.leafNodeResolution = self.maxVoxelResolution * 4
    self.birdNavigationGridStates = {}
    self.EBirdNavigationGridStates = {UNDEFINED = 0, PREPARE = 1, GENERATE = 2, DEBUG = 3, UPDATE = 4, IDLE = 5}
    self.EDirections = {X = 0, MINUSX = 1, Y = 2, MINUSY = 3, Z = 4, MINUSZ = 5}
    self.currentGridState = self.EBirdNavigationGridStates.UNDEFINED
    self.octreeDebug = false
    self.mapBoundaryIDs = {}
    self.gridUpdateQueue = {}
    self.onGridUpdateQueueIncreasedEvent = {}
    self.bActivated = false
    self.latentUpdates = {}
    -- used by the grid states to know if collision check was solid, set in the trace callback
    self.bTraceVoxelSolid = false
    self.collisionMask = CollisionFlag.STATIC_WORLD + CollisionFlag.WATER

    Placeable.finalizePlacement = Utils.appendedFunction(Placeable.finalizePlacement,
        function(...)
            self:onPlaceableModified(unpack({...}))
        end
    )

    Placeable.onSell = Utils.prependedFunction(Placeable.onSell,
        function(...)
            self:onPlaceableModified(unpack({...}))
        end
    )

    table.insert(self.birdNavigationGridStates,BirdNavGridStatePrepare.new())
    self.birdNavigationGridStates[self.EBirdNavigationGridStates.PREPARE]:init(self)
    table.insert(self.birdNavigationGridStates,BirdNavGridStateGenerate.new())
    self.birdNavigationGridStates[self.EBirdNavigationGridStates.GENERATE]:init(self)
    table.insert(self.birdNavigationGridStates,BirdNavGridStateDebug.new())
    self.birdNavigationGridStates[self.EBirdNavigationGridStates.DEBUG]:init(self)
    table.insert(self.birdNavigationGridStates,BirdNavGridStateUpdate.new())
    self.birdNavigationGridStates[self.EBirdNavigationGridStates.UPDATE]:init(self)

    self:addGridUpdateQueueIncreasedEvent(self,BirdNavigationGrid.OnGridNeedUpdate)

    self:changeState(self.EBirdNavigationGridStates.PREPARE)
    registerObjectClassName(self, "BirdNavigationGrid")

    return self
end

function BirdNavigationGrid.OnGridNeedUpdate(birdNavigationGrid)

    if birdNavigationGrid.currentGridState ~= birdNavigationGrid.EBirdNavigationGridStates.GENERATE and birdNavigationGrid.currentGridState ~= birdNavigationGrid.EBirdNavigationGridStates.UPDATE then
        birdNavigationGrid:changeState(birdNavigationGrid.EBirdNavigationGridStates.UPDATE)
    end

end

function BirdNavigationGrid:delete()

    self.isDeleted = true
    if self.birdNavigationGridStates[self.currentGridState] ~= nil then
        self.birdNavigationGridStates[self.currentGridState]:leave()
    end

    for _, state in pairs(self.birdNavigationGridStates) do

        if state ~= nil then
            state:destroy()
        end

    end

    self.birdNavigationGridStates = nil
    self.nodeTree = nil

    self.gridUpdateQueue = nil
    self.gridUpdateQueue = {}
    self.onGridUpdateQueueIncreasedEvent = nil
    self.onGridUpdateQueueIncreasedEvent = {}

    BirdNavigationGrid:superClass().delete(self)

    unregisterObjectClassName(self)
end

function BirdNavigationGrid.getVectorDistance(x,y,z,x2,y2,z2)
    return math.sqrt(math.pow((x - x2),2) + math.pow((y - y2),2) + math.pow((z - z2),2))
end


function BirdNavigationGrid:changeState(newState)

    if newState == nil or newState == 0 then
        Logging.warning("Not a valid state given to BirdNavigationGrid:changeState() _ ".. tostring(newState))
        return
    end

    if newState == self.currentGridState then
        Logging.warning("BirdNavigationGrid:changeState() tried to change to same state as current! _ " .. tostring(newState))
        return
    end


    if self.birdNavigationGridStates[self.currentGridState] ~= nil then
        self.birdNavigationGridStates[self.currentGridState]:leave()
    end

    self.currentGridState = newState

    -- if there is work queued when returning to idle should set to update state instead
    if self.currentGridState == self.EBirdNavigationGridStates.IDLE and #self.gridUpdateQueue > 0 then
        self.currentGridState = self.EBirdNavigationGridStates.UPDATE
    -- if debug is on then when returning to idle should set to debug state instead
    elseif self.currentGridState == self.EBirdNavigationGridStates.IDLE and self.octreeDebug then
        self.currentGridState = self.EBirdNavigationGridStates.DEBUG
    end


    if self.birdNavigationGridStates[self.currentGridState] ~= nil then
        self.birdNavigationGridStates[self.currentGridState]:enter()
    end

end

function BirdNavigationGrid:addGridUpdateQueueIncreasedEvent(inOwner,callbackFunction)

    if callbackFunction == nil then
        return
    end

    for _,existingEventFunction in pairs(self.onGridUpdateQueueIncreasedEvent) do

        if existingEventFunction.callbackFunction == callbackFunction then
            Logging.warning("Existing queue increased event callback in BirdNavigationGrid:addGridUpdateQueueIncreasedEvent()!")
            return
        end
    end

    table.insert(self.onGridUpdateQueueIncreasedEvent,{owner = inOwner,callbackFunction = callbackFunction})
end

function BirdNavigationGrid:removeGridUpdateQueueIncreasedEvent(inOwner,callbackFunction)

    if inOwner == nil and callbackFunction == nil then
        return
    end

    local toRemove = {}
    for i,existingEventFunction in ipairs(self.onGridUpdateQueueIncreasedEvent) do

        -- if no specific function given then removes all from the provided owner
        if existingEventFunction.owner == inOwner and callbackFunction == nil then
            table.insert(toRemove,i)
        elseif existingEventFunction.callbackFunction == callbackFunction then
            table.insert(toRemove,i)
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(self.onGridUpdateQueueIncreasedEvent,toRemove[i])
    end

end

function BirdNavigationGrid:update(dt)
    BirdNavigationGrid:superClass().update(self,dt)

    if self.bActivated == false then
        self.bActivated = true
    end

    for i = #self.latentUpdates, 1, -1 do
        if self.latentUpdates[i] ~= nil then
            self.latentUpdates[i]:run()
            if self.latentUpdates[i].bFinished then
                table.remove(self.latentUpdates,i)
            end
        end
    end



    if self.birdNavigationGridStates[self.currentGridState] ~= nil then
         self.birdNavigationGridStates[self.currentGridState]:update(dt)
    end

end

function BirdNavigationGrid:octreeDebugToggle()

    if self == nil then
        return
    end

    self.octreeDebug = not self.octreeDebug

    if self.octreeDebug and self.currentGridState == self.EBirdNavigationGridStates.IDLE then
        self:changeState(self.EBirdNavigationGridStates.DEBUG)
    elseif not self.octreeDebug and self.currentGridState == self.EBirdNavigationGridStates.DEBUG then
        self:changeState(self.EBirdNavigationGridStates.IDLE)
    end


end














