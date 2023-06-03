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


--[[
    Overview of the arrangment of the children in the octree.
    octree voxels bottom index guide  |3| |1| and then top of voxel  |7| |5|
                                      |4| |2|                        |8| |6|
                                              1 -> 2 is positive X
                                              1 -> 3 is positive Z
                                              1 -> 5 is positive Y

    Overview of the arrangment of the 4x4x4 size leaf voxels in the octree divided into two 32bit.
    1st layer and 2nd layer     |12| |8 | |4| |0|  |28| |24| |20| |16|  3rd layer and 4th layer |12| |8 | |4| |0|   |28| |24| |20| |16|
    leafVoxelsBottom            |13| |9 | |5| |1|  |29| |25| |21| |17|  leafVoxelsTop           |13| |9 | |5| |1|   |29| |25| |21| |17|
    3D Cube sliced view         |14| |10| |6| |2|  |30| |26| |22| |18|                          |14| |10| |6| |2|   |30| |26| |22| |18|
                                |15| |11| |7| |3|  |31| |27| |23| |19|                          |15| |11| |7| |3|   |31| |27| |23| |19|

																				If would not		        |44| |40| |36| |32|   |60| |56| |52| |48|
																				be divided into two	        |45| |41| |37| |33|   |61| |57| |53| |49|
																				variables would look like:  |46| |42| |38| |34|   |62| |58| |54| |50|
                                                                                                            |47| |43| |39| |35|   |63| |59| |55| |51|					
]]


------ --- --- --- GRIDMAP3D STATES --- --- --- ------

---@class GridMap3DStateBase.
-- Is the base state class of GridMap3D, defines the base state functions.
GridMap3DStateBase = {}
GridMap3DStateBase_mt = Class(GridMap3DStateBase)
InitObjectClass(GridMap3DStateBase, "GridMap3DStateBase")

--- new overriden in children, creates a new class type based on this base.
--@param customMt Special metatable else uses default.
function GridMap3DStateBase.new(customMt)
    local self = setmetatable({}, customMt or GridMap3DStateBase_mt)
    -- overriden in child
    return self
end

--- init called after new, gives the owner to this state.
--@param inOwner given as the owner of the state.
function GridMap3DStateBase:init(inOwner)
    self.owner = inOwner
end

--- enter overriden in children, called when state changes into this.
function GridMap3DStateBase:enter()
    --
end

--- leave overriden in children, called when the state is changed to something else.
function GridMap3DStateBase:leave()
    --
end

--- update overriden in children, forwarded the update from owner into this.
--@param dt deltaTime forwarded from the owner update function.
function GridMap3DStateBase:update(dt)
    --
end

--- destroy overriden in children.
function GridMap3DStateBase:destroy()
    --
end


---@class GridMap3DStatePrepare.
-- Used to prepare some variables such as getting terrainSize and finding the boundaries.
GridMap3DStatePrepare = {}
GridMap3DStatePrepare_mt = Class(GridMap3DStatePrepare,GridMap3DStateBase)
InitObjectClass(GridMap3DStatePrepare, "GridMap3DStatePrepare")

--- new creates a new prepare state.
--@param customMt special metatable else uses default.
function GridMap3DStatePrepare.new(customMt)
    local self = GridMap3DStatePrepare:superClass().new(customMt or GridMap3DStatePrepare_mt)
    self.seenIDs = {}
    return self
end

--- enter executes functions to prepare grid generation.
-- And last requests a change to generate state.
function GridMap3DStatePrepare:enter()
    GridMap3DStatePrepare:superClass().enter(self)

    if self.owner == nil then
        Logging.warning("self.owner was nil in GridMap3DStatePrepare:enter()!")
        return
    end


    self:prepareGrid()

    self:findBoundaries()

    self.owner:changeState(self.owner.EGridMap3DStates.GENERATE)

end

--- leave has no stuff to do in this state.
function GridMap3DStatePrepare:leave()
    GridMap3DStatePrepare:superClass().leave(self)
    --
end

--- update has no stuff to do in this state.
--@param dt deltaTime forwarded from the owner update function.
function GridMap3DStatePrepare:update(dt)
    GridMap3DStatePrepare:superClass().update(self,dt)
    --
end

--- prepareGrid handles getting terrainSize ready.
function GridMap3DStatePrepare:prepareGrid()

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
function GridMap3DStatePrepare:destroy()
    GridMap3DStatePrepare:superClass().destroy(self)
    --
end

--- findBoundaries is used to collision check for the boundaries at the edge of the map.
-- As including those in the navigation grid would be a waste.
-- So this function calls forward to overlapBox each 4 map edges three times along the edge.
function GridMap3DStatePrepare:findBoundaries()

    -- Get the extremities of the map.
    local minX,maxX,minZ,maxZ = 0 - self.owner.terrainSize / 2, 0 + self.owner.terrainSize / 2, 0 - self.owner.terrainSize / 2, 0 + self.owner.terrainSize / 2
    -- Taking a decent sized extent box to test with so that it certainly finds the boundary, also default map has double boundaries to find them both.
    --                          Corner     Middle edge        Corner
    self:boundaryOverlapCheck(minX,0,minZ,  0,0,minZ,         maxX,0,minZ, self.owner.terrainSize / 3,self.owner.terrainSize / 2,50)

    --                          Corner     Middle edge        Corner
    self:boundaryOverlapCheck(minX,0,maxZ,  0,0,maxZ,         maxX,0,maxZ, self.owner.terrainSize / 3,self.owner.terrainSize / 2,50)

    --                          Corner     Middle edge        Corner
    self:boundaryOverlapCheck(minX,0,minZ,  minX,0,0,         minX,0,maxZ, 50,self.owner.terrainSize / 2, self.owner.terrainSize / 3)

    --                          Corner     Middle edge        Corner
    self:boundaryOverlapCheck(maxX,0,minZ,  maxX,0,0,         maxX,0,maxZ, 50,self.owner.terrainSize / 2, self.owner.terrainSize / 3)


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
function GridMap3DStatePrepare:boundaryOverlapCheck(x,y,z,x2,y2,z2,x3,y3,z3, extentX,extentY,extentZ)

    overlapBox(x,y,z,0,0,0,extentX,extentY,extentZ,"boundaryOverlapCheckCallback",self,CollisionFlag.STATIC_WORLD,false,true,true,false)
    overlapBox(x2,y2,z2,0,0,0,extentX / 2,extentY,extentZ,"boundaryOverlapCheckCallback",self,CollisionFlag.STATIC_WORLD,false,true,true,false)
    overlapBox(x3,y3,z3,0,0,0,extentX,extentY,extentZ,"boundaryOverlapCheckCallback",self,CollisionFlag.STATIC_WORLD,false,true,true,false)
    -- After checking for overlaps resets the seenIDs table, so that when next edge is checked it won't add false id's as boundary.
    self.seenIDs = nil
    self.seenIDs = {}
end

--- boundaryOverlapCheckCallback Callback function of the boundaryOverlapCheck's overlapBox calls.
-- If there is a collision with an object that has ClassIds.SHAPE then it puts it into seenIDs.
-- If a duplicate ID is found then it puts it in the owner's objectIgnoreIDs table.
-- The overlap checks of FS22 LUA works that the return true, will tell it to keep checking for more overlaps.
-- While returning a false would stop it from going through more overlapped objects.
-- Here in this function all overlapped objects needs to be checked.
--@hitObjectId is id of an object hit.
function GridMap3DStatePrepare:boundaryOverlapCheckCallback(hitObjectId)

    if hitObjectId < 1 or hitObjectId == g_currentMission.terrainRootNode then
        return true
    end

    if getHasClassId(hitObjectId,ClassIds.SHAPE) then
        if self.seenIDs[hitObjectId] then
            self.owner:addObjectIgnoreID(hitObjectId)
        else
            self.seenIDs[hitObjectId] = true
        end
    end

    return true
end



---@class GridMap3DStateGenerate.
-- This state handles the actual creation of the octree.
GridMap3DStateGenerate = {}
GridMap3DStateGenerate_mt = Class(GridMap3DStateGenerate,GridMap3DStateBase)
InitObjectClass(GridMap3DStateGenerate, "GridMap3DStateGenerate")

--- new creates a new generate state.
--@param customMt special metatable else uses default.
function GridMap3DStateGenerate.new(customMt)
    local self = GridMap3DStateGenerate:superClass().new(customMt or GridMap3DStateGenerate_mt)

    self.currentNodeIndex = 1
    self.generationTime = 0
    self.EInternalState = {UNDEFINED = -1 , PRELOOP = 0, CREATE = 1, EXTERNALNEIGHBOURS = 2 ,FINISH = 3 ,IDLE = 4}
    self.currentState = self.EInternalState.PRELOOP
    self.currentLayerNodes = {}
    self.nextLayerNodes = {}

    return self
end

--- enter this state will make sure to raiseActive on the owner so that update function will be called.
function GridMap3DStateGenerate:enter()
    GridMap3DStateGenerate:superClass().enter(self)


    if self.owner ~= nil then
        -- create the root octree node that covers the whole map in size.
        local rootNode = GridMap3DNode.new(0,self.owner.terrainSize / 2,0,nil,self.owner.terrainSize)
        self.owner.nodeTree = rootNode
        table.insert(self.currentLayerNodes,rootNode)

        -- if dedicated then skips preloop and goes to create
        if g_currentMission ~= nil and g_currentMission.connectedToDedicatedServer then
            self.currentState = self.EInternalState.CREATE
        end

    end

end

function GridMap3DStateGenerate:preLoop()
    if self.owner == nil then
        return
    end

    self.currentState = self.EInternalState.CREATE
    for i = 0, self.owner.maxOctreePreLoops do
        if self:iterateOctree() then
            return
        end
    end

end

--- leave clean up some used temp variables
function GridMap3DStateGenerate:leave()
    GridMap3DStateGenerate:superClass().leave(self)
    self.currentLayerNodes = nil
    self.nextLayerNodes = nil
end

--- destroy not used on this state.
function GridMap3DStateGenerate:destroy()
    GridMap3DStateGenerate:superClass().destroy(self)
    --
end

--- update for this state handles looping few times per update constructing the octree.
--@param dt deltaTime forwarded from the owner update function.
function GridMap3DStateGenerate:update(dt)
    GridMap3DStateGenerate:superClass().update(self,dt)
    if self.owner == nil then
        return
    end

    -- on dedicated the grid will be generated much faster
    if g_currentMission ~= nil and g_currentMission.connectedToDedicatedServer then
        -- accumulate time
        self.generationTime = self.generationTime + (dt / 1000)
        for i = 0, 30000 do
            if self:iterateOctree() then
                self:finishGrid()
                return
            end
        end
    else

        -- initially once on game start in PRELOOP state, where a certain amount of the octree is created immediately (gets stuck for few seconds on loading screen after enter is pressed)
        if self.currentState == self.EInternalState.PRELOOP then
            self:preLoop()
            return
        end

        -- accumulate time
        self.generationTime = self.generationTime + (dt / 1000)

        if self.currentState == self.EInternalState.FINISH then
            self:finishGrid()
        end

        -- Loop through the creation n times per update
        for i = 0, self.owner.maxOctreeGenerationLoopsPerUpdate do
            if self:iterateOctree() then
                return
            end
        end
    end

end

--- iterateOctree is called from update function to do one iteration of creating the octree.
function GridMap3DStateGenerate:iterateOctree()

    if self.currentState == self.EInternalState.CREATE then
        -- doOctree returns true when the octree has been fully made.
        if self:doOctree() == true then
            self.currentState = self.EInternalState.FINISH
            return true
        end
    elseif self.currentState == self.EInternalState.EXTERNALNEIGHBOURS then
        if self:doExternNeighbours() == true then
            self.currentState = self.EInternalState.CREATE
        end
    end

    return false
end

--- finishGrid is called when octree creation is completed.
-- Prints out the time taken to create the octree and broadcasts a message that octree has been generated.
-- Finally requests to change owner state to idle.
function GridMap3DStateGenerate:finishGrid()

    local minutes = math.floor(self.generationTime / 60)
    local seconds = self.generationTime % 60
    Logging.info(string.format("GridMap3DStateGenerate done generating octree! Took around %d Minutes, %d Seconds",minutes,seconds))

    -- Change state to idle
    self.currentState = self.EInternalState.IDLE
    if self.owner ~= nil then
        self.owner.bGridGenerated = true

        if g_messageCenter ~= nil then
            g_messageCenter:publish(MessageType.GRIDMAP3D_GRID_GENERATED)
        end

        self.owner:changeState(self.owner.EGridMap3DStates.IDLE)
    end
end

--- doOctree does all parts regarding the octree creation.
-- currentNodeIndex are stored in the state, so that this function can be executed in parts.
function GridMap3DStateGenerate:doOctree()

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

--- doExternNeighbours is called after one whole layer has been done and does it for each 8 children of a node.
-- Forwards call to the owner to find the neighbours.
--@return true if all the nodes for current layer has had their neighbours found.
function GridMap3DStateGenerate:doExternNeighbours()

    if self.owner == nil then
        return false
    end

    -- As octree has always 8 children, means they are next to each other for 8 indices.
    for i = 1, 8 do
        self.owner:findNeighbours(self.currentLayerNodes[self.currentNodeIndex + (i - 1)],i)
    end


    self.currentNodeIndex = self.currentNodeIndex + 8
    if self.currentLayerNodes[self.currentNodeIndex] == nil then
        self.currentNodeIndex = 1
        return true
    end

    return false
end

--- increaseLayer is called after every node has been looped through and had it's children created if solid.
--@return true if no more nodes found in the nextLayerNodes, which means the octree has been completed.
function GridMap3DStateGenerate:increaseLayer()
    self.currentLayerNodes = self.nextLayerNodes
    self.currentNodeIndex = 1
    self.nextLayerNodes = nil
    self.nextLayerNodes = {}
    if next(self.currentLayerNodes) == nil then
        return true
    end

    return false
end



--- createChildren gets called for every node which is still not enough resolution to be a leaf node.
-- It creates eight children only if there is a collision found.
-- The newly created children will also have their neighbours linked after being created.
--@param parent node which owns these possible child nodes.
--@param parentVoxelSize the full extent of the parent node voxel.
function GridMap3DStateGenerate:createChildren(parent)

    if self.owner == nil or parent == nil then
        return
    end

    -- Need to check for a collision if no collision then current node is childless node but not a leaf
    self.owner:voxelOverlapCheck(parent.positionX,parent.positionY,parent.positionZ,parent.size / 2)
    if self.owner.bUnderTerrain == true then
        parent.leafVoxelsTop = -1
        return
    elseif self.owner.bTraceVoxelSolid == false and self.owner.bCenterUnderTerrain == false then
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
                local newNode = GridMap3DNode.new(self.startLocationX + (x * (parent.size / 2)) ,self.startLocationY + (y * (parent.size / 2)), self.startLocationZ + (z * (parent.size / 2)),parent,parent.size / 2)
                table.insert(self.nextLayerNodes,newNode)
                table.insert(parent.children,newNode)
            end
        end
    end


end


---@class GridMap3DStateUpdate.
-- Used to update existing octree after some static object has been deleted or constructed.
GridMap3DStateUpdate = {}
GridMap3DStateUpdate_mt = Class(GridMap3DStateUpdate,GridMap3DStateBase)
InitObjectClass(GridMap3DStateUpdate, "GridMap3DStateUpdate")

--- new creates a new update state.
--@param customMt special metatable else uses default.
function GridMap3DStateUpdate.new(customMt)
    local self = GridMap3DStateUpdate:superClass().new(customMt or GridMap3DStateUpdate_mt)
    self.gridUpdate = nil
    self.nodesToCheck = {}
    self.nodesToDelete = {}
    self.currentLayerNodes = {}
    self.currentNodeIndex = 1
    self.nextLayerNodes = {}
    self.bFindNeighbours = false
    self.bDeletedNodes = false
    self.temp = {}
    return self
end

--- enter deques a grid update from the queue from parent.
function GridMap3DStateUpdate:enter()
    GridMap3DStateUpdate:superClass().enter(self)

    if self.owner == nil then
        Logging.warning("self.owner was nil in GridMap3DStateUpdate:enter()")
        self.owner:changeState(self.owner.EGridMap3DStates.IDLE)
        return
    end

    self:receiveWork()

end

--- leave has no stuff to do in this state.
function GridMap3DStateUpdate:leave()
    GridMap3DStateUpdate:superClass().leave(self)
    self.gridUpdate = nil
    self.nodesToCheck = nil
    self.nodesToCheck = {}
    self.currentLayerNodes = nil
    self.currentLayerNodes = {}
    self.nextLayerNodes = nil
    self.nextLayerNodes = {}
    self.currentNodeIndex = 1
    self.bDeletedNodes = false
    self.bFindNeighbours = false
end

--- update works to update the area that has been modified.
--@param dt deltaTime forwarded from the owner update function.
function GridMap3DStateUpdate:update(dt)
    GridMap3DStateUpdate:superClass().update(self,dt)
    if self.owner == nil then
        return
    end


    for i = 0, self.owner.maxOctreePreLoops do
        if not self.bFindNeighbours and self:updateGrid() == true then

            if next(self.nodesToCheck) ~= nil then
                table.insert(self.currentLayerNodes,self.nodesToCheck[1])
                table.remove(self.nodesToCheck,1)
                return
            else
                Logging.info("Updated GridMap3D")
                g_messageCenter:publish(MessageType.GRIDMAP3D_GRID_UPDATED,self.gridUpdate.id)
                self:receiveWork()
                return
            end
        elseif self.bFindNeighbours then
            self:doExternNeighbours()
        end
    end
end


--- destroy no cleanup needed in this state.
function GridMap3DStateUpdate:destroy()
    GridMap3DStateUpdate:superClass().destroy(self)
    --
end

--- receiveWork is called when changed into this state, and it will dequeue an update from owner to be processed.
function GridMap3DStateUpdate:receiveWork()
    if self.owner == nil then
        return
    end

    -- if no update ready returns
    if next(self.owner.gridUpdateReadyQueue) == nil then
        self.owner:changeState(self.owner.EGridMap3DStates.IDLE)
        return
    end

    local nextTableValue = {next(self.owner.gridUpdateReadyQueue)}

    self.gridUpdate = nextTableValue[2]
    self.owner.gridUpdateReadyQueue[nextTableValue[1]] = nil

    -- Get the octree nodes which include the area that has been modified.
    self:getNodeToRedo()

    if next(self.nodesToCheck) == nil then
        self.owner:changeState(self.owner.EGridMap3DStates.IDLE)
        return
    end

    table.insert(self.currentLayerNodes,self.nodesToCheck[1])
    table.remove(self.nodesToCheck,1)

end

--- getNodeToRedo prepares gets the maxExtent of the aabb of the update, and proceeds to run a recursive function to find the nodes within.
function GridMap3DStateUpdate:getNodeToRedo()
    if self.owner == nil or self.gridUpdate == nil or self.owner.nodeTree == nil then
        return
    end

    local maxExtent = math.max(math.abs(self.gridUpdate.aabb[1] - self.gridUpdate.aabb[4]), math.abs(self.gridUpdate.aabb[3] - self.gridUpdate.aabb[6]))

    self:findEncomppasingNode(self.owner.nodeTree,maxExtent)

end

--- findEncomppasingNode is a recursive function which runs to add the octree nodes which are inside the aabb of the update,
-- into the nodesToCheck table.
--@param node current that is being checked.
--@param maxExtent is the longest axis of the aabb.
function GridMap3DStateUpdate:findEncomppasingNode(node,maxExtent)

    local aabbNode = {node.positionX - (node.size / 2), node.positionY - (node.size / 2), node.positionZ - (node.size / 2),node.positionX + (node.size / 2), node.positionY + (node.size / 2), node.positionZ + (node.size / 2) }

    if GridMap3DNode.checkAABBIntersection(aabbNode,self.gridUpdate.aabb) ~= true then
        return
    end


    if node.size < maxExtent then
        table.insert(self.nodesToCheck,node)
        return
    elseif node.children == nil then
        table.insert(self.nodesToCheck,node)
        return
    end

    for _,child in pairs(node.children) do
        self:findEncomppasingNode(child,maxExtent)
    end


end

--- updateGrid is the actual function updating the octree, works a bit similarily as the generation state.
function GridMap3DStateUpdate:updateGrid()

    if self.owner == nil then
        return
    end


    -- getting the currentNode, which will have either leafvoxels or children created for (if solid).
    local currentNode = self.currentLayerNodes[self.currentNodeIndex]

    if currentNode.size == self.owner.leafNodeResolution then
        self.owner:createLeafVoxels(currentNode,currentNode.size)
        self.bDeletedNodes = true
    else
        self:reCheckChildren(currentNode)
    end

    if self.bDeletedNodes and self.gridUpdate.bDeletion then
        self.bDeletedNodes = false
        self:checkForNonSolids(currentNode.parent)
    end


    self.currentNodeIndex = self.currentNodeIndex + 1
    if self.currentLayerNodes[self.currentNodeIndex] == nil then
        self.currentLayerNodes = self.nextLayerNodes
        self.currentNodeIndex = 1
        self.nextLayerNodes = nil
        self.nextLayerNodes = {}
        if next(self.currentLayerNodes) == nil then
            return true
        end

          self.bFindNeighbours = true
    end

    return false
end

--- checkForNonSolids is called if some nodes has been deleted, it will go recursively check parents if all the children are non-solid,
-- in such cases it can then remove all the 8 children from the node.
--@param parent is the parent which children are being checked if all are non solid then can clear the children of this parent.
function GridMap3DStateUpdate:checkForNonSolids(parent)

    if parent == nil or parent.children == nil then
        return
    end

    local emptyAmount = {}

    for i = 1, 8 do
        if GridMap3DNode.isNodeSolid({parent.children[i],-1}) == true then
            return
        end
        table.insert(emptyAmount,true)
    end

    if #emptyAmount == 8 then
        for i = 1, 8 do
            self:removeNeighbours(parent.children[i],parent)
        end
        parent.children = nil
        self:checkForNonSolids(parent.parent)
    end

end

--- reCheckChildren is the main check run when updating the octree.-
-- It checks if there is any change for the non-leaf node.
-- And then either adds new or removes if there is a change.
--@param parent is the node which is being checked for any changes.
function GridMap3DStateUpdate:reCheckChildren(parent)

    if self.owner == nil or parent == nil then
        return
    end

    self.owner:voxelOverlapCheck(parent.positionX,parent.positionY,parent.positionZ,parent.size / 2)
    if self.owner.bUnderTerrain == true then
        parent.leafVoxelsTop = -1
        return
    end


    if self.owner.bTraceVoxelSolid and parent.children == nil then
        -- divided by 4 to get the new child voxels radius to offset inside the parent node
        self.startLocationX = parent.positionX - (parent.size / 4)
        self.startLocationY = parent.positionY - (parent.size / 4)
        self.startLocationZ = parent.positionZ - (parent.size / 4)
        parent.children = {}
        for y = 0, 1 do
            for z = 0 , 1 do
                for x = 0, 1 do
                    local newNode = GridMap3DNode.new(self.startLocationX + (x * (parent.size / 2)) ,self.startLocationY + (y * (parent.size / 2)), self.startLocationZ + (z * (parent.size / 2)),parent,parent.size / 2)
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
        self.bDeletedNodes = true
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

--- doExternNeighbours is called when one layer has been checked and will create/recheck the proper neighbours for each node.
function GridMap3DStateUpdate:doExternNeighbours()

    if self.owner == nil then
        return
    end

    for i = 1, 8 do
        self.owner:findNeighbours(self.currentLayerNodes[self.currentNodeIndex + (i - 1)],i)
    end


    self.currentNodeIndex = self.currentNodeIndex + 8
    if self.currentLayerNodes[self.currentNodeIndex] == nil then
        self.currentNodeIndex = 1
        self.bFindNeighbours = false
    end

end

--- removeNeighbours is a recursive function which will remove properly the neighbours from the nodes which will be deleted.
--@param node is the current node which will have it's neighbours removed.
--@param parent is the most outer node which has been changed and will be used as the neighbours for all the children's neighbours that depended on the children.
function GridMap3DStateUpdate:removeNeighbours(node,parent)

    if node.children == nil then
        self:deleteAllNeighbours(node)
        return
    end

    for i = 1, 8 do
        self:removeNeighbours(node.children[i],parent)
    end

    self:deleteAllNeighbours(node,parent)

end

--- deleteAllNeighbours clears the neighbours from this node, and set instead as the parent node which still exists.
--@param node is the node which is being deleted.
--@param newParentNeighbour is the outer parent which is not being deleted, so it can be set as the new neighbour, as each node needs a neighbour, if not outside the map.
function GridMap3DStateUpdate:deleteAllNeighbours(node,newParentNeighbour)

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


---@class GridMap3DStateDebug.
-- Handles visualizing the octree, can't enter this state if it is currently generating the octree or updating.
-- Can activate by the console command GridMap3DOctreeDebug.
GridMap3DStateDebug = {}
GridMap3DStateDebug_mt = Class(GridMap3DStateDebug,GridMap3DStateBase)
InitObjectClass(GridMap3DStateDebug, "GridMap3DStateDebug")

--- increaseDebugLayer is a console command that increases the octree layer to be visualized.
function GridMap3DStateDebug:increaseDebugLayer()

    self.currentDebugLayer = self.currentDebugLayer + 1
    self.nodeRefreshNeeded = true
    -- max debug layer will be limited to octree's layers, but adding one more so that the leaf node's 64 voxels can also be shown at layer + 1
    self.currentDebugLayer = MathUtil.clamp(self.currentDebugLayer,1,self.maxDebugLayer + 1)

end

--- decreaseDebugLayer is a console command that decreases the octree layer to be visualized.
function GridMap3DStateDebug:decreaseDebugLayer()

    self.currentDebugLayer = self.currentDebugLayer - 1
    self.nodeRefreshNeeded = true
    self.currentDebugLayer = MathUtil.clamp(self.currentDebugLayer,1,self.maxDebugLayer)

end

--- new creates a new debug state
--@param customMt special metatable else uses default.
function GridMap3DStateDebug.new(customMt)
    local self = GridMap3DStateDebug:superClass().new(customMt or GridMap3DStateDebug_mt)
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
function GridMap3DStateDebug:enter()
    GridMap3DStateDebug:superClass().enter(self)

    if self == nil or self.owner == nil then
        return
    end

    self.maxDebugLayer = self.owner:getNodeTreeLayer(self.owner.leafNodeResolution)
    if g_inputBinding ~= nil and InputAction.FLYPATHFINDING_DBG_PREVIOUS ~= nil then
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.FLYPATHFINDING_DBG_PREVIOUS, self, self.decreaseDebugLayer, true, false, false, true, true, true)
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.FLYPATHFINDING_DBG_NEXT, self, self.increaseDebugLayer, true, false, false, true, true, true)
    end

end

--- leave removes the console command action bindings.
function GridMap3DStateDebug:leave()
    GridMap3DStateDebug:superClass().leave(self)

    if g_inputBinding ~= nil then
        g_inputBinding:removeActionEventsByTarget(self)
    end
    self.nodeRefreshNeeded = true
    self.debugGrid = nil
    self.debugGrid = {}

end

--- update calls the functions that handles visualizing the octree and info about current node.
--@param dt deltaTime forwarded from the owner update function.
function GridMap3DStateDebug:update(dt)
    GridMap3DStateDebug:superClass().update(self,dt)

    if self.owner == nil or self.owner.nodeTree == nil then
        return
    end



    self:updatePlayerDistance()

    self:renderOctreeDebugView()

    self:printCurrentNodeInfo(self.owner.nodeTree)


end

--- renderOctreeDebugView calls to gather the relevant nodes if refresh needed and then renders a debug cube for each node.
function GridMap3DStateDebug:renderOctreeDebugView()
    if self.owner == nil then
        return
    end

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

            if GridMap3DNode.isLeaf(node) and GridMap3DNode.isNodeSolid({node,-1}) then

                for i = 0, 63 do
                    if GridMap3DNode.isNodeSolid({node,i}) then
                        local leafPosition = self.owner:getNodeLocation({node,i})
                        DebugUtil.drawSimpleDebugCube(leafPosition.x, leafPosition.y, leafPosition.z, self.owner.maxVoxelResolution, 1, 0, 0)
                    end
                end
            end

        end
    else
        for _,node in pairs(self.debugGrid) do
            if GridMap3DNode.isNodeSolid({node,-1}) then
                DebugUtil.drawSimpleDebugCube(node.positionX, node.positionY, node.positionZ, node.size, 1, 0, 0)
            end
        end
    end

end

--- getLimitRenderDistance is a tiny helper function to get if the distance of visible nodes should be limited for performance reasons.
--@return true if should limit the distance of visible debug nodes.
function GridMap3DStateDebug:getLimitRenderDistance()

    -- if the current debug layer is more than 0.7 (70%) of existing layers, then showing quite high resolution so can limit the render distance.
    if (self.currentDebugLayer / (self.maxDebugLayer + 1))  > 0.7 then
        return true
    end

    return false
end

--- printCurrentNodeInfo finds the node which player is currently in up to the currently selected layer.
-- and prints some basic information about the node.
--@param node takes in first the root node of the octree and is a recursive function so goes deeper into the octree.
function GridMap3DStateDebug:printCurrentNodeInfo(node)

    if self.owner == nil or node == nil then
        return
    end

    local playerPosition = {}
    playerPosition.x,playerPosition.y,playerPosition.z = getWorldTranslation(g_currentMission.player.rootNode)

    local aabbNode = {node.positionX - (node.size / 2), node.positionY - (node.size / 2), node.positionZ - (node.size / 2),node.positionX + (node.size / 2), node.positionY + (node.size / 2), node.positionZ + (node.size / 2) }

    if GridMap3DNode.checkPointInAABB(playerPosition,aabbNode) == true then

        -- need to cap it, as it could be one above the array index to indicate the leaf nodes voxel layers.
        local currentLayer = MathUtil.clamp(self.currentDebugLayer,1,self.maxDebugLayer)

        -- -1 as currentLayer 1 is the root of octree
        local currentDivision = math.pow(2,currentLayer - 1)
        local targetVoxelSize = self.owner.terrainSize / currentDivision

        -- if current node is the size that currentlayer indicates then we have found the node player resides in
        if node.size == targetVoxelSize then
            if node.positionX ~= self.lastNode.x or node.positionY ~= self.lastNode.y or node.positionZ ~= self.lastNode.z then
                self.lastNode.x, self.lastNode.y , self.lastNode.z = node.positionX, node.positionY, node.positionZ
                DebugUtil.printTableRecursively(node," ",0,0)
            end
            if node.xNeighbour ~= nil then
                renderText3D(node.xNeighbour.positionX,node.xNeighbour.positionY,node.xNeighbour.positionZ,0,0,0,2,"xNeighbour")
            end
            if node.yNeighbour ~= nil then
                renderText3D(node.yNeighbour.positionX,node.yNeighbour.positionY,node.yNeighbour.positionZ,0,0,0,2,"yNeighbour")
            end
            if node.zNeighbour ~= nil then
                renderText3D(node.zNeighbour.positionX,node.zNeighbour.positionY,node.zNeighbour.positionZ,0,0,0,2,"zNeighbour")
            end
            if node.xMinusNeighbour ~= nil then
                renderText3D(node.xMinusNeighbour.positionX,node.xMinusNeighbour.positionY,node.xMinusNeighbour.positionZ,0,0,0,2,"xMinusNeighbour")
            end
            if node.yMinusNeighbour ~= nil then
                renderText3D(node.yMinusNeighbour.positionX,node.yMinusNeighbour.positionY,node.yMinusNeighbour.positionZ,0,0,0,2,"yMinusNeighbour")
            end
            if node.zMinusNeighbour ~= nil then
                renderText3D(node.zMinusNeighbour.positionX,node.zMinusNeighbour.positionY,node.zMinusNeighbour.positionZ,0,0,0,2,"zMinusNeighbour")
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
function GridMap3DStateDebug:updatePlayerDistance()

    local playerX,playerY,playerZ = getWorldTranslation(g_currentMission.player.rootNode)
    local distance = MathUtil.vector3Length(self.playerLastLocation.x - playerX,self.playerLastLocation.y - playerY,self.playerLastLocation.z - playerZ)
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
function GridMap3DStateDebug:findCloseEnoughVoxels(node)

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

    if GridMap3DNode.checkAABBIntersection(aabbNode,aabbPlayer) == true and node.children ~= nil then
        for _, childNode in pairs(node.children) do
            self:findCloseEnoughVoxels(childNode)
        end
    end

end


--- appendDebugGrid helper function appends a given nodes table into the debugGrid.
function GridMap3DStateDebug:appendDebugGrid(nodes)

    for _,node in pairs(nodes) do
        table.insert(self.debugGrid,node)
    end

end

--- destroy not used by this state.
function GridMap3DStateDebug:destroy()
    GridMap3DStateDebug:superClass().destroy(self)
    --
end



