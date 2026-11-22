-- STDP Measurement Protocol for Keithley 2450
reset()

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== STDP PARAMETERS =====
local pre_pulse_voltage = 0.01      -- Pre-synaptic pulse (V)
local post_pulse_voltage = 0.0120     -- Post-synaptic pulse (V)
local pulse_width = 0.005         -- Pulse width (1ms)
local read_voltage = 0.01           -- Read voltage (V)
local current_limit = 0.001          -- Compliance (A)

-- Time intervals to test (ms converted to seconds)
local delta_t_values = {
    -50e-3, -20e-3, -10e-3, -5e-3, 5e-3, 10e-3, 20e-3, 50e-3         -- LTP (post before pre)
}

local num_repeats = 3  -- Repeat each Δt for statistics

-- ===== DATA FILE =====
local filename = "/usb1/stdp_data.csv"
local file = io.open(filename, "w")

if not file then
    print("USB not accessible, using internal memory...")
    filename = "stdp_data.csv"
    file = io.open(filename, "w")
end

if file then
    file:write("DeltaT_ms,WeightChange_percent,Conductance_uS,Trial\n")
    print("Data will be saved to: " .. filename)
else
    print("WARNING: Could not open file, data will only print to console")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = current_limit
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.nplc = 0.1
smu.source.output = smu.ON

print("STDP Measurement Started")
print("DeltaT(ms), WeightChange(%), Conductance(uS), Trial")

-- ===== MAIN STDP PROTOCOL =====
for trial = 1, num_repeats do
    for _, delta_t in ipairs(delta_t_values) do
        
        -- Measure initial conductance
        smu.source.level = read_voltage
        delay(0.01)
        local i_initial = smu.measure.read()
        local g_initial = i_initial / read_voltage
        smu.source.level = 0
        delay(0.05)
        
        -- Apply STDP protocol
        if delta_t < 0 then
            -- LTD: Pre before Post (Δt negative)
            smu.source.level = pre_pulse_voltage
            delay(pulse_width)
            smu.source.level = 0
            delay(math.abs(delta_t))  -- Wait |Δt|
            smu.source.level = post_pulse_voltage
            delay(pulse_width)
            smu.source.level = 0
        else
            -- LTP: Post before Pre (Δt positive)
            smu.source.level = post_pulse_voltage
            delay(pulse_width)
            smu.source.level = 0
            delay(delta_t)  -- Wait Δt
            smu.source.level = pre_pulse_voltage
            delay(pulse_width)
            smu.source.level = 0
        end
        
        delay(0.1)  -- Relaxation time
        
        -- Measure final conductance
        smu.source.level = read_voltage
        delay(0.01)
        local i_final = smu.measure.read()
        local g_final = i_final / read_voltage
        smu.source.level = 0
        
        -- Calculate weight change
        local delta_g = g_final - g_initial
        local weight_change = (delta_g / g_initial) * 100  -- Percentage
        
        -- Print and save
        local delta_t_ms = delta_t * 1000  -- Convert to ms
        local line = string.format("%.2f,%.4f,%.6f,%d",
                                   delta_t_ms, weight_change, 
                                   g_final * 1e6, trial)
        print(line)
        
        if file then
            file:write(line .. "\n")
        end
        
        delay(0.5)  -- Inter-trial delay
    end
    
    -- Fixed: Changed from f-string to string.format
    print(string.format("Trial %d/%d complete", trial, num_repeats))
end

-- ===== CLEANUP =====
smu.source.output = smu.OFF

if file then
    file:close()
    print("Data saved to: " .. filename)
end

print("STDP measurement complete")