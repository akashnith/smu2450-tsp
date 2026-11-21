-- ==================================================================
-- REFRACTORY PERIOD MEASUREMENT
-- Test responsiveness to second stimulus at various intervals
-- ==================================================================

reset()

-- ===== REAR TERMINAL SELECTION =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== PARAMETERS =====
local stimulus_voltage = 2.0
local stimulus_width = 20e-3
local read_voltage = 0.1
local inter_stimulus_intervals = {5e-3, 10e-3, 20e-3, 50e-3, 100e-3}
local compliance = 100e-6

-- ===== DATA FILE =====
local filename = "/usb1/refractory_period.csv"
local file = io.open(filename, "w")
if not file then
    filename = "refractory_period.csv"
    file = io.open(filename, "w")
end

if file then
    file:write("ISI_ms,Response1_uS,Response2_uS,RelativeResponse\n")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.limiti = compliance
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.nplc = 0.01
smu.source.output = smu.ON

print("Refractory Period Measurement")
print("ISI(ms), Response1(µS), Response2(µS), Relative")

-- ===== TEST EACH ISI =====
for _, isi in ipairs(inter_stimulus_intervals) do
    
    -- Reset device
    smu.source.limiti = 100e-3
    smu.source.level = -2.0
    delay(0.5)
    smu.source.level = 0
    delay(0.2)
    
    -- First stimulus
    smu.source.limiti = compliance
    smu.source.level = stimulus_voltage
    delay(stimulus_width)
    smu.source.level = 0
    delay(0.01)
    
    -- Measure response 1
    smu.source.limiti = 100e-3
    smu.source.level = read_voltage
    delay(0.01)
    local i1 = smu.measure.read()
    local g1 = (i1 / read_voltage) * 1e6
    smu.source.level = 0
    
    -- Wait inter-stimulus interval
    delay(isi)
    
    -- Second stimulus
    smu.source.limiti = compliance
    smu.source.level = stimulus_voltage
    delay(stimulus_width)
    smu.source.level = 0
    delay(0.01)
    
    -- Measure response 2
    smu.source.level = read_voltage
    delay(0.01)
    local i2 = smu.measure.read()
    local g2 = (i2 / read_voltage) * 1e6
    smu.source.level = 0
    
    -- Calculate relative response
    local relative = (g2 / g1) * 100
    
    local line = string.format("%.1f,%.6f,%.6f,%.2f", 
                               isi * 1e3, g1, g2, relative)
    print(line)
    if file then file:write(line .. "\n") end
    
    delay(0.5)
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

if file then file:close() end
print("Refractory Period Measurement Complete")