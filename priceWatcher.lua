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
    SQUARE_BALE_HAY=true
}
priceWatcher.AllTimeHighPrices = {}
priceWatcher.AnnualHighPrices = {}

addModEventListener(priceWatcher)

function priceWatcher:loadMap(name)
    Logging.info("[PW] Loading priceWatcher v" .. priceWatcher.VERSION)
    priceWatcher.FillTypes = g_fillTypeManager.fillTypes
    priceWatcher.difficultyMult = g_currentMission.economyManager:getPriceMultiplier()

    Logging.info("[PW] Detected difficulty multiplier: " .. priceWatcher.difficultyMult)
    local path = g_currentMission.missionInfo.savegameDirectory
    if path ~= nil then
        priceWatcher.xmlPath = path .. "/priceWatcher.xml"
    else
        priceWatcher.xmlPath = getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex .. "/priceWatcher.xml"
    end
    if fileExists(priceWatcher.xmlPath) then
        priceWatcher.parseXmlFile() 
    else
        priceWatcher.initializePriceData()
    end
    g_messageCenter:subscribe(MessageType.HOUR_CHANGED, priceWatcher.checkPrices, priceWatcher)
    g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, priceWatcher.rollPeriod, priceWatcher)
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, priceWatcher.saveSavegame)
    --InGameMenuPricesFrame.updateFluctuations = Utils.overwrittenFunction(InGameMenuPricesFrame.updateFluctuations, priceWatcher.updateFluctuations)
    --Gui:loadProfiles(priceWatcher.BASE_DIRECTORY .. "/presets/guiPresets.xml")
end

function priceWatcher.saveSavegame()
    if g_server ~= nil then
        Logging.info("Savegame Detected, writing price data...")
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
        setXMLFloat(xmlFile, "priceWatcher.FillTypes." .. k .. "#AnnualHigh", v)
    end
    saveXMLFile(xmlFile)
    Logging.info("[PW] - Price data saved")
end

function priceWatcher.parseXmlFile()
    local xml = loadXMLFile("priceWatcher", priceWatcher.xmlPath)
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
        if priceWatcher.DO_NOT_TRACK_FILLTYPES[saveSafeName] == nil then
            priceWatcher.AnnualHighPrices[saveSafeName] = Utils.getNoNil(getXMLFloat(xml, "priceWatcher.FillTypes." .. saveSafeName .. "#AnnualHigh"), 0)
            priceWatcher.AllTimeHighPrices[saveSafeName] = Utils.getNoNil(getXMLFloat(xml, "priceWatcher.FillTypes." .. saveSafeName .. "#AllTimeHigh"), 0)
            Logging.info(string.format("[PW] Loaded price data for %s: {%.3f, %.3f}", fillType.title, priceWatcher.AnnualHighPrices[saveSafeName], priceWatcher.AllTimeHighPrices[saveSafeName]))
        end
    end
    delete(xml)
end

function priceWatcher.initializePriceData()
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
        if (priceWatcher.DO_NOT_TRACK_FILLTYPES[saveSafeName] == nil) then
            local max = fillType.pricePerLiter
            for i,v in ipairs(fillType.economy.history) do 
                if v > max then
                    max = v
                end
            end
            max = max * g_currentMission.economyManager:getPriceMultiplier()
            max = priceWatcher.round(max, 3)
            priceWatcher.AnnualHighPrices[saveSafeName] = max
            priceWatcher.AllTimeHighPrices[saveSafeName] = max
        end
    end
end

function priceWatcher.rollPeriod() 
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        local saveSafeName = string.upper(string.gsub(fillType.title, " ", "_"))
        if (priceWatcher.DO_NOT_TRACK_FILLTYPES[saveSafeName] == nil) then
            local max = fillType.pricePerLiter
            for i,v in ipairs(fillType.economy.history) do 
                if v > max then
                    max = v
                end
            end
            max = max * g_currentMission.economyManager:getPriceMultiplier()
            max = priceWatcher.round(max, 3)
            priceWatcher.AnnualHighPrices[saveSafeName] = max
        end
    end
end

function priceWatcher.checkPrices()
    Logging.info("[PW] - Checking Prices")
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
        if priceWatcher.AllTimeHighPrices[k] <= v[3] or priceWatcher.AllTimeHighPrices[k] == nil then
            priceWatcher.AllTimeHighPrices[k] = v[3]
            g_currentMission.hud:addSideNotification(priceWatcher.ALL_TIME_HIGH_COLOR, string.format(g_i18n:getText("PW_NEW_ALL_TIME_MAX"), v[1], v[3], v[2]), priceWatcher.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
            tableIsDirty = true
        elseif priceWatcher.AnnualHighPrices[k] <= v[3] or priceWatcher.AnnualHighPrices[k] == nil then
            priceWatcher.AnnualHighPrices[k] = v[3]
            g_currentMission.hud:addSideNotification(priceWatcher.NEW_TWELVE_MONTH_HIGH_COLOR, string.format(g_i18n:getText("PW_NEW_TWELVE_MONTH_HIGH"), v[1], v[3], v[2]), priceWatcher.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
            tableIsDirty = true
        elseif (priceWatcher.AnnualHighPrices[k] * priceWatcher.TARGET_PERCENT_OF_MAX) <= v[3] then
            local high = math.ceil(priceWatcher.TARGET_PERCENT_OF_MAX * 100)
            g_currentMission.hud:addSideNotification(priceWatcher.HIGH_PRICE_COLOR, string.format(g_i18n:getText("PW_CLOSE_MAX"), v[1], high, v[2], v[3], priceWatcher.AnnualHighPrices[k]), priceWatcher.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
        end
    end
    if tableIsDirty then
        Logging.info("[PW] - Tables Updated")
        tableIsDirty = false
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