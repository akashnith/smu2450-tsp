-- Simple DC I-V Sweep for Keithley 2450
reset()
smu.measure.terminals = smu.TERMINALS_REAR

-- Parameters
local v_start = 0
local v_end = 1.0
local v_step = 0.1
local current_limit = 0.0001

-- Data file
local file = io.open("/usb1/dc_iv_sweep.csv", "w")
if not file then
    file = io.open("dc_iv_sweep.csv", "w")
end

if file then
    file:write("Voltage_V,Current_A\n")
end

-- Configure
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.autorange = smu.ON
smu.source.ilimit.level = current_limit
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.source.output = smu.ON

print("Voltage(V), Current(A)")

-- Sweep
for v = v_start, v_end, v_step do
    smu.source.level = v
    delay(0.01)
    local i = smu.measure.read()
    
    local line = string.format("%.3f,%.6e", v, i)
    print(line)
    if file then file:write(line .. "\n") end
end

-- Cleanup
smu.source.level = 0
smu.source.output = smu.OFF
if file then file:close() end
print("DC I-V sweep complete")