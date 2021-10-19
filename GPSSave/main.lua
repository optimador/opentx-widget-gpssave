local defaultOptions = {
    { "Save", BOOL, 0 },
    { "MinSats", VALUE, 5, 3, 36 },
}

local gpsId
local satsId
local latitude = 0
local longitude = 0
local sats = 0

local function round(aVal, aDec)
    if aDec then
        return math.floor((aVal * 10^aDec) + 0.5) / (10^aDec)
    end

    return math.floor(aVal + 0.5)
end

local function getLogFileName()
    local modelInfo = model.getInfo()
    return "/LOGS/" .. modelInfo["name"] .. "-last-gps-data.txt"
end

local function getTelemetryId(aName)
    local fieldInfo = getFieldInfo(aName)
    if fieldInfo then
        return fieldInfo.id
    end

    return -1
end

local function saveLastPosToFile(valueLat, valueLon, valueSats)
    local logFile = io.open(getLogFileName(), "w")
    io.write(logFile, valueLat, "\n")
    io.write(logFile, valueLon, "\n")
    io.write(logFile, valueSats, "\n")
    io.close(logFile)
end

local function loadLastPosFromFile()
    local logFile = io.open(getLogFileName(), "r")

    if logFile == nil then
        latitude = "<n/a>"
        longitude = "<n/a>"
        sats = "<n/a>"
    else
        local dataBuffer = io.read(logFile, 512)
        io.close(logFile)

        local lines = {}
        local linesIterator = 0

        for line in string.gmatch(dataBuffer, "([^\n]+)\n") do
            linesIterator = linesIterator + 1
            lines[linesIterator] = line
        end

        latitude = lines[1]
        longitude = lines[2]
        sats = lines[3]
    end
end

local function backgroundProcess(aGpsWidget)
    local gpsLatLon = getValue(gpsId)
    local gpsSats = getValue(satsId)

    if type(gpsLatLon) == "table" and gpsSats >= aGpsWidget.options.MinSats then
        sats = gpsSats
        latitude = round(gpsLatLon["lat"], 6)
        longitude = round(gpsLatLon["lon"], 6)

        if aGpsWidget.options.Save == 1 and (aGpsWidget.gps_value_lat ~= latitude or aGpsWidget.gps_value_lon ~= longitude) then
            saveLastPosToFile(latitude, longitude, sats)
        end

        aGpsWidget.from_file = false
    else
        if not aGpsWidget.from_file then
            loadLastPosFromFile()
        end

        aGpsWidget.from_file = true
    end

    aGpsWidget.gps_value_lat = latitude
    aGpsWidget.gps_value_lon = longitude
    aGpsWidget.gps_sats = sats
end

local function refreshDataOnScreen(aGpsWidget)
    local x1 = aGpsWidget.zone.x
    local y1 = aGpsWidget.zone.y
    local w = aGpsWidget.zone.w
    local h = aGpsWidget.zone.h
    local x2 = x1 + w
    local y2 = y1 + h

    lcd.drawRectangle(x1, y1, w, h, 0)
    lcd.drawLine(x1, y1+20, x2-2, y1+20, DOTTED, 0)

    if aGpsWidget.from_file then
        lcd.drawText(x1+5, y1+2, "SAVED", SMLSIZE)
    else
        lcd.drawText(x1+5, y1+2, "NOW", SMLSIZE)
    end

    lcd.drawText(x1+90, y1+2, "Sats: " .. aGpsWidget.gps_sats, SMLSIZE)

    lcd.drawText(x1+5, y1+25, "LAT: " .. aGpsWidget.gps_value_lat, 0)
    lcd.drawText(x1+5, y1+45, "LON: " .. aGpsWidget.gps_value_lon, 0)
end

local function printError(aGpsWidget)
    lcd.drawText(aGpsWidget.zone.x, aGpsWidget.zone.y, "Not supported size", 0)
end


local function createWidget(aZone, aOptions)
    gpsId = getTelemetryId("GPS")
    satsId = getTelemetryId("Sats")

    local gpsWidget = { zone=aZone, options=aOptions, gps_value_lat=latitude, gps_value_lon=longitude, gps_sats=sats, from_file=false }

    return gpsWidget
end

local function updateWidget(aGpsWidget, aOptions)
    aGpsWidget.options = aOptions
end

local function refreshWidget(aGpsWidget)
    backgroundProcess(aGpsWidget)

    local w = aGpsWidget.zone.w
    local h = aGpsWidget.zone.h

	if w >= 170 and w <= 230 and h >= 65 and h <= 125 then
        refreshDataOnScreen(aGpsWidget)
    else
        printError(aGpsWidget)
    end
end

local function backgroundWidget(aGpsWidget)
    backgroundProcess(aGpsWidget)
end

return { name="GPSSave", options=defaultOptions, create=createWidget, update=updateWidget, refresh=refreshWidget, background=backgroundWidget }
