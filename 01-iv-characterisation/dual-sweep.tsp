--[[ PROGRAM 2: STANDARD DUAL SWEEP ]]
reset()
errorqueue.clear()

local filename = "/usb1/Standard_Dual.csv"
local v_start = 0.5
local v_stop = 1.5
local v_step = 0.25
local icc = 500e-6 

-- Setup for Precision
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autozero.enable = smu.ON   -- ON for accuracy
smu.measure.nplc = 1.0                 -- Standard integration
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.terminals = smu.TERMINAL_REAR

-- Create Buffer
local def_buf = defbuffer1
def_buf.clear()
def_buf.capacity = 10000

print("Starting Standard Range Sweep...")

-- Stepped Sweep: 0.5, 0.75, 1.0, 1.25, 1.5
for v_target = v_start, v_stop, v_step do
    print("Sweeping Target: " .. v_target .. " V")
    smu.source.ilimit.level = icc
    
    -- High res dual sweep (100 points per leg approx)
    local step_size = v_target / 25 
    
    -- 0 -> V
    for v = 0, v_target, step_size do
        smu.source.level = v
        delay(0.001) -- Settling time
        smu.measure.read(def_buf)
    end
    -- V -> 0
    for v = v_target, 0, -step_size do
        smu.source.level = v
        delay(0.001)
        smu.measure.read(def_buf)
    end
    -- 0 -> -V
    for v = 0, -v_target, -step_size do
        smu.source.level = v
        delay(0.001)
        smu.measure.read(def_buf)
    end
    -- -V -> 0
    for v = -v_target, 0, step_size do
        smu.source.level = v
        delay(0.001)
        smu.measure.read(def_buf)
    end
end

smu.source.level = 0
smu.source.output = smu.OFF

-- Save
print("Saving to " .. filename)
file.save(filename, def_buf)
print("Done.")