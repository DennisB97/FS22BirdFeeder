---Custom object class for the bird navigation grid

---@class BirdNavigationGrid
BirdNavigationGrid = {}
BirdNavigationGrid.className = "BirdNavigationGrid"
BirdNavigationGrid_mt = Class(BirdNavigationGrid,Object)
InitObjectClass(BirdNavigationGrid, "BirdNavigationGrid")

BirdNavNode = {}

function BirdNavNode.new(x,y,z,parent,size)
    local self = setmetatable({},nil)
    self.positionX = x
    self.positionY = y
    self.positionZ = z
    self.size = size
    self.parent = parent
    self.children = nil
    self.xNeighbour = nil
    self.xMinusNeighbour = nil
    self.yNeighbour = nil
    self.yMinusNeighbour = nil
    self.zNeighbour = nil
    self.zMinusNeighbour = nil
    self.leafVoxelsBottom = nil
    self.leafVoxelsTop = nil
    return self
end

function BirdNavNode.isSolid(node)

    if node.children == nil then
        if (node.leafVoxelsBottom ~= nil and node.leafVoxelsBottom ~= 0) or (node.leafVoxelsTop ~= nil and node.leafVoxelsTop ~= 0) then
            return true
        else
            return false
        end
    end

    return true
end

function BirdNavNode.isLeaf(node)

    if node.children == nil then
        if node.leafVoxelsBottom ~= nil and node.leafVoxelsTop ~= nil then
            return true
        end
    end

    return false
end


function BirdNavigationGrid:addNode(layerIndex,node)
    if self == nil then
        return -1
    end

    if self.nodeTree == nil then
        self.nodeTree = {}
    end


    if self.nodeTree[layerIndex] == nil then
        table.insert(self.nodeTree,layerIndex,{})
    end

    table.insert(self.nodeTree[layerIndex],node)

    return #self.nodeTree[layerIndex]
end


---new bird navigation being created
function BirdNavigationGrid.new(customMt)

    local self = Object.new(true,false, customMt or BirdNavigationGrid_mt)
    self.nodeTree = {}
    self.terrainSize = 2048
    self.maxVoxelResolution = 2 -- in meters
    self.birdNavigationStates = {}
    self.EBirdNavigationStates = {UNDEFINED = 0, PREPARE = 1, GENERATE = 2, DEBUG = 3, IDLE = 4}
    self.EDirections = {X = 0, MINUSX = 1, Y = 2, MINUSY = 3, Z = 4, MINUSZ = 5}
    self.currentState = self.EBirdNavigationStates.UNDEFINED
    self.navGridStartLocation = {x = 0, y = 0, z = 0}
    self.octreeDebug = false
    self.mapBoundaryIDs = {}

    table.insert(self.birdNavigationStates,BirdNavGridStatePrepare.new())
    self.birdNavigationStates[self.EBirdNavigationStates.PREPARE]:init(self)
    table.insert(self.birdNavigationStates,BirdNavGridStateGenerate.new())
    self.birdNavigationStates[self.EBirdNavigationStates.GENERATE]:init(self)
    table.insert(self.birdNavigationStates,BirdNavGridStateDebug.new())
    self.birdNavigationStates[self.EBirdNavigationStates.DEBUG]:init(self)

    self:changeState(self.EBirdNavigationStates.PREPARE)
    registerObjectClassName(self, "BirdNavigationGrid")

    return self
end


function BirdNavigationGrid:delete()

    self.isDeleted = true
    if self.birdNavigationStates[self.currentState] ~= nil then
        self.birdNavigationStates[self.currentState]:leave()
    end

    for _, state in pairs(self.birdNavigationStates) do

        if state ~= nil then
            state:destroy()
        end

    end

    self.birdNavigationStates = nil
    self.nodeTree = nil

    BirdNavigationGrid:superClass().delete(self)

    unregisterObjectClassName(self)
end

function BirdNavigationGrid.getVectorDistance(x,y,z,x2,y2,z2)
    return math.sqrt(math.pow((x - x2),2) + math.pow((y - y2),2) + math.pow((z - z2),2))
end


function BirdNavigationGrid:changeState(newState)

    if newState == nil or newState == 0 then
        Logging.warning("Not a valid state given to BirdNavigationGrid:changeState() _ ".. tostring(newState))
        return
    end

    if newState == self.currentState then
        Logging.warning("BirdNavigationGrid:changeState() tried to change to same state as current! _ " .. tostring(newState))
    end


    if self.birdNavigationStates[self.currentState] ~= nil then
        self.birdNavigationStates[self.currentState]:leave()
    end

    self.currentState = newState

    -- if debug is on then when returning to idle should set to debug state instead
    if self.currentState == self.EBirdNavigationStates.IDLE and self.octreeDebug then
        self.currentState = self.EBirdNavigationStates.DEBUG
    end


    if self.birdNavigationStates[self.currentState] ~= nil then
        self.birdNavigationStates[self.currentState]:enter()
    end


end


function BirdNavigationGrid:update(dt)
    BirdNavigationGrid:superClass().update(self,dt)

    if self.birdNavigationStates[self.currentState] ~= nil then
         self.birdNavigationStates[self.currentState]:update(dt)
    end


end

function BirdNavigationGrid:octreeDebugToggle()

    if self == nil then
        return
    end

    self.octreeDebug = not self.octreeDebug

    if self.octreeDebug and self.currentState == self.EBirdNavigationStates.IDLE then
        self:changeState(self.EBirdNavigationStates.DEBUG)
    elseif not self.octreeDebug and self.currentState == self.EBirdNavigationStates.DEBUG then
        self:changeState(self.EBirdNavigationStates.IDLE)
    end


end














