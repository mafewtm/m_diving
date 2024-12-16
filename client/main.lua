local config = require 'config.client'
local sharedConfig = require 'config.shared'
local wreckZone = {}
local activeInteractables = {}
local wreckBlip

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

local function attachTank()
    local netId = lib.callback.await('m_diving:server:spawnTank', false)
    local tank = NetworkGetEntityFromNetworkId(netId)

    if DoesEntityExist(tank) then
        local bone = GetPedBoneIndex(cache.ped, 24818)

        NetworkRequestControlOfEntity(tank)

        lib.waitFor(function()
            if NetworkGetEntityOwner(tank) == cache.playerId then
                return true
            end
        end, locale('failed_get_control'), 3000)

        AttachEntityToEntity(tank, cache.ped, bone, -0.25, -0.25, 0.0, 180.0, 90.0, 0.0, true, true, false, false, 2, true)
    end
end

local function useDivingGear()
    if IsEntityDead(cache.ped) or IsPedSwimming(cache.ped) or cache.vehicle then
        exports.qbx_core:Notify(locale('cannot_right_now'), 'error')
        return
    end

    local alreadyUsingScuba = GetPedConfigFlag(cache.ped, 135, true)

    if lib.progressBar({
        duration = config.suitUseTime,
        label = alreadyUsingScuba and locale('remove_gear') or locale('put_on_gear'),
        useWhileDead = false,
        allowSwimming = false,
        anim = {
            dict = 'clothingshirt',
            clip = 'try_shirt_positive_d',
            blendIn = 8.0
        }
    }) then
        SetEnableScuba(cache.ped, not alreadyUsingScuba)

        if alreadyUsingScuba then
            TriggerServerEvent('m_diving:server:deleteTank')
            ClearPedScubaGearVariation(cache.ped)
        else
            attachTank()
            SetPedScubaGearVariation(cache.ped)
        end

        SetPedMaxTimeUnderwater(cache.ped, alreadyUsingScuba and 10.0 or 2000.0)
    else
        exports.qbx_core:Notify(locale('canceled'), 'error')
    end
end
exports('UseDivingGear', useDivingGear)

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
        label = isSalvage and 'Breaking apart...' or 'Opening...',
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
            clip = isSalvage and 'idle_a' or 'open_trunk_rushed',
            blendIn = 8.0,
            flag = 16,
        },
    }) then
        if not activeInteractables[index] then return end

        local coords = GetEntityCoords(cache.ped)
        local entityCoords = GetEntityCoords(entity)

        if #(coords - entityCoords) > 3.0 or not DoesEntityExist(entity) then return end

        TriggerServerEvent('m_diving:server:lootCollected', entity, index, isSalvage)
        removeInteractables(index)
    else
        exports.qbx_core:Notify(locale('canceled'), 'error')
    end
end

---@param self CPoint
local function onEnterDivingZone(self)
    local isSalvage = self.type == 'salvage'
    local model = isSalvage and `prop_rail_wheel01` or `tr_prop_tr_chest_01a`

    for i = 1, #self.points do
        local point = self.points[i]
        local object = CreateObject(model, point.x, point.y, point.z, false, true, false)

        lib.waitFor(function()
            if DoesEntityExist(object) then
                return true
            end
        end, 'failed to spawn '..model, 2000)

        PlaceObjectOnGroundProperly(object)
        FreezeEntityPosition(object, true)

        exports.ox_target:addLocalEntity(object, {
            name = 'wreckLoot',
            label = isSalvage and 'Break Apart' or 'Open',
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
    if table.type(wreckZone) ~= 'empty' then
        wreckZone:remove()

        wreckZone = nil
    end

    removeInteractables()

    local wreck = sharedConfig.wrecks[wreckData.id]

    wreckZone = lib.points.new({
        coords = wreck.coords,
        distance = 100.0,
        points = wreck.points,
        type = wreckData.type,
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

    wreckZone:remove()
    wreckZone = nil

    if DoesBlipExist(wreckBlip) then
        RemoveBlip(wreckBlip)

        wreckBlip = nil
    end

    removeInteractables()
end)

RegisterNetEvent('m_diving:client:newLocation', setDivingLocation)

RegisterNetEvent('m_diving:client:removeInteractable', removeInteractables)