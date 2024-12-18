assert(lib.checkDependency('qbx_core', '1.22.3'), 'qbx_core v1.22.3 or higher is required')
assert(lib.checkDependency('ox_lib', '3.27.0'), 'ox_lib v3.27.0 or higher is required')
assert(lib.checkDependency('ox_inventory', '2.43.3'), 'ox_inventory v2.43.3 or higher is required')

local config = require 'config.server'
local sharedConfig = require 'config.shared'
local wreck = {}

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

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end

    getNewLocation()
end)

RegisterNetEvent('m_diving:server:lootCollected', function(source, index)
    if type(index) ~= 'number' or index <= 0 or index > #sharedConfig.wrecks[wreck.id].points then return end

    local player = exports.qbx_core:GetPlayer(source)

    if not player then return end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local interactable = sharedConfig.wrecks[wreck.id].points[index]
    local interactableCoords = vec3(interactable.x, interactable.y, interactable.z)

    if #(coords - interactableCoords) > 3.0 then return end

    TriggerClientEvent('m_diving:client:removeInteractable', -1, index)

    local loot = wreck.type == 'salvage' and config.loot.salvage.item or config.loot.looting.item
    local lootAmount = wreck.type == 'salvage' and config.loot.salvage.amount or config.loot.looting.amount

    if exports.ox_inventory:CanCarryItem(source, loot, lootAmount) then
        exports.ox_inventory:AddItem(source, loot, lootAmount)
    else
        local label = wreck.type == 'salvage' and locale('scrapped') or locale('treasure')

        exports.ox_inventory:CustomDrop(label, {
            { name = loot, count = lootAmount }
        }, coords, 1, 10.0, nil, `bkr_prop_duffel_bag_01a`)
    end
end)