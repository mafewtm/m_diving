local config = require 'config.client'
local sharedConfig = require 'config.shared'
local wreckZone = {}
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
        allowCuffed = false,
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

---@param wreckData table
local function setDivingLocation(wreckData)
    if table.type(wreckZone) ~= 'empty' then
        wreckZone:remove()

        wreckZone = nil
    end

    local wreck = sharedConfig.wrecks[wreckData.id]

    wreckZone = lib.points.new({
        coords = wreck.coords,
        distance = 60.0,
        points = wreck.points,
        type = wreckData.type,
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

    RemoveBlip(wreckBlip)
end)

RegisterNetEvent('m_diving:client:newLocation', setDivingLocation)