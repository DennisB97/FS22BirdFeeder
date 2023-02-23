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

    if self == nil or self.owner == nil then
        return
    end

    parent.leafVoxels = 0

    -- early check if no collision for whole leaf node then no 4x4x4 voxels need to be checked
    self:voxelOverlapCheck(parent.positionX,parent.positionY,parent.positionZ,parentVoxelSize / 2)
    if self.bTraceVoxelSolid == false then
        return
    end


    local startPositionX = parent.positionX - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)
    local startPositionY = parent.positionY - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)
    local startPositionZ = parent.positionZ - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)

    local count = 0
    for y = 0, 3 do
        for z = 0 , 3 do
            for x = 0, 3 do
                local currentPositionX = startPositionX + (self.owner.maxVoxelResolution * x)
                local currentPositionY = startPositionY + (self.owner.maxVoxelResolution * y)
                local currentPositionZ = startPositionZ + (self.owner.maxVoxelResolution * z)
                self:voxelOverlapCheck(currentPositionX,currentPositionY,currentPositionZ,self.owner.maxVoxelResolution / 2)

                if self.bTraceVoxelSolid == true then
                    parent.leafVoxels = parent.leafVoxels + math.pow(2,count)
--                 else
--                     parent.leafVoxels = parent.leafVoxels - math.pow(2,count)
                end

                count = count + 1
            end
        end
    end

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
    -- max debug layer will be limited to octree's layers, but adding one more so that the leaf node's 64 voxels can also be shown at layer + 1
    BirdNavGridStateDebug.currentDebugLayer = MathUtil.clamp(BirdNavGridStateDebug.currentDebugLayer,2,BirdNavGridStateDebug.maxDebugLayer + 1)

end

function BirdNavGridStateDebug.decreaseDebugLayer()

    BirdNavGridStateDebug.currentDebugLayer = BirdNavGridStateDebug.currentDebugLayer - 1
    BirdNavGridStateDebug.currentDebugLayer = MathUtil.clamp(BirdNavGridStateDebug.currentDebugLayer,2,BirdNavGridStateDebug.maxDebugLayer)

end


function BirdNavGridStateDebug.new(customMt)
    local self = BirdNavGridStateDebug:superClass().new(customMt or BirdNavGridStateDebug_mt)
    self.debugGrid = {}
    self.playerLastLocation = { x = 0, y = 0, z = 0}
    self.voxelMaxRenderDistance = 70
    self.maxVoxelsAtTime = 70000
    self.positionUpdated = false

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

    self:updatePlayerDistance()

    if BirdNavGridStateDebug.currentDebugLayer == #self.owner.nodeTree + 1 then

        if self.positionUpdated then
            self.positionUpdated = false
            self:findCloseEnoughVoxels(self.owner.nodeTree[1][1],1,#self.owner.nodeTree)
        end

        for _,voxel in pairs(self.debugGrid) do

            if voxel.leafVoxels ~= nil and voxel.leafVoxels ~= 0 then

                local childNumber = 0
                local startPositionX = voxel.positionX - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)
                local startPositionY = voxel.positionY - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)
                local startPositionZ = voxel.positionZ - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)

                for y = 0, 3 do
                    for z = 0 , 3 do
                        for x = 0, 3 do
                            local currentPositionX = startPositionX + (self.owner.maxVoxelResolution * x)
                            local currentPositionY = startPositionY + (self.owner.maxVoxelResolution * y)
                            local currentPositionZ = startPositionZ + (self.owner.maxVoxelResolution * z)

                            local bitState = math.floor(voxel.leafVoxels / (2^childNumber)) % 2
                            if bitState ~= 0 then
                                DebugUtil.drawSimpleDebugCube(currentPositionX, currentPositionY, currentPositionZ, self.owner.maxVoxelResolution, 1, 0, 0)
                            end

                            childNumber = childNumber + 1
                        end
                    end
                end
            end

        end

    elseif #self.owner.nodeTree[BirdNavGridStateDebug.currentDebugLayer] > self.maxVoxelsAtTime then

        if self.positionUpdated then
            self.positionUpdated = false
            self:findCloseEnoughVoxels(self.owner.nodeTree[1][1],1,BirdNavGridStateDebug.currentDebugLayer)
        end

        for _,voxel in pairs(self.debugGrid) do
            if voxel.children ~= nil or (voxel.leafVoxels ~= nil and voxel.leafVoxels ~= 0) then
                DebugUtil.drawSimpleDebugCube(voxel.positionX, voxel.positionY, voxel.positionZ, voxelSize, 1, 0, 0)
            end
        end


    else
         for _,voxel in pairs(self.owner.nodeTree[BirdNavGridStateDebug.currentDebugLayer]) do
            if voxel.children ~= nil or (voxel.leafVoxels ~= nil and voxel.leafVoxels ~= 0) then
                DebugUtil.drawSimpleDebugCube(voxel.positionX, voxel.positionY, voxel.positionZ, voxelSize, 1, 0, 0)
            end
        end
    end


end

function BirdNavGridStateDebug:updatePlayerDistance()

    if self == nil or self.owner == nil then
        return
    end

    local playerX,playerY,playerZ = getWorldTranslation(g_currentMission.player.rootNode)
    local distance = BirdNavigationGrid.getVectorDistance(self.playerLastLocation.x,self.playerLastLocation.y,self.playerLastLocation.z,playerX,playerY,playerZ)
    if distance > 50 then
        self.positionUpdated = true
        self.debugGrid = nil
        self.debugGrid = {}
        self.playerLastLocation.x = playerX
        self.playerLastLocation.y = playerY
        self.playerLastLocation.z = playerZ
    end


end

function BirdNavGridStateDebug:findCloseEnoughVoxels(node,layer,maxLayer)

    if self == nil or self.owner == nil then
        return
    end

    -- -1 as layerIndex 1 is the root of octree
    local currentDivision = math.pow(2,layer - 1)
    local voxelSize = self.owner.terrainSize / currentDivision



    if voxelSize == self.owner.maxVoxelResolution * 8 and node.children ~= nil then
        self:appendDebugGrid(node.children)
        return
    elseif layer + 1 == maxLayer then
        if node.children ~= nil then
            self:appendDebugGrid(node.children)
        end
        return
    elseif node.children == nil then
        return
    end


    local aabbNode = {node.positionX - (voxelSize / 2), node.positionY - (voxelSize / 2), node.positionZ - (voxelSize / 2),node.positionX + (voxelSize / 2), node.positionY + (voxelSize / 2), node.positionZ + (voxelSize / 2) }
    local aabbPlayer = {self.playerLastLocation.x - self.voxelMaxRenderDistance, self.playerLastLocation.y - self.voxelMaxRenderDistance, self.playerLastLocation.z - self.voxelMaxRenderDistance,self.playerLastLocation.x
        + self.voxelMaxRenderDistance, self.playerLastLocation.y + self.voxelMaxRenderDistance, self.playerLastLocation.z + self.voxelMaxRenderDistance}

    if BirdNavGridStateDebug.checkAABBIntersection(aabbNode,aabbPlayer) == true then

        for _, voxel in pairs(node.children) do
            self:findCloseEnoughVoxels(voxel,layer + 1)
        end

    end


end

function BirdNavGridStateDebug.checkAABBIntersection(aabb1, aabb2)


  if aabb1[1] > aabb2[4] or aabb2[1] > aabb1[4] or aabb1[2] > aabb2[5] or aabb2[2] > aabb1[5] or aabb1[3] > aabb2[6] or aabb2[3] > aabb1[6] then
    return false
  else
    return true
  end
end


function BirdNavGridStateDebug:appendDebugGrid(nodes)

    if self == nil then
        return
    end

    for _,voxel in pairs(nodes) do
        table.insert(self.debugGrid,voxel)
    end

end


function BirdNavGridStateDebug:destroy()
    BirdNavGridStateDebug:superClass().destroy(self)

end



