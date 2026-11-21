-- Pulsed I-V Measurement with 10ms pulses
reset()

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== PULSE PARAMETERS =====
local voltages = {5.0, 5.8, 7.7, 0.5, 0.5, 0.5, -1.6, -0.8}  -- Voltage sequence (V)
local pulse_width = 10e-3           -- 10 milliseconds
local base_voltage = 0.0            -- Base level
local inter_pulse_delay = 20e-3     -- 10ms between pulses
local current_limit = 0.1           -- Compliance (A)

-- ===== DATA FILE =====
local filename = "/usb1/pulsed_iv_10ms.csv"
local file = io.open(filename, "w")

if not file then
    print("USB not accessible, using internal memory...")
    filename = "pulsed_iv_10ms.csv"
    file = io.open(filename, "w")
end

if file then
    file:write("Time_ms,Voltage_V,Current_A\n")
    print("Data will be saved to: " .. filename)
else
    print("WARNING: Data will only print to console")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = current_limit
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.nplc = 1
smu.source.output = smu.ON

print("Starting Pulsed I-V Measurement (10ms pulses)")
print("Time(ms), Voltage(V), Current(A)")

local time = 0  -- Time in milliseconds

-- ===== PULSE SEQUENCE =====
for _, voltage in ipairs(voltages) do
    
    -- Apply voltage pulse
    smu.source.level = voltage
    delay(pulse_width)
    local current = smu.measure.read()
    
    -- Record pulse
    local line = string.format("%.3f,%.3f,%.6e", time, voltage, current)
    print(line)
    if file then
        file:write(line .. "\n")
    end
    
    time = time + pulse_width * 1e3  -- Convert to ms
    
    -- Return to base level
    smu.source.level = base_voltage
    delay(inter_pulse_delay)
    local current_base = smu.measure.read()
    
    -- Record base level
    line = string.format("%.3f,%.3f,%.6e", time, base_voltage, current_base)
    print(line)
    if file then
        file:write(line .. "\n")
    end
    
    time = time + inter_pulse_delay * 1e3
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

if file then
    file:close()
    print("Data saved to: " .. filename)
end

print("Pulsed I-V measurement complete")