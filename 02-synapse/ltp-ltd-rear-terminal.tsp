-- LTP/LTD with Rear Terminal + Data Save (FIXED)
reset()

-- ===== SELECT REAR TERMINALS FIRST =====
smu.measure.terminals = smu.TERMINALS_REAR

-- Parameters
local set_voltage = 0.01
local reset_voltage = -0.01
local pulse_width = 0.005
local read_voltage = 0.01
local num_cycles = 32
local current_limit = 0.0001

-- Data file with fallback
local filename = "/usb1/ALD13S_ltp_ltd_data.csv"
local file = io.open(filename, "w")

if not file then
    print("USB not accessible, using internal memory...")
    filename = "ltp_ltd_data.csv"
    file = io.open(filename, "w")
end

if file then
    file:write("Cycle,Type,Current,Conductance\n")
    print("Data will be saved to: " .. filename)
else
    print("WARNING: Could not open file")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.autorange = smu.ON
smu.source.ilimit.level = current_limit

smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.measure.nplc = 0.01

-- ===== OUTPUT ON =====
smu.source.output = smu.ON

print("Cycle, Type, Current(A), Conductance(S)")

for cycle = 1, num_cycles do
    -- SET pulse
    smu.source.level = set_voltage
    delay(pulse_width)
    smu.source.level = 0
    delay(0.01)
    
    -- Read state
    smu.source.level = read_voltage
    delay(0.001)
    local i_set = smu.measure.read()
    local g_set = i_set / read_voltage
    smu.source.level = 0
    
    local line = string.format("%d,SET,%.6e,%.6e", cycle, i_set, g_set)
    print(line)
    if file then file:write(line .. "\n") end
    delay(0.05)
    
    -- RESET pulse
    smu.source.level = reset_voltage
    delay(pulse_width)
    smu.source.level = 0
    delay(0.01)
    
    -- Read state
    smu.source.level = read_voltage
    delay(0.001)
    local i_reset = smu.measure.read()
    local g_reset = i_reset / read_voltage
    smu.source.level = 0
    
    line = string.format("%d,RESET,%.6e,%.6e", cycle, i_reset, g_reset)
    print(line)
    if file then file:write(line .. "\n") end
    delay(0.05)
end

smu.source.output = smu.OFF
if file then 
    file:close()
    print("Data saved to: " .. filename)
end
print("LTP/LTD sequence complete")