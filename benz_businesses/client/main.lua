local createBusinessMainBlips
local refreshServerBusinessBlips
local refreshAllBlips
local removeAllDeliveryBlips

refreshAllBlips = function()
    if createBusinessMainBlips then createBusinessMainBlips() end
    if refreshServerBusinessBlips then refreshServerBusinessBlips() end

    if not Config.EnableAllBlips or not Config.EnableDeliveryBlips then
        removeAllDeliveryBlips()
        return
    end

    removeAllDeliveryBlips()

    for _, data in pairs(RegisteredEStations or {}) do
        if data.station and data.station.type == 'delivery' then
            addDeliveryBlip(data.businessId, data.station.businessLabel or data.businessId, data.station)
        end
    end
end

local PlayerJob = nil
local TabletOpen = false
local ZonesCreated = false
local CreatedTargetZones = {}

local handleAnyStationSelect
local openCraftStationMenu
local openRegisterStation

local RegisteredEStations = {}

local BusinessMainBlips = {}

local ServerBusinessBlips = {}

local function removeServerBusinessBlip(businessId)
    businessId = tostring(businessId or '')

    local serverBlip = ServerBusinessBlips[businessId]
    if serverBlip and DoesBlipExist(serverBlip) then
        RemoveBlip(serverBlip)
    end
    ServerBusinessBlips[businessId] = nil

    -- If this business also had a config-created blip, remove it so the updated admin blip
    -- is the only marker shown at the new coordinates.
    local configBlip = BusinessMainBlips[businessId]
    if configBlip and DoesBlipExist(configBlip) then
        RemoveBlip(configBlip)
    end
    BusinessMainBlips[businessId] = nil
end

local function removeServerBusinessBlips()
    for _, blip in pairs(ServerBusinessBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    ServerBusinessBlips = {}
end

local function createOrUpdateServerBusinessBlip(business)
    if not business or not business.id then return end

    local businessId = tostring(business.id)
    removeServerBusinessBlip(businessId)

    if not Config.EnableAllBlips or not Config.EnableBusinessMainBlips then return end

    local blipData = business.blip or {}
    if blipData.enabled == false then return end

    if Config.BusinessBlipsJobOnly and (not PlayerJob or PlayerJob.name ~= business.job) then return end

    local coords = blipData.coords or business.coords
    local x = coords and tonumber(coords.x)
    local y = coords and tonumber(coords.y)
    local z = coords and tonumber(coords.z)
    if not x or not y or not z then return end

    local blip = AddBlipForCoord(x + 0.0, y + 0.0, z + 0.0)
    SetBlipSprite(blip, tonumber(blipData.sprite) or Config.BusinessBlipDefaultSprite or 439)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, tonumber(blipData.scale) or Config.BusinessBlipDefaultScale or 0.75)
    SetBlipColour(blip, tonumber(blipData.color) or Config.BusinessBlipDefaultColor or 2)
    SetBlipAsShortRange(blip, blipData.shortRange ~= nil and blipData.shortRange or Config.BusinessBlipShortRange ~= false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipData.label or business.label or businessId)
    EndTextCommandSetBlipName(blip)

    ServerBusinessBlips[businessId] = blip
end

local function createServerBusinessBlips(list)
    removeServerBusinessBlips()
    for _, business in pairs(list or {}) do
        createOrUpdateServerBusinessBlip(business)
    end
end

refreshServerBusinessBlips = function()
    local ok, list = pcall(function()
        return lib.callback.await('qbox_all_businesses:server:getBusinessBlips', false)
    end)

    if ok then
        createServerBusinessBlips(list or {})
    end
end

RegisterNetEvent('qbox_all_businesses:client:setBusinessBlips', function(list)
    createServerBusinessBlips(list or {})
end)

RegisterNetEvent('qbox_all_businesses:client:updateBusinessBlipNow', function(business)
    createOrUpdateServerBusinessBlip(business)
end)

RegisterNetEvent('qbox_all_businesses:client:removeBusinessBlipNow', function(businessId)
    removeServerBusinessBlip(businessId)
end)

CreateThread(function()
    Wait(2500)
    if refreshServerBusinessBlips then
        refreshServerBusinessBlips()
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(2500)
    if refreshServerBusinessBlips then
        refreshServerBusinessBlips()
    end
end)



local function getBusinessBlipCoords(business)
    local override = Config.BusinessBlips and Config.BusinessBlips[business.id]

    if override and override.coords then
        return override.coords
    end

    if business.blip and business.blip.coords then
        return business.blip.coords
    end

    for _, station in pairs(business.stations or {}) do
        if station.coords then
            return station.coords
        end
    end

    return nil
end

local function getBusinessBlipData(business)
    local override = Config.BusinessBlips and Config.BusinessBlips[business.id] or {}
    local native = business.blip or {}

    return {
        label = override.label or native.label or business.label,
        sprite = override.sprite or native.sprite or Config.BusinessBlipDefaultSprite or 439,
        color = override.color or native.color or Config.BusinessBlipDefaultColor or 2,
        scale = override.scale or native.scale or Config.BusinessBlipDefaultScale or 0.75,
        shortRange = override.shortRange
    }
end

local function canShowBusinessBlip(business)
    if not Config.BusinessBlipsJobOnly then return true end

    local job = PlayerJob or refreshJob()
    return job and job.name == business.job
end

local function removeBusinessMainBlips()
    for _, blip in pairs(BusinessMainBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    BusinessMainBlips = {}
end

createBusinessMainBlips = function()
    if not Config.EnableAllBlips or not Config.EnableBusinessMainBlips then return end

    removeBusinessMainBlips()

    for _, business in pairs(Config.Businesses or {}) do
        if canShowBusinessBlip(business) then
            local coords = getBusinessBlipCoords(business)
            if coords then
                local data = getBusinessBlipData(business)
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

                SetBlipSprite(blip, data.sprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, data.scale)
                SetBlipColour(blip, data.color)
                SetBlipAsShortRange(blip, data.shortRange ~= nil and data.shortRange or Config.BusinessBlipShortRange ~= false)

                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(data.label or business.label)
                EndTextCommandSetBlipName(blip)

                BusinessMainBlips[business.id] = blip
            end
        end
    end
end



local DeliveryBlips = {}

local function coordsToVec3(coords)
    if type(coords) == 'vector3' then return coords end
    if coords and coords.x then return vec3(coords.x, coords.y, coords.z) end
    return vec3(0.0, 0.0, 0.0)
end

local function addDeliveryBlip(businessId, businessLabel, station)
    if not Config.EnableAllBlips or not Config.EnableDeliveryBlips then return end
    if not station or station.type ~= 'delivery' then return end

    if Config.DeliveryBlipsJobOnly then
        local job = PlayerJob or refreshJob()
        local requiredJob = station.accessJob or station.job
        if requiredJob and (not job or job.name ~= requiredJob) then
            return
        end
    end

    local key = businessId .. '_' .. station.id
    if DeliveryBlips[key] then return end

    local coords = coordsToVec3(station.coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, Config.DeliveryBlipSprite or 478)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.DeliveryBlipScale or 0.75)
    SetBlipColour(blip, Config.DeliveryBlipColor or 5)
    SetBlipAsShortRange(blip, Config.DeliveryBlipShortRange ~= false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString((Config.DeliveryBlipLabelFormat or '%s Delivery'):format(businessLabel or businessId))
    EndTextCommandSetBlipName(blip)

    DeliveryBlips[key] = blip
end

local function removeDeliveryBlip(businessId, stationId)
    local key = businessId .. '_' .. stationId
    local blip = DeliveryBlips[key]

    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end

    DeliveryBlips[key] = nil
end

removeAllDeliveryBlips = function()
    for _, blip in pairs(DeliveryBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    DeliveryBlips = {}
end



local function stationCoordsToVec3(coords)
    if type(coords) == 'vector3' then return coords end
    if coords and coords.x then return vec3(coords.x, coords.y, coords.z) end
    return vec3(0.0, 0.0, 0.0)
end

local function getStationDistance(station)
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local scoords = stationCoordsToVec3(station.coords)
    return #(pcoords - scoords)
end


local function canAccessStation(data)
    local job = PlayerJob or refreshJob()
    if not job then return false end

    local station = data.station or {}
    local requiredJob = station.accessJob or station.job or data.jobName

    if Config.RegisteredJobStationAccess and requiredJob and job.name ~= requiredJob then
        return false
    end

    if station.bossOnly then
        if job.isboss then return true end
        if job.grade and job.grade.level and job.grade.level >= (Config.MenuEditorMinGrade or 4) then return true end
        return false
    end

    return true
end


local function registerEStation(businessId, jobName, station)
    if not Config.UseEToInteractStations then return end
    if not station or not station.id then return end

    station.job = station.job or jobName
    station.accessJob = station.accessJob or jobName

    local key = businessId .. '_' .. (station.type or 'station') .. '_' .. station.id
    RegisteredEStations[key] = {
        businessId = businessId,
        jobName = jobName,
        station = station
    }
end

local function getClosestEStation()
    local closest, closestDist = nil, nil
    local drawDist = Config.EInteractDrawDistance or 15.0

    for _, data in pairs(RegisteredEStations) do
        local station = data.station
        local dist = getStationDistance(station)

        if dist <= drawDist and canAccessStation(data) then
            if not closestDist or dist < closestDist then
                closest = data
                closestDist = dist
            end
        end
    end

    return closest, closestDist
end


handleAnyStationSelect = handleAnyStationSelect or function(_, _, _)
    openTablet()
end


createBusinessMainBlips = createBusinessMainBlips or function() end
refreshAllBlips = refreshAllBlips or function()
    if createBusinessMainBlips then createBusinessMainBlips() end
end
removeAllDeliveryBlips = removeAllDeliveryBlips or function() end

CreateThread(function()
    -- E-to-interact has been converted to ox_target third-eye.
    -- This thread intentionally stays idle so no [E] TextUI prompts appear.
    while true do
        Wait(5000)
    end
end)



local function notify(title, description, ntype)
    lib.notify({
        title = title or 'Business',
        description = description or '',
        type = ntype or 'inform',
        duration = 5000,
        position = 'top-right'
    })
end

local function refreshJob()
    local data = exports.qbx_core:GetPlayerData()
    PlayerJob = data and data.job or nil
    return PlayerJob
end

local function hasJob(jobName, bossOnly)
    local job = PlayerJob or refreshJob()
    if not job or job.name ~= jobName then return false end

    if bossOnly then
        if job.isboss then return true end
        if job.grade and job.grade.level and job.grade.level >= (Config.MenuEditorMinGrade or 4) then return true end
        return false
    end

    return true
end

local function openStash(stashId)
    exports.ox_inventory:openInventory('stash', stashId)
end

local function removeTargetZone(name)
    if not name or not CreatedTargetZones[name] then return end

    if GetResourceState('ox_target') == 'started' then
        pcall(function()
            exports.ox_target:removeZone(name)
        end)
    end

    CreatedTargetZones[name] = nil
end

local function addBoxZone(name, coords, size, rotation, debug, option)
    if GetResourceState('ox_target') ~= 'started' then
        CreateThread(function()
            while GetResourceState('ox_target') ~= 'started' do Wait(500) end
            addBoxZone(name, coords, size, rotation, debug, option)
        end)
        return
    end

    removeTargetZone(name)

    exports.ox_target:addBoxZone({
        name = name,
        coords = coords,
        size = size,
        rotation = rotation or 0.0,
        debug = debug or false,
        options = {
            {
                name = option.name or name .. '_use',
                label = option.label,
                icon = option.icon,
                distance = option.distance or Config.TargetDistance or 2.0,
                canInteract = option.canInteract,
                onSelect = option.onSelect
            }
        }
    })

    CreatedTargetZones[name] = true
end
AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if GetResourceState('ox_target') == 'started' then
        for zoneName in pairs(CreatedTargetZones or {}) do
            pcall(function() exports.ox_target:removeZone(zoneName) end)
        end
    end

    CreatedTargetZones = {}
end)


local refreshTablet


local TabletOpen = TabletOpen or false
local AdminPanelOpen = AdminPanelOpen or false

local function updateNuiFocus()
    local focused = TabletOpen or AdminPanelOpen
    SetNuiFocus(focused, focused)
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(false)
    end
end

local function closeTabletOnly()
    TabletOpen = false
    updateNuiFocus()
    SendNUIMessage({ action = 'closeTablet' })
end

local function closeAdminOnly()
    AdminPanelOpen = false
    updateNuiFocus()
    SendNUIMessage({ action = 'closeAdminPanel' })
end


local function openTablet()
    local data = lib.callback.await('qbox_all_businesses:server:getTabletData', false)

    if not data then
        notify('Business Tablet', 'You do not have a configured business job.', 'error')
        return
    end

    TabletOpen = true
    updateNuiFocus()
    SendNUIMessage({
        action = 'openTablet',
        data = data
    })

    -- Force one extra refresh after opening so UI always has latest DB-backed values.
    SetTimeout(250, function()
        if refreshTablet then refreshTablet() end
    end)
end

refreshTablet = function()
    if not TabletOpen then return end

    local data = lib.callback.await('qbox_all_businesses:server:getTabletData', false)
    SendNUIMessage({
        action = 'refreshTablet',
        data = data
    })
end

RegisterCommand(Config.TabletCommand or 'businesstablet', function()
    if Config.DisableTabletCommand then
        notify('Business Tablet', 'You must use the tablet item.', 'error')
        return
    end

    openTablet()
end, false)

RegisterNetEvent('qbox_all_businesses:client:openTablet', openTablet)
RegisterNetEvent('qbox_all_businesses:client:useBusinessTablet', openTablet)

RegisterNetEvent('qbox_all_businesses:client:tabletOpenStash', function(stashId)
    SetNuiFocus(false, false)
    TabletOpen = false
    SendNUIMessage({ action = 'closeTablet' })
    openStash(stashId)
end)

RegisterNetEvent('qbox_all_businesses:client:djPlay', function(data)
    if GetResourceState('xsound') ~= 'started' then
        notify('DJ Booth', 'xsound is not started.', 'error')
        return
    end

    if exports.xsound:soundExists(data.soundId) then
        exports.xsound:Destroy(data.soundId)
    end

    exports.xsound:PlayUrlPos(data.soundId, data.url, data.volume or 0.25, data.coords)
    exports.xsound:Distance(data.soundId, data.hearRadius or 35.0)
end)

RegisterNetEvent('qbox_all_businesses:client:djStop', function(soundId)
    if GetResourceState('xsound') == 'started' and exports.xsound:soundExists(soundId) then
        exports.xsound:Destroy(soundId)
    end
end)

RegisterNetEvent('qbox_all_businesses:client:djVolume', function(soundId, volume)
    if GetResourceState('xsound') == 'started' and exports.xsound:soundExists(soundId) then
        exports.xsound:setVolume(soundId, volume)
    end
end)

RegisterNUICallback('tabletClose', function(_, cb)
    TabletOpen = false
    updateNuiFocus()
    cb({ ok = true })
end)

RegisterNUICallback('tabletRefresh', function(_, cb)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('accountDeposit', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletDeposit', data.amount, data.note)
    Wait(500)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('accountWithdraw', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletWithdraw', data.amount, data.note)
    Wait(500)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('hireEmployee', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletHire', data.targetId, data.grade)
    Wait(500)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletFire', data.targetId)
    Wait(500)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('setEmployeeRank', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletSetRank', data.targetId, data.grade)
    Wait(500)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('createSupplyOrder', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletCreateSupplyOrder', data.items or {})
    Wait(700)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('claimSupplyOrder', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletClaimSupplyOrder', data.orderId)
    Wait(700)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('addMenuItem', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletAddMenuItem', data.stationId, data.item)
    Wait(500)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNUICallback('removeMenuItem', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletRemoveMenuItem', data.stationId, data.index)
    Wait(500)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)




RegisterNUICallback('deleteStation', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletDeleteStation', data.stationId)
    Wait(700)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)

RegisterNetEvent('qbox_all_businesses:client:removePlacedStation', function(businessId, stationId)
    businessId = tostring(businessId or '')
    stationId = tostring(stationId or '')

    for key, data in pairs(RegisteredEStations or {}) do
        if tostring(data.businessId or '') == businessId and data.station and tostring(data.station.id or '') == stationId then
            if data.station.type == 'delivery' then
                removeDeliveryBlip(businessId, stationId)
            end
            RegisteredEStations[key] = nil
        end
    end

    -- Also remove the matching ox_target zone so deleted/moved stations do not leave old third-eye points behind.
    for zoneName in pairs(CreatedTargetZones or {}) do
        if zoneName:find('business_' .. businessId .. '_', 1, true) and zoneName:find('_' .. stationId, 1, true) then
            removeTargetZone(zoneName)
        end
    end
end)


RegisterNUICallback('placeStation', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    data = data or {}
    data.coords = { x = coords.x, y = coords.y, z = coords.z }
    data.rotation = heading

    TriggerServerEvent('qbox_all_businesses:server:tabletPlaceStation', data)

    Wait(700)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)


RegisterNUICallback('placeDJBooth', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    TriggerServerEvent('qbox_all_businesses:server:tabletPlaceDJBooth', {
        type = 'dj',
        label = data.label or 'DJ Booth',
        hearRadius = data.hearRadius or Config.DefaultPlacedDJHearRadius or 45.0,
        useRadius = data.useRadius or Config.DefaultPlacedDJUseRadius or 2.0,
        sizeX = data.sizeX or 1.4,
        sizeY = data.sizeY or 1.4,
        sizeZ = data.sizeZ or 1.0,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        rotation = heading
    })

    Wait(700)
    if refreshTablet then refreshTablet() end
    cb({ ok = true })
end)


RegisterNUICallback('djPlay', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletDjPlay', data.stationId, data.url, data.volume)
    cb({ ok = true })
end)

RegisterNUICallback('djStop', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletDjStop', data.stationId)
    cb({ ok = true })
end)

RegisterNUICallback('djVolume', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletDjVolume', data.stationId, data.volume)
    cb({ ok = true })
end)

RegisterNUICallback('openStash', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:tabletOpenStash', data.stationId)
    cb({ ok = true })
end)





local function ingredientsToText(ingredients)
    local out = {}

    for item, amount in pairs(ingredients or {}) do
        out[#out + 1] = tostring(amount) .. 'x ' .. item
    end

    if #out == 0 then return 'No ingredients required' end
    return table.concat(out, ', ')
end

openCraftStationMenu = function(businessId, station)
    local items = lib.callback.await('qbox_all_businesses:server:getStationItems', false, businessId, station.id) or {}
    local options = {}

    for index, itemData in pairs(items) do
        options[#options + 1] = {
            title = itemData.label or itemData.item,
            description = ('Creates %sx %s | Ingredients: %s'):format(itemData.amount or 1, itemData.item or 'unknown', ingredientsToText(itemData.ingredients)),
            icon = station.type == 'drink' and 'martini-glass' or 'utensils',
            onSelect = function()
                TriggerServerEvent('qbox_all_businesses:server:craft', businessId, station.id, index)
            end
        }
    end

    if #options == 0 then
        notify(station.label or 'Crafting', 'No recipes set up for this station.', 'error')
        return
    end

    lib.registerContext({
        id = 'business_craft_' .. businessId .. '_' .. station.id,
        title = station.label or 'Crafting',
        options = options
    })

    lib.showContext('business_craft_' .. businessId .. '_' .. station.id)
end

openRegisterStation = function(businessId, station)
    local input = lib.inputDialog(station.label or 'Register', {
        { type = 'number', label = 'Customer Server ID', min = 1, required = true },
        { type = 'number', label = 'Amount', min = 1, required = true },
        { type = 'select', label = 'Payment Method', required = true, options = {
            { label = 'Cash', value = 'cash' },
            { label = 'Bank', value = 'bank' }
        }},
        { type = 'input', label = 'Reason', required = false, placeholder = 'Business purchase' }
    })

    if input then
        TriggerServerEvent(
            'qbox_all_businesses:server:bill',
            businessId,
            tonumber(input[1]),
            tonumber(input[2]),
            tostring(input[3] or 'cash'),
            input[4] or 'Business purchase'
        )
    end
end


handleAnyStationSelect = function(businessId, jobName, station)
    if not station then return end

    if station.type == 'stash' or station.type == 'fridge' then
        if businessId then
            openStash(businessId .. '_' .. station.id)
        else
            TriggerServerEvent('qbox_all_businesses:server:tabletOpenStash', station.id)
        end
        return
    end

    if station.type == 'food' or station.type == 'drink' then
        if businessId then
            openCraftStationMenu(businessId, station)
        else
            openTablet()
        end
        return
    end

    if station.type == 'register' then
        if businessId then
            openRegisterStation(businessId, station)
        else
            openTablet()
        end
        return
    end

    -- Tablet-managed station types.
    if station.type == 'menu_editor'
        or station.type == 'business_ui'
        or station.type == 'delivery'
        or station.type == 'dj'
        or station.type == 'boss'
        or station.type == 'wardrobe'
    then
        openTablet()
        return
    end

    openTablet()
end

local function handlePlacedStationSelect(station)
    -- Dynamic stations are validated server-side for job access.
    if station.type == 'stash' or station.type == 'fridge' then
        TriggerServerEvent('qbox_all_businesses:server:tabletOpenStash', station.id)
        return
    end

    if station.type == 'food' or station.type == 'drink' then
        openCraftStationMenu(station.businessId, station)
        return
    end

    if station.type == 'register' then
        openRegisterStation(station.businessId, station)
        return
    end

    openTablet()
end

local function addStationZone(businessId, jobName, station)
    station.businessId = station.businessId or businessId
    station.job = station.job or jobName
    station.accessJob = station.accessJob or station.job or jobName
    registerEStation(businessId, jobName, station)

    if station.type == 'delivery' then
        addDeliveryBlip(businessId, station.businessLabel or businessId, station)
    end

    if not (Config.UseThirdEyeStations or Config.AllStationsUseThirdEye) then return end

    local zoneName = 'business_' .. businessId .. '_' .. (station.type or 'station') .. '_' .. station.id

    addBoxZone(
        zoneName,
        vec3(station.coords.x, station.coords.y, station.coords.z),
        station.size and vec3(station.size.x or 1.4, station.size.y or 1.4, station.size.z or 1.0) or (Config.DefaultPlacedStationSize or vec3(1.4, 1.4, 1.0)),
        station.rotation or 0.0,
        Config.Debug,
        {
            name = zoneName .. '_use',
            label = station.label or station.type or 'Station',
            icon = Config.StationIcons and Config.StationIcons[station.type] or 'fa-solid fa-location-dot',
            distance = station.useRadius or Config.TargetDistance or 2.0,
            canInteract = function()
                return canAccessStation({ station = station, jobName = jobName })
            end,
            onSelect = function()
                handlePlacedStationSelect(station)
            end
        }
    )
end

RegisterNetEvent('qbox_all_businesses:client:addPlacedStationZone', function(businessId, jobName, station)
    addStationZone(businessId, jobName, station)
end)


local function addDJBoothZone(businessId, jobName, booth)
    local zoneName = 'business_' .. businessId .. '_' .. booth.id

    addBoxZone(
        zoneName,
        vec3(booth.coords.x, booth.coords.y, booth.coords.z),
        Config.DefaultPlacedDJSize or vec3(1.4, 1.4, 1.0),
        booth.rotation or 0.0,
        Config.Debug,
        {
            name = zoneName .. '_use',
            label = booth.label or 'DJ Booth',
            icon = 'fa-solid fa-music',
            distance = booth.useRadius or Config.DefaultPlacedDJUseRadius or 2.0,
            canInteract = function()
                return hasJob(booth.accessJob or booth.job or jobName, false)
            end,
            onSelect = function()
                openTablet()
            end
        }
    )
end

RegisterNetEvent('qbox_all_businesses:client:addPlacedDJBoothZone', function(businessId, jobName, booth)
    addDJBoothZone(businessId, jobName, booth)
end)


CreateThread(function()
    while (((Config.UseThirdEyeStations or Config.AllStationsUseThirdEye) and GetResourceState('ox_target') ~= 'started')
    or GetResourceState('ox_inventory') ~= 'started'
    or GetResourceState('ox_lib') ~= 'started')
do
    Wait(1000)
end
    refreshJob()
    if refreshAllBlips then refreshAllBlips() end

    if Config.DisableDefaultConfigStations or (Config.DisableLegacyWorldStationsWhenTabletEnabled and Config.EnableBusinessTablet) then
        return
    end

    if ZonesCreated then return end
    ZonesCreated = true

    for _, business in pairs(Config.Businesses or {}) do
        for _, station in pairs(business.stations or {}) do
            station.businessId = station.businessId or business.id
            station.job = station.job or business.job
            station.accessJob = station.accessJob or business.job
            registerEStation(business.id, business.job, station)
            if station.type == 'delivery' then
                addDeliveryBlip(business.id, business.label, station)
            end

            if Config.UseThirdEyeStations or Config.AllStationsUseThirdEye then
                local zoneName = 'business_' .. business.id .. '_' .. station.id

                addBoxZone(zoneName, station.coords, station.size or vec3(1.0, 1.0, 1.0), station.rotation or 0.0, Config.Debug, {
                    name = zoneName .. '_use',
                    label = station.label or station.type or 'Station',
                    icon = Config.StationIcons and Config.StationIcons[station.type] or 'fa-solid fa-location-dot',
                    distance = station.useRadius or Config.TargetDistance or 2.0,
                    canInteract = function()
                        return canAccessStation({ station = station, jobName = business.job })
                    end,
                    onSelect = function()
                        handleAnyStationSelect(business.id, business.job, station)
                    end
                })
            end
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerJob = job
    if refreshAllBlips then refreshAllBlips() end
end)

RegisterNetEvent('qbx_core:client:onSetPlayerData', function(data)
    PlayerJob = data and data.job or PlayerJob
    if refreshAllBlips then refreshAllBlips() end
end)

RegisterNetEvent('qbx_core:client:playerLoggedIn', function()
    refreshJob()
    if refreshAllBlips then refreshAllBlips() end
end)


CreateThread(function()
    while GetResourceState('ox_lib') ~= 'started' do Wait(1000) end
    Wait(1500)

    local stations = {}
    for attempt = 1, 10 do
        local ok, result = pcall(function()
            return lib.callback.await('qbox_all_businesses:server:getDynamicStations', false)
        end)

        if ok then
            stations = result or {}
            break
        end

        Wait(500)
    end
    for _, station in pairs(stations) do
        addStationZone(station.businessId, station.job, station)
    end
end)


-- Admin Panel

local function openAdminPanel()
    local allowed = false

    local okAllowed, resultAllowed = pcall(function()
        return lib.callback.await('qbox_all_businesses:server:isAdminPanelAllowed', false)
    end)

    if okAllowed then
        allowed = resultAllowed == true
    end

    if not allowed then
        notify('Business Admin', 'You do not have permission or the admin callback failed.', 'error')
        return
    end

    local okData, data = pcall(function()
        return lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    end)

    if not okData or not data then
        notify('Business Admin', 'Could not load admin panel data.', 'error')
        return
    end

    AdminPanelOpen = true
    updateNuiFocus()
    SendNUIMessage({
        action = 'openAdminPanel',
        data = data
    })
    SetTimeout(100, function()
        AdminPanelOpen = true
        updateNuiFocus()
    end)

    -- Force one extra refresh after opening so selected business/supply/station data is current.
    SetTimeout(250, function()
        local refreshed = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
        SendNUIMessage({
            action = 'refreshAdminPanel',
            data = refreshed or { businesses = {}, supplyItems = {} }
        })
    end)
end

RegisterNetEvent('qbox_all_businesses:client:openAdminPanel', openAdminPanel)

RegisterCommand(Config.AdminPanelCommand or 'businessadmin', function()
    openAdminPanel()
end, false)

RegisterNetEvent('qbox_all_businesses:client:adminTeleport', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x + 0.0, coords.y + 0.0, coords.z + 0.5, false, false, false, false)
end)


RegisterNUICallback('tabletTabSelected', function(_, cb)
    local data = lib.callback.await('qbox_all_businesses:server:getTabletData', false)
    SendNUIMessage({ action = 'refreshTablet', data = data })
    cb({ ok = true })
end)

RegisterNUICallback('adminBusinessSelected', function(_, cb)
    local data = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = data or { businesses = {}, supplyItems = {} } })
    cb({ ok = true })
end)


RegisterNUICallback('adminUiReady', function(_, cb)
    AdminPanelOpen = true
    updateNuiFocus()
    cb({ ok = true })
end)

RegisterNUICallback('adminClose', function(_, cb)
    AdminPanelOpen = false
    updateNuiFocus()
    cb({ ok = true })
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    local data = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = data or { businesses = {}, supplyItems = {} } })
    cb({ ok = true })
end)

RegisterNUICallback('adminUpdateBusiness', function(data, cb)
    data = data or {}

    if data.blipUseCurrentLocation then
        local coords = GetEntityCoords(PlayerPedId())
        data.blipCoords = { x = coords.x, y = coords.y, z = coords.z }
        data.blipX = coords.x
        data.blipY = coords.y
        data.blipZ = coords.z
    end

    local result = lib.callback.await('qbox_all_businesses:server:adminUpdateBusinessImmediate', false, data.businessId, data)

    if result and result.blips then
        createServerBusinessBlips(result.blips)
    else
        refreshServerBusinessBlips()
    end

    SendNUIMessage({
        action = 'refreshAdminPanel',
        data = (result and result.adminData) or { businesses = {}, supplyItems = {} }
    })

    cb({ ok = result and result.ok == true })
end)

RegisterNUICallback('adminDeleteStation', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:adminDeleteStation', data.businessId, data.stationId)
    Wait(600)
    local refreshed = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = refreshed })
    cb({ ok = true })
end)

RegisterNUICallback('adminTeleportToStation', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:adminTeleportToStation', data.businessId, data.stationId)
    cb({ ok = true })
end)

RegisterNUICallback('adminPlaceStation', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    data.coords = { x = coords.x, y = coords.y, z = coords.z }
    data.rotation = heading

    TriggerServerEvent('qbox_all_businesses:server:adminPlaceStation', data.businessId, data)
    Wait(700)
    local refreshed = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = refreshed })
    cb({ ok = true })
end)



RegisterNUICallback('adminSaveSupplyItem', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:adminSaveSupplyItem', data)
    Wait(500)
    local refreshed = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = refreshed })
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteSupplyItem', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:adminDeleteSupplyItem', data.item)
    Wait(500)
    local refreshed = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = refreshed })
    cb({ ok = true })
end)



RegisterCommand('businessadmin_force', function()
    TriggerEvent('qbox_all_businesses:client:openAdminPanel')
end, false)


RegisterNUICallback('adminSaveBusinessSupplyItem', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:adminSaveBusinessSupplyItem', data)
    Wait(500)
    local refreshed = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = refreshed or { businesses = {}, supplyItems = {} } })
    refreshServerBusinessBlips()
    cb({ ok = true })
end)

RegisterNUICallback('adminDeleteBusinessSupplyItem', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:adminDeleteBusinessSupplyItem', data)
    Wait(500)
    local refreshed = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = refreshed or { businesses = {}, supplyItems = {} } })
    cb({ ok = true })
end)



RegisterNUICallback('adminCreateBusiness', function(data, cb)
    data = data or {}

    if data.blipUseCurrentLocation then
        local coords = GetEntityCoords(PlayerPedId())
        data.blipCoords = { x = coords.x, y = coords.y, z = coords.z }
        data.blipX = coords.x
        data.blipY = coords.y
        data.blipZ = coords.z
    end

    local result = lib.callback.await('qbox_all_businesses:server:adminCreateBusinessImmediate', false, data)

    if result and result.blips then
        createServerBusinessBlips(result.blips)
    else
        refreshServerBusinessBlips()
    end

    SendNUIMessage({
        action = 'refreshAdminPanel',
        data = (result and result.adminData) or { businesses = {}, supplyItems = {} }
    })

    cb({ ok = result and result.ok == true })
end)

RegisterNUICallback('adminDeleteBusiness', function(data, cb)
    TriggerServerEvent('qbox_all_businesses:server:adminDeleteBusiness', data.businessId)
    Wait(700)
    local refreshed = lib.callback.await('qbox_all_businesses:server:getAdminPanelData', false)
    SendNUIMessage({ action = 'refreshAdminPanel', data = refreshed or { businesses = {}, supplyItems = {} } })
    refreshServerBusinessBlips()
    cb({ ok = true })
end)

RegisterNetEvent('qbox_all_businesses:client:removeBusinessZones', function(businessId)
    for key, data in pairs(RegisteredEStations or {}) do
        if data.businessId == businessId then
            RegisteredEStations[key] = nil
        end
    end

    if refreshAllBlips then refreshAllBlips() end
end)



RegisterNUICallback('closeTabletOnly', function(_, cb)
    closeTabletOnly()
    cb({ ok = true })
end)

RegisterNUICallback('closeAdminOnly', function(_, cb)
    closeAdminOnly()
    cb({ ok = true })
end)


CreateThread(function()
    Wait(1500)
    refreshServerBusinessBlips()
end)
