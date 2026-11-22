-- LIF (LEAKY INTEGRATE-AND-FIRE) NEURON EMULATION

reset()
errorqueue.clear()

-- 1. FIX: Correct Rear Terminal Command for 2450
if smu.terminals then
    smu.terminals = smu.TERMINALS_REAR
end

-- ===== LIF PARAMETERS =====
local input_voltage = 0.5          -- Input spike amplitude (V)
local spike_width = 10e-3          -- 10ms spike width
local inter_spike_interval = 50e-3 -- 50ms between spikes
local read_voltage = 0.1           -- Read voltage (V)
local threshold_conductance = 500  -- Firing threshold (uS)
local leak_duration = 2.0          -- Time to observe leak (s)
local max_spikes = 20              -- Maximum input spikes
local compliance = 100e-6

-- ===== DATA FILE =====
local filename = "/usb1/lif_neuron_behavior.csv"
local file = io.open(filename, "w")
if not file then
    print("Warning: USB not found. Printing to screen only.")
else
    file:write("SpikeNum,Time_ms,Conductance_uS,State\n")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = compliance
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.nplc = 0.01 -- Fast integration
smu.source.output = smu.ON

print("LIF Neuron Emulation Started")
print("SpikeNum, Time(ms), Conductance(uS), State")

-- Reset to Resting Potential (Low Conductance)
smu.source.level = -2.0
delay(0.5)
smu.source.level = 0
delay(0.1)

local current_time = 0
local fired = false
local final_spike_count = 0

-- PHASE 1: INTEGRATION (INPUT SPIKES)
for spike = 1, max_spikes do
    
    if fired then break end
    
    final_spike_count = spike
    
    -- A. Apply Input Spike (Integrate)
    smu.source.level = input_voltage
    delay(spike_width)
    smu.source.level = 0
    current_time = current_time + (spike_width * 1000)
    
    -- B. Read Membrane Potential (Conductance)
    delay(0.01)
    smu.source.level = read_voltage
    delay(0.01)
    local amps = smu.measure.read()
    local g = (amps / read_voltage) * 1e6  -- uS
    smu.source.level = 0
    
    local state = "INTEGRATING"
    
    -- C. Check Threshold
    if g >= threshold_conductance then
        state = "FIRED"
        fired = true
        print(string.format("*** NEURON FIRED at spike %d! ***", spike))
    end
    
    local line = string.format("%d,%.2f,%.6f,%s", spike, current_time, g, state)
    print(line)
    if file then file:write(line .. "\n") end
    
    -- D. Inter-Spike Interval (Leak happens here in real physics)
    if not fired then
        delay(inter_spike_interval)
        current_time = current_time + (inter_spike_interval * 1000)
    end
end

-- PHASE 2: LEAK OBSERVATION
print("Observing leak/decay phase...")

-- FIX: Replaced float loop with integer loop
-- 2.0s duration / 0.1s steps = 20 steps
local steps = leak_duration / 0.1 

for i = 1, steps do
    
    smu.source.level = read_voltage
    delay(0.01)
    local amps = smu.measure.read()
    local g = (amps / read_voltage) * 1e6
    smu.source.level = 0
    
    current_time = current_time + 100 -- Add 100ms per step
    
    local line = string.format("%d,%.2f,%.6f,LEAK", final_spike_count, current_time, g)
    
    -- FIX: Safe integer modulo (Print every 5th point)
    if math.mod(i, 5) == 0 then
        print(line)
    end
    
    if file then file:write(line .. "\n") end
    
    delay(0.1) -- 100ms delay
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

if file then file:close() end
print("LIF Neuron Emulation Complete")