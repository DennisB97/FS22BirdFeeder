---@class AStarDebug.
--Custom debugging object class for the A* pathfinding algorithm.
AStarDebug = {}
AStarDebug.aStars = {}
AStarDebug_mt = Class(AStarDebug,Object)
InitObjectClass(AStarDebug, "AStarDebug")

--- new creates a new AStarDebug object.
function AStarDebug.new()
    local self = Object.new(true,false, AStarDebug_mt)
    self.debugPaths = {}
    self.currentDebugPathIndex = 1
    self.maxSavedDebugPaths = 10000
    self.bShowClosedNodes = false

    if g_inputBinding ~= nil and InputAction.FLYPATHFINDING_DBG_PREVIOUS ~= nil then
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.FLYPATHFINDING_DBG_PREVIOUS, self, self.debugPreviousPath, true, false, false, true, true, true)
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.FLYPATHFINDING_DBG_NEXT, self, self.debugNextPath, true, false, false, true, true, true)
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.FLYPATHFINDING_DBG_ASTAR_SHOW_CLOSEDNODES, self, self.toggleClosedNodes, true, false, false, true, true, true)
    end

    return self
end

--- delete function called to clean up and remove input bindings from the debug functions.
function AStarDebug:delete()

    if g_inputBinding ~= nil then
        g_inputBinding:removeActionEventsByTarget(self)
    end
    self.debugPaths = nil

    for _,aStar in ipairs(AStarDebug.aStars) do
        aStar:delete()
    end

    AStarDebug.aStars = {}

    AStarDebug:superClass().delete(self)
end

--- debugNextPath is bound to keyinput to increase the currentDebugPathIndex.
function AStarDebug:debugNextPath()
    self.currentDebugPathIndex = MathUtil.clamp(self.currentDebugPathIndex + 1,1,#self.debugPaths)
end

--- debugPreviousPath is bound to keyinput to decrease the currentDebugPathIndex.
function AStarDebug:debugPreviousPath()
    self.currentDebugPathIndex = MathUtil.clamp(self.currentDebugPathIndex - 1,1,#self.debugPaths)
end

--- toggleClosedNodes is bound to keyinputs to toggle boolean to visualize the closed nodes or not.
function AStarDebug:toggleClosedNodes()
    self.bShowClosedNodes = not self.bShowClosedNodes
end

--- addPath is called to add a path that can be visualized.
--@param aStarSearchResult is the search result finished, table of {path,bGoalWasReached}.
--@param closedNodes is the nodes that were visited and closed in the path, closedNodes[gridNode][leafvoxelindex] = gridNode.
--@param closedNodeCount is the amount of closed nodes.
--@param timeTaken is around how long it took for the path to find goal (if goal was even reached).
function AStarDebug:addPath(aStarSearchResult,closedNodes,closedNodeCount,timeTaken)

    if #self.debugPaths == self.maxSavedDebugPaths then
        return
    end

    if aStarSearchResult[1] == nil then
        Logging.info(string.format("Pathfinding was run but no path could be received! Time taken around: %f, closed node count: %d " ,timeTaken,closedNodeCount))
        return
    end

    local positions = {}
    for i, position in ipairs(aStarSearchResult[1]) do
        table.insert(positions,{x=position.x,y=position.y,z=position.z})
    end
    local closed = {}
    for _,indexHolder in pairs(closedNodes) do
            for _,closedGridNode in pairs(indexHolder) do
                if closedGridNode ~= nil and g_currentMission.gridMap3D ~= nil then
                    local position = g_currentMission.gridMap3D:getNodeLocation(closedGridNode)
                    table.insert(closed,{x=position.x,y=position.y,z=position.z,size=g_currentMission.gridMap3D:getNodeSize(closedGridNode)})
                end
            end
    end

    table.insert(self.debugPaths,{positions,closed})
    self.currentDebugPathIndex = MathUtil.clamp(self.currentDebugPathIndex,1,#self.debugPaths)
    if #self.debugPaths == 1 then
        self:raiseActive()
    end

    if aStarSearchResult[2] then
        Logging.info(string.format("Path was finished and reached all the way to goal! Time taken around: %f, closed node count: %d " ,timeTaken,closedNodeCount))
    else
        Logging.info(string.format("Path was finished but goal was blocked, showing the nearest found path! Time taken around: %f, closed node count: %d " ,timeTaken,closedNodeCount))
    end

end

--- update is called every tick if a path has been added, else raiseActive isn't called and this function does not run.
-- Debug visualizes the path from start to goal, and optionally shows all the closed nodes.
--@param dt is the deltaTime , not needed in this case.
function AStarDebug:update(dt)
    AStarDebug:superClass().update(self,dt)

    if self.bShowClosedNodes and self.debugPaths[self.currentDebugPathIndex] ~= nil then
        for _,location in pairs(self.debugPaths[self.currentDebugPathIndex][2]) do
            DebugUtil.drawSimpleDebugCube(location.x, location.y, location.z, location.size, 1, 0, 0)
        end
    end

    if self.debugPaths[self.currentDebugPathIndex] ~= nil then
        self:raiseActive()
        if self.debugPaths[self.currentDebugPathIndex] ~= nil then
            for i,location in ipairs(self.debugPaths[self.currentDebugPathIndex][1]) do
                if i ~= 1 then
                    local startX = self.debugPaths[self.currentDebugPathIndex][1][i-1].x
                    local startY = self.debugPaths[self.currentDebugPathIndex][1][i-1].y
                    local startZ = self.debugPaths[self.currentDebugPathIndex][1][i-1].z
                    local endX = location.x
                    local endY = location.y
                    local endZ = location.z

                    if endX ~= nil then
                        DebugUtil.drawDebugLine(startX, startY, startZ,endX ,endY , endZ, 0, 1, 0, 1, false)
                    end
                end
                DebugUtil.drawSimpleDebugCube(location.x, location.y, location.z, 0.3, 0, 0, 1)

            end
        end
    end

end

--- aStarDebugPathCreate console command with one can create and visualize A* search with given coordinates.
--@param x the x coordinate of start position.
--@param y the y coordinate of start position.
--@param z the z coordinate of start position.
--@param x2 the x2 coordinate of goal position.
--@param y2 the y2 coordinate of goal position.
--@param z2 the z2 coordinate of goal position.
function AStarDebug.aStarDebugPathCreate(debugClass,x,y,z,x2,y2,z2)
    if x == nil or y == nil or z == nil or x2 == nil or y2 == nil or z2 == nil or g_currentMission.gridMap3D == nil or g_currentMission.gridMap3D:isAvailable() == false or AStar.debugObject == nil then
        return
    end

    local pathfinder = AStar.new(true,false)
    pathfinder:register(true)
    pathfinder:find({x=tonumber(x),y=tonumber(y),z=tonumber(z)},{x=tonumber(x2),y=tonumber(y2),z=tonumber(z2)},true,true,true)
    table.insert(AStarDebug.aStars,pathfinder)

end