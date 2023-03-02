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

-- Overview of the arrangment of the children in the octree.
-- octree voxels bottom index guide  |3| |1| and then top of voxel  |7| |5|
--                                   |4| |2|                        |8| |6|
--                                            1 -> 2 is positive X
--                                            1 -> 3 is positive Z
--                                            1 -> 5 is positive Y

-- Overview of the arrangment of the 4x4x4 size leaf voxels in the octree divided into two 32bit.
--    1st layer and 2nd layer     |12| |8 | |4| |0|  |28| |24| |20| |16|  3rd layer and 4th layer |12| |8 | |4| |0|   |28| |24| |20| |16|
--    leafVoxelsBottom            |13| |9 | |5| |1|  |29| |25| |21| |17|  leafVoxelsTop           |13| |9 | |5| |1|   |29| |25| |21| |17|
--    3D Cube flattened view      |14| |10| |6| |2|  |30| |26| |22| |18|                          |14| |10| |6| |2|   |30| |26| |22| |18|
--                                |15| |11| |7| |3|  |31| |27| |23| |19|                          |15| |11| |7| |3|   |31| |27| |23| |19|
--



------ --- --- --- BIRD NAV GRID STATES --- --- --- ------

---@class BirdNavGridStateBase.
-- Is the base state class of BirdNavGrid, defines the base state functions.
BirdNavGridStateBase = {}
BirdNavGridStateBase_mt = Class(BirdNavGridStateBase)
InitObjectClass(BirdNavGridStateBase, "BirdNavGridStateBase")

--- new overriden in children, creates a new class type based on this base.
--@param customMt Special metatable else uses default.
function BirdNavGridStateBase.new(customMt)
    local self = setmetatable({}, customMt or BirdNavGridStateBase_mt)
    -- overriden in child
    return self
end

--- init called after new, gives the owner to this state.
--@param inOwner given as the owner of the state.
function BirdNavGridStateBase:init(inOwner)
    self.owner = inOwner
end

--- enter overriden in children, called when state changes into this.
function BirdNavGridStateBase:enter()
    --
end

--- leave overriden in children, called when the state is changed to something else.
function BirdNavGridStateBase:leave()
    --
end

--- update overriden in children, forwarded the update from owner into this.
--@param dt deltaTime forwarded from the owner update function.
function BirdNavGridStateBase:update(dt)
    --
end

--- destroy overriden in children.
function BirdNavGridStateBase:destroy()
    --
end


---@class BirdNavGridStatePrepare.
-- Used to prepare some variables such as getting terrainSize and finding the boundaries.
BirdNavGridStatePrepare = {}
BirdNavGridStatePrepare_mt = Class(BirdNavGridStatePrepare,BirdNavGridStateBase)
InitObjectClass(BirdNavGridStatePrepare, "BirdNavGridStatePrepare")

--- new creates a new prepare state.
--@param customMt special metatable else uses default.
function BirdNavGridStatePrepare.new(customMt)
    local self = BirdNavGridStatePrepare:superClass().new(customMt or BirdNavGridStatePrepare_mt)
    self.seenIDs = {}
    return self
end

--- enter executes functions to prepare grid generation.
-- And last requests a change to generate state.
function BirdNavGridStatePrepare:enter()
    BirdNavGridStatePrepare:superClass().enter(self)

    if self.owner == nil then
        Logging.warning("self.owner was nil in BirdNavGridStatePrepare:enter()!")
        return
    end


    self:prepareGrid()

    self:findBoundaries()

    self.owner:changeState(self.owner.EBirdNavigationGridStates.GENERATE)

end

--- leave has no stuff to do in this state.
function BirdNavGridStatePrepare:leave()
    BirdNavGridStatePrepare:superClass().leave(self)
    --
end

--- update has no stuff to do in this state.
--@param dt deltaTime forwarded from the owner update function.
function BirdNavGridStatePrepare:update(dt)
    BirdNavGridStatePrepare:superClass().update(self,dt)
    --
end

--- prepareGrid handles getting terrainSize ready.
function BirdNavGridStatePrepare:prepareGrid()

    if self.owner == nil then
        return
    end


    if g_currentMission.terrainRootNode ~= nil then
        self.owner.terrainSize = Utils.getNoNil(getTerrainSize(g_currentMission.terrainRootNode),self.owner.terrainSize)
    end


    local tileCount = self.owner.terrainSize / self.owner.maxVoxelResolution

    -- Making sure the terrain size divides evenly, else add a bit extra space.
    if tileCount % 2 ~= 0 then
        local extension = (2 - self.owner.tileCount % 2) * self.owner.maxVoxelResolution
        self.owner.terrainSize = self.owner.terrainSize + extension
    end

end

--- destroy no cleanup needed in this state.
function BirdNavGridStatePrepare:destroy()
    BirdNavGridStatePrepare:superClass().destroy(self)
    --
end

--- findBoundaries is used to collision check for the boundaries at the edge of the map.
-- As including those in the navigation grid would be a waste.
-- So this function calls forward to overlapBox each 4 map edges three times along the edge.
function BirdNavGridStatePrepare:findBoundaries()

    -- Get the extermities of the map.
    local minX,maxX,minZ,maxZ = 0 - self.owner.terrainSize / 2, 0 + self.owner.terrainSize / 2, 0 - self.owner.terrainSize / 2, 0 + self.owner.terrainSize / 2
    -- Taking a decent sized extent box to test with so that it certainly finds the boundary, also default map has double boundaries to find them both.
    --                          Corner     Middle edge        Corner
    self:boundaryOverlapCheck(minX,0,minZ,  0,0,minZ,         maxX,0,minZ, self.owner.terrainSize / 3,self.owner.terrainSize / 2,100)

    --                          Corner     Middle edge        Corner
    self:boundaryOverlapCheck(minX,0,maxZ,  0,0,maxZ,         maxX,0,maxZ, self.owner.terrainSize / 3,self.owner.terrainSize / 2,100)

    --                          Corner     Middle edge        Corner
    self:boundaryOverlapCheck(minX,0,minZ,  minX,0,0,         minX,0,maxZ, 100,self.owner.terrainSize / 2, self.owner.terrainSize / 3)

    --                          Corner     Middle edge        Corner
    self:boundaryOverlapCheck(maxX,0,minZ,  maxX,0,0,         maxX,0,maxZ, 100,self.owner.terrainSize / 2, self.owner.terrainSize / 3)


end

--- boundaryOverlap checks given three points with overlapBox.
-- It checks the corners of an edge and the middle, so that it can find the id of the boundary.
-- As the boundary is extremely long along the edge of the map, we can assume that there is no building near the edge which is as long as the boundaries.
--@param x The first corner X coordinate.
--@param y The first corner Y coordinate.
--@param z The first corner Z coordinate.
--@param x2 The middle point X coordinate.
--@param y2 The middle point Y coordinate.
--@param z2 The middle point Z coordinate.
--@param x3 The second corner X coordinate.
--@param y3 The second corner Y coordinate.
--@param z3 The second corner Z coordinate.
--@param extentX The X radius extent of the overlapBox to collision test map against.
--@param extentY The Y radius extent of the overlapBox to collision test map against.
--@param extentZ The Z radius extent of the overlapBox to collision test map against.
function BirdNavGridStatePrepare:boundaryOverlapCheck(x,y,z,x2,y2,z2,x3,y3,z3, extentX,extentY,extentZ)

    overlapBox(x,y,z,0,0,0,extentX,extentY,extentZ,"boundaryOverlapCheckCallback",self,CollisionFlag.STATIC_WORLD,false,true,true,false)
    overlapBox(x2,y2,z2,0,0,0,extentX / 2,extentY,extentZ,"boundaryOverlapCheckCallback",self,CollisionFlag.STATIC_WORLD,false,true,true,false)
    overlapBox(x3,y3,z3,0,0,0,extentX,extentY,extentZ,"boundaryOverlapCheckCallback",self,CollisionFlag.STATIC_WORLD,false,true,true,false)
    -- After checking for overlaps resets the seenIDs table, so that when next edge is checked it won't add false id's as boundary.
    self.seenIDs = nil
    self.seenIDs = {}
end

--- boundaryOverlapCheckCallback Callback function of the boundaryOverlapCheck's overlapBox calls.
-- If there is a collision with an object that has ClassIds.SHAPE then it puts it into seenIDs.
-- If a duplicate ID is found then it puts it in the owner's mapBoundaryIDs table.
-- The overlap checks of FS22 LUA works that the return true, will tell it to keep checking for more overlaps.
-- While returning a false would stop it from going through more overlapped objects.
-- Here in this function all overlapped objects needs to be checked.
--@hitObjectId is id of an object hit.
function BirdNavGridStatePrepare:boundaryOverlapCheckCallback(hitObjectId)

    if hitObjectId < 1 or hitObjectId == g_currentMission.terrainRootNode then
        return true
    end

    if getHasClassId(hitObjectId,ClassIds.SHAPE) then
        if self.seenIDs[hitObjectId] then
            self.owner.mapBoundaryIDs[hitObjectId] = true
        else
            self.seenIDs[hitObjectId] = true
        end
    end

    return true
end



---@class BirdNavGridStateGenerate.
-- This state handles the actual creation of the octree.
BirdNavGridStateGenerate = {}
BirdNavGridStateGenerate_mt = Class(BirdNavGridStateGenerate,BirdNavGridStateBase)
InitObjectClass(BirdNavGridStateGenerate, "BirdNavGridStateGenerate")

--- new creates a new generate state.
--@param customMt special metatable else uses default.
function BirdNavGridStateGenerate.new(customMt)
    local self = BirdNavGridStateGenerate:superClass().new(customMt or BirdNavGridStateGenerate_mt)

    self.dynamicLoopLimit = 1
    self.dynamicLoopRemove = 2
    self.dynamicLoopAdd = 1
    self.targetFPS = 0
    self.currentNodeIndex = 1
    self.generationTime = 0
    self.EInternalState = {UNDEFINED = -1 , GETFPS = 0 ,CREATE = 1, EXTERNALNEIGHBOURS = 2 ,IDLE = 3}
    self.currentState = self.EInternalState.GETFPS
    self.fiveSecondFPSLog = {}
    self.FPSLogAmount = 5
    self.currentLayerNodes = {}
    self.nextLayerNodes = {}

    return self
end

--- enter this state will make sure to raiseActive on the owner so that update function will be called.
function BirdNavGridStateGenerate:enter()
    BirdNavGridStateGenerate:superClass().enter(self)


    if self.owner ~= nil then
        -- create the root octree node that covers the whole map in size.
        local rootNode = BirdNavNode.new(0,self.owner.terrainSize / 2,0,nil,self.owner.terrainSize)
        self.owner.nodeTree = rootNode
        table.insert(self.currentLayerNodes,rootNode)
        self.owner:raiseActive()
    end


end

--- leave clean up some used temp variables
function BirdNavGridStateGenerate:leave()
    BirdNavGridStateGenerate:superClass().leave(self)
    self.currentLayerNodes = nil
    self.nextLayerNodes = nil
end

--- destroy not used on this state.
function BirdNavGridStateGenerate:destroy()
    BirdNavGridStateGenerate:superClass().destroy(self)
    --
end

--- update for this state handles looping few times per update constructing the octree.
-- tries to keep the FPS at a targetFPS, calculated by an average FPS of the first five seconds in to the game.
--@param dt deltaTime forwarded from the owner update function.
function BirdNavGridStateGenerate:update(dt)
    BirdNavGridStateGenerate:superClass().update(self,dt)

    if self.owner ~= nil then
        self.owner:raiseActive()
    end

    -- accumulate time
    self.generationTime = self.generationTime + (dt / 1000)

    -- initially once on game start in GETFPS state, where the average FPS is measured and then target FPS is set.
    if self.currentState == self.EInternalState.GETFPS then

        -- every second passed, take in fps value.
        if self.generationTime >= 1 then
            self.generationTime = 0
            table.insert(self.fiveSecondFPSLog,1 / (dt / 1000))
            -- If enough fps's gathered as per FPSLogAmount, then can take the average and get the targetFPS.
            if #self.fiveSecondFPSLog == self.FPSLogAmount then

                self.targetFPS = (self.fiveSecondFPSLog[1] + self.fiveSecondFPSLog[2] + self.fiveSecondFPSLog[3] + self.fiveSecondFPSLog[4] + self.fiveSecondFPSLog[5]) / self.FPSLogAmount

                -- depending on if there is a frameLimit on, either setting -1 from frameLimit or if fps is already lower than the limit then just averageFPS - 1.
                if g_gameSettings.frameLimit > 0 and self.targetFPS >= g_gameSettings.frameLimit then
                    self.targetFPS = g_gameSettings.frameLimit - 1
                else
                    if self.targetFPS > 60 then
                        self.targetFPS = 59
                    elseif self.targetFPS < 30 then
                        self.targetFPS = 29
                    else
                        self.targetFPS = self.targetFPS - 1
                    end
                end
                Logging.info(string.format("Target FPS to keep while generating BirdFeeder Nav is: %d",self.targetFPS))
                self.fiveSecondFPSLog = nil
                -- Change to internal create state
                self.currentState = self.EInternalState.CREATE
                return
            end
        end

        return
    end


    local currentLoops = 0

    -- Loop through the creation as many times as possible restricted by the dynamicLoopLimit
    while currentLoops < self.dynamicLoopLimit do

        if self.currentState == self.EInternalState.CREATE then

            -- doOctree returns true when the octree has been fully made.
            if self:doOctree() == true then
                self:finishGrid()

            end
        elseif self.currentState == self.EInternalState.EXTERNALNEIGHBOURS then

            if self:doExternNeighbours() == true then
                self.currentState = self.EInternalState.CREATE
            end
        end

        currentLoops = currentLoops + 1
    end

    -- Increase or lower the dynamicLoopLimit depending on the FPS.
    local currentFPS = 1 / (dt / 1000)
    if self.dynamicLoopLimit > 0 + self.dynamicLoopRemove and currentFPS < self.targetFPS  then
        self.dynamicLoopLimit = self.dynamicLoopLimit - self.dynamicLoopRemove
    elseif currentFPS > self.targetFPS then
        self.dynamicLoopLimit = self.dynamicLoopLimit + self.dynamicLoopAdd
    elseif self.dynamicLoopLimit < 1 then
        self.dynamicLoopLimit = self.dynamicLoopLimit + self.dynamicLoopAdd
    end


end

function BirdNavGridStateGenerate:finishGrid()

    local minutes = math.floor(self.generationTime / 60)
    local seconds = self.generationTime % 60
    Logging.info(string.format("BirdNavGridStateGenerate done generating octree! Took around %d Minutes, %d Seconds",minutes,seconds))
    -- Change state to idle
    self.currentState = self.EInternalState.IDLE
    if self.owner ~= nil then
        self.owner:changeState(self.owner.EBirdNavigationGridStates.IDLE)
    end
end

--- doOctree does all parts regarding the octree creation.
-- currentNodeIndex are stored in the state, so that this function can be executed in parts.
function BirdNavGridStateGenerate:doOctree()

    if self.owner == nil then
        return
    end

    -- getting the currentNode, which will have either leafvoxels or children created for (if solid).
    local currentNode = self.currentLayerNodes[self.currentNodeIndex]
    if currentNode.size == self.owner.leafNodeResolution then
        self.owner:createLeafVoxels(currentNode)
    else
        self:createChildren(currentNode)
    end

    self.currentNodeIndex = self.currentNodeIndex + 1
    if self.currentLayerNodes[self.currentNodeIndex] == nil then
        if self:increaseLayer() == true then
            return true
        end
        self.currentState = self.EInternalState.EXTERNALNEIGHBOURS
    end

    return false

end

function BirdNavGridStateGenerate:doExternNeighbours()

    if self.owner == nil then
        return false
    end

    for i = 1, 8 do
        self.owner.findNeighbours(self.currentLayerNodes[self.currentNodeIndex + (i - 1)],i)
    end


    self.currentNodeIndex = self.currentNodeIndex + 8
    if self.currentLayerNodes[self.currentNodeIndex] == nil then
        self.currentNodeIndex = 1
        return true
    end

    return false
end


function BirdNavGridStateGenerate:increaseLayer()
    self.currentLayerNodes = self.nextLayerNodes
    self.currentNodeIndex = 1
    self.nextLayerNodes = nil
    self.nextLayerNodes = {}
    if #self.currentLayerNodes < 1 then
        return true
    end

    return false
end



--- createChildren gets called for every node which is still not enough resolution to be a leaf node.
-- It creates eight children only if there is a collision found.
-- The newly created children will also have their neighbours linked after being created.
--@param parent node which owns these possible child nodes.
--@param parentVoxelSize the full extent of the parent node voxel.
function BirdNavGridStateGenerate:createChildren(parent)

    if self.owner == nil or parent == nil then
        return
    end

    -- Need to check for a collision if no collision then current node is childless node but not a leaf
    self.owner:voxelOverlapCheck(parent.positionX,parent.positionY,parent.positionZ,parent.size / 2)
    if self.owner.bTraceVoxelSolid == false then
        return
    end

    -- divided by 4 to get the new child voxels radius to offset inside the parent node
    self.startLocationX = parent.positionX - (parent.size / 4)
    self.startLocationY = parent.positionY - (parent.size / 4)
    self.startLocationZ = parent.positionZ - (parent.size / 4)

    parent.children = {}
    for y = 0, 1 do
        for z = 0 , 1 do
            for x = 0, 1 do
                local newNode = BirdNavNode.new(self.startLocationX + (x * (parent.size / 2)) ,self.startLocationY + (y * (parent.size / 2)), self.startLocationZ + (z * (parent.size / 2)),parent,parent.size / 2)
                table.insert(self.nextLayerNodes,newNode)
                table.insert(parent.children,newNode)
            end
        end
    end


end


---@class BirdNavGridStateUpdate.
-- Used to update existing octree after some static object has been deleted or constructed.
BirdNavGridStateUpdate = {}
BirdNavGridStateUpdate_mt = Class(BirdNavGridStateUpdate,BirdNavGridStateBase)
InitObjectClass(BirdNavGridStateUpdate, "BirdNavGridStateUpdate")

--- new creates a new update state.
--@param customMt special metatable else uses default.
function BirdNavGridStateUpdate.new(customMt)
    local self = BirdNavGridStateUpdate:superClass().new(customMt or BirdNavGridStateUpdate_mt)
    self.gridUpdate = nil
    self.nodeToCheck = nil
    self.nodesToDelete = {}
    self.currentLayerNodes = {}
    self.currentLayerNodes = {}
    self.currentNodeIndex = 1
    self.nextLayerNodes = {}
    self.bFindNeighbours = false

    return self
end

--- enter deques a grid update from the queue from parent.
function BirdNavGridStateUpdate:enter()
    BirdNavGridStateUpdate:superClass().enter(self)

    if self.owner == nil then
        Logging.warning("self.owner was nil in BirdNavGridStateUpdate:enter()")
        self.owner:changeState(self.owner.EBirdNavigationGridStates.IDLE)
        return
    end

    self:receiveWork()
    if self.owner ~= nil then
        self.owner:raiseActive()
    end
end

--- leave has no stuff to do in this state.
function BirdNavGridStateUpdate:leave()
    BirdNavGridStateUpdate:superClass().leave(self)
    self.gridUpdate = nil
    self.nodeToCheck = nil
    self.currentLayerNodes = nil
    self.currentLayerNodes = {}
    self.nextLayerNodes = nil
    self.nextLayerNodes = {}
end

--- update works to update the area that has been modified.
--@param dt deltaTime forwarded from the owner update function.
function BirdNavGridStateUpdate:update(dt)
    BirdNavGridStateUpdate:superClass().update(self,dt)

    if self.owner ~= nil then
        self.owner:raiseActive()
    end

    if not self.bFindNeighbours and self:updateGrid() == true then
        Logging.info("Updated BirdNavigationGrid")
        self:receiveWork()
    elseif self.bFindNeighbours then
        self:doExternNeighbours()
    end

end


--- destroy no cleanup needed in this state.
function BirdNavGridStateUpdate:destroy()
    BirdNavGridStateUpdate:superClass().destroy(self)
    --
end


function BirdNavGridStateUpdate:receiveWork()
    if self.owner == nil then
        return
    end

    if #self.owner.gridUpdateQueue < 1 then
        self.owner:changeState(self.owner.EBirdNavigationGridStates.IDLE)
        return
    end

    self.gridUpdate = self.owner.gridUpdateQueue[1]
    table.remove(self.owner.gridUpdateQueue,1)

    self:getNodeToRedo()

end

function BirdNavGridStateUpdate:getNodeToRedo()
    if self.owner == nil or self.gridUpdate == nil or self.owner.nodeTree == nil then
        return
    end

    local currentNode = self.owner.nodeTree
    local splitNodes = {}

    while true do

        if currentNode.children ~= nil then
            for i,node in ipairs(currentNode.children) do
                if self:findEncomppasingNode(node) == true then
                    table.insert(splitNodes,i)
                end
            end
        end

        if #splitNodes == 0 or #splitNodes > 1 then
            self.nodeToCheck = currentNode
            table.insert(self.currentLayerNodes,currentNode)
            return
        else
            currentNode = currentNode.children[splitNodes[1]]
            splitNodes = {}
        end

    end

end

function BirdNavGridStateUpdate:findEncomppasingNode(node)

    local aabbNode = {node.positionX - (node.size / 2), node.positionY - (node.size / 2), node.positionZ - (node.size / 2),node.positionX + (node.size / 2), node.positionY + (node.size / 2), node.positionZ + (node.size / 2) }

    if BirdNavNode.checkAABBIntersection(aabbNode,self.gridUpdate.aabb) == true then
        return true
    else
        return false
    end

end


function BirdNavGridStateUpdate:updateGrid()

    if self.owner == nil or self.nodeToCheck == nil then
        return
    end


    -- getting the currentNode, which will have either leafvoxels or children created for (if solid).
    local currentNode = self.currentLayerNodes[self.currentNodeIndex]

    if currentNode.size == self.owner.leafNodeResolution then
        self.owner:createLeafVoxels(currentNode,currentNode.size)
    else
        self:reCheckChildren(currentNode)
    end

    self.currentNodeIndex = self.currentNodeIndex + 1
    if self.currentLayerNodes[self.currentNodeIndex] == nil then
        self.currentLayerNodes = self.nextLayerNodes
        self.currentNodeIndex = 1
        self.nextLayerNodes = nil
        self.nextLayerNodes = {}
        if #self.currentLayerNodes < 1 then
            return true
        end

          self.bFindNeighbours = true
    end

    return false
end

function BirdNavGridStateUpdate:reCheckChildren(parent)

    if self.owner == nil or parent == nil then
        return
    end

    self.owner:voxelOverlapCheck(parent.positionX,parent.positionY,parent.positionZ,parent.size / 2)

    print("overlap check was : " .. tostring(self.owner.bTraceVoxelSolid))

    if self.owner.bTraceVoxelSolid and parent.children == nil then
        -- divided by 4 to get the new child voxels radius to offset inside the parent node
        self.startLocationX = parent.positionX - (parent.size / 4)
        self.startLocationY = parent.positionY - (parent.size / 4)
        self.startLocationZ = parent.positionZ - (parent.size / 4)
        parent.children = {}
        for y = 0, 1 do
            for z = 0 , 1 do
                for x = 0, 1 do
                    local newNode = BirdNavNode.new(self.startLocationX + (x * (parent.size / 2)) ,self.startLocationY + (y * (parent.size / 2)), self.startLocationZ + (z * (parent.size / 2)),parent,parent.size / 2)
                    table.insert(self.nextLayerNodes,newNode)
                    table.insert(parent.children,newNode)
                end
            end
        end
    elseif not self.owner.bTraceVoxelSolid and parent.children ~= nil then
        -- become empty delete children and redo neigbours
        for i = 1, 8 do
            self:removeNeighbours(parent.children[i],parent)
        end
        parent.children = nil
    elseif not self.owner.bTraceVoxelSolid and parent.children == nil then
        -- no change on this node
        return
    else
        -- no change for this node but has children so need to go deeper
        for i = 1, 8 do
            table.insert(self.nextLayerNodes,parent.children[i])
        end
    end


end

function BirdNavGridStateUpdate:doExternNeighbours()

    if self.owner == nil then
        return
    end

    for i = 1, 8 do
        self.owner.findNeighbours(self.currentLayerNodes[self.currentNodeIndex + (i - 1)],i)
    end


    self.currentNodeIndex = self.currentNodeIndex + 8
    if self.currentLayerNodes[self.currentNodeIndex] == nil then
        self.currentNodeIndex = 1
        self.bFindNeighbours = false
    end

end


function BirdNavGridStateUpdate:removeNeighbours(node,parent)

    if node.children == nil then
        self:deleteAllNeighbours(node)
        return
    end

    for i = 1, 8 do
        self:removeNeighbours(node.children[i],parent)
    end

    self:deleteAllNeighbours(node,parent)

end

function BirdNavGridStateUpdate:deleteAllNeighbours(node,newParentNeighbour)

    if node.xNeighbour ~= nil then
        node.xNeighbour.xMinusNeighbour = newParentNeighbour
    end

    if node.yNeighbour ~= nil then
        node.yNeighbour.yMinusNeighbour = newParentNeighbour
    end

    if node.zNeighbour ~= nil then
        node.zNeighbour.zMinusNeighbour = newParentNeighbour
    end

    if node.xMinusNeighbour ~= nil then
        node.xMinusNeighbour.xNeighbour = newParentNeighbour
    end

    if node.yMinusNeighbour ~= nil then
        node.yMinusNeighbour.yNeighbour = newParentNeighbour
    end

    if node.zMinusNeighbour ~= nil then
        node.zMinusNeighbour.zNeighbour = newParentNeighbour
    end


end


---@class BirdNavGridStateDebug.
-- Handles visualizing the octree, can't enter this state if it is currently generating the octree or updating.
-- Can activate by the console command BirdFeederOctreeDebug.
BirdNavGridStateDebug = {}
BirdNavGridStateDebug_mt = Class(BirdNavGridStateDebug,BirdNavGridStateBase)
InitObjectClass(BirdNavGridStateDebug, "BirdNavGridStateDebug")

--- increaseDebugLayer is a console command that increases the octree layer to be visualized.
function BirdNavGridStateDebug:increaseDebugLayer()

    self.currentDebugLayer = self.currentDebugLayer + 1
    self.nodeRefreshNeeded = true
    -- max debug layer will be limited to octree's layers, but adding one more so that the leaf node's 64 voxels can also be shown at layer + 1
    self.currentDebugLayer = MathUtil.clamp(self.currentDebugLayer,1,self.maxDebugLayer + 1)

end

--- decreaseDebugLayer is a console command that decreases the octree layer to be visualized.
function BirdNavGridStateDebug:decreaseDebugLayer()

    self.currentDebugLayer = self.currentDebugLayer - 1
    self.nodeRefreshNeeded = true
    self.currentDebugLayer = MathUtil.clamp(self.currentDebugLayer,1,self.maxDebugLayer)

end

--- new creates a new debug state
--@param customMt special metatable else uses default.
function BirdNavGridStateDebug.new(customMt)
    local self = BirdNavGridStateDebug:superClass().new(customMt or BirdNavGridStateDebug_mt)
    -- debugGrid will be gathered all the locations of the grid to be shown and rendered with the DebugUtil.drawSimpleDebugCube function.
    self.debugGrid = {}
    -- save the new player location every n(playerLocationUpdateDistance) meters to optimize rendering the debug.
    self.playerLastLocation = { x = 0, y = 0, z = 0}
    self.playerLocationUpdateDistance = 50
    self.voxelCurrentRenderDistance = 0
    -- if maxVoxelsAtTime exceeds then how far should voxels be gathered from and displayed
    self.voxelLimitedMaxRenderDistance = 70
    self.maxVoxelsAtTime = 70000
    -- saving the last node that player was in to compare each update, to know when the player enters a new node to display updated info about the new node.
    self.lastNode = {x = 0, y = 0, z = 0}
    -- This variable is adjusted by the two console commands to increase and decrease the currently visualized layer of octree.
    self.currentDebugLayer = 1
    -- This variable is set after finishing the octree creation to the maximum layer + 1, +1 to indicate the possibility to visualize the leaf voxels within the leaf node layer.
    self.maxDebugLayer = 9999
    -- bool to know if the player has moved beyond the update distance to gather new set of voxels to visualize or if layer has been changed.
    self.nodeRefreshNeeded = true
    return self
end

--- enter this state and the console commands will be bound with the actions.
function BirdNavGridStateDebug:enter()
    BirdNavGridStateDebug:superClass().enter(self)

    if self == nil or self.owner == nil then
        return
    end

    self.maxDebugLayer = self.owner:getNodeTreeLayer(self.owner.leafNodeResolution)
    if g_inputBinding ~= nil then
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.BIRDFEEDER_DBG_OCTREE_LAYER_DOWN, self, self.decreaseDebugLayer, true, false, false, true, true, true)
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.BIRDFEEDER_DBG_OCTREE_LAYER_UP, self, self.increaseDebugLayer, true, false, false, true, true, true)
    end

    if self.owner ~= nil then
        self.owner:raiseActive()
    end

end

--- leave removes the console command action bindings.
function BirdNavGridStateDebug:leave()
    BirdNavGridStateDebug:superClass().leave(self)

    if g_inputBinding ~= nil then
        g_inputBinding:removeActionEventsByTarget(self)
    end
    self.nodeRefreshNeeded = true
    self.debugGrid = nil
    self.debugGrid = {}

end

--- update calls the functions that handles visualizing the octree and info about current node.
--@param dt deltaTime forwarded from the owner update function.
function BirdNavGridStateDebug:update(dt)
    BirdNavGridStateDebug:superClass().update(self,dt)

    if self.owner == nil or self.owner.nodeTree == nil then
        return
    end

    self.owner:raiseActive()

    self:updatePlayerDistance()

    self:renderOctreeDebugView()

    self:printCurrentNodeInfo(self.owner.nodeTree)


end

--- renderOctreeDebugView calls to gather the relevant nodes if refresh needed and then renders a debug cube for each node.
function BirdNavGridStateDebug:renderOctreeDebugView()

    -- node refresh is set to true if layer is changed or player moves enough distance
    if self.nodeRefreshNeeded then
        self.nodeRefreshNeeded = false
        self.debugGrid = nil
        self.debugGrid = {}

        -- if too many voxels at current layer to render then limit distance, else whole maps distance of nodes can be gathered.
        if self:getLimitRenderDistance() then
            self.voxelCurrentRenderDistance = self.voxelLimitedMaxRenderDistance
        else
            self.voxelCurrentRenderDistance = self.owner.terrainSize
        end

        self:findCloseEnoughVoxels(self.owner.nodeTree)
    end

    -- if layer is beyond the leaf node layer means want to show the leaf nodes highest resolution 64 voxels, and need to bit manipulate to get the solid info.
    if self.currentDebugLayer == self.maxDebugLayer + 1 then

        for _,node in pairs(self.debugGrid) do

            if BirdNavNode.isSolid(node) and BirdNavNode.isLeaf(node) then

                local childNumber = 0
                local startPositionX = node.positionX - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)
                local startPositionY = node.positionY - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)
                local startPositionZ = node.positionZ - self.owner.maxVoxelResolution - (self.owner.maxVoxelResolution / 2)

                for y = 0, 1 do
                    for z = 0 , 3 do
                        for x = 0, 3 do
                            local currentPositionX = startPositionX + (self.owner.maxVoxelResolution * x)
                            local currentPositionY = startPositionY + (self.owner.maxVoxelResolution * y)
                            local currentPositionZ = startPositionZ + (self.owner.maxVoxelResolution * z)

                            -- get the bit state and only render if it is a 1 == solid
                            local bitState = bitAND(math.floor(node.leafVoxelsBottom / (math.pow(2,childNumber))), 1)
                            if bitState ~= 0 then
                                DebugUtil.drawSimpleDebugCube(currentPositionX, currentPositionY, currentPositionZ, self.owner.maxVoxelResolution, 1, 0, 0)
                            end

                            childNumber = childNumber + 1
                        end
                    end
                end

                childNumber = 0
                for y = 2, 3 do
                    for z = 0 , 3 do
                        for x = 0, 3 do
                            local currentPositionX = startPositionX + (self.owner.maxVoxelResolution * x)
                            local currentPositionY = startPositionY + (self.owner.maxVoxelResolution * y)
                            local currentPositionZ = startPositionZ + (self.owner.maxVoxelResolution * z)

                            -- get the bit state and only render if it is a 1 == solid
                            local bitState = bitAND(math.floor(node.leafVoxelsTop / (math.pow(2,childNumber))), 1)
                            if bitState ~= 0 then
                                DebugUtil.drawSimpleDebugCube(currentPositionX, currentPositionY, currentPositionZ, self.owner.maxVoxelResolution, 1, 0, 0)
                            end

                            childNumber = childNumber + 1
                        end
                    end
                end

            end

        end
    else
        for _,node in pairs(self.debugGrid) do
            if BirdNavNode.isSolid(node) then
                DebugUtil.drawSimpleDebugCube(node.positionX, node.positionY, node.positionZ, node.size, 1, 0, 0)
            end
        end
    end

end

--- getLimitRenderDistance is a tiny helper function to get if the distance of visible nodes should be limited for performance reasons.
--@return true if should limit the distance of visible debug nodes.
function BirdNavGridStateDebug:getLimitRenderDistance()

    -- if the current debug layer is more than 0.7 (70%) of existing layers, then showing quite high resolution so can limit the render distance.
    if (self.currentDebugLayer / (self.maxDebugLayer + 1))  > 0.7 then
        return true
    end

    return false
end

--- printCurrentNodeInfo finds the node which player is currently in up to the currently selected layer.
-- and prints some basic information about the node.
--@param node takes in first the root node of the octree and is a recursive function so goes deeper into the octree.
function BirdNavGridStateDebug:printCurrentNodeInfo(node)

    if self.owner == nil or node == nil then
        return
    end


    local playerX,playerY,playerZ = getWorldTranslation(g_currentMission.player.rootNode)

    local aabbNode = {node.positionX - (node.size / 2), node.positionY - (node.size / 2), node.positionZ - (node.size / 2),node.positionX + (node.size / 2), node.positionY + (node.size / 2), node.positionZ + (node.size / 2) }

    if BirdNavNode.checkPointInAABB(playerX,playerY,playerZ,aabbNode) == true then

        -- need to cap it, as it could be one above the array index to indicate the leaf nodes voxel layers.
        local currentLayer = MathUtil.clamp(self.currentDebugLayer,1,self.maxDebugLayer)

        -- -1 as currentLayer 1 is the root of octree
        local currentDivision = math.pow(2,currentLayer - 1)
        local targetVoxelSize = self.owner.terrainSize / currentDivision

        -- if current node is the size that currentlayer indicates then we have found the node player resides in
        if node.size == targetVoxelSize then
            if node.positionX ~= self.lastNode.x or node.positionY ~= self.lastNode.y or node.positionZ ~= self.lastNode.z then
                self.lastNode.x, self.lastNode.y , self.lastNode.z = node.positionX, node.positionY, node.positionZ
                Logging.info(string.format("Current node position x:%d y:%d z:%d ",node.positionX,node.positionY,node.positionZ))
                Logging.info("Current node is solid: " .. tostring(BirdNavNode.isSolid(node)))
                Logging.info("Current node is a leaf node: " .. tostring(BirdNavNode.isLeaf(node)))
                Logging.info("Current node size: " .. tostring(node.size))
                if BirdNavNode.isLeaf(node) then
                    Logging.info(string.format("Current leaf node's bottom voxel info %d, top voxel info %d",node.leafVoxelsBottom,node.leafVoxelsTop))
                    Logging.info(string.format("Current leaf node's child voxels size: %d",node.size / 4))
                end
            end
            return


        elseif node.children ~= nil then
            for _ , node in pairs(node.children) do
                self:printCurrentNodeInfo(node)
            end
        end
    end


end

--- updatePlayerDistance handles updating the player's last location variable every n meters passed.
function BirdNavGridStateDebug:updatePlayerDistance()

    local playerX,playerY,playerZ = getWorldTranslation(g_currentMission.player.rootNode)
    local distance = BirdNavigationGrid.getVectorDistance(self.playerLastLocation.x,self.playerLastLocation.y,self.playerLastLocation.z,playerX,playerY,playerZ)
    if distance > self.playerLocationUpdateDistance then
        self.nodeRefreshNeeded = true
        self.playerLastLocation.x = playerX
        self.playerLastLocation.y = playerY
        self.playerLastLocation.z = playerZ
    end

end

--- findCloseEnoughVoxels Is a recursive function that finds all the nodes within required distance.
-- Doesn't return a value but appends the found nodes within range into debugGrid.
--@param node is initially the root node of octree, and as a recursive function goes deeper into the octree.
function BirdNavGridStateDebug:findCloseEnoughVoxels(node)

    if self.owner == nil or node == nil then
        return
    end

    -- need to cap it, as it could be one above the array index to indicate the leaf nodes voxel layers.
    local currentLayer = MathUtil.clamp(self.currentDebugLayer,1,self.maxDebugLayer)

    -- -1 as currentLayer 1 is the root of octree
    local currentDivision = math.pow(2,currentLayer - 1)
    local targetVoxelSize = self.owner.terrainSize / currentDivision

    -- Special situation where root could be the only node required then add just the one node.
    if node.size == targetVoxelSize then
        self:appendDebugGrid({node})
        return
    elseif node.size / 2 == targetVoxelSize and node.children ~= nil then
        self:appendDebugGrid(node.children)
        return
    end


    local aabbNode = {node.positionX - (node.size / 2), node.positionY - (node.size / 2), node.positionZ - (node.size / 2),node.positionX + (node.size / 2), node.positionY + (node.size / 2), node.positionZ + (node.size / 2) }
    local aabbPlayer = {self.playerLastLocation.x - self.voxelCurrentRenderDistance, self.playerLastLocation.y - self.voxelCurrentRenderDistance, self.playerLastLocation.z - self.voxelCurrentRenderDistance,self.playerLastLocation.x
        + self.voxelCurrentRenderDistance, self.playerLastLocation.y + self.voxelCurrentRenderDistance, self.playerLastLocation.z + self.voxelCurrentRenderDistance}

    if BirdNavNode.checkAABBIntersection(aabbNode,aabbPlayer) == true and node.children ~= nil then
        for _, childNode in pairs(node.children) do
            self:findCloseEnoughVoxels(childNode)
        end
    end

end


--- appendDebugGrid helper function appends a given nodes table into the debugGrid.
function BirdNavGridStateDebug:appendDebugGrid(nodes)

    for _,node in pairs(nodes) do
        table.insert(self.debugGrid,node)
    end

end

--- destroy not used by this state.
function BirdNavGridStateDebug:destroy()
    BirdNavGridStateDebug:superClass().destroy(self)
    --
end



