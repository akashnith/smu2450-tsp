-- Multi-Cycle Potentiation/Depression Protocol
reset()

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== PARAMETERS =====
local potentiation_voltage = 0.01
local depression_voltage = -0.01
local pulse_width = 10e-3          -- 100 microseconds
local read_voltage = 0.01
local inter_pulse_delay = 1e-3
local current_limit = 0.0001

local pulses_per_phase = 64         -- Pulses in each phase
local num_cycles = 50                -- Number of full cycles

-- ===== DATA FILE =====
local filename = "/usb1/ALsD13S_multi_cycle_ltp_ltd.csv"
local file = io.open(filename, "w")

if not file then
    filename = "multi_cycle_ltp_ltd.csv"
    file = io.open(filename, "w")
end

if file then
    file:write("Cycle,PulseNum,Type,Current_A,Conductance_uS\n")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = current_limit
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.nplc = 0.01
smu.source.output = smu.ON

print("Multi-Cycle Potentiation/Depression Protocol")
print("Cycle, PulseNum, Type, Current(A), Conductance(uS)")

local total_pulse = 0

-- ===== MULTI-CYCLE LOOP =====
for cycle = 1, num_cycles do
    
    -- POTENTIATION PHASE
    for pulse = 1, pulses_per_phase do
        total_pulse = total_pulse + 1
        
        -- Apply pulse
        smu.source.level = potentiation_voltage
        delay(pulse_width)
        smu.source.level = 0
        delay(inter_pulse_delay)
        
        -- Read
        smu.source.level = read_voltage
        delay(0.001)
        local current = smu.measure.read()
        local conductance = current / read_voltage
        smu.source.level = 0
        
        -- Save
        local line = string.format("%d,%d,POT,%.6e,%.6f", 
                                   cycle, total_pulse, current, conductance * 1e6)
        print(line)
        if file then file:write(line .. "\n") end
        
        delay(inter_pulse_delay)
    end
    
    print(string.format("Cycle %d: Potentiation complete", cycle))
    
    -- DEPRESSION PHASE
    for pulse = 1, pulses_per_phase do
        total_pulse = total_pulse + 1
        
        -- Apply pulse
        smu.source.level = depression_voltage
        delay(pulse_width)
        smu.source.level = 0
        delay(inter_pulse_delay)
        
        -- Read
        smu.source.level = read_voltage
        delay(0.001)
        local current = smu.measure.read()
        local conductance = current / read_voltage
        smu.source.level = 0
        
        -- Save
        local line = string.format("%d,%d,DEP,%.6e,%.6f", 
                                   cycle, total_pulse, current, conductance * 1e6)
        print(line)
        if file then file:write(line .. "\n") end
        
        delay(inter_pulse_delay)
    end
    
    print(string.format("Cycle %d: Depression complete", cycle))
    delay(0.1)
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

if file then
    file:close()
    print("Data saved to: " .. filename)
end

print("Multi-cycle protocol complete")