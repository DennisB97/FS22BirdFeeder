--- --- --- --- --- BIRD NAV GRID STATES --- --- --- --- ---

--- GRID BASE STATE CLASS ---
BirdNavGridStateBase = {}
BirdNavGridStateBase_mt = Class(BirdNavGridStateBase)
InitObjectClass(BirdNavGridStateBase, "BirdNavGridStateBase")

function BirdNavGridStateBase.new(customMt)
    local self = setmetatable({}, customMt or BirdNavGridStateBase_mt)

    return self
end

function BirdNavGridStateBase:init(inOwner)
    self.owner = inOwner
end

function BirdNavGridStateBase:enter()

end

function BirdNavGridStateBase:leave()

end

function BirdNavGridStateBase:update(dt)

end



--- GRID PREPARE STATE CLASS ---
BirdNavGridStatePrepare = {}
BirdNavGridStatePrepare_mt = Class(BirdNavGridStatePrepare,BirdNavGridStateBase)
InitObjectClass(BirdNavGridStatePrepare, "BirdNavGridStatePrepare")

function BirdNavGridStatePrepare.new(customMt)
    local self = BirdNavGridStatePrepare:superClass().new(customMt or BirdNavGridStatePrepare_mt)

    return self
end

function BirdNavGridStatePrepare:enter()
    BirdNavGridStatePrepare:superClass().enter(self)

    self:prepareGrid()

    if self.owner ~= nil then
        self.owner:changeState(self.owner.EBirdNavigationStates.GENERATE)
    end
end

function BirdNavGridStatePrepare:leave()
    BirdNavGridStatePrepare:superClass().leave(self)

end

function BirdNavGridStatePrepare:update(dt)
    BirdNavGridStatePrepare:superClass().update(self,dt)

end


function BirdNavGridStatePrepare:prepareGrid()

    if self.owner == nil then
        return
    end


    if g_currentMission.terrainRootNode ~= nil then
        self.owner.terrainSize = Utils.getNoNil(getTerrainSize(g_currentMission.terrainRootNode),self.owner.terrainSize)
    end


    local tileCount = self.owner.terrainSize / self.owner.maxVoxelResolution

    -- Making sure the terrain size divides evenly, else add a bit extra space
    if tileCount % 2 ~= 0 then
        local extension = (2 - self.owner.tileCount % 2) * self.owner.maxVoxelResolution
        self.owner.terrainSize = self.owner.terrainSize + extension
        self.owner.tileCount = self.owner.terrainSize / self.owner.maxVoxelResolution
    end


    local rootNode = BirdNavNode.new(0,self.owner.terrainSize / 2,0)
    self.owner:addNode(1,rootNode)


end




--- GRID GENERATE STATE CLASS ---
BirdNavGridStateGenerate = {}
BirdNavGridStateGenerate_mt = Class(BirdNavGridStateGenerate,BirdNavGridStateBase)
InitObjectClass(BirdNavGridStateGenerate, "BirdNavGridStateGenerate")

function BirdNavGridStateGenerate.new(customMt)
    local self = BirdNavGridStateGenerate:superClass().new(customMt or BirdNavGridStateGenerate_mt)
    self.collisionMask = CollisionFlag.STATIC_WORLD + CollisionFlag.WATER
    self.bTraceVoxelSolid = true
    self.dynamicLoopLimit = 50
    self.dynamicLoopRemove = 10
    self.dynamicLoopAdd = 5
    self.targetFPS = 0
    self.currentLoops = 0
    self.currentLayerIndex = 1
    self.currentNodeIndex = 1
    self.currentChildIndex = 0
    self.startLocation = {}
    self.EInternalState = {UNDEFINED = -1 ,CREATE = 0, LINKNEIGHBOURS = 1}
    self.currentState = self.EInternalState.CREATE
    self.EDirections = {X = 0, MINUSX = 1, Y = 2, MINUSY = 3, Z = 4, MINUSZ = 5}


    return self
end

function BirdNavGridStateGenerate:enter()
    BirdNavGridStateGenerate:superClass().enter(self)

    if self == nil or self.owner == nil then
        return
    end

    if self.owner ~= nil then
        self.owner:raiseActive()
    end

end

function BirdNavGridStateGenerate:leave()
    BirdNavGridStateGenerate:superClass().leave(self)

end

function BirdNavGridStateGenerate:update(dt)
    BirdNavGridStateGenerate:superClass().update(self,dt)

    if self.targetFPS == 0 then
        self.targetFPS = 1 / (dt / 1000)

        if g_gameSettings.frameLimit > 0 and self.targetFPS > g_gameSettings.frameLimit then
            self.targetFPS = g_gameSettings.frameLimit - 1
        else
            if self.targetFPS > 60 then
                self.targetFPS = 59
            elseif self.targetFPS < 30 then
                self.targetFPS = 29
            end
        end

    end


    local currentLoops = 0
    local currentFPS = 1 / (dt / 1000)

    if self.dynamicLoopLimit > 0 + self.dynamicLoopRemove and currentFPS < self.targetFPS  then
        self.dynamicLoopLimit = self.dynamicLoopLimit - self.dynamicLoopRemove
    elseif currentFPS > self.targetFPS then
        self.dynamicLoopLimit = self.dynamicLoopLimit + self.dynamicLoopAdd
    elseif self.dynamicLoopLimit < 1 then
        self.dynamicLoopLimit = self.dynamicLoopLimit + self.dynamicLoopAdd
    end

    while currentLoops < self.dynamicLoopLimit do

        if self.currentState == self.EInternalState.CREATE then

            if self:doOctree() == true then
                Logging.info("BirdNavGridStateGenerate done generating octree!")
                self.currentState = self.EInternalState.UNDEFINED
--                 self.owner:changeState(self.owner.EBirdNavigationStates.DEBUG)
                self.owner.currentState = self.owner.EBirdNavigationStates.IDLE
            end
        elseif self.currentState == self.EInternalState.LINKNEIGHBOURS then
            self:linkNeighbours()
        end


        currentLoops = currentLoops + 1
    end

    if self ~= nil and self.owner ~= nil then
        self.owner:raiseActive()
    end


end

function BirdNavGridStateGenerate:doOctree()

    -- -1 as layerIndex 1 is the root of octree
    local currentDivision = math.pow(2,self.currentLayerIndex - 1)
    local parentVoxelSize = self.owner.terrainSize / currentDivision

    -- if next layer would be lower resolution than the leaf nodes should be then octree is done
    if parentVoxelSize / 2 < self.owner.maxVoxelResolution * 4 then
        return true
    end

    local currentNode = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex]

    self:createChildren(currentNode, parentVoxelSize)

    -- If all nodes for the parents have been added then need to link the neighbours before going down the layer to the just created nodes.
    if self:incrementNodeGeneration() == true then

        self.currentLayerIndex = self.currentLayerIndex + 1
        -- If no new layers means reached the final resolution so it is done
        if self.owner.nodeTree[self.currentLayerIndex] == nil then
            return true
        end

        self.currentState = self.EInternalState.LINKNEIGHBOURS
        return false
    end

    return false

end


function BirdNavGridStateGenerate:createChildren(parent,parentVoxelSize)

    if parent == nil or parentVoxelSize == nil then
        return
    end

    -- Need to check for a collision if no collision then current node is childless node
    self:voxelOverlapCheck(parent.positionX,parent.positionY,parent.positionZ,parentVoxelSize / 2)
    if self.bTraceVoxelSolid == false then
        return
    end

    -- divided by 4 to get the new child voxels radius to offset inside the parent node
    local startLocationX = parent.positionX - (parentVoxelSize / 4)
    local startLocationY = parent.positionY - (parentVoxelSize / 4)
    local startLocationZ = parent.positionZ - (parentVoxelSize / 4)

--     local compactedParentIndex = BirdNavigationGrid.compactLink(self.currentLayerIndex,self.currentNodeIndex,0)

    for y = 0, 1 do
        for z = 0 , 1 do
            for x = 0, 1 do
                local newNode = BirdNavNode.new(startLocationX + (x * (parentVoxelSize / 2)) ,startLocationY + (y * (parentVoxelSize / 2)), startLocationZ + (z * (parentVoxelSize / 2)),parent)
                self.owner:addNode(self.currentLayerIndex + 1,newNode)
--                 local firstChildIndex = self.owner:addNode(self.currentLayerIndex + 1,newNode)
--                 local compactedChildIndex = BirdNavigationGrid.compactLink(self.currentLayerIndex + 1,firstChildIndex,0)
                table.insert(parent.children,newNode)

            end
        end
    end


end

function BirdNavGridStateGenerate:incrementNodeGeneration()

    self.currentNodeIndex = self.currentNodeIndex + 1

    if self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex] == nil then
        self.currentNodeIndex = 1
        return true
    end

    return false
end

function BirdNavGridStateGenerate:linkNeighbours()

    local firstChild = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex]
    firstChild.xNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 1]
    firstChild.zNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 2]
    firstChild.yNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 4]

    local secondChild = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 1]
    secondChild.xMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex]
    secondChild.zNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 2]
    secondChild.yNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 4]
    self:LinkOutsideNeighbour(secondChild,self.EDirections.X,2)

    local thirdChild = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 2]
    thirdChild.xNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 3]
    thirdChild.zMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex - 2]
    thirdChild.yNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 4]
    self:LinkOutsideNeighbour(thirdChild,self.EDirections.Z,3)

    local fourthChild = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 3]
    fourthChild.xMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 2]
    fourthChild.zMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex - 2]
    fourthChild.yNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 4]
    self:LinkOutsideNeighbour(fourthChild,self.EDirections.X,4)
    self:LinkOutsideNeighbour(fourthChild,self.EDirections.Z,4)

    local fifthChild = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 4]
    fifthChild.xNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 5]
    fifthChild.zNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 6]
    fifthChild.yMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex - 4]
    self:LinkOutsideNeighbour(fifthChild,self.EDirections.Y,5)

    local sixthChild = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 5]
    sixthChild.xMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 4]
    sixthChild.zNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 7]
    sixthChild.yMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex - 4]
    self:LinkOutsideNeighbour(sixthChild,self.EDirections.Y,6)
    self:LinkOutsideNeighbour(sixthChild,self.EDirections.X,6)

    local seventhChild = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 6]
    seventhChild.xNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 7]
    seventhChild.zMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 4]
    seventhChild.yMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex - 4]
    self:LinkOutsideNeighbour(seventhChild,self.EDirections.Y,7)
    self:LinkOutsideNeighbour(seventhChild,self.EDirections.Z,7)

    local eigthChild = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 7]
    eigthChild.xMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 6]
    eigthChild.zMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex + 5]
    eigthChild.yMinusNeighbour = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex - 4]
    self:LinkOutsideNeighbour(eigthChild,self.EDirections.Y,8)
    self:LinkOutsideNeighbour(eigthChild,self.EDirections.X,8)
    self:LinkOutsideNeighbour(eigthChild,self.EDirections.Z,8)

    self.currentNodeIndex = self.currentNodeIndex + 8
    if self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex] == nil then
        self.currentNodeIndex = 1
        self.currentState = self.EInternalState.CREATE
    end

end

-- octree voxels bottom  |3| |1| and then top of voxel children |7| |5|
--                       |4| |2|                                |8| |6|
--                                   1 -> 2 is positive X
--                                   1 -> 3 is positive Z
--                                   1 -> 5 is positive Y


function BirdNavGridStateGenerate:LinkOutsideNeighbour(node,direction,childNumber)

    if node == nil or direction == nil or self == nil or self.owner == nil then
        return
    end


    local parentNode = node.parent

    if parentNode == nil then
        Logging.warning("parentNode was nil in BirdNavGridStateGenerate:LinkOutsideNeighbour")
        return
    end




    if direction ==  self.EDirections.X then

        if parentNode.xNeighbour ~= nil and parentNode.xNeighbour ~= 0 then

            local neighbourNode = parentNode.xNeighbour
            if #neighbourNode.children == 0 then
                node.xNeighbour = parentNode.xNeighbour
                return
            end

            if childNumber == 2 then
                node.xNeighbour = parentNode.xNeighbour.children[1]
                neighbourNode.children[1].xMinusNeighbour = node

            elseif childNumber == 4 then
                node.xNeighbour = parentNode.xNeighbour.children[3]
                neighbourNode.children[3].xMinusNeighbour = node

            elseif childNumber == 6 then
                node.xNeighbour = parentNode.xNeighbour.children[5]
                neighbourNode.children[5].xMinusNeighbour = node

            elseif childNumber == 8 then
                node.xNeighbour = parentNode.xNeighbour.children[7]
                neighbourNode.children[7].xMinusNeighbour = node

            end

            return
        end

    elseif direction == self.EDirections.Y then

        if parentNode.yNeighbour ~= nil and parentNode.yNeighbour ~= 0 then

            local neighbourNode = parentNode.yNeighbour
            if #neighbourNode.children == 0 then
                node.yNeighbour = parentNode.yNeighbour
                return
            end

             if childNumber == 5 then
                node.yNeighbour = parentNode.yNeighbour.children[1]
                neighbourNode.children[1].yMinusNeighbour = node

            elseif childNumber == 6 then
                node.yNeighbour = parentNode.yNeighbour.children[2]
                neighbourNode.children[2].yMinusNeighbour = node

            elseif childNumber == 7 then
                node.yNeighbour = parentNode.yNeighbour.children[3]
                neighbourNode.children[3].yMinusNeighbour = node

            elseif childNumber == 8 then
                node.yNeighbour = parentNode.yNeighbour.children[4]
                neighbourNode.children[4].yMinusNeighbour = node

            end

            return
        end


    elseif direction == self.EDirections.Z then

        if parentNode.zNeighbour ~= nil and parentNode.zNeighbour ~= 0 then

            local neighbourNode = parentNode.zNeighbour
            if #neighbourNode.children == 0 then
                node.zNeighbour = parentNode.zNeighbour
                return
            end

            if childNumber == 3 then
                node.zNeighbour = parentNode.zNeighbour.children[1]
                neighbourNode.children[1].zMinusNeighbour = node

            elseif childNumber == 4 then
                node.zNeighbour = parentNode.zNeighbour.children[2]
                neighbourNode.children[2].zMinusNeighbour = node

            elseif childNumber == 7 then
                node.zNeighbour = parentNode.zNeighbour.children[5]
                neighbourNode.children[5].zMinusNeighbour = node

            elseif childNumber == 8 then
                node.zNeighbour = parentNode.zNeighbour.children[6]
                neighbourNode.children[6].zMinusNeighbour = node

            end

            return
        end

    end

end


function BirdNavGridStateGenerate:voxelOverlapCheck(x,y,z, extentRadius)
    self.bTraceVoxelSolid = false
    overlapBox(x,y,z,0,0,0,extentRadius,extentRadius,extentRadius,"voxelOverlapCheckCallback",self,self.collisionMask,false,true,true,false)
end


function BirdNavGridStateGenerate:voxelOverlapCheckCallback(hitObjectId)

    if hitObjectId < 1 then
        return true
    end

    if hitObjectId == g_currentMission.terrainRootNode or getHasClassId(hitObjectId,ClassIds.SHAPE) then
        self.bTraceVoxelSolid = true
        return false
    end

    return true
end



function BirdNavGridStateGenerate.quickSort(inTable,low,high)

    if high <= low or #inTable < 1 then
        return
    end

    local pivot = BirdNavGridStateGenerate.partition(inTable,low,high)
    BirdNavGridStateGenerate.quickSort(inTable,low, pivot - 1)
    BirdNavGridStateGenerate.quickSort(inTable, pivot + 1,high)

end


function BirdNavGridStateGenerate.partition(inTable,low,high)

    local pivotValue = inTable[low]
    local pivotIndex = low

    local count = 0
    for i = low + 1, high do

        if inTable[i] <= pivotValue then
            count = count + 1
        end
    end

    pivotIndex = low + count

    local temp = inTable[low]
    inTable[low] = inTable[pivotIndex]
    inTable[pivotIndex] = temp

    local i , j = low, high

    while i < pivotIndex and j > pivotIndex do

        while inTable[i] <= pivotValue do
            i = i + 1
        end

        while inTable[j] > pivotValue do
            j = j - 1
        end


        if i < pivotIndex and j > pivotIndex then
            local tempValue = inTable[i]
            inTable[i] = inTable[j]
            inTable[j] = tempValue
            i = i + 1
            j = j - 1

        end

    end

	return pivotIndex;

end


--- GRID DEBUG STATE CLASS ---
BirdNavGridStateDebug = {}
BirdNavGridStateDebug_mt = Class(BirdNavGridStateDebug,BirdNavGridStateBase)
InitObjectClass(BirdNavGridStateDebug, "BirdNavGridStateDebug")

function BirdNavGridStateDebug.new(customMt)
    local self = BirdNavGridStateDebug:superClass().new(customMt or BirdNavGridStateDebug_mt)
    self.debugGrid = {}
    self.playerLastLocation = { x = 0, y = 0, z = 0}


    return self
end

function BirdNavGridStateDebug:enter()
    BirdNavGridStateDebug:superClass().enter(self)

    if self.owner ~= nil then
        self.owner:raiseActive()
    end

end

function BirdNavGridStateDebug:leave()
    BirdNavGridStateDebug:superClass().leave(self)

end

function BirdNavGridStateDebug:update(dt)
    BirdNavGridStateDebug:superClass().update(self,dt)

    if self.owner == nil then
        return
    end

    self.owner:raiseActive()






    for _,voxel in pairs(self.owner.nodeTree[2]) do
        DebugUtil.drawSimpleDebugCube(voxel.positionX, voxel.positionY, voxel.positionZ, self.owner.terrainSize / 2, 1, 0, 0)
    end




end




