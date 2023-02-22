---Custom object class for the bird navigation grid

---@class BirdNavigationGrid
BirdNavigationGrid = {}
BirdNavigationGrid.className = "BirdNavigationGrid"
BirdNavigationGrid_mt = Class(BirdNavigationGrid,Object)
InitObjectClass(BirdNavigationGrid, "BirdNavigationGrid")

BirdNavNode = {}

function BirdNavNode.new(x,y,z,parent)
    local self = setmetatable({},nil)
    self.positionX = x
    self.positionY = y
    self.positionZ = z
    -- all links 32/64 bits used, 4 bits layer index, 22bits node index, 6bit for highest resolution voxels if leaf node
    self.parent = parent
    self.children = {}
    self.xNeighbour = 0
    self.xMinusNeighbour = 0
    self.yNeighbour = 0
    self.yMinusNeighbour = 0
    self.zNeighbour = 0
    self.zMinusNeighbour = 0
    self.leafVoxels = 0
    return self
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
    self.currentState = self.EBirdNavigationStates.UNDEFINED
    self.navGridStartLocation = {x = 0, y = 0, z = 0}

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
    BirdNavigationGrid:superClass().delete(self)



    unregisterObjectClassName(self)

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
    self.birdNavigationStates[self.currentState]:enter()


end


function BirdNavigationGrid:update(dt)
    BirdNavigationGrid:superClass().update(self,dt)

    if self.birdNavigationStates[self.currentState] ~= nil then
         self.birdNavigationStates[self.currentState]:update(dt)
    end


end














