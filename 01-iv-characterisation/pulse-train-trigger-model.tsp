-- Reset SMU
reset()

local v_high = 5
local v_low = 0
local pulse_width = 0.5  -- seconds
local num_pulses = 10

smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.source.autorange = smu.ON

-- Create a Trigger Model to toggle levels
trigger.model.setblock(1, trigger.BLOCK_SOURCE_OUTPUT, smu.ON)
trigger.model.setblock(2, trigger.BLOCK_SOURCE_LEVEL_CONSTANT, v_high)
trigger.model.setblock(3, trigger.BLOCK_DELAY_CONSTANT, pulse_width)
trigger.model.setblock(4, trigger.BLOCK_MEASURE_DIGITIZE, defbuffer1)
trigger.model.setblock(5, trigger.BLOCK_SOURCE_LEVEL_CONSTANT, v_low)
trigger.model.setblock(6, trigger.BLOCK_DELAY_CONSTANT, pulse_width)
trigger.model.setblock(7, trigger.BLOCK_MEASURE_DIGITIZE, defbuffer1)
trigger.model.setblock(8, trigger.BLOCK_BRANCH_COUNTER, num_pulses, 2)
trigger.model.setblock(9, trigger.BLOCK_SOURCE_OUTPUT, smu.OFF)

trigger.model.initiate()