local playerTanks = {}

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