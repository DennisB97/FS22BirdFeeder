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

    You can check if this is available with the FlyPathfinding.bPathfindingEnabled and checking if the octree object exists by g_currentMission.gridMap3D ~= nil.
    To check if the octree grid has been generated you can either call g_currentMission.gridMap3D:isAvailable() which returns a bool. Can also bind to the g_messageCenter:subscribe(MessageType.GRIDMAP3D_GRID_GENERATED, "your function to call here", "function's self ref here")
    Can create the AStar pathfinding class by AStar.new(isServer,isClient) and remembering to call :register(true) on the created object. Currently the AStar pathfinding can't be queued up with the function call astarobject:find before octree is ready, so need to wait till octree has generated the grid done by like above.
    After creating an AStar and making sure the grid is ready, one can start pathfinding using the find function. AStar:find(startPosition,goalPosition,findNearest,allowSolidStart,allowSolidGoal,callback,smoothPath,customPathLoopAmount,customSearchNodeLimit)
    Where startPosition and goalPosition are given as tables {x=,y=,z=},
    findNearest a bool to indicate if goal wasn't reach to return the nearest found grid node if possible.
    allowSolidStart and allowSolidGoal bool to allow start and goal being inside a collision.
    callback will be called when path is done, and will contain the path like {array of {x=,y=,z=}, bool reached goal}, returns {nil,false} if did not reach goal and findNearest was false or didn't have a best node.
    customPathLoopAmount indicates how many loops per frame to pathfind, if not given uses value from config.xml.
    customSearchNodeLimit can limit how many closed nodes will search through before cancelling search, also if not given uses value from config.xml.

    Can create a catmull-rom by first creating the CatmullRomSplineCreator.new(isServer,isClient) and remembering to call :register(true) on the created object. Then the CatmullRomSplineCreator object has function: CatmullRomSplineCreator:createSpline(points,callback,customStartControlPoint,customEndControlPoint,lastDirection,roundSharpAngles,roundSharpAngleLimit,roundConnectionRadius,segment)
    points is an array of {x=,y=,z=} minimum of 2 points needed to create a spline.
    callback is a function to be called after spline is created and gives the created CatmullRomSpline as argument.
    customStartControlPoint and customEndControlPoint are optional P0 first segment, and P3 last segment's points given as {x=,y=,z=}.
    lastDirection is optional direction that a previous spline was going towards on last segment, if combining two splines without using the combineSplinesAtDistance function.
    roundSharpAngles is a bool to indicate if sharp angles beyond the roundSharpAngleLimit should be rounded a bit by the roundConnectionRadius

    Two splines can be combined with the: CatmullRomSplineCreator:combineSplinesAtDistance(spline1,spline2,distance,callback,roundSharpAngles,roundSharpAngleLimit,roundConnectionRadius)
    spline1 and spline2 are the splines to be combined the spline2 will be used up and should be nilled and not used anymore.
    distance is the distance at the spline to combine the two splines.
    callback is the function which will be called when the splines have been combined, returns the spline1 combined.

    The created spline CatmullRomSpline has mainly the function: CatmullRomSpline:getSplineInformationAtDistance(distance)
    Which returns the position, forward vector, right vector and upvector on the spline at given distance along the spline.

    The mod fully works in multiplayer. While in single player the config.xml has the maxOctreePreLoops that can be adjusted for example, this affects the speed of creating the octree grid,
    after loading screen is done and entering game the pre loops will be run and will lag the game for a few seconds depending on the amount of maxOctreePreLoops.
    Helps a minute or so of the generation time while game is fully running, and the maxOctreeGenerationLoopsPerUpdate can be also lowered if performance is too low,
    while generating at the beginning the octree grid. In dedicated servers the octree grid is fully generated when starting the dedicated server.

    !Issues!
    Does not work on modded maps with non-original map size, so larger than 2048. I think it is an issue with the FS22 LUA API's overlapBox collision check function.
    Did not see any possiblity to avoid including very thin meshes near terrain like the roads in the octree grid as solid, could cut some generation time by a good solution.


    If copying pathfinding to another mod should include the whole flyPathfinding folder and create the grid in same way as here, to avoid version issues if grid, AStar or CatmullRomSpline/Creator gets any breaking changes.
    Original place for the set of scripts can be found at https://github.com/DennisB97/FS22FlyPathfinding
--]]


---@class FlyPathfinding takes care of creating the pathfinding grid object.
FlyPathfinding = {}
FlyPathfinding.modName = g_currentModName;
FlyPathfinding.modDir = g_currentModDirectory .. "scripts/flyPathfinding/"
-- the g_currentMission.gridMap3D might ne valid if some other mod had it too, but if the required version was lower then the following bool is false to indicate can't use pathfinding until upgraded.
FlyPathfinding.bPathfindingEnabled = false
-- changed per basis of in included mod.
FlyPathfinding.requiredPathfindingVersion = "1.0.0"


--- deleteMap is FS22 function called after exiting played save.
function FlyPathfinding:deleteMap(savegame)
	
    -- delete the 3d grid if it hasn't already
    if g_server ~= nil and g_currentMission ~= nil and g_currentMission.gridMap3D ~= nil and not g_currentMission.gridMap3D.isDeleted then
        g_currentMission.gridMap3D:delete()
    end

    g_currentMission.gridMap3D = nil
end

--- Hook after the farmlandmanager's loadmapdata, where the g_currentMission will be valid.
-- Handles creating and initing the class for 3d navigation grid.
function FlyPathfinding:loadMapData(xmlFile)

    if g_currentMission ~= nil and g_server ~= nil then
        if g_currentMission.gridMap3D == nil then
            g_currentMission.gridMap3D = GridMap3D.new()
            g_currentMission.gridMap3D:register(true)
            if g_currentMission.gridMap3D:init() == false then
                g_currentMission.gridMap3D:delete()
                g_currentMission.gridMap3D = nil
                return
            end
            -- adds a debugging console command to be able to visualize the octree and A* pathfinding.
            addConsoleCommand( 'GridMap3DOctreeDebug', 'toggle debugging for octree', 'octreeDebugToggle', g_currentMission.gridMap3D)
            addConsoleCommand( 'AStarFlypathfindingDebug', 'toggle debugging for AStar pathfinding', 'aStarDebugToggle', AStar)
            addConsoleCommand( 'AStarFlypathfindingDebugPathCreate', 'Given two vector positions creates a debug path between those', 'aStarDebugPathCreate', AStarDebug)
            addConsoleCommand( 'CatmullRomDebug', 'toggle debugging for catmullrom', 'catmullRomDebugToggle', CatmullRomSplineCreator)
            addConsoleCommand( 'CatmullRomDebugSplineCreate', 'given at least 2 x y z points creates a catmullrom', 'catmullRomDebugSplineCreate', CatmullRomDebug)
            FlyPathfinding.bPathfindingEnabled = true
        else
            Logging.info("Some other mod has created the pathfinding grid before this mod at: " .. FlyPathfinding.modDir)
            local usedVersion = g_currentMission.gridMap3D:getVersion()
            local valid = FlyPathfinding.compareVersions(FlyPathfinding.requiredPathfindingVersion,usedVersion)
            if not valid then
                Logging.warning("Some mod requires a newer version of fly pathfinding!")
                Logging.warning("Requested version : " .. tostring(FlyPathfinding.requiredPathfindingVersion))
                Logging.warning("Used version : " .. tostring(usedVersion))
                return
            else
                FlyPathfinding.bPathfindingEnabled = true
            end
        end
    end

end

FarmlandManager.loadMapData = Utils.appendedFunction(FarmlandManager.loadMapData,FlyPathfinding.loadMapData)
addModEventListener(FlyPathfinding)

--- compareVersions is used to compare the pathfinding system version found in config.xml.
--@param v1 is the required version given as string, major, minor and patch (x.x.x).
--@param v2 is the current version of grid given as string, major, minor and patch (x.x.x).
--@return true if the version was fine and should not have issues running on this mod.
function FlyPathfinding.compareVersions(v1, v2)
    local major1, minor1, patch1 = string.match(v1, "(%d+)%.(%d+)%.(%d+)")
    local major2, minor2, patch2 = string.match(v2, "(%d+)%.(%d+)%.(%d+)")
    major1, minor1, patch1 = tonumber(major1),tonumber(minor1),tonumber(patch1)
    major2, minor2, patch2 = tonumber(major2),tonumber(minor2),tonumber(patch1)

    if major1 ~= major2 or minor1 > minor2 or patch1 > patch2 then
        return false
    end

    return true
end
