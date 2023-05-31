---CustomDischarge specialization for vehicle

---@class CustomDischarge
CustomDischarge = {}
CustomDischarge.className = "CustomDischarge"


---Checks if all prerequisite specializations are loaded, in this case the Dischargable is needed.
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function CustomDischarge.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Dischargeable, specializations)
end

---Init specialization by registering some xml paths for properties for new custom ray direction
function CustomDischarge.initSpecialization()

    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("CustomDischarge")

    schema:register(XMLValueType.FLOAT,"vehicle.customDischarge#customDirectionX", "Define the ray x direction")
    schema:register(XMLValueType.FLOAT,"vehicle.customDischarge#customDirectionY", "Define the ray y direction")
    schema:register(XMLValueType.FLOAT,"vehicle.customDischarge#customDirectionZ", "Define the ray z direction")
    -- This can be used
    schema:register(XMLValueType.BOOL,"vehicle.customDischarge#bUseCustomDirection", "bool for in case using a custom world direction")
    -- Or this option but not both
    schema:register(XMLValueType.BOOL,"vehicle.customDischarge#bUseCustomNodeDirection", "bool for in case using a custom node relative direction")
end

---Register overwritten functions
function CustomDischarge.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateRaycast", CustomDischarge.CustomDischargeRaycast)
end

---Register all needed FS events
function CustomDischarge.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", CustomDischarge)
end

---On load check xml file for given custom ray direction values and node relative direction or not
function CustomDischarge:onLoad(savegame)
	--- Register the spec
	self.spec_customDischarge = self["spec_FS22_BirdFeeder.customDischarge"]
    local spec = self.spec_customDischarge
    local xmlFile = self.xmlFile
    spec.bCustomDirection = xmlFile:getValue("vehicle.customDischarge#bUseCustomDirection")
    spec.bCustomNodeDirection = xmlFile:getValue("vehicle.customDischarge#bUseCustomNodeDirection")
    spec.customDirectionX = xmlFile:getValue("vehicle.customDischarge#customDirectionX")
    spec.customDirectionY = xmlFile:getValue("vehicle.customDischarge#customDirectionY")
    spec.customDirectionZ = xmlFile:getValue("vehicle.customDischarge#customDirectionZ")

    if spec.bCustomDirection == nil and spec.bCustomNodeDirection == nil or spec.customDirectionX == nil and spec.customDirectionY == nil and spec.customDirectionZ == nil then
        Logging.warning("CustomDischarge:onLoad: Why is customDischarge specialization being used, no custom direction being used.")
        return
    end

end

---Overridden discharge function, doesn't call base function because this one overrides the ray direction
function CustomDischarge:CustomDischargeRaycast(superFunc,dischargeNode)
    local spec = self.spec_dischargeable

    local raycast = dischargeNode.raycast
    if raycast.node == nil then
        return
    end

    dischargeNode.lastDischargeObject = dischargeNode.dischargeObject
    dischargeNode.dischargeObject = nil
    dischargeNode.dischargeHitObject = nil
    dischargeNode.dischargeHitObjectUnitIndex = nil
    dischargeNode.dischargeHitTerrain = false
    dischargeNode.dischargeShape = nil
    dischargeNode.dischargeDistance = math.huge
    dischargeNode.dischargeFillUnitIndex = nil
    dischargeNode.dischargeHit = false

    local x,y,z = getWorldTranslation(raycast.node)
    y = y + raycast.yOffset

    -- Custom code start --
     local specCustom = self.spec_customDischarge

    local xDirection = 0
    local yDirection = -1
    local zDirection = 0

    if specCustom.bCustomDirection == true then
        xDirection = tonumber(specCustom.customDirectionX) or 0
        yDirection = tonumber(specCustom.customDirectionY) or 0
        zDirection = tonumber(specCustom.customDirectionZ) or 0

    elseif specCustom.bCustomNodeDirection == true then
        xDirection, yDirection, zDirection = localDirectionToWorld(raycast.node, tonumber(specCustom.customDirectionX) or 0,tonumber(specCustom.customDirectionY) or -1,tonumber(specCustom.customDirectionZ) or 0)
    end

    -- Custom code end --

    spec.currentRaycastDischargeNode = dischargeNode
    spec.currentRaycast = raycast
    spec.isAsyncRaycastActive = true
    raycastAll(x,y,z, xDirection,yDirection,zDirection, "raycastCallbackDischargeNode", dischargeNode.maxDistance, spec, spec.raycastCollisionMask, false, false)
    -- TODO: remove if async raycast is added
    spec:raycastCallbackDischargeNode(nil)

end


