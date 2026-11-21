-- Reset instrument
reset()

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR
-- Configure for voltage source
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.autorange = smu.ON
smu.source.readback = smu.ON

-- Set current measurement and compliance
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.source.ilimit.level = 0.01  -- 100mA current limit

-- Turn output on
smu.source.output = smu.ON

-- IV Sweep: 0V to 5V in 0.1V steps
for v = 0, 0.5, 0.01 do
    smu.source.level = v
    delay(0.01)  -- 10ms settling time
    reading = smu.measure.read()
    print(string.format("V: %.2f, I: %.6e", v, reading))
end

for v = 0.5, 0, -0.01 do
    smu.source.level = v
    delay(0.01)  -- 10ms settling time
    reading = smu.measure.read()
    print(string.format("V: %.2f, I: %.6e", v, reading))
end

for v = -0.01, -1, -0.01 do
    smu.source.level = v
    delay(0.01)  -- 10ms settling time
    reading = smu.measure.read()
    print(string.format("V: %.2f, I: %.6e", v, reading))
end

for v = -1, 0, 0.01 do
    smu.source.level = v
    delay(0.01)  -- 10ms settling time
    reading = smu.measure.read()
    print(string.format("V: %.2f, I: %.6e", v, reading))
end
-- Turn output off
smu.source.output = smu.OFF

print("Sweep complete")