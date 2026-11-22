-- Memristor I-V Sweep (2-Wire Rear) - Error Protected
reset()
defbuffer1.clearstatistics()

-- Rear terminals, 2-wire
smu.terminals = smu.TERMINALS_REAR
smu.measure.sense = smu.SENSE_2WIRE

-- Measure current settings
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.measure.nplc = 1
smu.measure.offsetcompensation = smu.ON

-- Source voltage settings
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.autorange = smu.ON
smu.source.ilimit.level = 10e-3  -- 10mA compliance
smu.source.ilimit.autorange = smu.ON
smu.source.delay = 0.01

-- Voltage sweep: -2V to +2V, 101 points
smu.source.sweeplinear("IVSweep", -2, 2, 101)

-- Execute with error checking
smu.source.output = smu.ON
trigger.model.initiate()
waitcomplete()
smu.source.output = smu.OFF

-- Safe buffer output
print("Voltage(V)\tCurrent(A)")
if defbuffer1.n > 0 then
    for i = 1, defbuffer1.n do
        print(string.format("%7.3f\t%12.3e", 
               defbuffer1.sourcevalues[i], 
               defbuffer1.readings[i]))
    end
    print(string.format("Total readings: %d", defbuffer1.n))
else
    print("ERROR: No data collected - check wiring/compliance")
end

-- Dump errors
if errorqueue.count > 0 then
    print("Script errors:")
    errorqueue.dump()
end
