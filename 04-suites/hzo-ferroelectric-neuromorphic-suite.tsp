-- =============================================================================
-- MASTER HZO FERROELECTRIC & NEUROMORPHIC SCRIPT
-- Instrument: Keithley 2450 SourceMeter
-- Terminals: REAR
-- =============================================================================

reset()
errorqueue.clear()

-- === 1. CRITICAL SETUP ===
smu.terminals = smu.TERMINALS_REAR  -- <--- FORCE REAR TERMINALS

-- === GLOBAL PARAMETERS ===
local V_SET       = 0.9       -- Positive switching voltage (V)
local V_RESET     = -1.0      -- Negative switching voltage (V)
local V_READ      = 0.1       -- Read voltage (V)
local I_COMPLIANCE = 10e-3    -- 10mA compliance
local PULSE_WIDTH = 5e-3      -- 5ms pulse width
local DEVICE_AREA = 100e-8    -- 100 um^2 in cm^2

-- === SMU CONFIGURATION ===
function SetupSMU()
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.source.autorange = smu.OFF
    smu.source.range = 10 -- Fixed 20V range for speed
    smu.source.ilimit.level = I_COMPLIANCE
    
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.OFF
    smu.measure.range = 1e-3 -- 1mA range for better resolution
    smu.measure.nplc = 0.01  -- Fast measurement (PLC < 1)
    
    smu.source.output = smu.ON
end

-- === HELPER: READ CONDUCTANCE ===
function Read_Conductance()
    smu.source.level = V_READ
    delay(0.002) -- Charging delay
    local i = smu.measure.read()
    smu.source.level = 0
    return i / V_READ
end




-- =============================================================================
-- USB DATA LOGGING SETUP
-- =============================================================================
local use_usb = true -- Set to false to print to screen only
local file_handle = nil

-- Function to Open a File on USB
function Open_Log(filename)
    if use_usb then
        -- "/usb1/" is the standard path for the front USB port
        local path = "/usb1/" .. filename .. ".csv" 
        file_handle = io.open(path, "w")
        if file_handle == nil then
            print("ERROR: USB Drive not detected or write protected!")
        else
            print("Logging to: " .. path)
        end
    end
end

-- Function to Write Data
function Log(data_string)
    print(data_string) -- Keep printing to screen
    if use_usb and file_handle then
        file_handle:write(data_string .. "\n")
    end
end

-- Function to Close File
function Close_Log()
    if use_usb and file_handle then
        file_handle:close()
        file_handle = nil
        print("File saved and closed.")
    end
end
-- =============================================================================
-- MODULE 1: FERROELECTRIC CHARACTERIZATION
-- =============================================================================

-- 1. WAKE-UP CYCLING
function Run_WakeUp(cycles, freq)
    print("--- Starting Wake-Up Cycling ---")
    local delay_time = 1/(2*freq)
    
    for i = 1, cycles do
        smu.source.level = V_SET
        delay(delay_time)
        smu.source.level = V_RESET
        delay(delay_time)
        
        if math.mod(i, 1000) == 0 then
            print(string.format("Cycle: %d", i))
        end
    end
    smu.source.level = 0
    print("Wake-Up Complete")
end

-- 2. P-E HYSTERESIS LOOP (Quasistatic)
function Run_PE_Loop(v_max, steps)
    print("--- Starting P-E Loop ---")
    print("Voltage, Current")
    
    local step_size = (v_max * 4) / steps
    local v_curr = 0
    local v_targets = {v_max, -v_max, 0}
    
    for _, v_target in ipairs(v_targets) do
        while math.abs(v_curr - v_target) > 0.01 do
            if v_curr < v_target then v_curr = v_curr + step_size
            else v_curr = v_curr - step_size end
            
            smu.source.level = v_curr
            local i = smu.measure.read()
            print(string.format("%.4f, %.6e", v_curr, i))
        end
    end
    smu.source.level = 0
end

-- 3. PUND MEASUREMENT
function Run_PUND(v_amp, p_width)
    print("--- Starting PUND ---")
    
    local function Pulse_Measure(v, name)
        smu.source.level = v
        delay(p_width)
        local i = smu.measure.read()
        smu.source.level = 0
        delay(p_width) 
        local q = i * p_width 
        print(string.format("%s, %.2fV, Q=%.2e", name, v, q))
        return q
    end
    
    Pulse_Measure(-v_amp, "Preset") 
    local Q_P = Pulse_Measure(v_amp, "P_Switch")
    local Q_U = Pulse_Measure(v_amp, "U_NonSwitch")
    Pulse_Measure(v_amp, "Preset_Neg")
    local Q_N = Pulse_Measure(-v_amp, "N_Switch")
    local Q_D = Pulse_Measure(-v_amp, "D_NonSwitch")
    
    local Q_sw = ((Q_P - Q_U) + (Q_D - Q_N)) / 2
    local Pr = (Q_sw / DEVICE_AREA) * 1e6 
    print(string.format("Pr = %.2f uC/cm2", Pr))
end

-- =============================================================================
-- MODULE 2: SYNAPTIC MEASUREMENTS
-- =============================================================================

-- 4. LTP & LTD (Synaptic Plasticity)
function Run_LTP_LTD(num_pulses, pulse_v)
    print("--- Starting LTP/LTD ---")
    print("Pulse, Conductance")
    
    -- Reset to Low State
    smu.source.level = -pulse_v
    delay(0.1)
    
    -- LTP (Potentiation)
    for i = 1, num_pulses do
        smu.source.level = pulse_v
        delay(PULSE_WIDTH)
        smu.source.level = 0
        print(string.format("%d, %.6e", i, Read_Conductance()))
    end
    
    -- LTD (Depression)
    for i = 1, num_pulses do
        smu.source.level = -pulse_v
        delay(PULSE_WIDTH)
        smu.source.level = 0
        print(string.format("%d, %.6e", num_pulses+i, Read_Conductance()))
    end
end

-- 5. STDP (Spike Timing Dependent Plasticity)
function Run_STDP()
    print("--- Starting STDP ---")
    print("Delta_t, Delta_G")
    
    local time_points = {-0.1, -0.05, -0.01, 0.01, 0.05, 0.1}
    
    for _, dt in ipairs(time_points) do
        -- Reset
        smu.source.level = -V_SET
        delay(0.1)
        smu.source.level = V_SET/2 
        delay(0.01)
        
        local g_initial = Read_Conductance()
        
        -- Simulate Pulse Overlap
        local decay = math.exp(-math.abs(dt)/0.05)
        local v_eff = V_SET * decay
        if dt < 0 then v_eff = -v_eff end
        
        smu.source.level = v_eff
        delay(0.01)
        smu.source.level = 0
        
        local g_final = Read_Conductance()
        print(string.format("%.3f, %.6e", dt, g_final - g_initial))
    end
end

-- 6. PAIRED PULSE FACILITATION (PPF)
function Run_PPF()
    print("--- Starting PPF ---")
    print("Delay, PPF_%")
    
    local delays = {0.001, 0.005, 0.01, 0.05, 0.1}
    
    for _, t_delay in ipairs(delays) do
        smu.source.level = V_RESET
        delay(0.1)
        
        -- Pulse 1
        smu.source.level = V_SET * 0.8
        delay(PULSE_WIDTH)
        smu.source.level = 0
        local g1 = Read_Conductance()
        
        delay(t_delay)
        
        -- Pulse 2
        smu.source.level = V_SET * 0.8
        delay(PULSE_WIDTH)
        smu.source.level = 0
        local g2 = Read_Conductance()
        
        local ppf = ((g2 - g1) / g1) * 100
        print(string.format("%.3f, %.2f", t_delay, ppf))
    end
end

-- =============================================================================
-- MODULE 3: NEURON MEASUREMENT
-- =============================================================================

-- 7. INTEGRATE AND FIRE NEURON
function Run_IF_Neuron(threshold_amp)
    print("--- Starting IF Neuron ---")
    print("Pulse, Current, State")
    
    smu.source.level = V_RESET
    delay(0.1)
    
    local sub_v = V_SET * 0.7
    local fired = false
    
    for i = 1, 50 do
        smu.source.level = sub_v
        delay(PULSE_WIDTH)
        local i_meas = smu.measure.read()
        smu.source.level = 0
        delay(PULSE_WIDTH)
        
        local state = "Integrating"
        if i_meas > threshold_amp then
            state = "FIRE"
            fired = true
        end
        print(string.format("%d, %.6e, %s", i, i_meas, state))
        if fired then break end
    end
end
-- =============================================================================
-- MODULE 4: MULTI-LEVEL STATES (ANALOG MEMORY)
-- =============================================================================

-- 8. MULTI-STATE WRITE (Amplitude Modulation)
-- Sweeps pulse amplitude to find distinct conductance levels
function Run_Multistate_Write(v_start, v_stop, num_levels)
    print("--- Starting Multi-State Write Sweep ---")
    print("Level_ID, Write_Voltage, Conductance_S")

    -- 1. Global Reset (Ensure known starting state)
    smu.source.level = V_RESET
    delay(0.1)
    smu.source.level = 0
    delay(0.1)

    -- 2. Calculate Voltage Step
    local v_step = (v_stop - v_start) / (num_levels - 1)
    
    for i = 0, num_levels - 1 do
        local v_pulse = v_start + (i * v_step)
        
        -- A. WRITE PULSE
        smu.source.level = v_pulse
        delay(PULSE_WIDTH)
        smu.source.level = 0
        
        -- B. RELAXATION DELAY (Critical for Ferroelectrics)
        delay(0.01) 
        
        -- C. READ VERIFY
        local g = Read_Conductance()
        
        print(string.format("%d, %.3f, %.6e", i+1, v_pulse, g))
    end
end

-- 9. MULTI-STATE RETENTION CHECK
-- Programs a specific state and watches it drift over time
function Run_Multistate_Retention(target_v, duration_s)
    print("--- Retention Test: State V=" .. target_v .. " ---")
    print("Time_s, Conductance_S")

    -- 1. Program the specific State
    smu.source.level = V_RESET -- Reset first
    delay(0.05)
    smu.source.level = target_v -- Write target state
    delay(PULSE_WIDTH)
    smu.source.level = 0
    
    -- 2. Monitor Drift
    local timer = 0
    local interval = 1 -- Read every 1 second
    
    while timer < duration_s do
        local g = Read_Conductance()
        print(string.format("%.1f, %.6e", timer, g))
        
        delay(interval)
        timer = timer + interval
    end
end
-- =============================================================================
-- MAIN EXECUTION BLOCK (Uncomment to Run)
-- =============================================================================

SetupSMU()

Run_WakeUp(5, 1000)
Run_PE_Loop(3.0, 50)
Run_PUND(3.0, 0.001)
Run_LTP_LTD(50, 2.5)
Run_STDP()
Run_PPF()
Run_IF_Neuron(100e-6)
Run_Multistate_Write(1.0, 3.0, 16)
Run_Multistate_Retention(2.0, 60)
smu.source.output = smu.OFF