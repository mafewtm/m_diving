local sharedConfig = require 'config.shared'
local playerTanks = {}
local wreck = {}

---@param source number
local function deleteTank(source)
    local tank = playerTanks[source]

    if tank then
        if DoesEntityExist(tank) then
            DeleteEntity(tank)
        end

        playerTanks[source] = nil
    end
end

local function getNewLocation()
    wreck = {}

    local wreckId = math.random(1, #sharedConfig.wrecks)
    local wreckType = math.random() < 0.5 and 'salvage' or 'looting'

    wreck = { id = wreckId, type = wreckType }

    TriggerClientEvent('m_diving:client:newLocation', -1, wreck)
end

lib.cron.new('*/30 * * * *', getNewLocation)

lib.callback.register('m_diving:server:getLocation', function()
    return wreck
end)

lib.callback.register('m_diving:server:spawnTank', function(source)
    if playerTanks[source] then
        deleteTank(source)
    end

    local tank = CreateObject(`p_s_scuba_tank_s`, 1.0, 1.0, 1.0, true, false, false)

    lib.waitFor(function()
        if DoesEntityExist(tank) then
            return true
        end
    end, locale('failed_spawn'), 2000)

    playerTanks[source] = tank

    local netId = NetworkGetNetworkIdFromEntity(tank)

    return netId
end)

AddEventHandler('playerDropped', function()
    local src = source

    deleteTank(src)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end

    getNewLocation()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for i in pairs(playerTanks) do
        deleteTank(i)
    end
end)

RegisterNetEvent('m_diving:server:deleteTank', function()
    local src = source

    deleteTank(src)
end)