priceWatcher = {}
priceWatcher.version = "1.0.0.7"
addModEventListener(priceWatcher)

function priceWatcher:loadMap(name)
    Logging.info("[PW] Loading priceWatcher")
    priceWatcher.FillTypes = g_fillTypeManager.fillTypes
    priceWatcher.difficultyMult = g_currentMission.economyManager:getPriceMultiplier()
    priceWatcher.FillMaxPrices = {}
    priceWatcher.TARGET_PERCENT_OF_MAX = 0.9
    priceWatcher.NEW_MAX_PRICE_COLOR = {
        0.0976,
		0.624,
		0,
		1
    }
    priceWatcher.HIGH_PRICE_COLOR = {
        0,
        0.235,
        0.797,
        1
    }
    priceWatcher.NOTIFICATION_DURATION = 15000
    priceWatcher.DO_NOT_TRACK_FILLTYPES = {
        OILSEEDRADISH=true,
        SHEEP_BLACK_WELSH=true,
        SHEEP_LANDRACE=true,
        SHEEP_STEINSCHAF=true,
        SHEEP_SWISS_MOUNTAIN=true,
        SEEDS=true,
        DIESEL=true,
        SILAGE_ADDITIVE=true,
        PIGFOOD=true,
        ROUNDBALE=true,
        ROUNDBALE_COTTON=true,
        ROUNDBALE_GRASS=true,
        ROUNDBALE_DRYGRASS=true,
        ROUNDBALE_WOOD=true,
        SQUAREBALE=true,
        SQUAREBALE_COTTON=true,
        SQUAREBALE_GRASS=true,
        SQUAREBALE_DRYGRASS=true,
        SQUAREBALE_WOOD=true,
        FERTILIZER=true,
        LIQUIDFERTILIZER=true,
        HERBICIDE=true,
        TREESAPLINGS=true,
        LIQUIDMANURE=true,
        PIG_BERKSHIRE=true,
        PIG_BLACK_PIED=true,
        PIG_LANDRACE=true,
        DRYGRASS_WINDROW=true,
        GRASS_WINDROW=true,
        COW_ANGUS=true,
        COW_HOLSTEIN=true,
        COW_LIMOUSIN=true,
        COW_SWISS_BROWN=true,
        LIME=true,
        WATER=true,
        MINERAL_FEED=true,
        ELECTRICCHARGE=true,
        FORAGE=true,
        FORAGE_MIXING=true,
        DEF=true,
        METHANE=true,
        STONE=true
    }
    Logging.info("[PW] Detected difficulty multiplier: " .. priceWatcher.difficultyMult)
    local path = g_currentMission.missionInfo.savegameDirectory
    if path ~= nil then
        priceWatcher.xmlPath = path .. "/priceWatcher.xml"
    else
        priceWatcher.xmlPath = getUserProfileAppPath() .. "savegame" .. g_currentMission.missionInfo.savegameIndex .. "/priceWatcher.xml"
    end
    Logging.info("[PW] - XML Path set to " .. priceWatcher.xmlPath)

    if priceWatcher.xmlPath ~= nil and fileExists(priceWatcher.xmlPath) then
        Logging.info("[PW] Begin parsing XML")
        priceWatcher:parseXmlFile()
        Logging.info("[PW] Completed XML Parsing")
    else
        Logging.info("[PW] XML file not found.  Creating...")
        priceWatcher:initializeXmlFile()
        Logging.info("[PW] XML file created")
    end
    --DebugUtil.printTableRecursively(g_currentMission.economyManager.sellingStations, ">>", 0, 6)
    g_messageCenter:subscribe(MessageType.HOUR_CHANGED, priceWatcher.checkPrices, priceWatcher)
    FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, priceWatcher.saveSavegame)
end

function priceWatcher.saveSavegame()
    if g_server ~= nil then
        Logging.info("Savegame Detected, writing price data...")
        priceWatcher:saveToXML()
    end
end

function priceWatcher:saveToXML()
    local xmlFile = createXMLFile("priceWatcher", priceWatcher.xmlPath, "priceWatcher")

    setXMLString(xmlFile, "priceWatcher.version", priceWatcher.version)
    for k,v in pairs(priceWatcher.FillMaxPrices) do
        setXMLFloat(xmlFile, "priceWatcher.FillTypes." .. k, v)
    end
    saveXMLFile(xmlFile)
    Logging.info("[PW] - Price data saved")
end

function priceWatcher:parseXmlFile()
    local xml = loadXMLFile("priceWatcher", priceWatcher.xmlPath)
    for _,fillType in ipairs(g_fillTypeManager.fillTypes) do
        if fillType.pricePerLiter ~= 0 then
            priceWatcher.FillMaxPrices[fillType.name] = Utils.getNoNil(getXMLFloat(xml, "priceWatcher.FillTypes." .. fillType.name), 0)
            Logging.info("[PW] Loaded price data for " .. fillType.title)
        end
    end
    delete(xml)
end

function priceWatcher:initializeXmlFile()
    --create XMLFile
    --local xml = createXMLFile("priceWatcher", priceWatcher.xmlPath, "priceWatcher")
    --Populate table
    for _, fillType in ipairs(g_fillTypeManager.fillTypes) do
        if ((fillType.pricePerLiter > 0) and (priceWatcher.DO_NOT_TRACK_FILLTYPES[fillType.name] == nil)) then
            local seasonMax = 1
            for _, v in ipairs(fillType.economy.factors) do
                if v > seasonMax then
                    seasonMax = v
                end
            end
            local maxPrice = priceWatcher.round((fillType.pricePerLiter * seasonMax + 0.2 * fillType.pricePerLiter) * priceWatcher.difficultyMult, 3)
            priceWatcher.FillMaxPrices[fillType.name] = maxPrice
            --setXMLFloat(xml, "priceWatcher.FillTypes." .. fillType.name, maxPrice)
        end
    end
    --saveXMLFile(xml)
    --delete(xml)
end

function priceWatcher:checkPrices()
    Logging.info("[PW] - Checking Prices")
    local tableIsDirty = false
    local currentHighPrices = {}
    for _,sellingStation in pairs(g_currentMission.economyManager.sellingStations) do
        for i,supported in pairs(sellingStation.station.supportedFillTypes) do
            local fillType = g_fillTypeManager:getFillTypeByIndex(i)
            local fillPrice = priceWatcher.round(sellingStation.station:getEffectiveFillTypePrice(i), 3)
            if ((priceWatcher.DO_NOT_TRACK_FILLTYPES[fillType.name] == nil) and ((currentHighPrices[fillType.name] == nil) or (fillPrice > currentHighPrices[fillType.name][3]))) then
                currentHighPrices[fillType.name] = {fillType.title, sellingStation.station:getName(), fillPrice}
            end
        end
    end
    for k,v in pairs(currentHighPrices) do
        if priceWatcher.FillMaxPrices[k] == nil then
            print(string.format("%s, which hasn't been recorded was found selling at %s for $%.3f", v[1], v[2], v[3]))
            priceWatcher.FillMaxPrices[k] = v[3]
            tableIsDirty = true
        elseif priceWatcher.FillMaxPrices[k] < v[3] then
            g_currentMission.hud:addSideNotification(priceWatcher.NEW_MAX_PRICE_COLOR, string.format("%s has reached a new max price at %s.  $%.3f -> $%.3f", v[1], v[2], priceWatcher.FillMaxPrices[k], v[3]), priceWatcher.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
            priceWatcher.FillMaxPrices[k] = v[3]
            tableIsDirty = true
        elseif (priceWatcher.FillMaxPrices[k] * 0.9) <= v[3] then
            g_currentMission.hud:addSideNotification(priceWatcher.HIGH_PRICE_COLOR, string.format("%s is at 90%% or more of it's max value at %s.  $%.3f/$%.3f", v[1], v[2], v[3], priceWatcher.FillMaxPrices[k]), priceWatcher.NOTIFICATION_DURATION, GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
        end
    end
    if tableIsDirty then
        Logging.info("[PW] - Tables Updated")
        --priceWatcher:saveToXML()
        tableIsDirty = false
    end
end


function priceWatcher.round(number, decimalPlaces)
    return (math.floor(number * 10^decimalPlaces) / 10^decimalPlaces)
end