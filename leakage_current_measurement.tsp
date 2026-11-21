-- Reset the instrument, which also clears the buffer.
reset()
-- Set up the source function.
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = 10e-3
smu.source.level = 1
-- Set up measure function.
smu.measure.func = smu.FUNC_DC_CURRENT
smu.terminals = smu.TERMINALS_REAR
smu.measure.autorange = smu.ON
smu.measure.nplc = 1
-- Turn on the output and initiate readings.
smu.source.output = smu.ON
trigger.model.load("DurationLoop", 60, 0.2)
trigger.model.initiate()
-- Wait for the trigger model to complete.
waitcomplete()
-- Parse index and data into three columns.
print("Rdg #", "Time (s)", "Current (A)")
for i = 1, defbuffer1.n do
 print(i, defbuffer1.relativetimestamps[i], defbuffer1[i])
end
-- Discharge the capacitor to 0 V and turn off the output.
smu.source.level = 0
smu.source.output = smu.ON
delay(2)
smu.source.output = smu.OFF