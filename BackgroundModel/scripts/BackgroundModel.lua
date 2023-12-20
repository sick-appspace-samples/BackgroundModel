
--Start of Global Scope---------------------------------------------------------

-- This is an area sensor so we select false here.
local lineScanSensor = false

-- The first two background models will never forget their past.
-- They are therefore suited for adding images in a teach phase
-- followed by a use phase where compares are called.
--
-- The RunningGaussian background model allows the model to adapt
-- to changes over time. It may be combined with a Image.PixelRegion
-- in the add call to allow adapting to changes in one area, but not
-- another.

-- This version models the background using a simple average
--local meanThreshold = 2.0
--local varianceThreshold = nil -- Average model does not support a variance threshold
--local backgroundModel = Image.BackgroundModel.createAverage(lineScanSensor)

-- This version models the background using an average and a variance
--local meanThreshold = 1.5
--local varianceThreshold = 2.0
--local backgroundModel = Image.BackgroundModel.createGaussian(lineScanSensor)

-- Create a background model object with a learning rate
-- The selected learning rate is typically too high for a real application
-- but gives a nice visualization of the model as it updates.
local learningRate = 1/20
local meanThreshold = 1.5
local varianceThreshold = 2.0
local backgroundModel = Image.BackgroundModel.createRunningGaussian(lineScanSensor, learningRate)

-- Create a viewer and a decorator that spans 0 to 100 degrees celsius
local viewer = View.create()
local imagedecoration = View.ImageDecoration.create():setRange(0, 100)

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

---Handle each captured image
---@param image Image
local function callback(image)

  -- Update background model with this new observation
  backgroundModel:add(image)

  -- Use model to get parts of the image that don't belong
  local fg = backgroundModel:compare(image, "BRIGHTER", meanThreshold, varianceThreshold)

  -- Get the model content
  local modelImages = backgroundModel:getModelImages()

  ---Function used to build a visualization image
  ---This will concatenate the input image with any provided model images
  ---@param input Image
  ---@param modelImagesV Image[]
  ---@return Image
  local function createDisplayImage(input, modelImagesV)
    ---@param inputI Image
    ---@return Image
    local function toFloat(inputI)
      local inputF = Image.toType(inputI, "FLOAT32")
      local _,_,pixelSizeZ = Image.getPixelSize(inputI)
      local originZ = Image.getOrigin(inputI):getZ()
      Image.multiplyAddConstantInplace(inputF, pixelSizeZ, originZ)
      inputF:setPixelSizeZ(1.0)
      inputF:setOriginZ(0.0)
      return inputF
    end

    -- Convert the source image to a float with unitary coordinates
    input = toFloat(input)

    -- Concatenate all images but the last into one for easy display
    -- The first model image is the average value of each pixel in the model
    -- The second model image (if it exists) is the variance of each pixel in the model
    -- The final image has a different image type, indicating the number of samples observed
    for i = 1, (#modelImagesV-1) do
      input = input:concatenate(modelImagesV[i], "BELOW")
    end
    return input
  end

  local displayImage = createDisplayImage(image, modelImages)

  -- Display a visualization of the model
  viewer:clear()
  viewer:addImage(displayImage, imagedecoration)
  viewer:addPixelRegion(fg)
  viewer:present()
end

local function main()

  -- Use this simple function to keep the framerate
  -- we could also have used a Timer object.
  local tic = DateTime.getTimestamp()
  ---@param hz int
  local function pace(hz)
    local toc = DateTime.getTimestamp()
    local sleeptime = 1000/hz - (toc-tic)
    Script.sleep(math.max(0, sleeptime))
    tic = toc
  end

  -- This image set was collected at 6 Hz
  local hz = 6
  local images = Object.load('resources/area.json')

  -- Loop a few iterations
  for k = 1, 10 do

    -- Increment
    for imageIndex = 1, #images do
        callback(images[imageIndex])
        pace(hz)
    end

    -- Decrement
    for imageIndex = #images-1, 2, -1 do
        callback(images[imageIndex])
        pace(hz)
    end
  end

  print('App finished.')
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register("Engine.OnStarted", main)
--End of Function and Event Scope--------------------------------------------------
