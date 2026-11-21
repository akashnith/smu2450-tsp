-- Neuromorphic Pulse Measurement Script for Keithley 2450
reset()

-- ===== PULSE PARAMETERS =====
local pulse_amplitude = 1.0      -- Voltage amplitude (V)
local pulse_width = 0.001        -- Pulse width (seconds) - 1ms
local pulse_delay = 0.01         -- Delay between pulses (seconds) - 10ms
local base_level = 0.0           -- Base voltage level (V)
local num_pulses = 10            -- Number of pulses
local current_limit = 0.1        -- Current compliance (A)

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.readback = smu.ON
smu.source.autorange = smu.ON
smu.source.ilimit.level = current_limit

smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.measure.nplc = 0.01  -- Fast measurement (0.01 PLCs)

-- ===== OUTPUT ON =====
smu.source.output = smu.ON
smu.source.level = base_level
delay(0.1)  -- Initial settling

print("Starting neuromorphic pulse measurements...")
print("Pulse#, Time(s), Voltage(V), Current(A)")

-- ===== PULSE GENERATION =====
for pulse = 1, num_pulses do
    local start_time = os.clock()
    
    -- Apply pulse
    smu.source.level = pulse_amplitude
    delay(pulse_width)
    local i_pulse = smu.measure.read()
    
    -- Return to base level
    smu.source.level = base_level
    
    -- Print results
    print(string.format("%d, %.6f, %.3f, %.6e", 
          pulse, start_time, pulse_amplitude, i_pulse))
    
    -- Wait before next pulse
    delay(pulse_delay)
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF
print("Pulse sequence complete")