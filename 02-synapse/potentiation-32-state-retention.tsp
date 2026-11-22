-- 32-State Potentiation with 10s Retention (Sanitized)
reset()
errorqueue.clear() -- Clear previous errors

-- Configuration , change configuration according to sample behaviour 
smu.measure.terminals = smu.TERMINALS_REAR -- Ensure connections are on Rear
local start_v = 0.01
local end_v = 0.15
local num_states = 4
local pulse_w = 10e-3
local read_v = 0.01            
local retention_time = 10     -- 10 seconds change for more retention time 
local read_interval = 1     -- Read every 1s

-- Calculate step size
local v_step = (end_v - start_v) / (num_states - 1)

-- File Setup (USB1 priority, fallback to local)
local file_pot_path = "/usb1/ald13uspot_32.csv"
local file_ret_path = "/usb1/ald13usret_32.csv"

-- check if usb1 exists, otherwise write to local
if not io.open("/usb1/", "r") then
    file_pot_path = "pot_32.csv"
    file_ret_path = "ret_32.csv"
end

local file_pot = io.open(file_pot_path, "w")
local file_ret = io.open(file_ret_path, "w")

-- Write Headers
if file_pot then file_pot:write("State,Voltage_V,Conductance_uS\n") end
if file_ret then file_ret:write("State,Time_s,Conductance_uS\n") end

-- SMU Setup
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = 0.1
smu.measure.func = smu.FUNC_DC_CURRENT
smu.source.output = smu.ON

print("State, Voltage(V), Conductance(uS)")

-- Reset device condition
smu.source.level = -2.0
delay(0.5)
smu.source.level = 0
delay(0.1)

-- Main Loop
for state = 1, num_states do
    local v_pulse = start_v + (state - 1) * v_step
    
    -- 1. Apply Pulse
    smu.source.level = v_pulse
    delay(pulse_w)
    smu.source.level = 0
    delay(0.05)
    
    -- 2. Read Immediate State
    smu.source.level = read_v
    delay(0.01)
    local i = smu.measure.read()
    local g = (i / read_v) * 1e6 -- Calculate Conductance in uS
    smu.source.level = 0
    
    -- Log Potentiation Data
    local line = string.format("%d,%.3f,%.6f", state, v_pulse, g)
    print(line)
    if file_pot then file_pot:write(line .. "\n") end
    
    -- 3. Retention Test Loop
    -- print(string.format("Retention State %d...", state)) -- Optional: Uncomment to see progress
    
    -- Note: We use a manual timer loop to avoid 'for' loop float drift issues
    local t = 0
    while t <= retention_time do
        smu.source.level = read_v
        delay(0.01)
        i = smu.measure.read()
        g = (i / read_v) * 1e6
        smu.source.level = 0
        
        if file_ret then 
            file_ret:write(string.format("%d,%.1f,%.6f\n", state, t, g))
        end
        
        delay(read_interval)
        t = t + read_interval
    end
end

-- Cleanup
smu.source.output = smu.OFF
if file_pot then file_pot:close() end
if file_ret then file_ret:close() end
print("Complete")