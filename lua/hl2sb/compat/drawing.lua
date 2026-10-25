-- Legacy names remain outside the original drawing libraries.
if not CLIENT or not draw or not surface then return end
TEXT_ALIGN_LEFT = draw.TEXT_ALIGN_LEFT
TEXT_ALIGN_CENTER = draw.TEXT_ALIGN_CENTER
TEXT_ALIGN_RIGHT = draw.TEXT_ALIGN_RIGHT
TEXT_ALIGN_TOP = draw.TEXT_ALIGN_TOP
TEXT_ALIGN_BOTTOM = draw.TEXT_ALIGN_BOTTOM
function draw.GetFont(name)
    return surface.SetFont(name or "Default")
end
