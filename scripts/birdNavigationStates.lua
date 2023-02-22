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

function BirdNavGridStateBase:destroy()


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

function BirdNavGridStatePrepare:destroy()
    BirdNavGridStatePrepare:superClass().destroy(self)

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
    self.EInternalState = {UNDEFINED = -1 ,CREATE = 0, IDLE = 1}
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

function BirdNavGridStateGenerate:destroy()
    BirdNavGridStateGenerate:superClass().destroy(self)

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
                self.currentState = self.EInternalState.IDLE
                self.owner:changeState(self.owner.EBirdNavigationStates.IDLE)
            end

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

     -- if current layer is lower resolution than the leaf nodes should be then octree is done
    if parentVoxelSize < self.owner.maxVoxelResolution * 4 then
        return true
    end

    local currentNode = self.owner.nodeTree[self.currentLayerIndex][self.currentNodeIndex]

    if parentVoxelSize == self.owner.maxVoxelResolution * 4 then
        print("parent voxel is 8m")
        self:createLeafVoxels(currentNode,parentVoxelSize)
    else
        self:createChildren(currentNode, parentVoxelSize)
    end

    -- If all nodes for the parents have been added then next layer
    if self:incrementNodeGeneration() == true then

        self.currentLayerIndex = self.currentLayerIndex + 1
        -- If no new layers means reached the final resolution so it is done
        if self.owner.nodeTree[self.currentLayerIndex] == nil then
            return true
        end

        return false
    end

    return false

end

function BirdNavGridStateGenerate:createLeafVoxels(parent,parentVoxelSize)

    parent.leafVoxels = -1







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

    local childNumber = 1
    parent.children = {}
    for y = 0, 1 do
        for z = 0 , 1 do
            for x = 0, 1 do
                local newNode = BirdNavNode.new(startLocationX + (x * (parentVoxelSize / 2)) ,startLocationY + (y * (parentVoxelSize / 2)), startLocationZ + (z * (parentVoxelSize / 2)),parent)
                self.owner:addNode(self.currentLayerIndex + 1,newNode)
                table.insert(parent.children,newNode)
                self:findNeighbours(newNode,childNumber)
                childNumber = childNumber + 1
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


-- octree voxels bottom index guide  |3| |1| and then top of voxel  |7| |5|
--                                   |4| |2|                        |8| |6|
--                                            1 -> 2 is positive X
--                                            1 -> 3 is positive Z
--                                            1 -> 5 is positive Y

function BirdNavGridStateGenerate:findNeighbours(node,childNumber)

    if node == nil or childNumber < 1 or childNumber > 8 then
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
        self:findOutsideNeighbours(6,self.EDirections.MINUSY,node)

    elseif childNumber == 3 then
        node.zMinusNeighbour = node.parent.children[1]
        node.parent.children[1].zNeighbour = node

        self:findOutsideNeighbours(4,self.EDirections.MINUSX,node)
        self:findOutsideNeighbours(7,self.EDirections.MINUSY,node)

    elseif childNumber == 4 then
        node.zMinusNeighbour = node.parent.children[2]
        node.parent.children[2].zNeighbour = node

        node.xMinusNeighbour = node.parent.children[3]
        node.parent.children[3].xNeighbour = node

        self:findOutsideNeighbours(8,self.EDirections.MINUSY,node)



    elseif childNumber == 5 then
        node.yMinusNeighbour = node.parent.children[1]
        node.parent.children[1].yNeighbour = node

        self:findOutsideNeighbours(6,self.EDirections.MINUSX,node)
        self:findOutsideNeighbours(7,self.EDirections.MINUSZ,node)

    elseif childNumber == 6 then
        node.yMinusNeighbour = node.parent.children[2]
        node.parent.children[2].yNeighbour = node

        node.xMinusNeighbour = node.parent.children[5]
        node.parent.children[5].xNeighbour = node

        self:findOutsideNeighbours(8,self.EDirections.MINUSZ,node)

    elseif childNumber == 7 then
        node.yMinusNeighbour = node.parent.children[3]
        node.parent.children[3].yNeighbour = node

        node.zMinusNeighbour = node.parent.children[5]
        node.parent.children[5].zNeighbour = node


        self:findOutsideNeighbours(8,self.EDirections.MINUSX,node)

    elseif childNumber == 8 then
        node.yMinusNeighbour = node.parent.children[4]
        node.parent.children[4].yNeighbour = node

        node.xMinusNeighbour = node.parent.children[7]
        node.parent.children[7].xNeighbour = node

        node.zMinusNeighbour = node.parent.children[6]
        node.parent.children[6].zNeighbour = node

    end




end

function BirdNavGridStateGenerate:findOutsideNeighbours(neighbourChildNumber,direction,node)

    local parentNode = node.parent

    if direction ==  self.EDirections.MINUSX then

        if parentNode.xMinusNeighbour ~= nil then

            local neighbourNode = parentNode.xMinusNeighbour
            if neighbourNode.children == nil then
                node.xMinusNeighbour = parentNode.xMinusNeighbour
                return
            end

            node.xMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].xNeighbour = node

            return
        end

    elseif direction == self.EDirections.MINUSY then

        if parentNode.yMinusNeighbour ~= nil then

            local neighbourNode = parentNode.yMinusNeighbour
            if neighbourNode.children == nil then
                node.yMinusNeighbour = parentNode.yMinusNeighbour
                return
            end

            node.yMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].yNeighbour = node

            return
        end


    elseif direction == self.EDirections.MINUSZ then

        if parentNode.zMinusNeighbour ~= nil then

            local neighbourNode = parentNode.zMinusNeighbour
            if neighbourNode.children == nil then
                node.zMinusNeighbour = parentNode.zMinusNeighbour
                return
            end

            node.zMinusNeighbour = neighbourNode.children[neighbourChildNumber]
            neighbourNode.children[neighbourChildNumber].zNeighbour = node

            return
        end

    end



end


function BirdNavGridStateGenerate:voxelOverlapCheck(x,y,z, extentRadius)
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


function BirdNavGridStateGenerate:voxelOverlapCheckCallback(hitObjectId)

    if hitObjectId < 1 or hitObjectId == g_currentMission.terrainRootNode then
        return true
    end


    if getHasClassId(hitObjectId,ClassIds.SHAPE) then
        -- dirty hack to check if the shape is the boundary wall to ignore, as boundary wall would be extremely big, and most likely no building would be as big except at least water plane
        local posX,posY,posZ,radius = getShapeBoundingSphere(hitObjectId)
        local terrainSize = 2056
        if g_currentMission.terrainRootNode ~= nil then
            terrainSize = Utils.getNoNil(getTerrainSize(g_currentMission.terrainRootNode),self.owner.terrainSize)
        end
        if radius < terrainSize / 2.5 or bitAND(getCollisionMask(hitObjectId), CollisionFlag.WATER) == CollisionFlag.WATER then
            self.bTraceVoxelSolid = true
            return false
        end
    end

    return true
end



--- GRID DEBUG STATE CLASS ---
BirdNavGridStateDebug = {}
BirdNavGridStateDebug_mt = Class(BirdNavGridStateDebug,BirdNavGridStateBase)
InitObjectClass(BirdNavGridStateDebug, "BirdNavGridStateDebug")
BirdNavGridStateDebug.currentDebugLayer = 2
BirdNavGridStateDebug.maxDebugLayer = 9999

function BirdNavGridStateDebug.increaseDebugLayer()

    BirdNavGridStateDebug.currentDebugLayer = BirdNavGridStateDebug.currentDebugLayer + 1
    BirdNavGridStateDebug.currentDebugLayer = MathUtil.clamp(BirdNavGridStateDebug.currentDebugLayer,2,BirdNavGridStateDebug.maxDebugLayer)
    print("increased debug layer to: " .. tostring(BirdNavGridStateDebug.currentDebugLayer))
end

function BirdNavGridStateDebug.decreaseDebugLayer()

    BirdNavGridStateDebug.currentDebugLayer = BirdNavGridStateDebug.currentDebugLayer - 1
    BirdNavGridStateDebug.currentDebugLayer = MathUtil.clamp(BirdNavGridStateDebug.currentDebugLayer,2,BirdNavGridStateDebug.maxDebugLayer)
    print("decreased debug layer to: " .. tostring(BirdNavGridStateDebug.currentDebugLayer))
end


function BirdNavGridStateDebug.new(customMt)
    local self = BirdNavGridStateDebug:superClass().new(customMt or BirdNavGridStateDebug_mt)
    self.debugGrid = {}
    self.playerLastLocation = { x = 0, y = 0, z = 0}


    return self
end

function BirdNavGridStateDebug:enter()
    BirdNavGridStateDebug:superClass().enter(self)

    if self == nil or self.owner == nil then
        return
    end

    BirdNavGridStateDebug.maxDebugLayer = #self.owner.nodeTree
    if g_inputBinding ~= nil then
        local _, eventId = g_inputBinding:registerActionEvent(InputAction.BIRDFEEDER_DBG_OCTREE_LAYER_DOWN, self, BirdNavGridStateDebug.decreaseDebugLayer, true, false, false, true, true, true)
        local _, eventId = g_inputBinding:registerActionEvent(InputAction.BIRDFEEDER_DBG_OCTREE_LAYER_UP, self, BirdNavGridStateDebug.increaseDebugLayer, true, false, false, true, true, true)
    end

    if self.owner ~= nil then
        self.owner:raiseActive()
    end

end

function BirdNavGridStateDebug:leave()
    BirdNavGridStateDebug:superClass().leave(self)

    if g_inputBinding ~= nil then
        g_inputBinding:removeActionEventsByTarget(self)
    end
end

function BirdNavGridStateDebug:update(dt)
    BirdNavGridStateDebug:superClass().update(self,dt)

    if self.owner == nil then
        return
    end

    self.owner:raiseActive()

     -- -1 as layerIndex 1 is the root of octree
    local currentDivision = math.pow(2,BirdNavGridStateDebug.currentDebugLayer - 1)
    local voxelSize = self.owner.terrainSize / currentDivision


    for _,voxel in pairs(self.owner.nodeTree[BirdNavGridStateDebug.currentDebugLayer]) do
        if voxel.children ~= nil or voxel.leafVoxels ~= 0 then
            DebugUtil.drawSimpleDebugCube(voxel.positionX, voxel.positionY, voxel.positionZ, voxelSize, 1, 0, 0)
        end
    end


end

function BirdNavGridStateDebug:destroy()
    BirdNavGridStateDebug:superClass().destroy(self)

end



