local w = LocalPlayer():GetActiveWeapon()
local c = IsValid(w) and w:GetClass() or "nil"
local t = IsValid(w) and w:GetTable() or {}

print("class", c)
print("TranslateActivity", type(w and w.TranslateActivity))
print("SetWeaponHoldType", type(w and w.SetWeaponHoldType))
print("ActivityTranslate", type(t.ActivityTranslate))
print("ActivityTranslateAI", type(t.ActivityTranslateAI))
print("BaseClass", type(t.BaseClass))