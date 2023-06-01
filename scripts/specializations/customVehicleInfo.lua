---customVehicleInfo specialization for vehicle

---@class CustomVehicleInfo
CustomVehicleInfo = {}
CustomVehicleInfo.className = "CustomVehicleInfo"


---Checks if all prerequisite specializations are loaded, in this case none needed
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function CustomVehicleInfo.prerequisitesPresent(specializations)
    return true;
end

---Init this specialization, registering couple needed xml string paths
function CustomVehicleInfo.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("CustomVehicleInfo")
    schema:register(XMLValueType.STRING,"vehicle.customVehicleInfo#uiLinesToRemove", "Selected information to remove from the index, Mass etc on index usually 2.")
    schema:register(XMLValueType.STRING,"vehicle.customVehicleInfo#uiInfoTitle", "Title for the info UI")
end

---Register overwritten functions
function CustomVehicleInfo.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "showInfo", CustomVehicleInfo.showModifiedInfo)
end

---Register all needed FS events
function CustomVehicleInfo.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", CustomVehicleInfo)
end

---Overridden function that calls base function but also proceeds to change few variables of the UI box
function CustomVehicleInfo:showModifiedInfo(superFunc,box)
    superFunc(self,box)
    local spec = self.spec_customVehicleInfo

    -- Change the title if not nil
    if spec.infoTitle ~= nil then
        -- First checking if using a localized one then call the global function to get the localized string
        if string.sub(spec.infoTitle,1,6) == "$l10n_" then
            spec.infoTitle = g_i18n:getText(string.sub(spec.infoTitle,7))
        end
        box.title = spec.infoTitle
    end


    --If removeInfo string is not nil, then proceed to separate indices within the string and replace any special case spaces
    if spec.removeInfo ~= nil then
        local indices = CustomVehicleInfo.prepareTableFromString(spec.removeInfo)
        for i = #indices, 1 , -1 do
            table.remove(box.activeLines,indices[i])
        end
    end

 end

---Called to modify given string into index table
--@return a table value containing all indices that should be removed from UI info box.
function CustomVehicleInfo.prepareTableFromString(inString)

    local indiceTable = {}
    local currentWord = ""
    for i = 1, #inString do
        local char = inString:sub(i,i)

        if char ~= " " then
            currentWord = currentWord .. char
        end

        if char == " " and currentWord ~= "" or currentWord ~= "" and string.len(inString) == i then
            local newIndex = tonumber(currentWord)
            local bAdded = false
            for i,value in ipairs(indiceTable) do
                if value > newIndex then
                    table.insert(indiceTable,i,newIndex)
                    bAdded = true
                    break
                end
            end

            if not bAdded then
                table.insert(indiceTable,newIndex)
            end

            currentWord = ""
        end

    end

    return indiceTable
end

---On load create the spec path, and check xml for values
function CustomVehicleInfo:onLoad(savegame)
	--- Register the spec
	self.spec_customVehicleInfo = self["spec_FS22_BirdFeeder.customVehicleInfo"]
    local spec = self.spec_customVehicleInfo
    local xmlFile = self.xmlFile
    spec.infoTitle = xmlFile:getValue("vehicle.customVehicleInfo#uiInfoTitle")
    spec.removeInfo = xmlFile:getValue("vehicle.customVehicleInfo#uiLinesToRemove")

end


