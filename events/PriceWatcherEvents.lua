PriceWatcherEvent = {}
PriceWatcherEvent_mt = Class(PriceWatcherEvent, Event)

InitEventClass(PriceWatcherEvent, "PriceWatcherEvent")

function PriceWatcherEvent.emptyNew()
    local self = Event.new(PriceWatcherEvent_mt)
    return self
end

function PriceWatcherEvent.new(fillTypeSafeName, notificationType, fillTypeTitle, fillStationName, fillPrice, pct, annualHigh)
    local self = PriceWatcherEvent.emptyNew()
    self.fillTypeSafeName = fillTypeSafeName
    self.notificationType = notificationType
    self.fillTypeTitle = fillTypeTitle
    self.fillStationName = fillStationName
    self.fillPrice = fillPrice
    self.pct = pct
    self.annualHigh = annualHigh
    return self
end

function PriceWatcherEvent:writeStream(streamId)
    if self.fillTypeSafeName == nil or self.fillTypeSafeName == "" then
        self.fillTypeSafeName = "UNKNOWN"
    end
    if self.fillTypeTitle == nil or self.fillTypeTitle == "" then
        self.fillTypeTitle = "Unknown"
    end
    if self.fillStationName == nil or self.fillStationName == "" then
        self.fillStationName = "Unknown"
    end
    if self.fillPrice == nil then
        self.fillPrice = 0
    end
    if self.pct == nil then
        self.pct = 0
    end
    if self.annualHigh == nil then
        self.annualHigh = 0
    end
    streamWriteString(streamId, self.fillTypeSafeName)
    streamWriteInt32(streamId, self.notificationType)
    streamWriteString(streamId, self.fillTypeTitle)
    streamWriteString(streamId, self.fillStationName)
    streamWriteFloat32(streamId, self.fillPrice)
    streamWriteFloat32(streamId, self.pct)
    streamWriteFloat32(streamId, self.annualHigh)
end

function PriceWatcherEvent:readStream(streamId, connection)
    local ftsn = streamReadString(streamId)
    if ftsn == nil or ftsn == "" then
        ftsn = "UNKNOWN"
    end
    self.fillTypeSafeName = ftsn
    self.notificationType = streamReadInt32(streamId)
    local ftt = streamReadString(streamId)
    if ftt == nil or ftt == "" then
        ftt = "Unknown"
    end
    self.fillTypeTitle = ftt
    local fsn = streamReadString(streamId)
    if fsn == nil or fsn == "" then
        fsn = "Unknown"
    end
    self.fillStationName = fsn
    self.fillPrice = streamReadFloat32(streamId)
    self.pct = streamReadFloat32(streamId)
    self.annualHigh = streamReadFloat32(streamId)
    self:run(connection)
end

function PriceWatcherEvent:run(connection)
    if g_server ~= nil and connection:getIsServer() == false then
        --event is coming from client
        PriceWatcherEvent.sendEvent(self.fillTypeSafeName, self.notificationType, self.fillTypeTitle, self.fillStationName, self.fillPrice, self.pct, self.annualHigh)
    else
        --event is coming from server
        if self.fillTypeSafeName ~= "" then
            priceWatcher.notifyClient(self.fillTypeSafeName, self.notificationType, self.fillTypeTitle, self.fillStationName, self.fillPrice, self.pct, self.annualHigh)
        end
    end
end

function PriceWatcherEvent.sendEvent(fillTypeSafeName, notificationType, fillTypeTitle, fillStationName, fillPrice, pct, annualHigh)
    local event = PriceWatcherEvent.new(fillTypeSafeName, notificationType, fillTypeTitle, fillStationName, fillPrice, pct, annualHigh)
    if g_server ~= nil then
        g_server:broadcastEvent(event, true)
    else
        g_client:getServerConnection():sendEvent(event)
    end
end

function PriceWatcherEvent.sendToClient(connection, fillTypeSafeName, notificationType, fillTypeTitle, fillStationName, fillPrice, pct, annualHigh)
    if g_server ~= nil then
        connection:sendEvent(PriceWatcherEvent.new(fillTypeSafeName, notificationType, fillTypeTitle, fillStationName, fillPrice, pct, annualHigh))
    end
end