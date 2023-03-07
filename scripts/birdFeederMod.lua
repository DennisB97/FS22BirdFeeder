
---@class BirdFeederMod is the root class for the bird feeder mod.
-- Does register custom specialization, and creates 3dnavigation grid.
BirdFeederMod = {}
BirdFeederMod.modName = g_currentModName;
BirdFeederMod.modDir = g_currentModDirectory;
BirdFeederMod.bRegistered = false
BirdFeederMod.specFile = Utils.getFilename("scripts/specializations/placeableFeeder.lua", BirdFeederMod.modDir)

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

