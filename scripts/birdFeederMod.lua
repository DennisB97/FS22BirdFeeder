
---@class BirdFeederMod is the root class for the bird feeder mod.
-- Does register custom specialization, adds debug console commands.
BirdFeederMod = {}
BirdFeederMod.bDebug = false
BirdFeederMod.modName = g_currentModName;
BirdFeederMod.modDir = g_currentModDirectory;
BirdFeederMod.bRegistered = false
BirdFeederMod.specFile = Utils.getFilename("scripts/specializations/placeableFeeder.lua", BirdFeederMod.modDir)

--- debugToggle used with console command to toggle debugging for feeder and birds.
function BirdFeederMod.debugToggle()
    BirdFeederMod.bDebug = not BirdFeederMod.bDebug
end

--- The register function takes care of adding new placeable specialization and type
function BirdFeederMod.register(typeManager)

    if BirdFeederMod.bRegistered ~= true then
        -- bird feeder debug command to remove the seed level from the bird feeder next to player
        addConsoleCommand('pfRemoveSeeds', 'removed seeds', 'removeSeeds', PlaceableFeeder)
        addConsoleCommand('BirdFeederModDebug', 'Debug toggled for bird feeder mod', 'debugToggle', BirdFeederMod)
        FeederBird.createXMLSchema()
        g_placeableSpecializationManager:addSpecialization("placeableFeeder","PlaceableFeeder",BirdFeederMod.specFile)
        g_placeableTypeManager:addType("placeableFeeder","Placeable","dataS/scripts/placeables/Placeable.lua",nil,Placeable)
        g_placeableTypeManager:addSpecialization("placeableFeeder","placement")
        g_placeableTypeManager:addSpecialization("placeableFeeder","clearAreas")
        g_placeableTypeManager:addSpecialization("placeableFeeder","leveling")
        g_placeableTypeManager:addSpecialization("placeableFeeder","tipOcclusionAreas")
        g_placeableTypeManager:addSpecialization("placeableFeeder","placeableFeeder")
        g_placeableTypeManager:addSpecialization("placeableFeeder","infoTrigger")
        BirdFeederMod.bRegistered = true
    end
end

TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, BirdFeederMod.register)
