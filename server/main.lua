local config = require 'config.server'
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

lib.callback.register('m_diving:server:lootCollected', function(source, index, isSalvage)
    local player = exports.qbx_core:GetPlayer(source)

    if not player then return end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)

    TriggerClientEvent('m_diving:client:removeInteractable', -1, index)

    local loot = isSalvage and config.loot.salvage.item or config.loot.looting.item
    local lootAmount = isSalvage and config.loot.salvage.amount or config.loot.looting.amount

    if exports.ox_inventory:CanCarryItem(source, loot, lootAmount) then
        local added, _ = exports.ox_inventory:AddItem(source, loot, lootAmount)

        return added
    else
        local label = isSalvage and locale('scrapped') or locale('treasure')

        exports.ox_inventory:CustomDrop(label, {
            { name = loot, count = lootAmount }
        }, coords, 1, 10.0, nil, `bkr_prop_duffel_bag_01a`)

        return true
    end
end)