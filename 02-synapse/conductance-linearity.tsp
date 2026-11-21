-- ==================================================================
-- TEST 11: CONDUCTANCE LINEARITY
-- Fixed-amplitude pulse train for potentiation/depression
-- ==================================================================

reset()

-- ===== REAR TERMINAL SELECTION =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== PARAMETERS =====
local pot_voltage = 1.5              -- Potentiation voltage (V)
local dep_voltage = -1.5             -- Depression voltage (V)
local pulse_width = 100e-3
local read_voltage = 0.1
local num_pulses = 50
local compliance_set = 100e-6
local compliance_reset = 100e-3

-- ===== DATA FILE =====
local filename = "/usb1/conductance_linearity.csv"
local file = io.open(filename, "w")
if not file then
    filename = "conductance_linearity.csv"
    file = io.open(filename, "w")
end

if file then
    file:write("PulseNum,Type,Conductance_uS,DeltaG_uS\n")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.nplc = 0.01
smu.source.output = smu.ON

print("Conductance Linearity Test Started")
print("PulseNum, Type, Conductance(µS), DeltaG(µS)")

-- Reset device
smu.source.limiti = compliance_reset
smu.source.levelv = -2.0
delay(0.5)
smu.source.levelv = 0
delay(0.1)

local g_prev = 0

-- ===== POTENTIATION =====
for pulse = 1, num_pulses do
    
    -- Apply potentiation pulse
    smu.source.limiti = compliance_set
    smu.source.levelv = pot_voltage
    delay(pulse_width)
    smu.source.levelv = 0
    delay(0.01)
    
    -- Read conductance
    smu.source.limiti = 100e-3
    smu.source.levelv = read_voltage
    delay(0.01)
    local i = smu.measure.i()
    local g = (i / read_voltage) * 1e6
    smu.source.levelv = 0
    
    local delta_g = g - g_prev
    g_prev = g
    
    local line = string.format("%d,POT,%.6f,%.6f", pulse, g, delta_g)
    print(line)
    if file then file:write(line .. "\n") end
    
    delay(0.01)
end

-- ===== DEPRESSION =====
for pulse = 1, num_pulses do
    
    -- Apply depression pulse
    smu.source.limiti = compliance_reset
    smu.source.levelv = dep_voltage
    delay(pulse_width)
    smu.source.levelv = 0
    delay(0.01)
    
    -- Read conductance
    smu.source.levelv = read_voltage
    delay(0.01)
    local i = smu.measure.i()
    local g = (i / read_voltage) * 1e6
    smu.source.levelv = 0
    
    local delta_g = g - g_prev
    g_prev = g
    
    local line = string.format("%d,DEP,%.6f,%.6f", pulse, g, delta_g)
    print(line)
    if file then file:write(line .. "\n") end
    
    delay(0.01)
end

-- ===== CLEANUP =====
smu.source.levelv = 0
smu.source.output = smu.OFF

if file then file:close() end
print("Conductance Linearity Test Complete")