


---@class CatmullRomDebug.
--Custom debugging object class for the CatmullRomSpline curve.
CatmullRomDebug = {}
CatmullRomDebug.splineCreator = nil
CatmullRomDebug_mt = Class(CatmullRomDebug,Object)
InitObjectClass(CatmullRomDebug, "CatmullRomDebug")

--- new creates a new CatmullRomDebug object.
function CatmullRomDebug.new()
    local self = Object.new(true,false, CatmullRomDebug_mt)
    self.debugSplines = {}
    self.currentDebugSplineIndex = 1
    self.maxSavedDebugSplines = 10000
    self.debugFollowDistance1 = 0
    self.debugFollowDistance2 = 1
    self.debugFollowDistance3 = 2
    self.traceSpeed = 8

    if g_inputBinding ~= nil and InputAction.FLYPATHFINDING_DBG_PREVIOUS ~= nil then
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.FLYPATHFINDING_DBG_PREVIOUS, self, self.debugPreviousSpline, true, false, false, true, true, true)
        local _, _eventId = g_inputBinding:registerActionEvent(InputAction.FLYPATHFINDING_DBG_NEXT, self, self.debugNextSpline, true, false, false, true, true, true)
    end

    return self
end

--- makeCopy is called to recursively copy the given value.
-- used for copying the segments in catmullrom.
--@param originalValue is value that wants to be copied.
--@return a copy of the given variable.
function CatmullRomDebug.makeCopy(originalValue)
    local copy = nil
    if type(originalValue) == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(originalValue) do
            copy[orig_key] = CatmullRomDebug.makeCopy(orig_value)
        end
        setmetatable(copy, CatmullRomDebug.makeCopy(getmetatable(originalValue)))
    else
        copy = originalValue
    end
    return copy
end




--- delete function called to clean up and remove input bindings from the debug functions.
function CatmullRomDebug:delete()

    if g_inputBinding ~= nil then
        g_inputBinding:removeActionEventsByTarget(self)
    end

    if CatmullRomDebug.splineCreator ~= nil then
        CatmullRomDebug.splineCreator:delete()
    end

    self.debugSplines = nil

    CatmullRomDebug:superClass().delete(self)
end

--- debugNextPath is bound to keyinput to increase the currentDebugSplineIndex.
function CatmullRomDebug:debugNextSpline()
    self.currentDebugSplineIndex = MathUtil.clamp(self.currentDebugSplineIndex + 1,1,#self.debugSplines)
    self:onIndexChanged()
end

--- debugPreviousPath is bound to keyinput to decrease the currentDebugSplineIndex.
function CatmullRomDebug:debugPreviousSpline()
    self.currentDebugSplineIndex = MathUtil.clamp(self.currentDebugSplineIndex - 1,1,#self.debugSplines)
    self:onIndexChanged()
end

--- onIndexChanged called when index of debug rendered spline is changed.
-- So that the debugging points distance following previous spline can be reset.
function CatmullRomDebug:onIndexChanged()
    self.debugFollowDistance1 = 0
    self.debugFollowDistance2 = 1
    self.debugFollowDistance3 = 2
    if self.debugSplines ~= nil and self.debugSplines[self.currentDebugSplineIndex] ~= nil then
        DebugUtil.printTableRecursively(self.debugSplines[self.currentDebugSplineIndex])
    end
end

--- addSpline is called to add a catmullrom that can be visualized.
--@param spline is the finished spline to be added to the debug array.
function CatmullRomDebug:addSpline(spline)

    if spline == nil or spline.segments == nil then
        Logging.warning("No valid CatmullRomSpline given to CatmullRomDebug!")
        return
    end

    if #self.debugSplines >= self.maxSavedDebugSplines then
        return
    end

    -- required functions from the spline
    local splineCopy = {}
    splineCopy.getSplineInformationAtDistance = spline.getSplineInformationAtDistance
    splineCopy.getSplineLength = spline.getSplineLength
    splineCopy.getSegmentByDistance = spline.getSegmentByDistance
    splineCopy.binarySearchSegment = spline.binarySearchSegment
    splineCopy.getEstimatedT = spline.getEstimatedT
    splineCopy.isFloatNearlyEqual = spline.isFloatNearlyEqual
    splineCopy.getPosition = spline.getPosition
    splineCopy.getForwardDirectionAtDistance = spline.getForwardDirectionAtDistance
    splineCopy.getForwardDirection = spline.getForwardDirection
    splineCopy.getRightVector = spline.getRightVector
    splineCopy.getUpVector = spline.getUpVector

    -- recursively copy the segments
    splineCopy.segments = CatmullRomDebug.makeCopy(spline.segments)
    splineCopy.length = spline.length

    table.insert(self.debugSplines,splineCopy)
    self.currentDebugSplineIndex = MathUtil.clamp(self.currentDebugSplineIndex,1,#self.debugSplines)
    if #self.debugSplines == 1 then
        self:raiseActive()
    end

end

--- update is called every tick if a path has been added.
-- Debug visualizes the spline.
--@param dt is the deltaTime in ms.
function CatmullRomDebug:update(dt)
    CatmullRomDebug:superClass().update(self,dt)
    self:raiseActive()

    if self.debugSplines[self.currentDebugSplineIndex] ~= nil then
        local currentSpline = self.debugSplines[self.currentDebugSplineIndex]
        local splineLength = currentSpline.getSplineLength(currentSpline)

        self.debugFollowDistance1 = self.debugFollowDistance1 + ((dt / 1000) * self.traceSpeed)
        self.debugFollowDistance2 = self.debugFollowDistance2 + ((dt / 1000) * self.traceSpeed)
        self.debugFollowDistance3 = self.debugFollowDistance3 + ((dt / 1000) * self.traceSpeed)

        if self.debugFollowDistance1 >= splineLength then
            self.debugFollowDistance1 = math.abs(self.debugFollowDistance1 - splineLength)
        end
        if self.debugFollowDistance2 >= splineLength then
            self.debugFollowDistance2 = math.abs(self.debugFollowDistance2 - splineLength)
        end
        if self.debugFollowDistance3 >= splineLength then
            self.debugFollowDistance3 = math.abs(self.debugFollowDistance3 - splineLength)
        end

        local followPosition, _,_,_ = currentSpline.getSplineInformationAtDistance(currentSpline,self.debugFollowDistance1)
        DebugUtil.drawOverlapBox(followPosition.x, followPosition.y, followPosition.z, 0, 0, 0, 0.25, 0.25, 0.25, 0, 0, 1)

        followPosition, _,_,_ = currentSpline.getSplineInformationAtDistance(currentSpline,self.debugFollowDistance2)
        DebugUtil.drawOverlapBox(followPosition.x, followPosition.y, followPosition.z, 0, 0, 0, 0.25, 0.25, 0.25, 0, 0, 1)

        followPosition,forwardDirection,rightDirection,upDirection = currentSpline.getSplineInformationAtDistance(currentSpline,self.debugFollowDistance3)
        DebugUtil.drawOverlapBox(followPosition.x, followPosition.y, followPosition.z, 0, 0, 0, 0.25, 0.25, 0.25, 0, 0, 1)

        local forwardEndPoint = {x=0,y=0,z=0}
        forwardEndPoint.x = followPosition.x + (forwardDirection.x * 3)
        forwardEndPoint.y = followPosition.y + (forwardDirection.y * 3)
        forwardEndPoint.z = followPosition.z + (forwardDirection.z * 3)
        DebugUtil.drawDebugLine(followPosition.x, followPosition.y, followPosition.z,forwardEndPoint.x ,forwardEndPoint.y , forwardEndPoint.z, 0, 1, 0, 0.05, false)

        forwardEndPoint.x = followPosition.x + (rightDirection.x * 3)
        forwardEndPoint.y = followPosition.y + (rightDirection.y * 3)
        forwardEndPoint.z = followPosition.z + (rightDirection.z * 3)
        DebugUtil.drawDebugLine(followPosition.x, followPosition.y, followPosition.z,forwardEndPoint.x ,forwardEndPoint.y , forwardEndPoint.z, 0, 1, 0, 0.05, false)

        forwardEndPoint.x = followPosition.x + (upDirection.x * 3)
        forwardEndPoint.y = followPosition.y + (upDirection.y * 3)
        forwardEndPoint.z = followPosition.z + (upDirection.z * 3)
        DebugUtil.drawDebugLine(followPosition.x, followPosition.y, followPosition.z,forwardEndPoint.x ,forwardEndPoint.y , forwardEndPoint.z, 0, 1, 0, 0.05, false)

        for distance = 0,splineLength ,1 do
            local _segment,_index, t = currentSpline.getSegmentByDistance(currentSpline,distance)
            if _segment == nil then
                return
            end
            local point,_,_,_ = currentSpline.getSplineInformationAtDistance(currentSpline,distance)
            if point ~= nil then
                DebugUtil.drawOverlapBox(point.x, point.y, point.z, 0, 0, 0, 0.05, 0.05, 0.05, 0, 1, 0)
                renderText3D(point.x, point.y, point.z,0,0,0,0.1,tostring(t))
            end
        end

        for i,segment in ipairs(currentSpline.segments) do
            local startX = currentSpline.segments[i].p1.x
            local startY = currentSpline.segments[i].p1.y
            local startZ = currentSpline.segments[i].p1.z
            local endX = currentSpline.segments[i].p2.x
            local endY = currentSpline.segments[i].p2.y
            local endZ = currentSpline.segments[i].p2.z
            DebugUtil.drawOverlapBox(currentSpline.segments[i].p0.x, currentSpline.segments[i].p0.y, currentSpline.segments[i].p0.z, 0, 0, 0, 0.5, 0.5, 0.5, 1, 1, 0)
            DebugUtil.drawOverlapBox(currentSpline.segments[i].p3.x, currentSpline.segments[i].p3.y, currentSpline.segments[i].p3.z, 0, 0, 0, 0.5, 0.5, 0.5, 1, 1, 0)
            DebugUtil.drawDebugLine(startX, startY, startZ,endX ,endY , endZ, 1, 0, 0, 1, false)
        end

    end
end

--- catmullRomDebugSplineCreate is bound to console command to create a spline with given points.
--@param ... given at least two different location coordinates to be able to make a spline from x,y,z values. Like 0 500 0 0 200 0 as args.
function CatmullRomDebug.catmullRomDebugSplineCreate(debugClass,...)
    if CatmullRomSplineCreator.debugObject == nil then
        Logging.warning("Can't debug create a spline before turning on CatmullRom debug!")
        return
    end

    local points = {}

    local args = {...}

    if #args < 6 then
        Logging.warning("Too few arguments given to debug create a spline!")
        return
    end

    for i = 1, #args, 3 do
        table.insert(points, {x=tonumber(args[i]), y=tonumber(args[i+1]), z=tonumber(args[i+2])})
    end

    if CatmullRomDebug.splineCreator == nil then
        CatmullRomDebug.splineCreator = CatmullRomSplineCreator.new(true,false)
        CatmullRomDebug.splineCreator:register(true)
    end

    CatmullRomDebug.splineCreator:createSpline(points)
end