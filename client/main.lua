local sharedConfig = require 'config.shared'
local wreckPoint = {}
local activeInteractables = {}
local wreckBlip = 0

---@param wreck vector3
local function createBlip(wreck)
    if wreckBlip then
        RemoveBlip(wreckBlip)
    end

    wreckBlip = AddBlipForCoord(wreck.x, wreck.y, wreck.z)

    SetBlipSprite(wreckBlip, 780)
    SetBlipScale(wreckBlip, 0.8)
    SetBlipColour(wreckBlip, 29)
    SetBlipAsShortRange(wreckBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('wreck'))
    EndTextCommandSetBlipName(wreckBlip)
end

---@param index? integer
local function removeInteractables(index)
    if index then
        if type(index) ~= 'number' then return end

        exports.ox_target:removeLocalEntity(activeInteractables[index], 'wreckLoot')
        DeleteObject(activeInteractables[index])
        activeInteractables[index] = nil
    else
        for i = 1, #activeInteractables do
            exports.ox_target:removeLocalEntity(activeInteractables[i], 'wreckLoot')
            DeleteObject(activeInteractables[i])
            activeInteractables[i] = nil
        end

        activeInteractables = {}
    end
end

---@param entity integer
---@param index integer
---@param isSalvage boolean
local function selectInteractable(entity, index, isSalvage)
    if lib.progressBar({
        duration = 3500,
        label = isSalvage and locale('breaking') or locale('opening'),
        useWhileDead = false,
        allowSwimming = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        },
        anim = {
            dict = isSalvage and 'amb@world_human_welding@male@base' or 'anim@scripted@hs4f@ig14_open_car_trunk@male@',
            clip = isSalvage and 'base' or 'open_trunk_rushed',
            blendIn = 8.0,
            flag = 16,
        },
    }) then
        if not activeInteractables[index] or not DoesEntityExist(entity) or entity ~= activeInteractables[index] then return end

        local coords = GetEntityCoords(cache.ped)
        local entityCoords = GetEntityCoords(entity)

        if #(coords - entityCoords) > 3.0 then return end

        TriggerServerEvent('m_diving:server:lootCollected', index)
    else
        exports.qbx_core:Notify(locale('canceled'), 'error')
    end
end

---@param self CPoint
local function onEnterDivingZone(self)
    local isSalvage = self.wreck.type == 'salvage'
    local model = isSalvage and `prop_rail_wheel01` or `tr_prop_tr_chest_01a`

    for i = 1, #self.interactables do
        local interactable = self.interactables[i]
        local object = CreateObject(model, interactable.x, interactable.y, interactable.z, false, false, false)

        lib.waitFor(function()
            if DoesEntityExist(object) then
                return true
            end
        end, locale('failed_spawn'), 2000)

        PlaceObjectOnGroundProperly(object)
        FreezeEntityPosition(object, true)

        exports.ox_target:addLocalEntity(object, {
            name = 'wreckLoot',
            label = isSalvage and locale('break_apart') or locale('open_chest'),
            icon = isSalvage and 'fas fa-wrench' or 'fas fa-box-open',
            canInteract = function()
                return GetPedConfigFlag(cache.ped, 135, true)
            end,
            onSelect = function(data)
                selectInteractable(data.entity, i, isSalvage)
            end,
            distance = 2.0,
        })

        activeInteractables[i] = object
    end
end

local function onExitDivingZone()
    removeInteractables()
end

---@param wreckData table
local function setDivingLocation(wreckData)
    wreckPoint:remove()
    wreckPoint = {}

    removeInteractables()

    local wreck = sharedConfig.wrecks[wreckData.id]

    wreckPoint = lib.points.new({
        coords = wreck.coords,
        distance = 100.0,
        wreck = wreckData,
        interactables = wreck.points,
        onEnter = onEnterDivingZone,
        onExit = onExitDivingZone,
    })

    createBlip(wreck.coords)
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local wreckData = lib.callback.await('m_diving:server:getLocation', false)

    setDivingLocation(wreckData)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end

    local wreckData = lib.callback.await('m_diving:server:getLocation', false)

    setDivingLocation(wreckData)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    wreckPoint:remove()
    wreckPoint = {}

    if DoesBlipExist(wreckBlip) then
        RemoveBlip(wreckBlip)
    end

    removeInteractables()
end)

RegisterNetEvent('m_diving:client:newLocation', setDivingLocation)

RegisterNetEvent('m_diving:client:removeInteractable', removeInteractables)