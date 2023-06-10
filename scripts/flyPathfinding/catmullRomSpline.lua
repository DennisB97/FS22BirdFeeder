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


---@class Segment of the catmull-rom
CatmullRomSegment = {}
CatmullRomSegment_mt = Class(CatmullRomSegment)
InitObjectClass(CatmullRomSegment,"CatmullRomSegment")

--- new creates a new segment of a catmull-rom.
--@param p0 is the first control point, given as {x=,y=,z=}.
--@param p1 is the first control point, given as {x=,y=,z=}.
--@param p2 is the first control point, given as {x=,y=,z=}.
--@param p3 is the first control point, given as {x=,y=,z=}.
function CatmullRomSegment.new(p0,p1,p2,p3)
    local self = setmetatable({},CatmullRomSegment_mt)
    self.length = nil
    self.segmentStartLength = nil
    self.p0 = p0
    self.p1 = p1
    self.p2 = p2
    self.p3 = p3

    -- values calculated once, used to receive position on segment.
    self.sSample = nil
    self.tSample = nil
    self.tsSlope = nil
    self.a = nil
    self.b = nil
    self.m1 = nil
    self.m2 = nil
    return self
end

---@class Spline class using by catmull-rom.
CatmullRomSpline = {}
CatmullRomSpline_mt = Class(CatmullRomSpline)
InitObjectClass(CatmullRomSpline, "CatmullRomSpline")


--- new creates a new CatmullRomSpline class.
function CatmullRomSpline.new()
    local self = setmetatable({}, CatmullRomSpline_mt)
    self.segments = {}
    self.length = 0
    return self
end

--- getSegmentByTime is called to get the segment, it's index and first estimate t by given t value.
--@param t is a value between 0-1, where 0 is spline start and 1 spline end.
--@return segment which is of type CatmullRomSegment, it's index found at, and t value between the segment.
function CatmullRomSpline:getSegmentByTime(t)
    if t == nil then
        return nil
    end

    t = MathUtil.clamp(t,0,1)

    return self:getSegmentByDistance(self:getSplineLength() * t)
end

--- getSegmentByDistance is called to get the segment, it's index and t by given distance value.
--@param distance is given distance along the spline that segment wants to be received.
--@return segment which is of type CatmullRomSegment, it's index found at, and t value between the segment.
function CatmullRomSpline:getSegmentByDistance(distance)
    if distance == nil or self.segments == nil then
        return nil
    end

    local lastIndex = #self.segments
    if CatmullRomSpline.isFloatNearlyEqual(distance,self:getSplineLength()) then
        return  self.segments[lastIndex],lastIndex,1
    elseif distance == 0 then
        return self.segments[1],1,0
    end

    return self:binarySearchSegment(distance,1,lastIndex)
end

--- binarySearchSegment searches recursively for the segment which contains the given distance.
--@param distance stays same, and is the distance which is compared with segment's start and end length if it falls between them.
--@param low is the low index of currently searched segment.
--@param high is the high index of currently searched segment.
--@return segment which is of type CatmullRomSegment, it's index found at, and t value between the segment.
function CatmullRomSpline:binarySearchSegment(distance,low,high)

    if high < low then
        printCallstack()
        DebugUtil.printTableRecursively(self)
        Logging.warning("CatmullRomSpline:binarySearchSegment: segment was not found")
        Logging.warning("Tried to find with distance: " .. tostring(distance))
        return nil
    end

    local middle = math.floor((low + high) / 2)

    local startSegmentLength = self.segments[middle].segmentStartLength
    local endSegmentLength = MathUtil.clamp(self.segments[middle].length + self.segments[middle].segmentStartLength,0,self:getSplineLength())

    if startSegmentLength <= distance and endSegmentLength >= distance then
        local t = CatmullRomSpline.normalize01(distance,startSegmentLength,endSegmentLength)
        return self.segments[middle],middle,t
    end

    if self.segments[middle].segmentStartLength > distance then
        return self:binarySearchSegment(distance,low,middle-1)
    else
        return self:binarySearchSegment(distance,middle+1,high)
    end

end

--- isNearlySamePosition is a helper function used for checking if two given vectors (as {x=,y=,z=} are almost same position.
--@param position1 is first position to compare using.
--@param position2 is second position to compare with.
--@limit is a distance limit before they are considered nearly same.
--@return true if they are almost same position.
function CatmullRomSpline.isNearlySamePosition(position1,position2,limit)
    if position1 == nil or position2 == nil then
        return false
    end
    limit = limit or 0.01

    local distance = MathUtil.vector3Length(position1.x - position2.x, position1.y - position2.y, position1.z - position2.z)
    return distance <= limit

end

--- isNearlyEqualDirection is a helper function used for checking if two given direction vectors (as {x=,y=,z=} are almost same direction.
--@param position1 is first direction to compare using.
--@param position2 is second direction to compare with.
--@limit is a radian value limit before they are considered nearly same.
--@return true if they are almost same direction.
function CatmullRomSpline.isNearlyEqualDirection(vector1, vector2, limit)
    if vector1 == nil or vector2 == nil then
        return false
    end

    limit = limit or 0.001
    return MathUtil.dotProduct(vector1.x,vector1.y,vector1.z,vector2.x,vector2.y,vector2.z) > 0 and math.abs(vector1.x - vector2.x) < limit and math.abs(vector1.y - vector2.y) < limit and math.abs(vector1.z - vector2.z) < limit
end

--- isFloatNearlyEqual can be called to check if given two values are almost equal with given limit value.
--@param a is the first value to compare with.
--@param b is the second value to compare with.
--@param limit is the limit on how close is counted as nearly equal.
--@return true if was nearly equal.
function CatmullRomSpline.isFloatNearlyEqual(a, b, limit)
    if a == nil or b == nil then
        return false
    end

    limit = limit or 0.01
    return math.abs(a - b) < limit
end

--- normalize01 is a helper function which normalizes a given value and limits into 0-1 range.
--@param value is the value to be normalized.
--@param minLimit is the lower limit of value.
--@param maxLimit is the higher limit of value.
function CatmullRomSpline.normalize01(value,minLimit,maxLimit)

    local divider = maxLimit - minLimit

    if divider == 0 then
        return value
    end

    return (value - minLimit) / divider
end

--- getSplineInformationAtTime call to get position, tangent and normal at given t.
-- t = 0 start of spline, t = 1 end of spline.
--@return position, tangent and normal all given as tables {x=,y=,z=}.
function CatmullRomSpline:getSplineInformationAtTime(t)
    if t == nil then
        return nil
    end

    t = MathUtil.clamp(t,0,1)

    return self:getSplineInformationAtDistance(self:getSplineLength() * t)
end

--- getSplineInformationAtDistance call to get position, tangent and normal at given distance.
--@param distance value between 0 - spline length.
--@return position, forward vector, right vector and up vector of spline,all given as tables {x=,y=,z=}.
function CatmullRomSpline:getSplineInformationAtDistance(distance)
    if distance == nil or self.segments == nil then
        return nil
    end

    local splineLength = self:getSplineLength()
    distance = MathUtil.clamp(distance,0,splineLength)
    local lastIndex = #self.segments

    local position = {}
    local tangentDirection = {}
    local biNormalDirection = {}
    local normalDirection = {}

    if distance == 0 then
        tangentDirection.x, tangentDirection.y, tangentDirection.z = MathUtil.vector3Normalize(self.segments[1].m1.x,self.segments[1].m1.y,self.segments[1].m1.z)
        position = self.segments[1].p1
    elseif CatmullRomSpline.isFloatNearlyEqual(distance,splineLength) then
        tangentDirection.x, tangentDirection.y, tangentDirection.z = MathUtil.vector3Normalize(self.segments[lastIndex].m2.x,self.segments[lastIndex].m2.y,self.segments[lastIndex].m2.z)
        position = self.segments[lastIndex].p2
    else

        local segment, _index, t = self:getSegmentByDistance(distance)

        if t == 0 then
            tangentDirection.x, tangentDirection.y, tangentDirection.z = MathUtil.vector3Normalize(segment.m1.x,segment.m1.y,segment.m1.z)
            position = segment.p1
        elseif t == 1 then
            tangentDirection.x, tangentDirection.y, tangentDirection.z = MathUtil.vector3Normalize(segment.m2.x,segment.m2.y,segment.m2.z)
            position = segment.p2
        else
            estimatedT = self:getEstimatedT(segment,distance)
            tangentDirection = CatmullRomSpline.getForwardDirection(segment,estimatedT)
            position = CatmullRomSpline.getPosition(segment,estimatedT)
        end
    end

    biNormalDirection = CatmullRomSpline.getRightVector(tangentDirection)
    normalDirection = CatmullRomSpline.getUpVector(tangentDirection,biNormalDirection)

    return position, tangentDirection, biNormalDirection, normalDirection
end

--- getPosition is called to get position on segment with given values.
--@param segment which of a position is wanted.
--@param t is given between 0-1 to interpolate the position.
--@return position with given t as {x=,y=,z=}.
function CatmullRomSpline.getPosition(segment,t)
    if segment == nil or t == nil then
        return nil
    end

    t = MathUtil.clamp(t,0,1)

    if t == 0 then
        return segment.p1
    elseif t == 1 then
        return segment.p2
    end

    -- The polynomial standard form used, which have had precomputed coefficients a,b and tangent at p1(m1) p2(m2)
    -- where p0 is t = 0 so p1 position and p1 is p2 position in the formula
    -- p(t) = (2p0 + m0 - 2p1 + m1)t^3 + (-3p0 + 3p1 + 2m0 - m1)t^2 + m0t + p0
    local point = {}
    point.x = segment.a.x * t * t * t + segment.b.x * t * t + segment.m1.x * t + segment.p1.x;
    point.y = segment.a.y * t * t * t + segment.b.y * t * t + segment.m1.y * t + segment.p1.y;
    point.z = segment.a.z * t * t * t + segment.b.z * t * t + segment.m1.z * t + segment.p1.z;

    return point
end

--- getForwardDirection takes the derivative of given segment and t point and normalizes it for forward direction.
--@param segment the segment which t value to get forward direction from.
--@param t value between 0-1 given more accurate t value to get forward direction on that position.
function CatmullRomSpline.getForwardDirection(segment,t)
    if segment == nil or t == nil then
        return nil
    end

    local tangent = CatmullRomSpline.getDerivative(segment,t)
    local forwardDirection = {}
    forwardDirection.x,forwardDirection.y,forwardDirection.z = MathUtil.vector3Normalize(tangent.x,tangent.y,tangent.z)

    return forwardDirection
end

--- getEstimatedT is called to get a more accurate t from the sampled values.
--@param segment which segment the t is being required from.
--@param distance distance traveled along the spline.
function CatmullRomSpline:getEstimatedT(segment,distance)

    distance = distance - segment.segmentStartLength

    if distance <= 0 then
        return 0
    elseif CatmullRomSpline.isFloatNearlyEqual(distance,segment.length) or distance >= segment.length then
        return 1
    end

    local i = 2

    while i < #segment.sSample do

        if distance < segment.sSample[i] then
            break
        end

        i = i + 1
    end

    local t = segment.tSample[i-1] + segment.tsSlope[i] * (distance - segment.sSample[i-1])

    return t
end

--- getSplineLength returns the spline's length
--@return spline length
function CatmullRomSpline:getSplineLength()
    if self.segments == nil then
        return 0
    end
--
--     return self.segments[#self.segments].length + self.segments[#self.segments].segmentStartLength
    return self.length
end

--- getDerivative gets derivative of a segment
--@param p0 is the first control point of a segment.
--@param p1 is the second control point of a segment.
--@param p2 is the third control point of a segment.
--@param p3 is the fourth control point of a segment.
--@param t value on the segment between 0-1.
--@return derivative given as {x=,y=,z=}
function CatmullRomSpline.getDerivative(segment,t)
    if segment == nil or t == nil then
        return nil
    end

    local tangent = {}

    tangent.x = (6 * t * t - 6 * t) * segment.p1.x + (3 * t * t - 4 * t + 1) * segment.m1.x + (-6 * t * t + 6 * t) * segment.p2.x
        + (3 * t * t - 2 * t) * segment.m2.x;
    tangent.y = (6 * t * t - 6 * t) * segment.p1.y + (3 * t * t - 4 * t + 1) * segment.m1.y + (-6 * t * t + 6 * t) * segment.p2.y
        + (3 * t * t - 2 * t) * segment.m2.y;
    tangent.z = (6 * t * t - 6 * t) * segment.p1.z + (3 * t * t - 4 * t + 1) * segment.m1.z + (-6 * t * t + 6 * t) * segment.p2.z
        + (3 * t * t - 2 * t) * segment.m2.z;

    return tangent

end

--- getRightVector used to get the right vector/binormal of spline, just cross product with world up.
--@param forwardVector is the normalized tangent of spline.
--@return the binormal direction as {x=,y=,z=}
function CatmullRomSpline.getRightVector(forwardVector)
    if forwardVector == nil then
        return nil
    end

    local biNormal = {}
    biNormal.x, biNormal.y, biNormal.z = MathUtil.vector3Normalize(MathUtil.crossProduct(forwardVector.x,forwardVector.y,forwardVector.z,0,1,0))
    return biNormal
end

--- getUpVector used to get the up vector/normal of spline.
--@param forwardVector is the normalized tangent of spline.
--@param rightVector is the normalized binormal of spline.
--@return the normal direction as {x=,y=,z=}
function CatmullRomSpline.getUpVector(forwardVector,rightVector)
    if forwardVector == nil or rightVector == nil then
        return nil
    end

    local normal = {}
    normal.x, normal.y, normal.z = MathUtil.vector3Normalize(MathUtil.crossProduct(rightVector.x,rightVector.y,rightVector.z,forwardVector.x,forwardVector.y,forwardVector.z))
    return normal
end

---------- SPLINE CREATOR -------------

---@class Spline creator class that creates catmull-rom splines when requested.
CatmullRomSplineCreator = {}
CatmullRomSplineCreator.debugObject = nil
CatmullRomSplineCreator_mt = Class(CatmullRomSplineCreator,Object)
InitObjectClass(CatmullRomSplineCreator, "CatmullRomSplineCreator")

--- new creates a new CatmullRomSplineCreator class.
--@param isServer bool to indicate if server owns object.
--@param isClient bool to indicate if client owns object.
function CatmullRomSplineCreator.new(isServer,isClient)
    local self = Object.new(isServer,isClient, CatmullRomSplineCreator_mt)
    self.points = nil
    self.pointCount = 0
    self.ESplineStates = {IDLE = 1, SAMPLINGSEGMENTS = 2, FINISHING = 3}
    self.currentState = self.ESplineStates.IDLE
    self.callback = nil
    self.currentSegmentIndex = 1
    -- if adding more segments between some need a different variable to keep in check last index in the array.
    self.lastSegmentIndex = 0
    self.currentSampleIndex = 1
    self.maxSampleCount = 0
    self.spline = nil
    self.reCalculateStartLengthStartIndex = 1
    --config values
    self.segmentLengthEstimationPointsDefault = 10
    self.tSamplesPerMeterDefault = 1
    self.tTotalSamplesLimitDefault = 200
    self.newtonsTEpsilonDefault = 0.1
    self.newtonsTLoopLimitDefault = 10
    self.bRoundSharpAngles = nil
    self.bRoundSharpAnglesDefault = false
    self.roundSharpAngleLimit = nil
    self.roundSharpAngleLimitDefault = 0.4
    self.roundConnectionRadius = nil
    self.roundConnectionRadiusDefault = 0.2
    self.ghostPointScalingLengthDefault = 0.1
    self.alpha = 0.5
    self.tension = 0
    self.maxSampleLoops = 1
    self:loadConfig()
    self.sampleSegments = {}
    self.sampleSegmentsKeys = {}
    self.isDeleted = false
    return self
end

--- delete takes care of cleaning up the creator.
function CatmullRomSplineCreator:delete()

    if self.isDeleted then
        return
    end

    self:interrupt()
    self.isDeleted = true

    CatmullRomSplineCreator:superClass().delete(self)
end

--- catmullRomDebugToggle console command which toggles on debugging for the catmullromcreator
function CatmullRomSplineCreator.catmullRomDebugToggle()
    if g_currentMission.gridMap3D == nil or g_currentMission.gridMap3D.bOctreeDebug or AStar.debugObject ~= nil then
        Logging.info("Can't turn on catmullrom debug at same time as Octree debug mode or AStar debug mode!")
        return
    end

    if CatmullRomSplineCreator.debugObject == nil then
        CatmullRomSplineCreator.debugObject = CatmullRomDebug.new()
        CatmullRomSplineCreator.debugObject:register(true)
    else
        CatmullRomSplineCreator.debugObject:delete()
        CatmullRomSplineCreator.debugObject = nil
    end

end

--- interrupt the creator from creating/updating spline.
function CatmullRomSplineCreator:interrupt()
    if self.currentState == self.ESplineStates.IDLE then
        return
    end

    self:clean()
end

--- clean called to clean up any variables related to one spline creation or update.
function CatmullRomSplineCreator:clean()
    self.spline = nil
    self.currentState = self.ESplineStates.IDLE
    self.callback = nil
    self.currentSegmentIndex = 1
    self.lastSegmentIndex = 0
    self.currentSampleIndex = 1
    self.reCalculateStartLengthStartIndex = 1
    self.pointCount = 0
    self.points = nil
    self.maxSampleCount = 0
    self.sampleSegments = {}
    self.sampleSegmentsKeys = {}
    self.bRoundSharpAngles = nil
    self.roundSharpAngleLimit = nil
    self.roundConnectionRadius = nil
    self.lastDirection = nil
end

--- loadConfig called to load some default values for the pathfinding algorithm from xml file.
function CatmullRomSplineCreator:loadConfig()

    local dedicatedScalingFactor = nil
    if fileExists(FlyPathfinding.modDir .. "config/config.xml") then
        local filePath = Utils.getFilename("config/config.xml", FlyPathfinding.modDir)
        local xmlFile = loadXMLFile("TempXML", filePath)
        if getXMLString(xmlFile, "Config.catmullRomConfig#roundSharpAngles") ~= nil then
            self.bRoundSharpAnglesDefault = getXMLBool(xmlFile,"Config.catmullRomConfig#roundSharpAngles")
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#roundSharpAngleLimit") ~= nil then
            self.roundSharpAngleLimitDefault = math.abs(MathUtil.degToRad(Utils.getNoNil(getXMLFloat(xmlFile,"Config.catmullRomConfig#roundSharpAngleLimit"),20)))
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#roundConnectionRadius") ~= nil then
            self.roundConnectionRadiusDefault = getXMLFloat(xmlFile,"Config.catmullRomConfig#roundConnectionRadius")
            if self.roundConnectionRadiusDefault <= 0.0 then
                self.roundConnectionRadiusDefault = 0.2
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#segmentLengthEstimationPoints") ~= nil then
            self.segmentLengthEstimationPointsDefault = getXMLInt(xmlFile,"Config.catmullRomConfig#segmentLengthEstimationPoints")
            if self.segmentLengthEstimationPointsDefault < 1 then
                self.segmentLengthEstimationPointsDefault = 1
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#tTotalSamplesLimit") ~= nil then
            self.tTotalSamplesLimitDefault = getXMLInt(xmlFile,"Config.catmullRomConfig#tTotalSamplesLimit")
            if self.tTotalSamplesLimitDefault < 10 then
                self.tTotalSamplesLimitDefault = 100
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#tSamplesPerMeter") ~= nil then
            self.tSamplesPerMeterDefault = getXMLInt(xmlFile,"Config.catmullRomConfig#tSamplesPerMeter")
            if self.tSamplesPerMeterDefault < 1 then
                self.tSamplesPerMeterDefault = 1
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#newtonsTEpsilon") ~= nil then
            self.newtonsTEpsilonDefault = getXMLFloat(xmlFile,"Config.catmullRomConfig#newtonsTEpsilon")
            if self.newtonsTEpsilonDefault <= 0 then
                self.newtonsTEpsilonDefault = 0.1
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#newtonsTLoopLimit") ~= nil then
            self.newtonsTLoopLimitDefault = getXMLInt(xmlFile,"Config.catmullRomConfig#newtonsTLoopLimit")
            if self.newtonsTLoopLimitDefault < 10 then
                self.newtonsTLoopLimitDefault = 10
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#ghostPointScalingLength") ~= nil then
            self.ghostPointScalingLengthDefault = getXMLFloat(xmlFile,"Config.catmullRomConfig#ghostPointScalingLength")
            if self.ghostPointScalingLengthDefault <= 0 then
                self.ghostPointScalingLengthDefault = 0.1
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#alpha") ~= nil then
            self.alpha = getXMLFloat(xmlFile,"Config.catmullRomConfig#alpha")
            if self.alpha < 0 or self.alpha > 1 then
                self.alpha = 0.5
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#alpha") ~= nil then
            self.tension = getXMLFloat(xmlFile,"Config.catmullRomConfig#alpha")
            if self.tension < 0 or self.tension > 1 then
                self.tension = 0
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#maxSampleLoops") ~= nil then
            self.maxSampleLoops = getXMLInt(xmlFile,"Config.catmullRomConfig#maxSampleLoops")
            if self.maxSampleLoops < 1 then
                self.maxSampleLoops = 1
            end
        end

        if getXMLString(xmlFile, "Config.catmullRomConfig#dedicatedScalingFactor") ~= nil then
            dedicatedScalingFactor = getXMLInt(xmlFile,"Config.catmullRomConfig#dedicatedScalingFactor")
            if dedicatedScalingFactor < 1 then
                dedicatedScalingFactor = 1
            end
        end
    end

    if self.isServer == true and g_currentMission ~= nil and g_currentMission.connectedToDedicatedServer then
        dedicatedScalingFactor = MathUtil.clamp(dedicatedScalingFactor or 2,1,10)
    else
        dedicatedScalingFactor = 1
    end

    self.maxSampleLoops = self.maxSampleLoops * dedicatedScalingFactor
end

--- createSpline is called to start creating a new CatmullRomSpline class.
--@param points is a array of positions that wants to be made into spline, given in {x=,y=,z=} tables, needs at least 2.
--@param callback is a reference to a function that will be run after catmullrom is created completely if given a function, sends self/spline as param.
--@param customStartControlPoint can add a specified location as the p0 of first segment if wanted, given as {x=,y=,z=}.
--@param customEndControlPoint can add a specified location as the p3 of last segment if wanted, given as {x=,y=,z=}.
--@param lastDirection can add a direction from which last spline ended for example if the combine function wasn't used and roundSharpAngles is true to avoid going same direction. Given as {x=,y=,z=}.
--@param roundSharpAngles is an optional bool to indicate if sharp angles should be tried to be smoothed by an additional segment inbetween.
--@param roundSharpAngleLimit is an optional float for adjusting the angle limit for when between segments are deemed too sharp.
--@param roundConnectionRadius is an optional float, a radius of to move the end and start point of the segments each to their own direction, which angle was too sharp.
--@return returns true if started creating the spline.
function CatmullRomSplineCreator:createSpline(points,callback,customStartControlPoint,customEndControlPoint,lastDirection,roundSharpAngles,roundSharpAngleLimit,roundConnectionRadius)
    if self.currentState == nil or self.currentState ~= self.ESplineStates.IDLE then
        Logging.warning("Can't start a new spline creation while CatmullRomSplineCreator is still generating/updating!")
        return false
    end

    -- this class adds a ghost control point at start and end so it only needs 2 real points to create a catmullromspline class
    local pointCount = #points
    if points == nil or pointCount < 2 then
        Logging.info("CatmullRomSplineCreator:createSpline: too few points given!")
        return false
    end
    self.spline = CatmullRomSpline.new()
    self.currentState = self.ESplineStates.SAMPLINGSEGMENTS
    self.lastDirection = lastDirection
    self.points = points
    self.pointCount = pointCount
    self.callback = callback
    self.bRoundSharpAngles = (roundSharpAngles and {roundSharpAngles} or {self.bRoundSharpAnglesDefault})[1]
    if roundSharpAngles ~= nil then
        roundSharpAngles = MathUtil.degToRad(roundSharpAngles)
    end
    self.roundSharpAngleLimit = roundSharpAngleLimit or self.roundSharpAngleLimitDefault
    self.roundConnectionRadius = roundConnectionRadius or self.roundConnectionRadiusDefault

    if lastDirection ~= nil and self.bRoundSharpAngles then
        self:adjustStartPosition()
    end

    self:createExtraStartPoint(customStartControlPoint)
    self.pointCount = self.pointCount + 1
    self:createExtraEndPoint(customEndControlPoint)
    self.pointCount = self.pointCount + 1

    while self.currentSegmentIndex <= self.pointCount - 3 do
        self:createSegment()
    end
    self.currentSegmentIndex = 1

    self:raiseActive()
    return true
end

--- adjustStartPosition is used in case bRoundSharpAngles and lastDirection, checks that the given direction is not same as given points[2] -> [1].
-- if it is then it adds a new tiny segment and offsets the original points[1] position to make a little bit of curve.
function CatmullRomSplineCreator:adjustStartPosition()
    if self.currentState == nil or self.currentState ~= self.ESplineStates.SAMPLINGSEGMENTS then
        return
    end

    local direction = {}
    direction.x, direction.y, direction.z = MathUtil.vector3Normalize(self.points[1].x - self.points[2].x,self.points[1].y - self.points[2].y,self.points[1].z - self.points[2].z)

    if CatmullRomSpline.isNearlyEqualDirection(direction,self.lastDirection,self.roundSharpAngleLimit) then
        local offsetDirection = self:getSmoothOffsetVector(self.points[1],{x=self.lastDirection.x * -1,y=self.lastDirection.y * -1, z=self.lastDirection.z * -1},{x=direction.x * -1, y=direction.y * -1,z=direction.z * -1})
        -- could add raycast to make sure not going inside static objects if needed here...
        local newPosition = {}
        newPosition.x,newPosition.y,newPosition.z = self.points[1].x + (self.roundConnectionRadius * offsetDirection.x * 2), self.points[1].y + (self.roundConnectionRadius * offsetDirection.y * 2), self.points[1].z + (self.roundConnectionRadius * offsetDirection.z * 2)
        table.insert(self.points,2,newPosition)
        self.pointCount = self.pointCount + 1
    end

end


--- combineSplinesAtTime is called to combine two different catmullrom splines by t value.
--@param spline1 is the spline to which the second will be attached, the spline2 will be deleted.
--@param spline2 is the spline which will be attached to the spline1, spline2 will be deleted.
--@param t is value between 0-1 along where spline to be combined at on spline1.
--@param callback function to call after the combining is done.
--@param roundSharpAngles is an optional bool to indicate if sharp angles should be tried to be smoothed by an additional segment inbetween.
--@param roundSharpAngleLimit is an optional float for adjusting the angle limit for when between segments are deemed too sharp.
--@param roundConnectionRadius is an optional float, a radius of to move the end and start point of the segments each to their own direction, which angle was too sharp.
function CatmullRomSplineCreator:combineSplinesAtTime(spline1,spline2,t,callback,roundSharpAngles,roundSharpAngleLimit,roundConnectionRadius)
    if self.currentState == nil or self.currentState ~= self.ESplineStates.IDLE then
        Logging.warning("Can't start a new spline combining while CatmullRomSplineCreator is still generating/updating!")
        return false
    end
    t = t or 1

    return self:combineSplinesAtDistance(spline1,spline2,t * spline1:getSplineLength(),callback,roundSharpAngles,roundSharpAngleLimit,roundConnectionRadius)
end


--- combineSplinesAtDistance is called to combine two different catmullrom splines.
--@param spline1 is the spline to which the second will be attached, the spline2 will be deleted.
--@param spline2 is the spline which will be attached to the spline1, spline2 will be deleted.
--@param distance is at the given distance along the spline1 to be joined at.
--@param callback function to call after the combining is done.
--@param roundSharpAngles is an optional bool to indicate if sharp angles should be tried to be smoothed by an additional segment inbetween.
--@param roundSharpAngleLimit is an optional float for adjusting the angle limit for when between segments are deemed too sharp.
--@param roundConnectionRadius is an optional float, a radius of to move the end and start point of the segments each to their own direction, which angle was too sharp.
--@return true if is combining the splines.
function CatmullRomSplineCreator:combineSplinesAtDistance(spline1,spline2,distance,callback,roundSharpAngles,roundSharpAngleLimit,roundConnectionRadius)
    if self.currentState == nil or spline1 == nil or spline2 == nil then
        return false
    end

    if self.currentState ~= self.ESplineStates.IDLE then
        Logging.warning("Can't start a new spline combining while CatmullRomSplineCreator is still generating/updating!")
        return false
    end

    distance = distance or spline1:getSplineLength()

    -- No point joining spline if it replaces pretty much whole self.
    if distance <= 0.1 then
        Logging.warning("CatmullRomSpline:combineSplinesAtDistance: Too short distance to combine, almost whole self spline would be replaced!")
        return false
    end

    self.currentState = self.ESplineStates.SAMPLINGSEGMENTS
    self.callback = callback
    self.bRoundSharpAngles = (roundSharpAngles and {roundSharpAngles} or {self.bRoundSharpAnglesDefault})[1]
    self.roundSharpAngleLimit = roundSharpAngleLimit or self.roundSharpAngleLimitDefault
    self.roundConnectionRadius = roundConnectionRadius or self.roundConnectionRadiusDefault
    self.spline = spline1

    local splineLength = spline1:getSplineLength()
    distance = MathUtil.clamp(distance or splineLength,0,splineLength)

    -- get the segment, index and t between the segment with the given distance
    local segment,index,_t = spline1:getSegmentByDistance(distance)
    if segment == nil then
        return false
    end

    local estimatedT = spline1:getEstimatedT(segment,distance)

    -- getting the position where should be joined at
    local position = CatmullRomSpline.getPosition(segment,estimatedT)
    -- check if position is close to p1
    local bNearP1 = CatmullRomSpline.isNearlySamePosition(position,segment.p1,0.05)

    -- if not near p1 can set p2 to position
    if bNearP1 then
        index = index - 1
    end
    spline1.segments[index].p2 = position
    self.reCalculateStartLengthStartIndex = index

    -- if spline2 starts close to given distance on spline1 then does not need a segment to connect the splines
    local bSpline2NearSpline1 = CatmullRomSpline.isNearlySamePosition(position,spline2.segments[1].p1,0.05)

    if not bSpline2NearSpline1 then -- needed a connection segment between the splines

        -- create a new segment
        local splineExtensionSegment = CatmullRomSegment.new(spline1.segments[index].p1,spline1.segments[index].p2,spline2.segments[1].p1,spline2.segments[1].p2)
        spline1.segments[index].p3 = spline2.segments[1].p1
        spline2.segments[1].p0 = spline1.segments[index].p2
        self:addToBeSampled(spline1.segments[index])
        self:addToBeSampled(spline2.segments[1])
        self:addToBeSampled(splineExtensionSegment)
        self:replaceSegment(spline1,index+1,splineExtensionSegment)
        index = index + 1
        -- check if needs to make curved at the last segment and new extension segment
        if self:makeCurvedAtIndex(index) then
            index = index + 1
        end

    else -- no new segment needed so can just join them together directly
        spline2.segments[1].p1 = spline1.segments[index].p2
        spline1.segments[index].p3 = spline2.segments[1].p2
        spline2.segments[1].p0 = spline1.segments[index].p1
        self:addToBeSampled(spline1.segments[index])
        self:addToBeSampled(spline2.segments[1])

    end

    -- adding the first segment of spline2 to spline1
    self:replaceSegment(spline1,index+1,spline2.segments[1])
    index = index + 1

    -- checking if need to smooth between spline1 last segment and spline2 first segment
    if self:makeCurvedAtIndex(index) then
        index = index + 1
    end

    -- get whichever is longer left of spline1 or spline2, -1 on spline2 as first segment already been added
    local maxIndex = index + math.max((#spline1.segments - index),#spline2.segments - 1)

    for i = 2, maxIndex do

        if spline2.segments[i] ~= nil then
            if i == 2 then
                spline2.segments[i].p0 = spline1.segments[index].p1
            end

            self:replaceSegment(spline1,index + 1,spline2.segments[i])
            index = index + 1

        else
            spline1.segments[index + 1] = nil
            index = index + 1
        end

    end

    self:raiseActive()
    return true
end


--- createExtraStartPoint adds a pure non visited control point to the start of spline.
--@param customPoint is the custom point if given in createSpline function, given as {x=,y=,z=}.
function CatmullRomSplineCreator:createExtraStartPoint(customPoint)
    if self.points == nil then
        return
    end

    if customPoint ~= nil then
        table.insert(self.points,1,customPoint)
        return
    end

    local backwardDirectionX, backwardDirectionY, backwardDirectionZ = MathUtil.vector3Normalize(self.points[1].x - self.points[2].x,self.points[1].y - self.points[2].y,self.points[1].z - self.points[2].z)

    local segmentStraightLength = MathUtil.vector3Length(self.points[1].x - self.points[2].x,self.points[1].y - self.points[2].y,self.points[1].z - self.points[2].z)

    local firstExtraPoint = {x = self.points[1].x + (backwardDirectionX * (self.ghostPointScalingLengthDefault * segmentStraightLength)), y = self.points[1].y + (backwardDirectionY * (self.ghostPointScalingLengthDefault * segmentStraightLength)) ,
        z = self.points[1].z + (backwardDirectionZ * (self.ghostPointScalingLengthDefault * segmentStraightLength))}
    table.insert(self.points,1,firstExtraPoint)
end

--- createExtraEndPoint adds a pure non visited control point to the end of spline.
--@param customPoint is the custom point if given in createSpline function, given as {x=,y=,z=}.
function CatmullRomSplineCreator:createExtraEndPoint(customPoint)
    if self.points == nil then
        return
    end

    if customPoint ~= nil then
        table.insert(self.points,customPoint)
        return
    end

    local forwardDirectionX, forwardDirectionY, forwardDirectionZ = MathUtil.vector3Normalize(self.points[self.pointCount].x - self.points[self.pointCount-1].x,
        self.points[self.pointCount].y - self.points[self.pointCount-1].y,self.points[self.pointCount].z - self.points[self.pointCount-1].z)

    local segmentStraightLength = MathUtil.vector3Length(self.points[self.pointCount].x - self.points[self.pointCount-1].x,
        self.points[self.pointCount].y - self.points[self.pointCount-1].y,self.points[self.pointCount].z - self.points[self.pointCount-1].z)

    local secondExtraPoint = {x = self.points[self.pointCount].x + (forwardDirectionX * (self.ghostPointScalingLengthDefault * segmentStraightLength)), y = self.points[self.pointCount].y + (forwardDirectionY * (self.ghostPointScalingLengthDefault * segmentStraightLength)),
        z = self.points[self.pointCount].z + (forwardDirectionZ * (self.ghostPointScalingLengthDefault * segmentStraightLength)) }

    table.insert(self.points,secondExtraPoint)
end

--- update called every frame when updating or creating spline.
-- used to iterate the sampling of segments.
--@param dt is the deltatime in ms.
function CatmullRomSplineCreator:update(dt)
    if self.currentState == nil or self.currentState == self.ESplineStates.IDLE then
        return
    end

    if self.currentState == self.ESplineStates.SAMPLINGSEGMENTS then
        for i = 1, self.maxSampleLoops do
            if self:sampleSegment(self.sampleSegments[self.currentSegmentIndex]) == true then
                break
            end
        end
    end

    if self.currentState == self.ESplineStates.FINISHING then

        self:reCalculateStartLengths()

        if CatmullRomSplineCreator.debugObject ~= nil then
            CatmullRomSplineCreator.debugObject:addSpline(self.spline)
        end

        local callback = self.callback
        local spline = self.spline

        self:clean()

        if callback ~= nil then
           callback(spline)
        end
        return
    end

    self:raiseActive()
end


--- estimateSegmentLength will approximate the segment length of given four control points between given t values.
-- simple way of estimating... perhaps would need Simpson's rule perhaps too heavy..
--@param p0 is the p0 control point of a segment, given as a table {x=,y=,z=}.
--@param p1 is the p1 control point of a segment, given as a table {x=,y=,z=}.
--@param p2 is the p2 control point of a segment, given as a table {x=,y=,z=}.
--@param p3 is the p3 control point of a segment, given as a table {x=,y=,z=}.
--@param returns the length of the segment.
function CatmullRomSplineCreator:estimateSegmentLength(segment,t0,t1)
    if segment == nil then
        Logging.warning("CatmullRomSplineCreator:estimateSegmentLength: nil variables encountered")
        return 0
    end

    t0 = t0 or 0
    t1 = t1 or 1

    local previousPosition = CatmullRomSpline.getPosition(segment,t0)

    local step =  1 / self.segmentLengthEstimationPointsDefault

    local segmentLength = 0
    for a = step,1,step do
        local currentAlpha = MathUtil.lerp(t0,t1,a)
        local currentPosition = CatmullRomSpline.getPosition(segment,currentAlpha)
        segmentLength = segmentLength + MathUtil.vector3Length(previousPosition.x - currentPosition.x, previousPosition.y - currentPosition.y, previousPosition.z - currentPosition.z)
        previousPosition = currentPosition
    end

    return segmentLength
end

--- addToBeSampled called to add a segment to array and hash key to sample the segments.
--@param segment the segment to add to be sampled.
function CatmullRomSplineCreator:addToBeSampled(segment)
    if segment == nil or self.sampleSegmentsKeys[segment] ~= nil then
        return
    end

    segment.sSample = nil
    segment.tSample = nil
    segment.tsSlope = nil
    segment.a = nil
    segment.b = nil
    segment.m1 = nil
    segment.m2 = nil
    self.sampleSegmentsKeys[segment] = true
    table.insert(self.sampleSegments,segment)
end

--- createSegment used when creating a new spline iterates this function to create the initial segments part of the spline.
function CatmullRomSplineCreator:createSegment()
    if self.points == nil or self.spline == nil then
        Logging.warning("CatmullRomSplineCreator:createSegment: nil variables encountered")
        return
    end

    local newSegment = CatmullRomSegment.new(self.points[self.currentSegmentIndex],self.points[self.currentSegmentIndex+1],self.points[self.currentSegmentIndex+2],self.points[self.currentSegmentIndex+3])

    table.insert(self.spline.segments,newSegment)
    self:addToBeSampled(newSegment)
    self.currentSegmentIndex = self.currentSegmentIndex + 1
    self.lastSegmentIndex = self.lastSegmentIndex + 1

    if self:makeCurvedAtIndex(self.lastSegmentIndex) then
        self.lastSegmentIndex = self.lastSegmentIndex + 1
    end
end

--- makeCurvedAtIndex is used to try make the segments between given index and previous so smoothly curve in a case where the directions are close to equal.
--@param index is segment index from which between that and the next segment as smoother curved would be tried to make if necessary.
--@return true if it added a segment to make more curved between given index and next index.
function CatmullRomSplineCreator:makeCurvedAtIndex(index)
    if index == nil or self.spline == nil or self.spline.segments[index] == nil or self.spline.segments[index-1] == nil or not self.bRoundSharpAngles then
        return false
    end

    local direction1 = {}
    local direction2 = {}

    direction1.x,direction1.y,direction1.z = MathUtil.vector3Normalize(self.spline.segments[index-1].p2.x - self.spline.segments[index-1].p1.x,self.spline.segments[index-1].p2.y - self.spline.segments[index-1].p1.y,self.spline.segments[index-1].p2.z - self.spline.segments[index-1].p1.z)
    direction2.x,direction2.y,direction2.z = MathUtil.vector3Normalize(self.spline.segments[index].p1.x - self.spline.segments[index].p2.x,self.spline.segments[index].p1.y - self.spline.segments[index].p2.y,self.spline.segments[index].p1.z - self.spline.segments[index].p2.z)

    -- check if according to limit value if needs a new segment between the two segments
    if CatmullRomSpline.isNearlyEqualDirection(direction1,direction2,self.roundSharpAngleLimit) then

        local sidePoint = {}
        local reverseSidePoint = {}
        local reverseSideDirection = {}

        local offsetDirection = self:getSmoothOffsetVector(self.spline.segments[index-1].p2,{x=direction1.x * -1, y=direction1.y * -1,z=direction1.z * -1},{x=direction2.x * -1,y=direction2.y * -1,z = direction2.z * -1})

        reverseSideDirection.x = offsetDirection.x * -1
        reverseSideDirection.y = offsetDirection.y * -1
        reverseSideDirection.z = offsetDirection.z * -1
        -- could add raycast to make sure not going inside static objects if needed here...
        sidePoint.x,sidePoint.y,sidePoint.z = self.spline.segments[index-1].p2.x + (reverseSideDirection.x * self.roundConnectionRadius),self.spline.segments[index-1].p2.y +
            (reverseSideDirection.y * self.roundConnectionRadius),self.spline.segments[index-1].p2.z + (reverseSideDirection.z * self.roundConnectionRadius)

        reverseSidePoint.x, reverseSidePoint.y, reverseSidePoint.z = self.spline.segments[index-1].p2.x + (offsetDirection.x * self.roundConnectionRadius),self.spline.segments[index-1].p2.y +
            (offsetDirection.y * self.roundConnectionRadius),self.spline.segments[index-1].p2.z + (offsetDirection.z * self.roundConnectionRadius)

        self.spline.segments[index].p1 = reverseSidePoint
        self.spline.segments[index-1].p2 = sidePoint
        self.spline.segments[index-1].p3 = self.spline.segments[index].p1
        self.spline.segments[index].p0 = self.spline.segments[index-1].p2

        if self.spline.segments[index-2] ~= nil then
            self.spline.segments[index-2].p3 = self.spline.segments[index-1].p2
        end

        self:addToBeSampled(self.spline.segments[index-1])

        local roundNewSegment = CatmullRomSegment.new(self.spline.segments[index-1].p1,self.spline.segments[index-1].p2,self.spline.segments[index].p1,self.spline.segments[index].p2)

        self:addToBeSampled(roundNewSegment)
        self:addToBeSampled(self.spline.segments[index])

        table.insert(self.spline.segments,index,roundNewSegment)
        return true
    end

    return false
end

--- getSmoothOffsetVector is called to get a suitable vector for offsetting a segment start/end which has too sharp angle, if bRoundSharpAngles true.
--@param position is the control point position which of needs to be adjusted.
--@param direction1 is the first segment's direction towards the position from previous position.
--@param direction2 is the second segment's direction backwards towards the position from next position.
--@return offsetDirection which is the direction the position can be moved towards.
function CatmullRomSplineCreator:getSmoothOffsetVector(position,direction1,direction2)

    local offsetDirection = {}
    local crossResult = {}
    crossResult.x, crossResult.y, crossResult.z = MathUtil.crossProduct(direction1.x, direction1.y, direction1.z, direction2.x, direction2.y, direction2.z)

    if  tostring(crossResult.x) == "nan" or tostring(crossResult.y) == "nan" or tostring(crossResult.z) == "nan" or CatmullRomSpline.isNearlySamePosition(crossResult,{x=0,y=0,z=0}) then
        local crossWorldUp = {}
        crossWorldUp.x, crossWorldUp.y, crossWorldUp.z = MathUtil.crossProduct(direction2.x, direction2.y, direction2.z,0,1,0)
        if  tostring(crossWorldUp.x) == "nan" or tostring(crossWorldUp.y) == "nan" or tostring(crossWorldUp.z) == "nan" or CatmullRomSpline.isNearlySamePosition(crossWorldUp,{x=0,y=0,z=0}) then
            -- just takes the cross vector of direction and world x vector
            offsetDirection.x,offsetDirection.y,offsetDirection.z = MathUtil.crossProduct(direction2.x,direction2.y,direction2.z,1,0,0)
        else
            -- just takes the cross vector of direction and world up vector
            offsetDirection.x,offsetDirection.y,offsetDirection.z = MathUtil.crossProduct(direction2.x,direction2.y,direction2.z,0,1,0)
        end

    else
        local tempPoint = {}
        local tempPoint2 = {}
        tempPoint.x, tempPoint.y, tempPoint.z = position.x + (1 * direction2.x),position.y + (1 * direction2.y),position.z + (1 * direction2.z)
        tempPoint2.x, tempPoint2.y, tempPoint2.z = position.x + (1 * direction1.x),position.y + (1 * direction1.y),position.z + (1 * direction1.z)

        local reverseDirection2 = {}
        reverseDirection2.x = direction2.x * -1
        reverseDirection2.y = direction2.y * -1
        reverseDirection2.z = direction2.z * -1

        offsetDirection.x, offsetDirection.y, offsetDirection.z = MathUtil.vector3Normalize(tempPoint.x - tempPoint2.x,tempPoint.y - tempPoint2.y,tempPoint.z - tempPoint2.z)
    end

    return offsetDirection
end

--- sampleSegment is called from update loop per frame to sample one segment at a time.
--@param segment given segment is being sampled.
--@return true if done with all the segments as next() call from update gave a nil.
function CatmullRomSplineCreator:sampleSegment(segment)
    if segment == nil then
        self.currentState = self.ESplineStates.FINISHING
        return true
    end

    if segment.sSample == nil then
        self:prepareSample(segment)
    end

    if self.currentSampleIndex <= self.maxSampleCount then
        table.insert(segment.sSample,self.sampleStepSize * self.currentSampleIndex)
        local lastIndex = self.currentSampleIndex + 1 -- + 1 as 0 value was inserted in prepareSampleTValues
        table.insert(segment.tSample,self:getCurveParameter(segment,segment.sSample[lastIndex]))
        table.insert(segment.tsSlope,(segment.tSample[lastIndex] - segment.tSample[lastIndex-1]) / (segment.sSample[lastIndex] - segment.sSample[lastIndex-1]))

        if self.currentSampleIndex == self.maxSampleCount then
            table.insert(segment.sSample,segment.length)
            table.insert(segment.tSample,1)
            table.insert(segment.tsSlope,(segment.tSample[lastIndex+1] - segment.tSample[lastIndex]) / (segment.sSample[lastIndex+1] - segment.sSample[lastIndex]))
            self.currentSegmentIndex = self.currentSegmentIndex + 1

            return false
        end

        self.currentSampleIndex = self.currentSampleIndex + 1
    end
    return false
end

--- prepareSample called to prepare a segment to sample values.
--@param segment which needs to be prepared for sampling.
function CatmullRomSplineCreator:prepareSample(segment)

    segment.sSample = {}
    segment.tsSlope = {}
    segment.tSample = {}
    self.currentSampleIndex = 1

    self:generateSegmentValues(segment)

    self.maxSampleCount = MathUtil.clamp(math.floor(self.tSamplesPerMeterDefault * segment.length),self.tSamplesPerMeterDefault,self.tTotalSamplesLimitDefault)
    self.sampleStepSize = segment.length / (self.maxSampleCount + 1)

    table.insert(segment.sSample,0)
    table.insert(segment.tsSlope,0)
    table.insert(segment.tSample,0)
end

--- generateSegmentValues called to calculate once per segment its tangents at p1 and p2, and the other values used to get position on spline.
--@param segment is the segment which needs its values calculated.
function CatmullRomSplineCreator:generateSegmentValues(segment)
    if segment == nil then
        return
    end

    local t1 = self:getPointsDistance(segment.p0,segment.p1)
    local t2 = self:getPointsDistance(segment.p1,segment.p2)
    local t3 = self:getPointsDistance(segment.p2,segment.p3)

    local m1 = {}
    local m2 = {}
    m1.x = (1.0 - self.tension) * (segment.p2.x - segment.p1.x + t2 * ((segment.p1.x - segment.p0.x) / t1 - (segment.p2.x - segment.p0.x) / (t1 + t2)))
    m1.y = (1.0 - self.tension) * (segment.p2.y - segment.p1.y + t2 * ((segment.p1.y - segment.p0.y) / t1 - (segment.p2.y - segment.p0.y) / (t1 + t2)))
    m1.z = (1.0 - self.tension) * (segment.p2.z - segment.p1.z + t2 * ((segment.p1.z - segment.p0.z) / t1 - (segment.p2.z - segment.p0.z) / (t1 + t2)))

    m2.x = (1.0 - self.tension) * (segment.p2.x - segment.p1.x + t2 * ((segment.p3.x - segment.p2.x) / t3 - (segment.p3.x - segment.p1.x) / (t2 + t3)))
    m2.y = (1.0 - self.tension) * (segment.p2.y - segment.p1.y + t2 * ((segment.p3.y - segment.p2.y) / t3 - (segment.p3.y - segment.p1.y) / (t2 + t3)))
    m2.z = (1.0 - self.tension) * (segment.p2.z - segment.p1.z + t2 * ((segment.p3.z - segment.p2.z) / t3 - (segment.p3.z - segment.p1.z) / (t2 + t3)))

    segment.a = {}
    segment.a.x = (2*segment.p1.x) + m1.x - (2*segment.p2.x) + m2.x
    segment.a.y = (2*segment.p1.y) + m1.y - (2*segment.p2.y) + m2.y
    segment.a.z = (2*segment.p1.z) + m1.z - (2*segment.p2.z) + m2.z

    segment.b = {}
    segment.b.x = (-3*segment.p1.x) + (3*segment.p2.x) - (2*m1.x) - m2.x
    segment.b.y = (-3*segment.p1.y) + (3*segment.p2.y) - (2*m1.y) - m2.y
    segment.b.z = (-3*segment.p1.z) + (3*segment.p2.z) - (2*m1.z) - m2.z

    segment.m1 = m1
    segment.m2 = m2

    segment.length = self:estimateSegmentLength(segment)

end

--- getCurveParameter bases on newton's method to get closer to actual t value on the catmullrom with given distance along the segment.
--@param segment is the segment which distance is moved along and t will be looked at.
--@param distance is the distance from segment start moved, not whole spline.
--@return more accurate estimated t value at given distance on segment.
function CatmullRomSplineCreator:getCurveParameter(segment,distance)

    local t = distance / segment.length

    local lower = 0
    local upper = 1
    local epsilon = self.newtonsTEpsilonDefault

    for i = 1, self.newtonsTLoopLimitDefault do

        local f = self:estimateSegmentLength(segment,0,t) - distance
        if math.abs(f) <= epsilon then
            return t
        end

        local dfdt = CatmullRomSpline.getDerivative(segment,t)
        dfdt = MathUtil.vector3Length(dfdt.x,dfdt.y,dfdt.z)
        local tNext = t - f / dfdt

        if f > 0 then
            upper = t
            if tNext <= lower then
                t = (upper + lower) / 2
            else
                t = tNext
            end
        else
            lower = t
            if tNext >= upper then
                t = (upper + lower) / 2
            else
                t = tNext
            end
        end
    end

    return t
end

--- getPointsDistance calculates distance between the two control points scaled with alpha of catmull-rom.
--@param p1 first control point to take distance from, given as {x=,y=,z=}.
--@param p2 second control point to take distance to, given as {x=,y=,z=}.
--@return distance between the given control points, scaled with alpha.
function CatmullRomSplineCreator:getPointsDistance(p1,p2)
    if p1 == nil or p2 == nil then
        return 0
    end

    local d = MathUtil.vector3Length(p1.x - p2.x, p1.y - p2.y, p1.z - p2.z)
    return math.pow(d,self.alpha)
end


--- reCalculateStartLengths is used as final step to set the correct segmentstartlength for each segment and final spline length.
function CatmullRomSplineCreator:reCalculateStartLengths()

    local lastIndex = #self.spline.segments

    for i = self.reCalculateStartLengthStartIndex, lastIndex do

        self.spline.segments[i].segmentStartLength = 0
        if i > 1 then
            self.spline.segments[i].segmentStartLength = self.spline.segments[i-1].segmentStartLength + self.spline.segments[i-1].length
        end

        if i == lastIndex then
            self.spline.length = self.spline.segments[i].segmentStartLength + self.spline.segments[i].length
        end

    end

end



--- replaceSegment helper function either inserts a new segment or overwrites an existing on given index.
--@param index is at the index to override with given segment.
--@param segment is of type CatmullRomSegment, and is the segment to be inserted.
function CatmullRomSplineCreator:replaceSegment(spline,index,segment)

    if spline == nil or index == nil or segment == nil then
        return
    end

    if spline.segments[index] == nil then
        table.insert(spline.segments,segment)
    else
        spline.segments[index] = nil
        spline.segments[index] = segment
    end

end




