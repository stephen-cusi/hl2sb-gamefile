-- Kinect is unavailable without a native device provider.
if motionsensor then
    motionsensor.IsAvailable = motionsensor.IsAvailable or function() return false end
    motionsensor.IsActive = motionsensor.IsActive or function() return false end
    motionsensor.Start = motionsensor.Start or function() return false end
end
