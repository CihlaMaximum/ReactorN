local component = require("component")
local computer = require("computer")
local config = require("config.config")

local me = {
    lastUpdate = -1000000,

    fluid = 0,
    lastValidFluid = 0,

    lowReadCounter = 0,

    readingValid = false,
    fluidConfirmedLow = false,

    cpu = {
        processors = {},
        idle = 0,
        busy = 0,
        total = 0
    }
}

local function getController()
    if component.isAvailable("me_controller") then
        return component.me_controller
    end

    if component.isAvailable("me_interface") then
        return component.me_interface
    end

    return nil
end

local function getCPUData(controller)
    local data = {
        processors = {},
        idle = 0,
        busy = 0,
        total = 0
    }

    if not controller or not controller.getCpus then
        return data
    end

    local success, cpus = pcall(function()
        return controller.getCpus()
    end)

    if not success or type(cpus) ~= "table" then
        return data
    end

    data.total = #cpus

    for i, cpu in ipairs(cpus) do
        local busy = cpu.busy == true

        data.processors[i] = {
            busy = busy
        }

        if busy then
            data.busy = data.busy + 1
        else
            data.idle = data.idle + 1
        end
    end

    return data
end

local function readFluid(controller)
    if not controller or not controller.getItemsInNetwork then
        return nil, false, "ME контроллер недоступен"
    end

    local success, items = pcall(function()
        return controller.getItemsInNetwork({
            name = config.fluidItemName
        })
    end)

    if not success then
        return nil, false, "Ошибка запроса ME"
    end

    if type(items) ~= "table" then
        return nil, false, "ME вернула неправильные данные"
    end

    local total = 0

    for _, item in ipairs(items) do
        if item and item.size then
            local label = tostring(item.label or "")
            local name = tostring(item.name or "")

            local correctName =
                name == config.fluidItemName
                or name == ""

            local correctLabel =
                label == ""
                or label:find(
                    config.fluidLabel,
                    1,
                    true
                ) ~= nil

            if correctName and correctLabel then
                total = total + (tonumber(item.size) or 0)
            end
        end
    end

    if total > config.fluidMaxValidValue then
        return nil, false, "ME вернула слишком большое значение"
    end

    return total, true, nil
end

local function processFluidReading(value, valid)
    me.readingValid = valid

    -- Ошибка запроса: сохраняем последнее нормальное значение.
    -- Ошибка связи не считается реальным отсутствием жидкости.
    if not valid or value == nil then
        me.fluid = me.lastValidFluid
        return
    end

    -- Значение выше или равно лимиту является нормальным.
    if value >= config.minFluidDrop then
        me.fluid = value
        me.lastValidFluid = value

        me.lowReadCounter = 0
        me.fluidConfirmedLow = false

        return
    end

    -- Получено значение ниже лимита.
    me.lowReadCounter = me.lowReadCounter + 1

    -- Пока недостаток не подтверждён,
    -- оставляем на экране последнее нормальное значение.
    if me.lowReadCounter < config.fluidLowConfirmations then
        me.fluid = me.lastValidFluid
        me.fluidConfirmedLow = false
        return
    end

    -- Низкое значение повторилось необходимое количество раз.
    me.fluid = value
    me.fluidConfirmedLow = true
end

function me.update(force)
    local now = computer.uptime()

    if not force
        and now - me.lastUpdate < config.meInterval then
        return nil
    end

    me.lastUpdate = now

    local controller = getController()

    me.cpu = getCPUData(controller)

    local fluidValue, valid, errorMessage =
        readFluid(controller)

    processFluidReading(fluidValue, valid)

    return {
        fluid = me.fluid,
        rawFluid = fluidValue,

        lastValidFluid = me.lastValidFluid,

        lowReadCounter = me.lowReadCounter,
        lowReadLimit = config.fluidLowConfirmations,

        readingValid = me.readingValid,
        fluidConfirmedLow = me.fluidConfirmedLow,

        error = errorMessage,
        cpu = me.cpu,
        available = controller ~= nil
    }
end

function me.getFluid()
    return me.fluid
end

function me.isFluidConfirmedLow()
    return me.fluidConfirmedLow
end

function me.getLowReadCounter()
    return me.lowReadCounter
end

function me.getCPU()
    return me.cpu
end

return me
