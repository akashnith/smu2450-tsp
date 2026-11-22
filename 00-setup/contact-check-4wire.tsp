--[[
    Simple Contact Check (Probing Test) - 4-Wire Version
    Instrument: Keithley 2450
    Description: Applies 1V and checks if current flows using 4-wire measurement.
]]

-- 1. Reset and Configure
reset()

local test_voltage = 30       -- 1V
local limit_current = 1e-2      -- 1 uA compliance
local min_threshold = 50e-9     -- 50 nA (Below this = Bad Contact)

-- Setup for 4-Wire Measurement
smu.measure.terminals = smu.TERMINALS_REAR
smu.measure.sense = smu.SENSE_4WIRE  -- Enable 4-wire (remote) sensing
smu.measure.autozero.enable = smu.ON

-- Source Configuration
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.autorange = smu.ON
smu.source.readback = smu.ON  -- Optional: read back actual sourced voltage

-- Measure Configuration
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON

-- 2. Execute Test
smu.source.ilimit.level = limit_current
smu.source.level = test_voltage
smu.source.output = smu.ON

delay(0.5) -- Wait for contact to stabilize

-- Read current (voltage is measured at sense terminals in 4W mode)
local current = smu.measure.read()
local voltage_measured = smu.source.level  -- Or use readback if enabled
local resistance = voltage_measured / current

smu.source.output = smu.OFF

-- 3. Display Results on Screen
display.changescreen(display.SCREEN_USER_SWIPE)
display.clear()

if math.abs(current) < min_threshold then
    -- FAIL CASE
    print("STATUS: OPEN / BAD CONTACT")
    display.settext(display.TEXT1, "BAD CONTACT")
    display.settext(display.TEXT2, string.format("I < %.1f nA", min_threshold*1e9))
else
    -- PASS CASE
    print("STATUS: GOOD CONTACT")
    display.settext(display.TEXT1, "CONTACT OK")
    display.settext(display.TEXT2, string.format("R = %.1f kOhm", resistance/1000))
end

-- Print details to console/buffer
print(string.format("Applied: %.3f V", test_voltage))
print(string.format("Measured: %.3e A", current))
print(string.format("Resistance: %.3e Ohms", resistance))
print("Mode: 4-Wire (Remote Sense)")