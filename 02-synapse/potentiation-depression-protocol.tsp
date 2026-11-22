-- Potentiation and Depression Protocol
reset()

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== PARAMETERS =====
local set_voltage = 2.0           -- Potentiation voltage (V)
local reset_voltage = -2.5        -- Depression voltage (V)
local pulse_width = 100e-3        -- 100ms pulse width
local read_voltage = 0.2          -- Read voltage (V)
local read_time = 300e-3          -- 300ms read time
local current_limit = 0.01         -- Compliance (A)

local num_set_pulses = 32         -- Number of potentiation pulses
local num_reset_pulses = 32       -- Number of depression pulses
local num_cycles = 5              -- Number of full cycles (for figure b)

-- ===== DATA FILE =====
local filename = "/usb1/pot_dep_cycles.csv"
local file = io.open(filename, "w")

if not file then
    print("USB not accessible, using internal memory...")
    filename = "pot_dep_cycles.csv"
    file = io.open(filename, "w")
end

if file then
    file:write("Cycle,PulseNum,Type,Conductance_nS\n")
    print("Data will be saved to: " .. filename)
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = current_limit
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.nplc = 0.1
smu.source.output = smu.ON

print("Potentiation/Depression Cycling Started")
print("Cycle, PulseNum, Type, Conductance(nS)")

local total_pulse = 0

-- ===== MULTI-CYCLE LOOP =====
for cycle = 1, num_cycles do
    
    print(string.format("=== Cycle %d/%d - Potentiation Phase ===", cycle, num_cycles))
    
    -- POTENTIATION PHASE
    for pulse = 1, num_set_pulses do
        total_pulse = total_pulse + 1
        
        -- Apply SET pulse
        smu.source.level = set_voltage
        delay(pulse_width)
        smu.source.level = 0
        delay(0.01)
        
        -- Read conductance
        smu.source.level = read_voltage
        delay(read_time)
        local current = smu.measure.read()
        local conductance = (current / read_voltage) * 1e9  -- Convert to nS
        smu.source.level = 0
        delay(0.01)
        
        -- Save data
        local line = string.format("%d,%d,POT,%.3f", cycle, total_pulse, conductance)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    print(string.format("=== Cycle %d/%d - Depression Phase ===", cycle, num_cycles))
    
    -- DEPRESSION PHASE
    for pulse = 1, num_reset_pulses do
        total_pulse = total_pulse + 1
        
        -- Apply RESET pulse
        smu.source.level = reset_voltage
        delay(pulse_width)
        smu.source.level = 0
        delay(0.01)
        
        -- Read conductance
        smu.source.level = read_voltage
        delay(read_time)
        local current = smu.measure.read()
        local conductance = (current / read_voltage) * 1e9  -- Convert to nS
        smu.source.level = 0
        delay(0.01)
        
        -- Save data
        local line = string.format("%d,%d,DEP,%.3f", cycle, total_pulse, conductance)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    print(string.format("Cycle %d complete", cycle))
    delay(0.1)
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

if file then
    file:close()
    print("Data saved to: " .. filename)
end

print("Multi-cycle measurement complete")