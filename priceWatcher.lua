source(Utils.getFilename("events/PriceWatcherEvents.lua", g_currentModDirectory))

priceWatcher = {}
priceWatcher.VERSION = g_modManager:getModByName(g_currentModName).version
priceWatcher.MOD_NAME = g_currentModName
priceWatcher.BASE_DIRECTORY = g_currentModDirectory
priceWatcher.MOD_SETTINGS = getUserProfileAppPath() .. "modSettings"
priceWatcher.TARGET_PERCENT_OF_MAX = 0.95
priceWatcher.ALL_TIME_HIGH_COLOR = {0.767, 0.006, 0.006, 1}
priceWatcher.TWELVE_MONTH_HIGH_COLOR = {1, 0.687, 0, 1}
priceWatcher.NEW_TWELVE_MONTH_HIGH_COLOR = {0.0976, 0.624, 0, 1}
priceWatcher.HIGH_PRICE_COLOR = {0, 0.235, 0.797, 1}
priceWatcher.NOTIFICATION_DURATION = 10000
priceWatcher.DO_NOT_TRACK_FILLTYPES = {
    UNKNOWN=true,
    SEEDS=true,
    WATER=true,
    TOTAL_MIXED_RATION=true,
    FORAGE=true,
    CHAFF=true,
    TREE_SAPLINGS=true,
    OILSEED_RADISH=true,
    POPLAR=true,
    WOOD=true,
    DIESEL=true,
    DIESEL_EXHAUST_FLUID=true,
    AIR=true,
    ELECTRIC_CHARGE=true,
    METHANE=true,
    SNOW=true,
    ROAD_SALT=true,
    ROUND_BALE=true,
    ROUND_BALE_GRASS=true,
    ROUND_BALE_HAY=true,
    ROUND_BALE_COTTON=true,
    ROUND_BALE_WOOD=true,
    SQUARE_BALE=true,
    SQUARE_BALE_COTTON=true,
    SQUARE_BALE_WOOD=true,
    SOLID_FERTILIZER=true,
    LIQUID_FERTILIZER=true,
    DIGESTATE=true,
    PIG_FOOD=true,
    TARP=true,
    LIME=true,
    HERBICIDE=true,
    SILAGE_ADDITIVE=true,
    MINERAL_FEED=true,
    WEED=true,
    HORSE=true,
    COW=true,
    SHEEP=true,
    PIG=true,
    CHICKEN=true,
    SQUARE_BALE_GRASS=true,
    SQUARE_BALE_HAY=true,
    STONES=true
}
priceWatcher.AllTimeHighPrices = {}
priceWatcher.AnnualHighPrices = {}
priceWatcher.configXML = nil
priceWatcher.TrackPrices = {}
priceWatcher.DEBUGMODE = false
priceWatcher.MIN_XML_VERSION = 1010001
addModEventListener(priceWatcher)

--source(Utils.getFilename("hud/priceWatcherHud.lua", priceWatcher.BASE_DIRECTORY))
function priceWatcher:loadMap(name)
    priceWatcher.info("Loading Price Watcher v" .. priceWatcher.VERSION)
    priceWatcher.FillTypes = g_fillTypeManager.fillTypes
    priceWatcher.difficultyMult = g_currentMission.economyManager:getPriceMultiplier()
    priceWatcher.debug("Detected difficulty multiplier: " .. priceWatcher.difficultyMult)
    local path = g_currentMission.missionInfo.savegameDirectory
    if fileExists(priceWatcher.MOD_SETTINGS .. "/priceWatcherDebugEnable") then
        priceWatcher.DEBUGMODE = true
        priceWatcher.info("DEBUG MODE ENABLED")
    end
    if path ~= nil then
        priceWatcher.xmlPath = path .. "/priceWatcher.xml"
    else
        priceWatcher.xmlPath = getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex .. "/priceWatcher.xml"
    end
    if g_client ~=nil then
        priceWatcher.configXML = getUserProfileAppPath() .. "modSettings/priceWatcherConfig.xml"
        if fileExists(priceWatcher.configXML) then
            priceWatcher.loadConfig()
        else
            priceWatcher.initializeConfig()
        end
    end
    if fileExists(priceWatcher.xmlPath) then
        priceWatcher.parseXmlFile() 
    else
        priceWatcher.initializePriceData()
    end
    g_messageCenter:subscribe(MessageType.HOUR_CHANGED, priceWatcher.checkPrices, priceWatcher)
    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, priceWatcher.rollPeriod, priceWatcher)
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, priceWatcher.saveSavegame)
    priceWatcher.info("Price Watcher loading complete")
    --InGameMenuPricesFrame.updateFluctuations = Utils.overwrittenFunction(InGameMenuPricesFrame.updateFluctuations, priceWatcher.updateFluctuations)
    --Gui:loadProfiles(priceWatcher.BASE_DIRECTORY .. "/presets/guiPresets.xml")
end

function priceWatcher.saveSavegame()
    if g_server ~= nil then
        priceWatcher.info("Savegame detected.  Writing price data...")
        priceWatcher.saveToXML()
    end
end

function priceWatcher.saveToXML()
    local xmlFile = createXMLFile("priceWatcher", priceWatcher.xmlPath, "priceWatcher")

    setXMLString(xmlFile, "priceWatcher.version", priceWatcher.VERSION)
    for k,v in pairs(priceWatcher.AllTimeHighPrices) do
        setXMLFloat(xmlFile, "priceWatcher.FillTypes." .. k .. "#AllTimeHigh", v)
    end
    for k,v in pairs(priceWatcher.AnnualHighPrices) do
        for i = 1, 13 do
            setXMLFloat(xmlFile, "priceWatcher.FillTypes." .. k .. ".period" .. i, v[i])
        end
    end
    saveXMLFile(xmlFile)
    priceWatcher.info("Price data saved")
end

function priceWatcher.parseXmlFile()
    local xml = loadXMLFile("priceWatcher", priceWatcher.xmlPath)
    local xmlVersionString = getXMLString(xml, "priceWatcher.version")
    local xmlVersion = priceWatcher.getVersion(xmlVersionString)
    priceWatcher.debug("XML Version: " .. xmlVersion .. "(" .. xmlVersionString .. ")")
    if xmlVersion < priceWatcher.MIN_XML_VERSION then
        priceWatcher.warning("XML Version " .. xmlVersion .. " < " .. priceWatcher.MIN_XML_VERSION .. "(Min Req Ver).  New price data will be generated.")
        delete(xml)
        priceWatcher.initializePriceData()
        return
    end
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
        if priceWatcher.DO_NOT_TRACK_FILLTYPES[saveSafeName] == nil then
            local periods = {}
            for i = 1, 13 do
                local price = getXMLFloat(xml, "priceWatcher.FillTypes." .. saveSafeName .. ".period" .. i)
                periods[i] = Utils.getNoNil(price, 0)
                priceWatcher.debug("Loaded " .. saveSafeName .. " period" .. i .. ": $" .. Utils.getNoNil(price, 0) .. ":" .. periods[i])
            end
            priceWatcher.AnnualHighPrices[saveSafeName] = periods
            priceWatcher.AllTimeHighPrices[saveSafeName] = Utils.getNoNil(getXMLFloat(xml, "priceWatcher.FillTypes." .. saveSafeName .. "#AllTimeHigh"), 0)
            priceWatcher.debug(string.format("Loaded price data for %s: {%.3f, %.3f}", fillType.title, priceWatcher.AnnualHighPrices[saveSafeName][1], priceWatcher.AllTimeHighPrices[saveSafeName]))
        end
    end
    delete(xml)
end

function priceWatcher.loadConfig()
    priceWatcher.info("Loading client settings")
    local xmlFile = loadXMLFile("priceWatcher", priceWatcher.configXML)
    local trackedFillTypes = 0
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
        priceWatcher.TrackPrices[saveSafeName] = Utils.getNoNil(getXMLBool(xmlFile, "priceWatcher.Monitor." .. saveSafeName), false)
        if priceWatcher.TrackPrices[saveSafeName] ~= false then
            trackedFillTypes = trackedFillTypes + 1
            priceWatcher.debug(fillType.title .. " = ENABLED")
        end
    end
    priceWatcher.info("Tracking " .. trackedFillTypes .. " fill types")
    priceWatcher.TARGET_PERCENT_OF_MAX = Utils.getNoNil(getXMLFloat(xmlFile, "priceWatcher.PriceThreshold"), 0.95)
    priceWatcher.NOTIFICATION_DURATION = Utils.getNoNil(getXMLInt(xmlFile, "priceWatcher.NotificationDuration"), 10) * 1000
    priceWatcher.ALL_TIME_HIGH_COLOR = string.getVectorN(getXMLString(xmlFile, "priceWatcher.AllTimeHighColor"), 4) or {0.767, 0.006, 0.006, 1}
    priceWatcher.TWELVE_MONTH_HIGH_COLOR = string.getVectorN(getXMLString(xmlFile, "priceWatcher.AnnualHighColor"), 4) or {1, 0.687, 0, 1}
    priceWatcher.HIGH_PRICE_COLOR =string.getVectorN(getXMLString(xmlFile, "priceWatcher.NewAnnualHighColor"), 4) or {0.0976, 0.624, 0, 1}
    priceWatcher.HIGH_PRICE_COLOR =string.getVectorN(getXMLString(xmlFile, "priceWatcher.HighPriceColor"), 4) or {0, 0.235, 0.797, 1}
end

function priceWatcher.initializePriceData()
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
        local currentPeriod = g_currentMission.environment.currentPeriod
        if (priceWatcher.DO_NOT_TRACK_FILLTYPES[saveSafeName] == nil) then
            local max = fillType.pricePerLiter * g_currentMission.economyManager.getPriceMultiplier()
            local hist = {}
            for i = 1, 13 do
                local histPeriod = (currentPeriod - i) % 12 + 1
                hist[i] = Utils.getNoNil(fillType.economy.history[histPeriod], 0) * g_currentMission.economyManager.getPriceMultiplier()
                if hist[i] > max then
                    max = hist[i]
                end
            end
            priceWatcher.AnnualHighPrices[saveSafeName] = hist
            max = priceWatcher.round(max, 3)
            priceWatcher.AllTimeHighPrices[saveSafeName] = max
        end
    end

end

function priceWatcher.initializeConfig()
    local xmlFile = createXMLFile("priceWatcher", priceWatcher.configXML, "priceWatcher")
    setXMLString(xmlFile, "priceWatcher.version", priceWatcher.VERSION)
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do 
        local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
        if priceWatcher.DO_NOT_TRACK_FILLTYPES[saveSafeName] == nil then
            setXMLBool(xmlFile, "priceWatcher.Monitor." .. saveSafeName, true)
            priceWatcher.TrackPrices[saveSafeName] = true
        else
            setXMLBool(xmlFile, "priceWatcher.Monitor." .. saveSafeName, false)
            priceWatcher.TrackPrices[saveSafeName] = false
        end
    end
    setXMLFloat(xmlFile, "priceWatcher.PriceThreshold", priceWatcher.TARGET_PERCENT_OF_MAX)
    setXMLInt(xmlFile, "priceWatcher.NotificationDuration", priceWatcher.NOTIFICATION_DURATION / 1000)
    setXMLString(xmlFile, "priceWatcher.AllTimeHighColor", priceWatcher.vector4ToString(priceWatcher.ALL_TIME_HIGH_COLOR))
    setXMLString(xmlFile, "priceWatcher.AnnualHighColor", priceWatcher.vector4ToString(priceWatcher.TWELVE_MONTH_HIGH_COLOR))
    setXMLString(xmlFile, "priceWatcher.NewAnnualHighColor", priceWatcher.vector4ToString(priceWatcher.NEW_TWELVE_MONTH_HIGH_COLOR))
    setXMLString(xmlFile, "priceWatcher.HighPriceColor", priceWatcher.vector4ToString(priceWatcher.HIGH_PRICE_COLOR))
    saveXMLFile(xmlFile)
    priceWatcher.info("Initialized config file to " .. priceWatcher.configXML)
end

function priceWatcher.rollPeriod() 
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
        if (priceWatcher.DO_NOT_TRACK_FILLTYPES[saveSafeName] == nil) then
            local max = fillType.pricePerLiter
            local index = 13
            while index > 1 do
                priceWatcher.AnnualHighPrices[saveSafeName][index] = priceWatcher.AnnualHighPrices[saveSafeName][index - 1]
                index = index - 1
            end
            priceWatcher.AnnualHighPrices[saveSafeName][1] = priceWatcher.getCurrentHighPrice(fillType)
        end
    end
end

function priceWatcher.vector4ToString(vector)
    return string.format("%0.3f %0.3f %0.3f %0.3f", vector[1], vector[2], vector[3], vector[4])
end

function priceWatcher.stringToVector4(str)
    local retTable = {}
    for part in string.gmatch(str, "([%s]+)") do
        table.insert(retTable, part)
    end
    return retTable
end

function priceWatcher.getCurrentHighPrice(fillType)
    local maxPrice = 0
    for _,sellingStation in pairs(g_currentMission.economyManager.sellingStations) do
        if sellingStation.station.supportedFillTypes[fillType] ~= nil then
            if sellingStation.station:getEffectiveFillTypePrice(fillType) > maxPrice then
                maxPrice = sellingStation.station.getEffectiveFillTypePrice(fillType)
            end
        end
    end
    maxPrice = priceWatcher.round(maxPrice, 3)
    return maxPrice
end

function priceWatcher.checkPrices()
    if g_server ~= nil or g_dedicatedServer ~= nil then
        priceWatcher.debug("Checking prices")
        local tableIsDirty = false
        local currentHighPrices = {}
        for _,sellingStation in pairs(g_currentMission.economyManager.sellingStations) do
            for i,supported in pairs(sellingStation.station.supportedFillTypes) do
                local fillType = g_fillTypeManager:getFillTypeByIndex(i)
                local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
                local fillPrice = priceWatcher.round(sellingStation.station:getEffectiveFillTypePrice(i), 3)
                if ((priceWatcher.DO_NOT_TRACK_FILLTYPES[saveSafeName] == nil) and ((currentHighPrices[saveSafeName] == nil) or (fillPrice > currentHighPrices[saveSafeName][3]))) then
                    currentHighPrices[saveSafeName] = {fillType.title, sellingStation.station:getName(), fillPrice}
                end
            end
        end
        for k,v in pairs(currentHighPrices) do
            if priceWatcher.AnnualHighPrices[k][1] < v[3] then
                priceWatcher.AnnualHighPrices[k][1] = v[3]
            end
            local annualHighPrice = 0
            for i = 1,13 do
                if priceWatcher.AnnualHighPrices[k][i] > annualHighPrice then
                    annualHighPrice = priceWatcher.AnnualHighPrices[k][i]
                end
            end
            if priceWatcher.AllTimeHighPrices[k] <= v[3] or priceWatcher.AllTimeHighPrices[k] == nil then
                priceWatcher.AllTimeHighPrices[k] = v[3]
                priceWatcher.debug(string.format("NotifyClient: %s, %s, %s, %s, %s, %s, %s", tostring(k), tostring(1), tostring(v[1]), tostring(v[2]), tostring(v[3]), tostring(nil), tostring(nil)))
                --priceWatcher.notifyClient(k, 1, v[1], v[2], v[3], nil, nil)
                PriceWatcherEvent.sendEvent(k, 1, v[1], v[2], v[3], 0, 0)
                tableIsDirty = true
            elseif annualHighPrice <= v[3] or priceWatcher.AnnualHighPrices[k] == nil then
                priceWatcher.AnnualHighPrices[k][1] = v[3]
                priceWatcher.debug(string.format("NotifyClient: %s, %s, %s, %s, %s, %s, %s", tostring(k), tostring(2), tostring(v[1]), tostring(v[2]), tostring(v[3]), tostring(nil), tostring(nil)))
                --priceWatcher.notifyClient(k, 2, v[1], v[2], v[3], nil, nil)
                PriceWatcherEvent.sendEvent(k, 2, v[1], v[2], v[3], 0, 0)
                tableIsDirty = true
            elseif (annualHighPrice * priceWatcher.TARGET_PERCENT_OF_MAX) <= v[3] then
                local pct = math.ceil(priceWatcher.TARGET_PERCENT_OF_MAX * 100)
                --priceWatcher.notifyClient(k, 3, v[1], v[2], v[3], pct, annualHighPrice)
                PriceWatcherEvent.sendEvent(k, 3, v[1], v[2], v[3], pct, annualHighPrice)
                priceWatcher.debug(string.format("NotifyClient: %s, %s, %s, %s, %s, %s, %s", tostring(k), tostring(3), tostring(v[1]), tostring(v[2]), tostring(v[3]), tostring(pct), tostring(annualHighPrice)))
            end
        end
        if tableIsDirty then
            priceWatcher.debug("Tables udpated")
            tableIsDirty = false
        end
    else
        priceWatcher.debug("IS NOT SERVER, NO PRICE CHECK HERE")
    end
end

function priceWatcher.notifyClient(saveSafeName, notificationType, fillTypeTitle, fillStationName, fillPrice, pct, annualHigh)
    if priceWatcher.TrackPrices[saveSafeName] ~= false then
        if notificationType == 1 then
            priceWatcher.debug("Received all time high notification for " .. fillTypeTitle)
            g_currentMission.hud:addSideNotification(priceWatcher.ALL_TIME_HIGH_COLOR, string.format(g_i18n:getText("PW_NEW_ALL_TIME_MAX"), fillTypeTitle, fillPrice, fillStationName), priceWatcher.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
        elseif notificationType == 2 then
            priceWatcher.debug("Received annual high notification for " .. fillTypeTitle)
            g_currentMission.hud:addSideNotification(priceWatcher.NEW_TWELVE_MONTH_HIGH_COLOR, string.format(g_i18n:getText("PW_NEW_TWELVE_MONTH_HIGH"), fillTypeTitle, fillPrice, fillStationName), priceWatcher.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
        elseif notificationType == 3 then
            priceWatcher.debug("Received price threshold notification for " .. fillTypeTitle)
            g_currentMission.hud:addSideNotification(priceWatcher.HIGH_PRICE_COLOR, string.format(g_i18n:getText("PW_CLOSE_MAX"), fillTypeTitle, pct, fillStationName, fillPrice, annualHigh), priceWatcher.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
        else
            priceWatcher.warning("notifyClient passed unknown notificationType: " .. notificationType)
        end
    else
        priceWatcher.debug("Received notification for ignored fillType: " .. fillTypeTitle)
    end
end

function priceWatcher.round(number, decimalPlaces)
    return (math.floor(number * 10^decimalPlaces) / 10^decimalPlaces)
end

function priceWatcher.onMissionWillLoad(i18n)
	priceWatcher.addModTranslations(i18n)
end

function priceWatcher.addModTranslations(i18n)
	local global = getfenv(0).g_i18n.texts
	for key, text in pairs(i18n.texts) do
		global[key] = text
	end
end

function priceWatcher:updateFluctuations()
	local fillTypeDesc = self.fillTypes[self.productList.selectedIndex]
	local originalPrice = fillTypeDesc.pricePerLiter
	local currentPrice = originalPrice
	local totalPrice = 0
	local totalNumPrices = 0

	for _, station in ipairs(self.currentStations) do
		if station.uiIsSelling then
			totalPrice = totalPrice + station:getEffectiveFillTypePrice(fillTypeDesc.index)
			totalNumPrices = totalNumPrices + 1
		end
	end

	if totalNumPrices > 0 then
		currentPrice = totalPrice / totalNumPrices
	end

	local prices = fillTypeDesc.economy.history
	local min = math.huge
	local max = 0

	for i = 1, 12 do
		min = math.min(min, prices[i])
		max = math.max(max, prices[i])
	end

	local range = max - min
	min = math.max(min - range * 0.2, 0)
	max = max + range * 0.2
	local hasAnyFluctuations = min ~= max

	self.noFluctuationsText:setVisible(not hasAnyFluctuations)
	self.fluctuationsLayout:setVisible(hasAnyFluctuations)
	self.fluctuationCurrentPrice:setVisible(hasAnyFluctuations)

	if not hasAnyFluctuations then
		return
	end

	for month = 1, 12 do
		local barBg = self.fluctuationBars[month]
		local bar = barBg.elements[1]
		local percentageInView = (prices[month] - min) / (max - min)
		local prevPercentageInView = (prices[(month - 2) % 12 + 1] - min) / (max - min)
		local diff = percentageInView - prevPercentageInView

		if diff > 0 then
			barBg:applyProfile("ingameMenuPriceFluctuationBarBgUp")
			bar:applyProfile("ingameMenuPriceFluctuationBarUp")
			barBg:setPosition(nil, prevPercentageInView * barBg.parent.absSize[2])
		else
			barBg:applyProfile("ingameMenuPriceFluctuationBarBgDown")
			bar:applyProfile("ingameMenuPriceFluctuationBarDown")
			barBg:setPosition(nil, percentageInView * barBg.parent.absSize[2])
		end
        if priceWatcher.TABLEPRINTED == nil then
            local xmlFile = createXMLFile("priceWatcher", priceWatcher.MOD_SETTINGS .. "/fluctuationbars4.xml", "priceWatcher")
            priceWatcher.printTableRecursivelyToXML(self.fluctuationBars[4], "fluctuationBars", 0, 1, xmlFile, "priceWatcher")
            saveXMLFile(xmlFile)
            priceWatcher.TABLEPRINTED = true
        end
		barBg:setSize(nil, math.abs(diff) * barBg.parent.absSize[2])
	end

	local currentFactor = currentPrice / originalPrice

	if originalPrice == 0 then
		currentFactor = 1
	end

	local currentPosition = math.max(math.min((currentFactor - min) / (max - min), 1), 0)

	self.fluctuationCurrentPrice:setPosition(nil, currentPosition * (self.fluctuationCurrentPrice.parent.absSize[2] - self.fluctuationsColumn.elements[1].absSize[2]))

	for i = 1, 12 do
		self.fluctuationMonthHeader[i]:setText(g_i18n:formatPeriod(i, true))
	end
end

function priceWatcher.printTableRecursivelyToXML(value,parentName, depth, maxDepth,xmlFile,baseKey)
	depth = depth or 0
	maxDepth = maxDepth or 3
	if depth > maxDepth then
		return
	end
	local key = string.format('%s.depth:%d',baseKey,depth)
	local k = 0
	for i,j in pairs(value) do
		local key = string.format('%s(%d)',key,k)
		local valueType = type(j) 
		setXMLString(xmlFile, key .. '#valueType', tostring(valueType))
		setXMLString(xmlFile, key .. '#index', tostring(i))
		setXMLString(xmlFile, key .. '#value', tostring(j))
		setXMLString(xmlFile, key .. '#parent', tostring(parentName))
		if valueType == "table" then
			priceWatcher.printTableRecursivelyToXML(j,parentName.."."..tostring(i),depth+1, maxDepth,xmlFile,key)
		end
		k = k + 1
	end
end

function priceWatcher.getVersion(versionString)
    local versionTable = {}
    for part in string.gmatch(versionString, "([%d]+)") do
        table.insert(versionTable, tonumber(part))
    end
    return versionTable[1] * 1000000 + versionTable[2] * 10000 + versionTable[3] * 100 + versionTable[4]
end

function priceWatcher.info(message)
    print(string.format("PW::INFO    - %s", tostring(message)))
end

function priceWatcher.warning(message)
    print(string.format("PW::WARNING - %s", tostring(message)))
end

function priceWatcher.error(message)
    print(string.format("PW::ERROR   - %s", tostring(message)))
end

function priceWatcher.debug(message)
    if priceWatcher.DEBUGMODE == true then
        print(string.format("PW::DEBUG   - %s", tostring(message)))
    end
end