
local config = require "sprites.modules.config"

local txd = CreateRuntimeTxd('sprites')
for i = 1, #config.shapes do
    local img = config.shapes[i]
    CreateRuntimeTextureFromImage(txd, img, 'assets/' .. img .. '.png')
end

for i = 1, #config.keySprites do
    local img = config.keySprites[i]
    CreateRuntimeTextureFromImage(txd, img, 'assets/' .. img .. '.png')
end