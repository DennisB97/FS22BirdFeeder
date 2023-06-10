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

-- All the directions that pathfinding can take within the octree grid.
local ENavDirection = {NORTH = 1, EAST = 2, SOUTH = 3, WEST = 4, UP = 5, DOWN = 6}

-- Lookuptable for getting opposite direction from given key direction.
local mirroredDirectionTable = {
    [ENavDirection.NORTH] = ENavDirection.SOUTH,
    [ENavDirection.EAST] = ENavDirection.WEST,
    [ENavDirection.SOUTH] = ENavDirection.NORTH,
    [ENavDirection.WEST] = ENavDirection.EAST,
    [ENavDirection.UP] = ENavDirection.DOWN,
    [ENavDirection.DOWN] = ENavDirection.UP,
}

-- Lookuptable for getting next node, which is not within leaf node's tiniest voxels.
-- node provided as table of {GridMap3DNode,leafVoxelIndex(-1 - 63)}.
local nodeAdvancementTable = {
    [ENavDirection.NORTH] = function(node)
        if node == nil or node[1] == nil then
            return {nil,-1}
        end
        return {node[1].xNeighbour,-1}
    end,
    [ENavDirection.EAST] = function(node)
        if node == nil or node[1] == nil then
            return {nil,-1}
        end
        return {node[1].zNeighbour,-1}
    end,
    [ENavDirection.SOUTH] = function(node)
        if node == nil or node[1] == nil then
            return {nil,-1}
        end
        return {node[1].xMinusNeighbour,-1}
    end,
    [ENavDirection.WEST] = function(node)
        if node == nil or node[1] == nil then
            return {nil,-1}
        end
        return {node[1].zMinusNeighbour,-1}
    end,
    [ENavDirection.UP] = function(node)
        if node == nil or node[1] == nil then
            return {nil,-1}
        end
        return {node[1].yNeighbour,-1}
    end,
    [ENavDirection.DOWN] = function(node)
        if node == nil or node[1] == nil then
            return {nil,-1}
        end
        return {node[1].yMinusNeighbour,-1}
    end,
}

-- Lookuptable for getting all 4 nodes on edge from given key direction side.
-- node provided as table of {GridMap3DNode,leafVoxelIndex(-1 - 63)}.
local gridNodeChildrenWallPerDirection = {
    [ENavDirection.NORTH] = function(node)
        if node == nil or node[1] == nil or node[1].children == nil then
            return {}
        end
        return {{node[1].children[2],-1},{node[1].children[4],-1},{node[1].children[6],-1},{node[1].children[8],-1}}
    end,
    [ENavDirection.EAST] = function(node)
        if node == nil or node[1] == nil or node[1].children == nil then
            return {}
        end
        return {{node[1].children[3],-1},{node[1].children[4],-1},{node[1].children[7],-1},{node[1].children[8],-1}}
    end,
    [ENavDirection.SOUTH] = function(node)
        if node == nil or node[1] == nil or node[1].children == nil then
            return {}
        end
        return {{node[1].children[1],-1},{node[1].children[3],-1},{node[1].children[7],-1},{node[1].children[5],-1}}
    end,
    [ENavDirection.WEST] = function(node)
        if node == nil or node[1] == nil or node[1].children == nil then
            return {}
        end
        return {{node[1].children[1],-1},{node[1].children[2],-1},{node[1].children[5],-1},{node[1].children[6],-1}}
    end,
    [ENavDirection.UP] = function(node)
        if node == nil or node[1] == nil or node[1].children == nil then
            return {}
        end
        return {{node[1].children[5],-1},{node[1].children[6],-1},{node[1].children[7],-1},{node[1].children[8],-1}}
    end,
    [ENavDirection.DOWN] = function(node)
        if node == nil or node[1] == nil or node[1].children == nil then
            return {}
        end
        return {{node[1].children[1],-1},{node[1].children[2],-1},{node[1].children[3],-1},{node[1].children[4],-1}}
    end,
}

-- Lookuptable for getting the outer neighbour leaf voxel.
-- node provided as table of {GridMap3DNode,leafVoxelIndex(-1 - 63)}.
local gridLeafNodeChildPerDirection = {
        [ENavDirection.NORTH] = function(node,direction)
            if node == nil or node[1] == nil or node[2] == -1 then
                return {nil, -1}
            end

            -- if neighbour is same size as leaf node and not completely non-solid then can get the neighbouring leaf voxel
            if node[1].xNeighbour ~= nil and node[1].xNeighbour.size == node[1].size and GridMap3DNode.isNodeSolid({node[1].xNeighbour,-1}) then
                    return {node[1].xNeighbour,node[2] - 3}
            -- else just takes the leaf node itself as possible open node
            elseif node[1].xNeighbour ~= nil then
                    return {node[1].xNeighbour,-1}
            end

            return {nil,-1}
            end,
        [ENavDirection.EAST] = function(node,direction)
            if node == nil or node[1] == nil or node[2] == -1 then
                return {nil, -1}
            end

            if node[1].zNeighbour ~= nil and node[1].zNeighbour.size == node[1].size and GridMap3DNode.isNodeSolid({node[1].zNeighbour,-1}) then
                    return {node[1].zNeighbour,node[2] - 12}
            elseif node[1].zNeighbour ~= nil then
                    return {node[1].zNeighbour,-1}
            end

            return {nil,-1}
            end,
        [ENavDirection.SOUTH] = function(node,direction)
            if node == nil or node[1] == nil or node[2] == -1 then
                return {nil, -1}
            end

            if node[1].xMinusNeighbour ~= nil and node[1].xMinusNeighbour.size == node[1].size and GridMap3DNode.isNodeSolid({node[1].xMinusNeighbour,-1}) then
                    return {node[1].xMinusNeighbour,node[2] + 3}
            elseif node[1].xMinusNeighbour ~= nil then
                    return {node[1].xMinusNeighbour,-1}
            end

            return {nil,-1}
            end,
        [ENavDirection.WEST] = function(node,direction)
            if node == nil or node[1] == nil or node[2] == -1 then
                return {nil, -1}
            end

            if node[1].zMinusNeighbour ~= nil and node[1].zMinusNeighbour.size == node[1].size and GridMap3DNode.isNodeSolid({node[1].zMinusNeighbour,-1}) then
                    return {node[1].zMinusNeighbour,node[2] + 12}
            elseif node[1].zMinusNeighbour ~= nil then
                    return {node[1].zMinusNeighbour,-1}
            end

            return {nil,-1}
            end,
        [ENavDirection.UP] = function(node,direction)
            if node == nil or node[1] == nil or node[2] == -1 then
                return {nil, -1}
            end

            if node[1].yNeighbour ~= nil and node[1].yNeighbour.size == node[1].size and GridMap3DNode.isNodeSolid({node[1].yNeighbour,-1}) then
                    return {node[1].yNeighbour,node[2] + 16 - 64}
            elseif node[1].yNeighbour ~= nil then
                    return {node[1].yNeighbour,-1}
            end

            return {nil,-1}
            end,
        [ENavDirection.DOWN] = function(node,direction)
            if node == nil or node[1] == nil or node[2] == -1 then
                return {nil, -1}
            end

            if node[1].yMinusNeighbour ~= nil and node[1].yMinusNeighbour.size == node[1].size and GridMap3DNode.isNodeSolid({node[1].yMinusNeighbour,-1}) then
                    return {node[1].yMinusNeighbour,node[2] + 64 - 16}
            elseif node[1].yMinusNeighbour ~= nil then
                    return {node[1].yMinusNeighbour,-1}
            end

            return {nil,-1}
            end,
}
-- Lookuptable for getting all the leaf node's voxels on the edge for given key direction.
local gridLeafNodeChildrenWallPerDirection = {
        [ENavDirection.NORTH] = function()
            return {[3] = 3,[7] = 7,[11] = 11,[15] = 15,[19] = 19,[23] = 23,[27] = 27,[31] = 31,[35] = 35,[39] = 39,[43] = 43,[47] = 47,[51] = 51,[55] = 55,[59] = 59,[63] = 63}
            end,
        [ENavDirection.EAST] = function()
            return {[12] = 12,[13] = 13,[14] = 14,[15] = 15,[28] = 28,[29] = 29,[30] = 30,[31] = 31,[44] = 44,[45] = 45,[46] = 46,[47] = 47,[60] = 60,[61] = 61,[62] = 62,[63] = 63}
            end,
        [ENavDirection.SOUTH] = function()
            return {[0] = 0,[4] = 4,[8] = 8,[12] = 12,[16] = 16,[20] = 20,[24] = 24,[28] = 28,[32] = 32,[36] = 36,[40] = 40,[44] = 44,[48] = 48,[52] = 52,[56] = 56,[60] = 60}
            end,
        [ENavDirection.WEST] = function()
            return {[0] = 0,[1] = 1,[2] = 2,[3] = 3,[16] = 16,[17] = 17,[18] = 18,[19] = 19,[32] = 32,[33] = 33,[34] = 34,[35] = 35,[48] = 48,[49] = 49,[50] = 50,[51] = 51}
            end,
        [ENavDirection.UP] = function()
            return {[48] = 48,[49] = 49,[50] = 50,[51] = 51,[52] = 52,[53] = 53,[54] = 54,[55] = 55,[56] = 56,[57] = 57,[58] = 58,[59] = 59,[60] = 60,[61] = 61,[62] = 62,[63] = 63}
            end,
        [ENavDirection.DOWN] = function()
            return {[0] = 0,[1] = 1,[2] = 2,[3] = 3,[4] = 4,[5] = 5,[6] = 6,[7] = 7,[8] = 8,[9] = 9,[10] = 10,[11] = 11,[12] = 12,[13] = 13,[14] = 14,[15] = 15}
            end,
}
-- Lookuptable for returning the advancing to next voxel index or leaf node with given key direction.
-- node provided as table of {GridMap3DNode,leafVoxelIndex(-1 - 63)}.
local leafNodeAdvancementTable = {
        [ENavDirection.NORTH] = function(node,direction)
            if node == nil or node[1] == nil or node[2] < 0 then
                return {nil,-1}
            end

            -- if current leaf voxel index indicates being on the edge, then new node is in outer neighbour
            local wallLeafNodes = gridLeafNodeChildrenWallPerDirection[direction]()
            if wallLeafNodes[node[2]] ~= nil then
                return gridLeafNodeChildPerDirection[direction](node)
            end
            -- if not on edge then the next leaf voxel is within this same node, increments the index only.
            return {node[1],node[2] + 1}
            end,
        [ENavDirection.EAST] = function(node,direction)
            if node == nil or node[1] == nil or node[2] < 0 then
                return {nil,-1}
            end

            local wallLeafNodes = gridLeafNodeChildrenWallPerDirection[direction]()
            if wallLeafNodes[node[2]] ~= nil then
                return gridLeafNodeChildPerDirection[direction](node)
            end

            return {node[1],node[2] + 4}
            end,
        [ENavDirection.SOUTH] = function(node,direction)
            if node == nil or node[1] == nil or node[2] < 0 then
                return {nil,-1}
            end

            local wallLeafNodes = gridLeafNodeChildrenWallPerDirection[direction]()
            if wallLeafNodes[node[2]] ~= nil then
                return gridLeafNodeChildPerDirection[direction](node)
            end

            return {node[1],node[2] - 1}
            end,
        [ENavDirection.WEST] = function(node,direction)
            if node == nil or node[1] == nil or node[2] < 0 then
                return {nil,-1}
            end

            local wallLeafNodes = gridLeafNodeChildrenWallPerDirection[direction]()
            if wallLeafNodes[node[2]] ~= nil then
                return gridLeafNodeChildPerDirection[direction](node)
            end

            return {node[1],node[2] - 4}
            end,
        [ENavDirection.UP] = function(node,direction)
            if node == nil or node[1] == nil or node[2] < 0 then
                return {nil,-1}
            end

            local wallLeafNodes = gridLeafNodeChildrenWallPerDirection[direction]()
            if wallLeafNodes[node[2]] ~= nil then
                return gridLeafNodeChildPerDirection[direction](node)
            end

            return {node[1],node[2] + 16}
            end,
        [ENavDirection.DOWN] = function(node,direction)
            if node == nil or node[1] == nil or node[2] < 0 then
                return {nil,-1}
            end

            local wallLeafNodes = gridLeafNodeChildrenWallPerDirection[direction]()
            if wallLeafNodes[node[2]] ~= nil then
                return gridLeafNodeChildPerDirection[direction](node)
            end

            return {node[1],node[2] - 16}
            end,
}


---@class AStarOpenQueue
--Min max heap for the open nodes queue.
AStarOpenQueue = {}
AStarOpenQueue_mt = Class(AStarOpenQueue)
InitObjectClass(AStarOpenQueue, "AStarOpenQueue")

--- new creates a new openqueue.
function AStarOpenQueue.new()
    local self = setmetatable({},AStarOpenQueue_mt)
    self.openNodes = {}
    -- the hash table works as double table, first key will be the gridNode
    -- eg. self.hash[someGridNode]
    -- the value will be another table where the leaf voxel index is the key.
    -- eg. self.hash[someGridNode][leafvoxelIndex] -- and then finally value is index into the self.openNodes.
    self.hash = {}
    self.size = 0
    return self
end

--- getSize returns the size of the openqueue.
function AStarOpenQueue:getSize()
    return self.size
end
--- getParent returns parent index.
--@param i is the index from parent wanted.
function AStarOpenQueue:getParent(i)
    return math.floor(i / 2)
end
--- getLeftChild returns left child.
--@param i is the parent index from where left child index will be taken.
function AStarOpenQueue:getLeftChild(i)
    return 2*i
end
--- getRightChild returns right child.
--@param i is the parent index from where right child index will be taken.
function AStarOpenQueue:getRightChild(i)
    return 2*i + 1
end
--- empty cleans the openqueue for next path.
function AStarOpenQueue:empty()
    self.openNodes = {}
    self.hash = {}
    self.size = 0
end
--- insert used for adding a new node into the open queue.
-- checks if it already contains the same node and updates it if g value is lower on new node.
--@param node is the node to be added into the openqueue of type AStarNode
function AStarOpenQueue:insert(node)
    if node == nil or node.gridNode[1] == nil then
        return
    end

    if self:contains(node) then
        self:update(node)
        return
    end

    table.insert(self.openNodes,node)
    self.size = self.size + 1
    local index = self.size
    -- need to make sure there is a second table within the self.hash if this gridNode has never been added before it would be nil.
    if self.hash[node.gridNode[1]] == nil then
        self.hash[node.gridNode[1]] = {}
    end
    self.hash[node.gridNode[1]][node.gridNode[2]] = index

    local parentIndex = self:getParent(index)

    -- swap until it is in the right place
    while index > 1 and self.openNodes[parentIndex].f > self.openNodes[index].f do
        self:swap(index,parentIndex)
        index = parentIndex
        parentIndex = self:getParent(index)
    end

end

--- pop called to remove the root node which has the lowest f.
--@return AStarNode which had the lowest f value in the openqueue, nil if empty.
function AStarOpenQueue:pop()
    if self.size < 1 then
        return nil
    end

    if self.size == 1 then
        local node = table.remove(self.openNodes)
        self.size = 0
        self.hash[node.gridNode[1]][node.gridNode[2]] = nil
        return node
    end

    local node = self.openNodes[1]
    self:swap(1,self.size)
    table.remove(self.openNodes)
    self.size = self.size - 1
    self.hash[node.gridNode[1]][node.gridNode[2]] = nil
    self:heapify(1)
    return node
end

--- contains checks if a given node is already in the queue.
--@param node is the node that will be checked if already exists in the queue, of type AStarNode.
--@return true if the node exists in the queue.
function AStarOpenQueue:contains(node)

    if node ~= nil and node.gridNode[1] ~= nil then
        if self.hash[node.gridNode[1]] ~= nil then
            if self.hash[node.gridNode[1]][node.gridNode[2]] ~= nil then
                return true
            end
        end
    end

    return false
end

--- swap will swap two given indices within the self.openNodes, and then also correct the hash table.
--@param i index of one of the nodes that will be swapped.
--@param j index of the other of the nodes that will be swapped.
function AStarOpenQueue:swap(i,j)

    local temp = self.openNodes[j]
    self.openNodes[j] = self.openNodes[i]
    self.openNodes[i] = temp
    self.hash[self.openNodes[i].gridNode[1]][self.openNodes[i].gridNode[2]] = i
    self.hash[self.openNodes[j].gridNode[1]][self.openNodes[j].gridNode[2]] = j

end

--- update will try to update existing value in the queue if the new node's g value is lower than previously.
--@param node that will be updated, type AStarNode.
function AStarOpenQueue:update(node)

    if node ~= nil and node.gridNode[1] ~= nil and self.hash[node.gridNode[1]] ~= nil and self.hash[node.gridNode[1]][node.gridNode[2]] ~= nil then

        local index = self.hash[node.gridNode[1]][node.gridNode[2]]
        if self.openNodes[index].g > node.g then
            -- g was lower in new node then updates the values on the queue node and replaces parent.
            self.openNodes[index].g = node.g
            self.openNodes[index].f = node.g + node.h
            self.openNodes[index].parent = node.parent

            local parentIndex = self:getParent(index)
            -- Try to swap new updated node into place if f is lower than some older.
            while index > 1 and self.openNodes[parentIndex].f > self.openNodes[index].f do
                self:swap(index,parentIndex)
                index = parentIndex
                parentIndex = self:getParent(index)
            end

        end
    end
end

--- heapify adjust the heap to be correct.
--@param index starting parent index from where to children will be checked and adjusted.
function AStarOpenQueue:heapify(index)

    if self.size <= 1 then
        return
    end

    local leftIndex = self:getLeftChild(index)
    local rightIndex = self:getRightChild(index)
    local smallestIndex = index

    if leftIndex <= self.size and self.openNodes[leftIndex].f < self.openNodes[index].f then
        smallestIndex = leftIndex
    end

    if rightIndex <= self.size and self.openNodes[rightIndex].f < self.openNodes[smallestIndex].f then
        smallestIndex = rightIndex
    end

    if smallestIndex ~= index then
        self:swap(index,smallestIndex)
        self:heapify(smallestIndex)
    end

end


---@class AStarNode is used for the pathfinding when opening new nodes.
AStarNode = {}

--- new creates a new AStarNode.
--@param gridNode is the octree node and leaf node index, like {node,index(-1 - 63)}.
--@param g currently traveled distance from start to this node.
--@param h is the heuristic from this node to goal node.
--@param direction is the direction taken from previous node to this node.
--@return the newly created AStarNode.
function AStarNode.new(gridNode,g,h,parent, direction)
    local self = setmetatable({},nil)
    self.gridNode = gridNode
    self.g = g
    self.h = h
    self.f = g + h
    self.parent = parent
    self.direction = direction
    return self
end

---@class AStar.
--Custom object class for the A* pathfinding algorithm.
AStar = {}
AStar.debugObject = nil
AStar_mt = Class(AStar,Object)
InitObjectClass(AStar, "AStar")

function AStar.aStarDebugToggle()
    if g_currentMission.gridMap3D == nil or g_currentMission.gridMap3D.bOctreeDebug or CatmullRomSpline.debugObject then
        Logging.info("Can't turn on AStar flypathfinding debug at same time as Octree debug mode or catmullrom!")
        return
    end

    if AStar.debugObject == nil then
        AStar.debugObject = AStarDebug.new()
        AStar.debugObject:register(true)
    else
        AStar.debugObject:delete()
        AStar.debugObject = nil
    end

end


--- new creates a new A* pathfinding algorithm object.
function AStar.new(isServer,isClient)
    local self = Object.new(isServer,isClient, AStar_mt)
    self.open = AStarOpenQueue.new()
    self.closed = {}
    self.goalGridNode = nil
    self.startGridNode = nil
    self.bestNode = nil
    self.bFindNearest = false
    self.closedNodeCount = 0
    self.pathingTime = 0
    self.goalPath = nil
    self.callback = nil
    self.realStartLocation = {}
    self.realGoalLocation = {}
    self.maxSearchedNodes = 0
    self.maxPathfindLoops = 0
    self.defaultMaxPathfindLoops = 0
    self.defaultMaxSearchedNodes = 0
    self.bSmoothPath = true
    self.bReachedGoal = false
    self.bPathfinding = false
    self.isDeleted = false
    self.bTraceBlocked = false
    self:loadConfig()
    return self
end

--- loadConfig called to load some default values for the pathfinding algorithm from xml file.
function AStar:loadConfig()

    -- If closed node list goes beyond this stops the search early.
    self.defaultMaxSearchedNodes = 100000
    -- How many loops per update to run pathfinding.
    self.defaultMaxPathfindLoops = 20

    -- This is used to change up to how big in meters grid nodes should still prefer to have heuristic estimate range to be closer than smaller nodes.
    self.heuristicScalingMaxSize = 30

    self.dedicatedScalingFactor = 4

    if fileExists(FlyPathfinding.modDir .. "config/config.xml") then
        local filePath = Utils.getFilename("config/config.xml", FlyPathfinding.modDir)
        local xmlFile = loadXMLFile("TempXML", filePath)

        if getXMLString(xmlFile, "Config.aStarConfig#dedicatedScalingFactor") ~= nil then
            self.dedicatedScalingFactor = MathUtil.clamp(getXMLInt(xmlFile,"Config.aStarConfig#dedicatedScalingFactor") or self.dedicatedScalingFactor,1,10)
        end
        if getXMLString(xmlFile, "Config.aStarConfig#maxSearchedNodes") ~= nil then
            self.defaultMaxSearchedNodes = getXMLInt(xmlFile,"Config.aStarConfig#maxSearchedNodes")
        end
        if getXMLString(xmlFile, "Config.aStarConfig#maxPathfindLoops") ~= nil then
            self.defaultMaxPathfindLoops = getXMLInt(xmlFile,"Config.aStarConfig#maxPathfindLoops")
        end

        if getXMLString(xmlFile, "config.aStarConfig#heuristicScalingMaxSize") ~= nil then
            self.heuristicScalingMaxSize = getXMLInt(xmlFile,"Config.aStarConfig#heuristicScalingMaxSize")
        end
    end

    if self.isServer == true and g_currentMission ~= nil and g_currentMission.connectedToDedicatedServer then
        dedicatedScalingFactor = MathUtil.clamp(dedicatedScalingFactor or 2,1,10)
    else
        dedicatedScalingFactor = 1
    end

end

--- clean called to clean up the AStar object for allowing reuse.
function AStar:clean()
    if self.open ~= nil then
        self.open:empty()
    end
    self.closed = {}
    self.bFindNearest = false
    self.bSmoothPath = true
    self.goalGridNode = nil
    self.startGridNode = nil
    self.realStartLocation = {}
    self.realGoalLocation = {}
    self.bestNode = nil
    self.closedNodeCount = 0
    self.pathingTime = 0
    self.callback = nil
    self.goalPath = nil
    self.bReachedGoal = false
    self.bPathfinding = false
end

-- on deleting astar cleanup.
function AStar:delete()

    if self.isDeleted then
        return
    end

    self:interrupt()
    self.isDeleted = true

    AStar:superClass().delete(self)
end

--- isPathfinding called to check if currently pathfinding.
--@return true if pathfinding.
function AStar:isPathfinding()
    return self.bPathfinding
end

--- find is the function called from any object that wants to do pathfinding.
--@param startPosition is the start location of pathfinding, given as {x=,y=,z=}.
--@param goalPosition is the goal location of pathfinding, given as {x=,y=,z=}.
--@param findNearest is a bool to indicate if should return the closest path to goal if goal was not reached would return {path,false}.
--@param allowSolidStart is a bool to indicate if it is okay if start location is inside a solid node.
--@param allowSolidGoal is a bool to indicate if it is okay if end location is inside a solid node.
--@param callback is a function that wants to be called after pathfinding is done, returns the path as parameter as {array of {x=,y=,z=},true/false if goal was found or not}.
--@param smoothPath optional bool to indicate if the path should be automatically smoothed out a bit so no zigzag pattern.
--@param customPathLoopAmount is an optional number of custom amount of loops per update to pathfind.
--@param customSearchNodeLimit is an optional number of custom amount of maximum closed/visited nodes until search stops early as no path was found.
--@return returns true if started searching for path without issues.
function AStar:find(startPosition,goalPosition,findNearest,allowSolidStart,allowSolidGoal,callback,smoothPath,customPathLoopAmount,customSearchNodeLimit)

    if g_currentMission.gridMap3D == nil or startPosition == nil or goalPosition == nil or CatmullRomSpline.isNearlySamePosition(startPosition,goalPosition) then
        return false
    end

    if self.bPathfinding then
        Logging.info("Already AStar pathfinding, can't start another one without interrupting current!")
        return false
    end

    allowSolidStart = (allowSolidStart ~= nil and {allowSolidStart} or {false})[1]
    self.allowSolidGoal = (allowSolidGoal ~= nil and {allowSolidGoal} or {false})[1]
    self.bSmoothPath = (smoothPath ~= nil and {smoothPath} or {true})[1]
    self.maxSearchedNodes = customSearchNodeLimit or self.defaultMaxSearchedNodes
    self.maxPathfindLoops = (customPathLoopAmount or self.defaultMaxPathfindLoops) * self.dedicatedScalingFactor
    self.realStartLocation = startPosition
    self.realGoalLocation = goalPosition
    self.startGridNode = g_currentMission.gridMap3D:getGridNode(startPosition,allowSolidStart)
    self.goalGridNode = g_currentMission.gridMap3D:getGridNode(goalPosition,allowSolidGoal)
    self.bFindNearest = (findNearest ~= nil and {findNearest} or {true})[1]
    self.callback = callback

    if self.startGridNode[1] == nil or self.goalGridNode[1] == nil then
       return false
    end

    -- Open the first start node without a parent and direction
    self:openNode(nil,self.startGridNode,nil)

    self.bPathfinding = true

    self:raiseActive()
    return true
end

--- interrupt can be called to stop pathfinding.
--@param shouldCallback is a bool that can be set to return the path so far before interrupting.
--@param newCallback is a new callback that can be given if the original is not to be called with the interrupted path.
--@param returns true if interrupted a pathfinding in progress.
function AStar:interrupt(shouldCallback,newCallback)
    if not self.bPathfinding then
        return false
    end

    if shouldCallback then
        self.callback = newCallback or self.callback
        if self.bSmoothPath then
            self:postProcessPath(self.bestNode)
        else
            self:collectFinalPath(self.bestNode)
        end

        self:finishPathfinding()
    else
        self:clean()
    end

    return true
end


--- update here the pathfinding is looped per self.maxPathfindLoops, and raiseActive is only called when actually pathfinding.
--@param dt is deltaTime, used to get estimated time it took to generate the path.
function AStar:update(dt)
    AStar:superClass().update(self,dt)

    if self.bPathfinding then

        self.pathingTime = self.pathingTime + (dt / 1000)
        for i = 0, self.maxPathfindLoops do
            local finished, finishedNode = self:doSearch()
            if finished then

                if self.bReachedGoal or self.bFindNearest and finishedNode ~= nil then

                    if self.bSmoothPath then
                        self:postProcessPath(finishedNode)
                    else
                        self:collectFinalPath(finishedNode)
                    end
                end

                self:finishPathfinding()
                return
            end
        end

        self:raiseActive()
    end
end

--- finishPathfinding is called when pathfinding ends.
-- if a debug object exists sends path and information about generated path to it.
-- Calls the provided callback and then cleans up for next path request.
function AStar:finishPathfinding()

    if AStar.debugObject ~= nil then
        AStar.debugObject:addPath({self.goalPath,self.bReachedGoal},self.closed,self.closedNodeCount,self.pathingTime)
    end

    local aStarSearchResult = {self.goalPath,self.bReachedGoal}
    local callBack = self.callback

    self:clean()

    if callBack ~= nil then
        callBack(aStarSearchResult)
    end

end

--- doSearch is the function that handles iterating the path search.
--@return bool, node. bool is true if done pathfinding and the node is the final node reached.
function AStar:doSearch()

    local currentNode = self.open:pop()

    -- if open queue is empty no goal was found
    if currentNode == nil then
        return true,self.bestNode
    end

    -- Checks if current node is goal then can finalize path
    if self:isSameGridNode(currentNode.gridNode,self.goalGridNode) then
        self.bReachedGoal = true
        return true, currentNode
    end

    self:addToClosed(currentNode)

    -- if has higher resolution child nodes opens those and returns
    if currentNode.gridNode[1].children ~= nil then
        self:openChildren(currentNode)
        return false
    elseif GridMap3DNode.isLeaf(currentNode.gridNode[1]) and currentNode.gridNode[2] == -1 and GridMap3DNode.isNodeSolid(currentNode.gridNode) then
        self:openLeafVoxels(currentNode)
        return false
    end

    local bestNodeF = 9999999999
    if self.bestNode ~= nil then
        bestNodeF = self.bestNode.f
    end

    -- track the best node so far
    if currentNode.f  < bestNodeF and currentNode.gridNode[1] ~= self.startGridNode[1] and currentNode.gridNode[2] ~= self.startGridNode[2] then
        self.bestNode = currentNode
    end

    -- early exit if search goes too long
    if self.closedNodeCount >= self.maxSearchedNodes then
        return true, self.bestNode
    end

    -- try to open new nodes in each available direction
    for _, direction in pairs(ENavDirection) do
        local nextGridNode = nil
        -- if not within a leaf node's voxels then try open a normal node
        if currentNode.gridNode[2] == -1 then
            nextGridNode = nodeAdvancementTable[direction](currentNode.gridNode)
        else
            -- within a leaf voxel so need to try get the next leaf voxel index to open
            nextGridNode = leafNodeAdvancementTable[direction](currentNode.gridNode,direction)
        end

        if nextGridNode[1] ~= nil then
            self:openNode(currentNode,nextGridNode,direction)
        end

    end

    return false
end

--- openChildren is called to open the child nodes of a given node, not leaf voxel children.
--@param node is the AStarNode that has higher resolution children to be open.
function AStar:openChildren(node)
    if node == nil then
        return
    end

    local newChildren = nil
    if node.direction ~= nil then
        -- get all the nodes along the edge on the opposite direction from direction this node was opened from
        newChildren = gridNodeChildrenWallPerDirection[mirroredDirectionTable[node.direction]](node.gridNode)

        if newChildren == nil then
            return
        end
    else
        for _,child in pairs(node.children) do
            table.insert(newChildren,{child,-1})
        end
    end

    for _, newChild in pairs(newChildren) do
        self:openNode(node.parent,newChild,node.direction)
    end

end

--- openLeafVoxels will be called to open the leaf voxels if given node is a leaf node and has some solid leaf voxels.
--@param node is the AStarNode leaf node which has some solid leaf voxels.
function AStar:openLeafVoxels(node)
    if node == nil then
        return
    end
    local newLeafVoxelIndices = {}
    if node.direction ~= nil then
        newLeafVoxelIndices = gridLeafNodeChildrenWallPerDirection[mirroredDirectionTable[node.direction]]()
    else
        newLeafVoxelIndices = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,23,24,27,28,29,30,31,32,33,34,35,36,39,40,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63}
    end

    for _, newLeafVoxelIndex in pairs(newLeafVoxelIndices) do
        self:openNode(node.parent,{node.gridNode[1],newLeafVoxelIndex},node.direction)
    end

end

--- prepareNewNode will create a new AStarNode with the provided variables.
--@param parent is the previous AStarNode.
--@param gridNode is the octree {GridMap3DNode,leafVoxelIndex(-1 - 63)} node this AStarNode presents.
--@param direction is the direction taken from previous to this node.
function AStar:prepareNewNode(parent,gridNode,direction)

    local g = 0
    local h = 0

    -- g is a unit cost of 1 for every step.
    if parent ~= nil then
        g = parent.g + 1
    end

    -- get the heuristic which is euclidean distance * scaling dependent on octree layer of this node.
    h = self:getHeuristic(gridNode,self.goalGridNode)

    return AStarNode.new(gridNode,g,h,parent,direction)
end


--- collectFinalPath will be called instead of postProcessPath in case bSmoothPath is false.
-- will just go through the linked list to make an array of {x=,y=,z=} positions of the path.
--@param node is last node reached on search.
function AStar:collectFinalPath(node)

    if node == nil or g_currentMission.gridMap3D == nil then
        return
    end

    local path = {}

    local position = g_currentMission.gridMap3D:getNodeLocation(node.gridNode)
    if self.bReachedGoal then
        position = {x = self.realGoalLocation.x,y = self.realGoalLocation.y, z = self.realGoalLocation.z}
    end

    table.insert(path,position)
    local currentNode = node.parent

    -- edge case where the goal is within the same grid as start
    if currentNode == nil then
        table.insert(path,{x = self.realStartLocation.x,y = self.realStartLocation.y, z = self.realStartLocation.z })
    end

    while currentNode ~= nil do

        if currentNode.gridNode == self.startGridNode then
            table.insert(path,{x = self.realStartLocation.x,y = self.realStartLocation.y, z = self.realStartLocation.z })
            break
        else
            position = g_currentMission.gridMap3D:getNodeLocation(currentNode.gridNode)
            table.insert(path,position)
        end
        currentNode = currentNode.parent
    end

    self:reversePath(path)
end

--- postProcessPath called to reverse the found path so it goes from start->end, and also removes some zigzag found in the path.
--@param node is the final node that was reached.
function AStar:postProcessPath(node)

    if node == nil or g_currentMission.gridMap3D == nil then
        return
    end

    local path = {}

    local firstPosition = g_currentMission.gridMap3D:getNodeLocation(node.gridNode)

    if self.bReachedGoal then
        firstPosition = self.realGoalLocation
    end
    table.insert(path,firstPosition)

    local firstNode = node
    local secondNode = node.parent
    local thirdNode = nil
    if secondNode ~= nil then
        thirdNode = secondNode.parent
    end

    if secondNode == nil or thirdNode == nil then -- edge case where goal was in same grid as start or the next node
        table.insert(path,{x = self.realStartLocation.x,y = self.realStartLocation.y, z = self.realStartLocation.z })
    else

        while thirdNode ~= nil do

            if secondNode.gridNode == self.startGridNode then
                table.insert(path,{x = self.realStartLocation.x,y = self.realStartLocation.y, z = self.realStartLocation.z })
                break
            end

            local secondPosition = g_currentMission.gridMap3D:getNodeLocation(secondNode.gridNode)
            local bIsLast = thirdNode.gridNode == self.startGridNode
            local thirdPosition = g_currentMission.gridMap3D:getNodeLocation(thirdNode.gridNode)
            if bIsLast then
                thirdPosition = self.realStartLocation
            end

            -- do a raycast to check if middle node can be left out of path
            local directionX,directionY,directionZ = MathUtil.vector3Normalize(thirdPosition.x - firstPosition.x,thirdPosition.y - firstPosition.y,thirdPosition.z - firstPosition.z)
            local distance = MathUtil.vector3Length(thirdPosition.x - firstPosition.x,thirdPosition.y - firstPosition.y,thirdPosition.z - firstPosition.z)
            self.bTraceBlocked = false
            raycastClosest(firstPosition.x,firstPosition.y,firstPosition.z,directionX,directionY,directionZ,"pathTraceCallback",distance,self,CollisionFlag.STATIC_WORLD)

            if self.bTraceBlocked then

                table.insert(path,secondPosition)

                -- in case the second node was blocked then next raycast will be made from that node
                firstNode = secondNode
                firstPosition = g_currentMission.gridMap3D:getNodeLocation(firstNode.gridNode)
            end

            secondNode = thirdNode
            thirdNode = secondNode.parent

            if bIsLast then
                table.insert(path,thirdPosition)
                break
            end
        end
    end

    self:reversePath(path)
end

--- reversePath is called after linked list is made into an array but the path is in reverse, so this corrects it.
--@param path is an array of {x=,y=,z=} positions from goal to start.
function AStar:reversePath(path)
    if path == nil then
        return
    end
    self.goalPath = {}

    for i = #path, 1, -1 do
        table.insert(self.goalPath,path[i])
    end

end

--- pathTraceCallback is raycastClosest callback to check if found path can be smoothed.
--@param hitObjectId id of the hit static object.
function AStar:pathTraceCallback(hitObjectId)

    if hitObjectId < 1 then
        return true
    else
        -- set that trace was blocked so can't remove middle node from between
        self.bTraceBlocked = true
        return false
    end

end


--- isClosed is called to check if a given gridNode is already in the closed list.
--@param gridNode is the {GridMap3DNode,leafVoxelIndex (-1 - 63)} that needs to be checked.
function AStar:isClosed(gridNode)
    if gridNode == nil or gridNode[1] == nil then
        return true
    end

    if self.closed[gridNode[1]] == nil then
        return false
    elseif self.closed[gridNode[1]][gridNode[2]] == nil then
        return false
    end

    return true
end

--- addToClosed will add a given AStarNode into the closed list.
--@param node is the AStarNode to be added into the closed list.
function AStar:addToClosed(node)

    if self.closed[node.gridNode[1]] == nil then
        self.closed[node.gridNode[1]] = {}
    end

    -- The node's gridNode is added into the closed list, as the AStarNode's variable aren't need in there.
    self.closed[node.gridNode[1]][node.gridNode[2]] = node.gridNode
    self.closedNodeCount = self.closedNodeCount + 1
end

--- isSameGridNode is called to comapare two given gridNodes {GridMap3DNode,leafVoxelIndex (-1 - 63)}
--@param node is the first given node to compare with.
--@param node2 is the second given node to compare with.
function AStar:isSameGridNode(node,node2)
    if node == nil or node2 == nil then
        return false
    end

    if node[1] == node2[1] and node[2] == node2[2] then
        return true
    end

    return false
end

--- getHeuristic is the heuristic distance between the two given nodes.
--@param node1 is the first grid node of type {GridMap3DNode,leafVoxelIndex (-1 - 63)} table.
--@param node1 is the second grid node of type {GridMap3DNode,leafVoxelIndex (-1 - 63)} table.
--@return a distance between the two nodes.
function AStar:getHeuristic(node1,node2)
    if node1 == nil or node2 == nil or node1[1] == nil or node2[1] == nil or g_currentMission.gridMap3D == nil then
        return 0
    end

    local position = g_currentMission.gridMap3D:getNodeLocation(node1)
    local position2 = g_currentMission.gridMap3D:getNodeLocation(node2)

    -- scaling additionally with 1.5 to pivot even more on the estimated
    return 1.5 * (MathUtil.vector3Length(position.x - position2.x,position.y - position2.y,position.z - position2.z) * self:getHeuristicScaling(node1))
end

--- getHeuristicScaling is used to get scaling value for adding higher cost for higher resolution nodes.
--@param node is from which the scaling is received from, grid node is of type {GridMap3DNode,leafVoxelIndex (-1 - 63)} table.
function AStar:getHeuristicScaling(node)
    if g_currentMission.gridMap3D == nil or g_currentMission.gridMap3D.nodeTree == nil or node == nil or node[1] == nil then
        return
    end

    local size = node[1].size
    if node[2] > -1 then
        size = g_currentMission.gridMap3D.maxVoxelResolution
    end

    size = MathUtil.clamp(size,1,self.heuristicScalingMaxSize)

    return math.log(g_currentMission.gridMap3D.nodeTree.size / size,2)
end

--- openNode called to try add a new AStarNode into the open queue, checks first if it is possible.
--@param parent is the previous AStarNode.
--@param gridNode is the octree {GridMap3DNode,leafVoxelIndex(-1 - 63)} node this AStarNode presents.
--@param direction is the direction taken from previous to this node.
function AStar:openNode(parent,gridNode,direction)
    if gridNode == nil or gridNode[1] == nil then
        return
    end

    if self:checkgridNodePossibility(gridNode) == false then
        return
    end

    self.open:insert(self:prepareNewNode(parent,gridNode,direction))
end

--- checkGridNodePossiblity is used to check if the given gridNode is a possible next location in the path.
--@param gridNode is the grid node to be checked if is not solid or closed, of type {GridMap3DNode,leafVoxelIndex (-1 - 63)} table.
--@return true if given node can be opened up.
function AStar:checkgridNodePossibility(gridNode)

    if gridNode == nil or gridNode[1] == nil or self:isClosed(gridNode) then
        return false
    end

    local isGoal = false
    -- if it is the goal have to add it into the open if bool allows blocked nodes too if was solid.
    if self:isSameGridNode(gridNode,self.goalGridNode) then
        isGoal = true
    end

    -- if it is a leaf node need to check if the leaf node is not full solid and if it is within a leaf voxel that the leaf voxel is not solid.
    if GridMap3DNode.isLeaf(gridNode[1]) then
        if GridMap3DNode.isLeafFullSolid(gridNode[1]) or gridNode[2] > -1 and GridMap3DNode.isNodeSolid(gridNode) then
            if isGoal and self.allowSolidGoal then
                return true
            else
                return false
            end
        end

    else
        -- also avoiding adding any non leaf nodes that are completely under the terrain into the open queue.
        if GridMap3DNode.isUnderTerrain(gridNode[1]) then
            return false
        end

    end

    return true
end

