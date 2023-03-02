
--- Creating a root class for the mod containing some mod variables
BirdFeederMod = {}
BirdFeederMod.modName = g_currentModName;
BirdFeederMod.modDir = g_currentModDirectory;
BirdFeederMod.bRegistered = false
BirdFeederMod.specFile = Utils.getFilename("scripts/specializations/placeableFeeder.lua", BirdFeederMod.modDir)
BirdFeederMod.birdNavigation = nil

---@class BirdFeederLatentAction enable a function to be run in a n update tick delay.
BirdFeederLatentUpdateAction = {}
BirdFeederLatentUpdateAction_mt = Class(BirdFeederLatentUpdateAction)
InitObjectClass(BirdFeederLatentUpdateAction, "BirdFeederLatentUpdateAction")

function BirdFeederLatentUpdateAction.new(inOwner,inFunction,updateDelay)
    local self = setmetatable({},BirdFeederLatentUpdateAction_mt)
    self.latentFunction = inFunction
    self.updateDelay = updateDelay -- in update ticks to skip until action should fire
    self.delayCounter = 0
    self.owner = inOwner
    self.bFinished = false
    return self
end

function BirdFeederLatentUpdateAction:run()
    self.delayCounter = self.delayCounter + 1
    if self.delayCounter >= self.updateDelay and not self.bFinished then
        self.latentFunction(self.owner)
        self.delayCounter = 0
        self.bFinished = true
    end
end

function BirdFeederMod:loadMap(savegame)
	
end

function BirdFeederMod:deleteMap(savegame)

    if BirdFeederMod.birdNavigation ~= nil and not BirdFeederMod.birdNavigation.isDeleted then
        BirdFeederMod.birdNavigation:delete()
    end

    BirdFeederMod.birdNavigation = nil
end

-- Hook after the farmlandmanager's loadmapdata, where the g_currentMission and g_currentMission.terrainNode will be at least valid
function BirdFeederMod:loadMapData(xmlFile)

    -- for now create on server only the navigation grid
    if g_server ~= nil or g_dedicatedServerInfo ~= nil then
        BirdFeederMod.birdNavigation = BirdNavigationGrid.new()
        BirdFeederMod.birdNavigation:register(true)
        addConsoleCommand( 'BirdFeederOctreeDebug', 'toggle debugging for octree', 'octreeDebugToggle', BirdFeederMod.birdNavigation)
    end

end

FarmlandManager.loadMapData = Utils.appendedFunction(FarmlandManager.loadMapData,BirdFeederMod.loadMapData)


--- The register function takes care of adding new placeable specialization and type
function BirdFeederMod.register(typeManager)

    if BirdFeederMod.bRegistered ~= true then
        g_placeableSpecializationManager:addSpecialization("placeableFeeder","PlaceableFeeder",BirdFeederMod.specFile)
        g_placeableTypeManager:addType("placeableFeeder","Placeable","dataS/scripts/placeables/Placeable.lua",nil,Placeable)
        g_placeableTypeManager:addSpecialization("placeableFeeder","placement")
        g_placeableTypeManager:addSpecialization("placeableFeeder","clearAreas")
        g_placeableTypeManager:addSpecialization("placeableFeeder","leveling")
        g_placeableTypeManager:addSpecialization("placeableFeeder","hotspots")
        g_placeableTypeManager:addSpecialization("placeableFeeder","placeableFeeder")
        g_placeableTypeManager:addSpecialization("placeableFeeder","infoTrigger")
        BirdFeederMod.bRegistered = true
    end
end


TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, BirdFeederMod.register)

