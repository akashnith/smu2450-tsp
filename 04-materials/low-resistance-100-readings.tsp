-- Reset the instrument to the default settings
reset()
-- Configure the Simple Loop trigger model template to make 100 readings.
trigger.model.load("SimpleLoop", 100)
-- Change the view on the front panel to the GRAPH swipe screen.
display.changescreen(display.SCREEN_GRAPH_SWIPE)
-- Set to measure resistance, use 4-wire sense,
-- and offset compensation.
smu.measure.func = smu.FUNC_RESISTANCE
smu.measure.sense = smu.SENSE_4WIRE
smu.measure.offsetcompensation = smu.ON
-- Turn on the output
smu.source.output = smu.ON
-- Initiate trigger model and wait until finished.
trigger.model.initiate()
waitcomplete()
-- Turn off output
smu.source.output = smu.OFF
-- Read the resistance and time values from defbuffer1.
print("Resistance:\tTime:")
for i = 1, 100 do
 print(string.format("%f\t%f", defbuffer1[i], defbuffer1.relativetimestamps[i]))
end