priceWatcher = {}
addModEventListener(priceWatcher)

function priceWatcher:loadMap(name)
    print("[PW] Loading priceWatcher")
    self.FillTypes = g_fillTypeManager.fillTypes
    self.difficultyMult = g_currentMission.economyManager:getPriceMultiplier()
    self.FillMaxPrices = {}
    self.TARGET_PERCENT_OF_MAX = 0.9
    self.NEW_MAX_PRICE_COLOR = {
        0.0976,
		0.624,
		0,
		1
    }
    self.HIGH_PRICE_COLOR = {
        0,
        0.235,
        0.797,
        1
    }
    self.NOTIFICATION_DURATION = 5000
    print("[PW] Detected difficulty multiplier: " .. self.difficultyMult)
    local path = g_currentMission.missionInfo.savegameDirectory
    if path ~= nil then
        self.xmlPath = path .. "/priceWatcher.xml"
    else
        self.xmlPath = getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex .. "/priceWatcher.xml"
    end
    Logging.info("[PW] - XML Path set to " .. self.xmlPath)

    if self.xmlPath ~= nil and fileExists(self.xmlPath) then
        print("[PW] Begin parsing XML")
        self:parseXmlFile(self.xmlPath)
        print("[PW] Completed XML Parsing")
    else
        print("[PW] XML file not found.  Creating...")
        self:initializeXmlFile(self.xmlPath)
        print("[PW] XML file created")
    end
    --DebugUtil.printTableRecursively(g_currentMission.economyManager.sellingStations, ">>", 0, 6)
    g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.checkPrices, self)
end

function priceWatcher:parseXmlFile(xmlFile)
    local xml = loadXMLFile("priceWatcher", xmlFile)
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        if fillType.pricePerLiter ~= 0 then
            self.FillMaxPrices[fillType.name] = Utils.getNoNil(getXMLFloat(xml, "priceWatcher.FillTypes." .. fillType.name), 0)
            print("[PW] Loaded price data for " .. fillType.title)
        end
    end
    delete(xml)
end

function priceWatcher:initializeXmlFile(xmlFile)
    --create XMLFile
    local xml = createXMLFile("priceWatcher", xmlFile, "priceWatcher")
    --Populate table
    for _, fillType in ipairs(g_fillTypeManager.fillTypes) do
        if fillType.pricePerLiter > 0 then
            local seasonMax = 1
            for _, v in ipairs(fillType.economy.factors) do
                if v > seasonMax then
                    seasonMax = v
                end
            end
            local maxPrice = self.round(fillType.pricePerLiter * self.difficultyMult * seasonMax, 3)
            self.FillMaxPrices[fillType.name] = maxPrice
            setXMLFloat(xml, "priceWatcher.FillTypes." .. fillType.name, maxPrice)
        end
    end
    saveXMLFile(xml)
    delete(xml)
end

function priceWatcher:checkPrices()
    print("[PW] Checking Prices")
    local tableIsDirty = false
    local currentHighPrices = {}
    for _,sellingStation in pairs(g_currentMission.economyManager.sellingStations) do
        for i,supported in pairs(sellingStation.station.supportedFillTypes) do
            local fillType = g_fillTypeManager:getFillTypeByIndex(i)
            local fillPrice = self.round(sellingStation.station:getEffectiveFillTypePrice(i), 3)
            if ((currentHighPrices[fillType.name] == nil) or (fillPrice > currentHighPrices[fillType.name][3])) then
                currentHighPrices[fillType.name] = {fillType.title, sellingStation.station:getName(), fillPrice}
            end
        end
    end
    for k,v in pairs(currentHighPrices) do
        if self.FillMaxPrices[k] == nil then
            print(string.format("%s, which hasn't been recorded was found selling at %s for $%.3f", v[1], v[2], v[3]))
            self.FillMaxPrices[k] = v[3]
            tableIsDirty = true
        elseif self.FillMaxPrices[k] < v[3] then
            g_currentMission.hud:addSideNotification(self.NEW_MAX_PRICE_COLOR, string.format("%s has reached a new max price at %s.  $%.3f -> $%.3f", v[1], v[2], self.FillMaxPrices[k], v[3]), self.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
            self.FillMaxPrices[k] = v[3]
            tableIsDirty = true
        elseif (self.FillMaxPrices[k] * 0.9) <= v[3] then
            g_currentMission.hud:addSideNotification(self.HIGH_PRICE_COLOR, string.format("%s is at 90%% or more of it's max value at %s.  $%.3f/$%.3f", v[1], v[2], v[3], self.FillMaxPrices[k]), self.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
        end
    end
    if tableIsDirty then
        Logging.info("[PW] - Tables Updated, saving to XML")
        self:saveXmlFile(self.xmlPath)
        tableIsDirty = false
    end
end

function priceWatcher:saveXmlFile(xmlFile)
    if g_currentMission:getIsClient() and not g_currentMission:getIsServer() and not g_currentMission.isMasterUser then
        return
    end
  
    if not fileExists(xmlFile) then
        self:initializeXmlFile(xmlFile)
    end
    local xml = loadXMLFile("priceWatcher", xmlFile)
    for k,v in pairs(self.FillMaxPrices) do
        setXMLFloat(xml, "priceWatcher.FillTypes." .. k, v)
    end
    saveXMLFile(xml)
    delete(xml)
end


function priceWatcher.round(number, decimalPlaces)
    return (math.floor(number * 10^decimalPlaces) / 10^decimalPlaces)
end