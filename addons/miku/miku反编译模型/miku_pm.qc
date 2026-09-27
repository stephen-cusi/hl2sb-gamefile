// Created by Crowbar++ 0.74

$modelname "pm/miku_pm.mdl"

$model "HEAD" "face.smd" {

	flexfile "miku_pm_01.vta" 
	{
		defaultflex frame 0
		flex "eye_blink" frame 1
		flex "eye_blinkhappy" frame 2
		flex "eye_blinkleft" frame 3
		flex "eye_blinkright" frame 4
		flex "eye_blinkhappyleft" frame 5
		flex "eye_blinkhappyright" frame 6
		flex "eye_stare" frame 7
		flex "eye_-left" frame 8
		flex "eye_-right" frame 9
		flex "eye_bigleft" frame 10
		flex "eye_bigright" frame 11
		flex "eye_smileleft" frame 12
		flex "eye_smileright" frame 13
		flex "eye_heart" frame 14
		flex "eye_up" frame 15
		flex "eye_down" frame 16
		flex "eye_left" frame 17
		flex "eye_right" frame 18
		flex "eyebrow_up" frame 19
		flex "eyebrow_down" frame 20
		flex "eyebrow_wide" frame 21
		flex "eyebrow_upleft" frame 22
		flex "eyebrow_upright" frame 23
		flex "eyebrow_-ANGRY" frame 24
		flex "eyebrow_angry" frame 25
		flex "eyebrow_sad" frame 26
		flex "eyebrow_B" frame 27
		flex "gu_da_bao_left" frame 28
		flex "gu_da_bao_right" frame 29
		flex "mouth_a" frame 30
		flex "mouth_e" frame 31
		flex "mouth_i" frame 32
		flex "mouth_u" frame 33
		flex "mouth_-A" frame 34
		flex "mouth_happy" frame 35
		flex "mouth_sad" frame 36
		flex "mouth_wide" frame 37
		flex "mouth_w" frame 38
		flex "mouth_surprise" frame 39
		flex "mouth_bite" frame 40
		flex "mouth_grin" frame 41
		flex "mouth_shock" frame 42
		flex "mouth_laugh" frame 43
		flex "mouth_-BITE" frame 44
		flex "mouth_il" frame 45
		flex "mouth_ir" frame 46
		flex "mouth_o" frame 47
		flex "mouth_cry" frame 48
		flex "mouth_upright" frame 49
		flex "mouth_upleft" frame 50
		flex "eye_blank" frame 51
		flex "eye_douji" frame 52
		flex "eye_flat" frame 53
		flex "eyeball_big" frame 54
		flex "eyeball_narrow" frame 55
		flex "eyeball_small" frame 56
		flex "eye_lightmove" frame 57
		flex "eye_lightbig" frame 58
		flex "eye_lightvanish" frame 59
		flex "mouth_tougue" frame 60
		flex "eye_--" frame 61
	}

	flexcontroller eye range 0 1 "blink"
	flexcontroller eye range 0 1 "eye_blinkhappy"
	flexcontroller eye range 0 1 "eye_blinkleft"
	flexcontroller eye range 0 1 "eye_blinkright"
	flexcontroller eye range 0 1 "eye_blinkhappyleft"
	flexcontroller eye range 0 1 "eye_blinkhappyright"
	flexcontroller eye range 0 1 "eye_stare"
	flexcontroller eye range 0 1 "eye_left"
	flexcontroller eye range 0 1 "eye_right"
	flexcontroller eye range 0 1 "eye_bigleft"
	flexcontroller eye range 0 1 "eye_bigright"
	flexcontroller eye range 0 1 "eye_smileleft"
	flexcontroller eye range 0 1 "eye_smileright"
	flexcontroller eye range 0 1 "eye_heart"
	flexcontroller eye range 0 1 "eye_up"
	flexcontroller eye range 0 1 "eye_down"
	flexcontroller eye range 0 1 "eye_left2"
	flexcontroller eye range 0 1 "eye_right2"
	flexcontroller eyebrow range 0 1 "eyebrow_up"
	flexcontroller eyebrow range 0 1 "eyebrow_down"
	flexcontroller eyebrow range 0 1 "eyebrow_wide"
	flexcontroller eyebrow range 0 1 "eyebrow_upleft"
	flexcontroller eyebrow range 0 1 "eyebrow_upright"
	flexcontroller eyebrow range 0 1 "eyebrow_ANGRY"
	flexcontroller eyebrow range 0 1 "eyebrow_angry"
	flexcontroller eyebrow range 0 1 "eyebrow_sad"
	flexcontroller eyebrow range 0 1 "eyebrow_B"
	flexcontroller face range 0 1 "gu_da_bao_left"
	flexcontroller face range 0 1 "gu_da_bao_right"
	flexcontroller mouth range 0 1 "mouth_a"
	flexcontroller mouth range 0 1 "mouth_e"
	flexcontroller mouth range 0 1 "mouth_i"
	flexcontroller mouth range 0 1 "mouth_u"
	flexcontroller mouth range 0 1 "mouth_A"
	flexcontroller mouth range 0 1 "mouth_happy"
	flexcontroller mouth range 0 1 "mouth_sad"
	flexcontroller mouth range 0 1 "mouth_wide"
	flexcontroller mouth range 0 1 "mouth_w"
	flexcontroller mouth range 0 1 "mouth_surprise"
	flexcontroller mouth range 0 1 "mouth_bite"
	flexcontroller mouth range 0 1 "mouth_grin"
	flexcontroller mouth range 0 1 "mouth_shock"
	flexcontroller mouth range 0 1 "mouth_laugh"
	flexcontroller mouth range 0 1 "mouth_BITE"
	flexcontroller mouth range 0 1 "mouth_il"
	flexcontroller mouth range 0 1 "mouth_ir"
	flexcontroller mouth range 0 1 "mouth_o"
	flexcontroller mouth range 0 1 "mouth_cry"
	flexcontroller mouth range 0 1 "mouth_upright"
	flexcontroller mouth range 0 1 "mouth_upleft"
	flexcontroller eye range 0 1 "eye_blank"
	flexcontroller eye range 0 1 "eye_douji"
	flexcontroller eye range 0 1 "eye_flat"
	flexcontroller eye range 0 1 "eyeball_big"
	flexcontroller eye range 0 1 "eyeball_narrow"
	flexcontroller eye range 0 1 "eyeball_small"
	flexcontroller eye range 0 1 "eye_lightmove"
	flexcontroller eye range 0 1 "eye_lightbig"
	flexcontroller eye range 0 1 "eye_lightvanish"
	flexcontroller mouth range 0 1 "mouth_tougue"
	flexcontroller eye range 0 1 "eye_"

	%eye_blink = blink
	%eye_blinkhappy = eye_blinkhappy
	%eye_blinkleft = eye_blinkleft
	%eye_blinkright = eye_blinkright
	%eye_blinkhappyleft = eye_blinkhappyleft
	%eye_blinkhappyright = eye_blinkhappyright
	%eye_stare = eye_stare
	%eye_-left = eye_left
	%eye_-right = eye_right
	%eye_bigleft = eye_bigleft
	%eye_bigright = eye_bigright
	%eye_smileleft = eye_smileleft
	%eye_smileright = eye_smileright
	%eye_heart = eye_heart
	%eye_up = eye_up
	%eye_down = eye_down
	%eye_left = eye_left2
	%eye_right = eye_right2
	%eyebrow_up = eyebrow_up
	%eyebrow_down = eyebrow_down
	%eyebrow_wide = eyebrow_wide
	%eyebrow_upleft = eyebrow_upleft
	%eyebrow_upright = eyebrow_upright
	%eyebrow_-ANGRY = eyebrow_ANGRY
	%eyebrow_angry = eyebrow_angry
	%eyebrow_sad = eyebrow_sad
	%eyebrow_B = eyebrow_B
	%gu_da_bao_left = gu_da_bao_left
	%gu_da_bao_right = gu_da_bao_right
	%mouth_a = mouth_a
	%mouth_e = mouth_e
	%mouth_i = mouth_i
	%mouth_u = mouth_u
	%mouth_-A = mouth_A
	%mouth_happy = mouth_happy
	%mouth_sad = mouth_sad
	%mouth_wide = mouth_wide
	%mouth_w = mouth_w
	%mouth_surprise = mouth_surprise
	%mouth_bite = mouth_bite
	%mouth_grin = mouth_grin
	%mouth_shock = mouth_shock
	%mouth_laugh = mouth_laugh
	%mouth_-BITE = mouth_BITE
	%mouth_il = mouth_il
	%mouth_ir = mouth_ir
	%mouth_o = mouth_o
	%mouth_cry = mouth_cry
	%mouth_upright = mouth_upright
	%mouth_upleft = mouth_upleft
	%eye_blank = eye_blank
	%eye_douji = eye_douji
	%eye_flat = eye_flat
	%eyeball_big = eyeball_big
	%eyeball_narrow = eyeball_narrow
	%eyeball_small = eyeball_small
	%eye_lightmove = eye_lightmove
	%eye_lightbig = eye_lightbig
	%eye_lightvanish = eye_lightvanish
	%mouth_tougue = mouth_tougue
	%eye_-- = eye_
}
$bodygroup "body"
{
	studio "body.smd"
}
$bodygroup "hair"
{
	studio "hair.smd"
}
$bodygroup "apronbowknot"
{
	studio "apronbowknot.smd"
	blank
}
$bodygroup "apron"
{
	studio "apron.smd"
	blank
}
$bodygroup "catear"
{
	studio "catear.smd"
	blank
}
$bodygroup "earring"
{
	studio "earring.smd"
	blank
}
$bodygroup "hairband"
{
	studio "hairband.smd"
	blank
}
$bodygroup "headbowknot"
{
	studio "headbowknot.smd"
	blank
}
$bodygroup "plait"
{
	studio "plait.smd"
	blank
}
$bodygroup "bowtie"
{
	studio "bowtie.smd"
	blank
}
$bodygroup "pleat"
{
	studio "pleat.smd"
	blank
}
$bodygroup "ring"
{
	studio "ring.smd"
	blank
}
$bodygroup "shoe"
{
	studio "shoe.smd"
	blank
}
$bodygroup "shoulder"
{
	studio "shoulder.smd"
	blank
}
$bodygroup "stocking"
{
	studio "stocking.smd"
	blank
}
$bodygroup "tail"
{
	studio "tail.smd"
	blank
}


$surfaceprop "flesh"

$contents "solid"

$illumposition 0.064 0.62 36.633

$mostlyopaque

$cdmaterials "tex\miku\"

$attachment "eyes" "ValveBiped.Bip01_Head1" 2.04 -3.5 0 rotate 0 -80.1 -90
$attachment "mouth" "ValveBiped.Bip01_Head1" -0.3 -3.5 0 rotate 0 -80 -90
$attachment "chest" "ValveBiped.Bip01_Spine2" 5 4 0 rotate 0 90 90
$attachment "forward" "ValveBiped.Bip01_Head1" 0 0 0 rotate 0 -76 -90
$attachment "anim_attachment_RH" "ValveBiped.Bip01_R_Hand" 2.43 -1.55 -0.19 rotate 4.36 0.17 -179.99
$attachment "anim_attachment_LH" "ValveBiped.Bip01_L_Hand" 2.43 -1.55 0.19 rotate 4.36 -179.83 0.01
$attachment "anim_attachment_head" "ValveBiped.Bip01_Head1" 0 0 0 rotate -90 -90 0

$cbox 0 0 0 0 0 0

$bbox -7.995 -29.975 -0.645 6.756 30.103 73.912

$hboxset "default"
$hbox 3 "ValveBiped.Bip01_Pelvis" -6 -3.5 -4 6 4.5 4
$hbox 3 "ValveBiped.Bip01_Spine1" -0.5 -2.2 -4 6.5 4.8 4
$hbox 2 "ValveBiped.Bip01_Spine2" -1 -2.75 -4.11 10 4.75 4.11
$hbox 1 "ValveBiped.Bip01_Head1" -0.95 -5 -3.5 8.55 4 3.5
$hbox 4 "ValveBiped.Bip01_L_UpperArm" -1.73 -1.4 -1.73 9.73 1.4 1.13
$hbox 4 "ValveBiped.Bip01_L_Forearm" 0 -1.26 -1.41 10 1.26 0.81
$hbox 4 "ValveBiped.Bip01_L_Hand" 0.5 -1 -1.25 5.5 1 1.25
$hbox 5 "ValveBiped.Bip01_R_UpperArm" -1.73 -1.4 -1.13 9.73 1.4 1.73
$hbox 5 "ValveBiped.Bip01_R_Forearm" 0 -1.26 -0.82 10 1.26 1.42
$hbox 5 "ValveBiped.Bip01_R_Hand" 0.5 -1 -1.15 5.5 1 1.33
$hbox 6 "ValveBiped.Bip01_L_Thigh" -0.2 -3.05 -2.19 15.8 2.45 2.81
$hbox 6 "ValveBiped.Bip01_L_Calf" -0.5 -2.13 -1.81 19.5 2.38 2.19
$hbox 7 "ValveBiped.Bip01_R_Thigh" -0.2 -3.05 -2.8 15.8 2.45 2.2
$hbox 7 "ValveBiped.Bip01_R_Calf" -0.5 -2.13 -2.18 19.5 2.38 1.82
$hbox 6 "ValveBiped.Bip01_L_Foot" -2 -0.38 -1.5 6 2.38 1.5
$hbox 7 "ValveBiped.Bip01_R_Foot" -2 -0.38 -1.5 6 2.38 1.5
$hbox 6 "ValveBiped.Bip01_L_Toe0" -0.5 -1 -1.5 2.5 1 1.5
$hbox 7 "ValveBiped.Bip01_R_Toe0" -0.5 -1 -1.5 2.5 1 1.5
$skipboneinbbox

$definebone "ValveBiped.Bip01_Pelvis" "" 0 -0.967105 44.122166 0 0 89.999955 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Spine" "ValveBiped.Bip01_Pelvis" 0 3.523758 0.02995 -1.603422 89.999955 89.999955 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Spine1" "ValveBiped.Bip01_Spine" 0 0 0 0 -6.452705 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Spine2" "ValveBiped.Bip01_Spine1" 3.710045 0.150944 -0.000002 0 -0.724104 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Spine4" "ValveBiped.Bip01_Spine2" 0.000004 -0.000001 0 0 8.928002 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Neck1" "ValveBiped.Bip01_Spine4" 8.192108 -2.246392 -0.000003 0 12.839351 179.9998 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_Head1" "ValveBiped.Bip01_Neck1" 2.81097 0.786394 0.000004 0 6.29503 0 0 0 0 0 0 0
$definebone "ValveBiped.forward" "ValveBiped.Bip01_Head1" 0 0 0 0 -76.001106 -89.9999 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Clavicle" "ValveBiped.Bip01_Spine4" 7.248871 -2.063121 0.799392 -76.44069 166.164747 93.870234 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_UpperArm" "ValveBiped.Bip01_L_Clavicle" 3.40689 -0.117195 -0.331688 0.906763 13.529537 -83.282054 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Forearm" "ValveBiped.Bip01_L_UpperArm" 8.927933 0.000001 -0.000004 0 0 -0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Hand" "ValveBiped.Bip01_L_Forearm" 8.24489 0 -0.000004 0 0 89.999955 0 0 0 0 0 0
$definebone "ValveBiped.Anim_Attachment_LH" "ValveBiped.Bip01_L_Hand" 2.676094 -1.712418 -0.000012 -0.00132 89.989839 90.001389 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger4" "ValveBiped.Bip01_L_Hand" 2.602129 0.043274 -1.213689 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger41" "ValveBiped.Bip01_L_Finger4" 0.978357 0 0 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger42" "ValveBiped.Bip01_L_Finger41" 0.578138 0 0 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger3" "ValveBiped.Bip01_L_Hand" 2.666882 0.187336 -0.54283 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger31" "ValveBiped.Bip01_L_Finger3" 1.355406 0 0 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger32" "ValveBiped.Bip01_L_Finger31" 0.832703 0 0 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger2" "ValveBiped.Bip01_L_Hand" 2.710474 0.161205 0.196588 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger21" "ValveBiped.Bip01_L_Finger2" 1.473167 0 0 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger22" "ValveBiped.Bip01_L_Finger21" 0.846321 0 0 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger1" "ValveBiped.Bip01_L_Hand" 2.591167 0.126434 0.967711 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger11" "ValveBiped.Bip01_L_Finger1" 1.352854 0 0 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger12" "ValveBiped.Bip01_L_Finger11" 0.781221 0 0 0 0 0.000002 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger0" "ValveBiped.Bip01_L_Hand" 0.584726 -0.519913 0.370771 -25.564348 -35.954881 -74.577531 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger01" "ValveBiped.Bip01_L_Finger0" 1.518351 -0.367496 0.54443 0.105192 22.503081 0.048926 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Finger02" "ValveBiped.Bip01_L_Finger01" 0.979181 -0.236278 0.537338 0.70697 3.569123 0.257251 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Clavicle" "ValveBiped.Bip01_Spine4" 7.248871 -2.063119 -0.799398 76.441087 166.164965 -97.980956 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_UpperArm" "ValveBiped.Bip01_R_Clavicle" 3.406892 -0.140697 0.322426 -1.865378 13.432364 87.280809 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Forearm" "ValveBiped.Bip01_R_UpperArm" 8.927931 -0.000001 0.000004 -0.000001 0 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Hand" "ValveBiped.Bip01_R_Forearm" 8.244888 -0.000001 0.000004 -0.000001 0 -89.999955 0 0 0 0 0 0
$definebone "ValveBiped.Anim_Attachment_RH" "ValveBiped.Bip01_R_Hand" 2.676144 -1.712357 0.00008 -0.000573 -90.026312 -89.996881 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger4" "ValveBiped.Bip01_R_Hand" 2.602133 0.043266 1.213689 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger41" "ValveBiped.Bip01_R_Finger4" 0.978361 -0.000004 0 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger42" "ValveBiped.Bip01_R_Finger41" 0.578136 0 0 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger3" "ValveBiped.Bip01_R_Hand" 2.666882 0.187328 0.542829 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger31" "ValveBiped.Bip01_R_Finger3" 1.355406 0 0 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger32" "ValveBiped.Bip01_R_Finger31" 0.832703 -0.000004 0 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger2" "ValveBiped.Bip01_R_Hand" 2.710476 0.161201 -0.196589 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger21" "ValveBiped.Bip01_R_Finger2" 1.473166 0 0 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger22" "ValveBiped.Bip01_R_Finger21" 0.846323 -0.000004 0 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger1" "ValveBiped.Bip01_R_Hand" 2.591166 0.126427 -0.967711 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger11" "ValveBiped.Bip01_R_Finger1" 1.352856 0 0 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger12" "ValveBiped.Bip01_R_Finger11" 0.781223 -0.000004 0 0 -0.000001 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger0" "ValveBiped.Bip01_R_Hand" 0.584728 -0.519913 -0.370771 25.562169 -35.952804 74.578911 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger01" "ValveBiped.Bip01_R_Finger0" 1.518348 -0.367567 -0.544395 -0.104966 22.502227 -0.050421 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Finger02" "ValveBiped.Bip01_R_Finger01" 0.979185 -0.2363 -0.537319 -0.706686 3.569587 -0.255941 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Thigh" "ValveBiped.Bip01_Pelvis" 3.050961 -1.782368 -1.228622 0 -89.999955 -89.999955 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Calf" "ValveBiped.Bip01_L_Thigh" 16.332626 -0.000004 -0.000009 0 0 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Foot" "ValveBiped.Bip01_L_Calf" 20.043091 -0.000004 -0.000011 -1.36977 -61.631399 0.840586 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_L_Toe0" "ValveBiped.Bip01_L_Foot" 6.307809 1.971855 -0.164771 0.053457 -28.677324 -0.638733 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Thigh" "ValveBiped.Bip01_Pelvis" -3.050961 -1.782368 -1.228622 0 -89.999955 -89.999955 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Calf" "ValveBiped.Bip01_R_Thigh" 16.332621 -0.000004 -0.000005 0 0 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Foot" "ValveBiped.Bip01_R_Calf" 20.043093 -0.000004 -0.000006 0.653859 -61.793821 -0.606991 0 0 0 0 0 0
$definebone "ValveBiped.Bip01_R_Toe0" "ValveBiped.Bip01_R_Foot" 6.303392 1.991225 0.078041 -0.354432 -28.587378 -4.506427 0 0 0 0 0 0
$definebone "ValveBiped.Bip2" "ValveBiped.Bip01_Pelvis" 2.711403 5.259277 3.132617 -14.157841 17.264877 78.564599 0 0 0 0 0 0
$definebone "ValveBiped.Bip3" "ValveBiped.Bip01_Pelvis" 4.387142 5.259281 1.076985 -22.5558 24.182944 85.89958 0 0 0 0 0 0
$definebone "ValveBiped.Bip4" "ValveBiped.Bip01_Pelvis" 4.387142 5.259281 -1.463916 -22.420231 19.6234 97.783952 0 0 0 0 0 0
$definebone "ValveBiped.Bip5" "ValveBiped.Bip01_Pelvis" 2.711402 5.259277 -3.519549 -13.680795 9.790932 108.946237 0 0 0 0 0 0
$definebone "ValveBiped.Bip8" "ValveBiped.Bip01_Pelvis" -2.711403 5.259277 -3.519548 13.588893 -9.724923 108.946237 0 0 0 0 0 0
$definebone "ValveBiped.Bip9" "ValveBiped.Bip01_Pelvis" -4.387142 5.259281 -1.463915 22.279228 -19.499186 97.783952 0 0 0 0 0 0
$definebone "ValveBiped.Bip10" "ValveBiped.Bip01_Pelvis" -4.387142 5.259281 1.076986 22.414106 -24.031626 85.899642 0 0 0 0 0 0
$definebone "ValveBiped.Bip11" "ValveBiped.Bip01_Pelvis" -2.711403 5.259277 3.132617 14.062846 -17.150002 78.564538 0 0 0 0 0 0
$definebone "ValveBiped.Bip12" "ValveBiped.Bip01_Pelvis" 0 5.259277 3.917799 0 0 75.84729 0 0 0 0 0 0
$definebone "ValveBiped.Bip1" "ValveBiped.Bip12" 0 0 0.000004 0 0 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip7" "ValveBiped.Bip01_Pelvis" 0 5.259281 -4.304729 0 0 112.888807 0 0 0 0 0 0
$definebone "ValveBiped.Bip6" "ValveBiped.Bip7" 0 -0.000004 0.000004 0 0 0 0 0 0 0 0 0
$definebone "ValveBiped.Bip14" "ValveBiped.Bip01_Pelvis" 0 3.36586 -2.270664 0 0 -172.860094 0 0 0 0 0 0
$definebone "ValveBiped.Bip13" "ValveBiped.Bip14" 0 0.000004 0 0 0 0 0 0 0 0 0 0
$definebone "pd.103" "ValveBiped.Bip01_Spine4" 3.894241 1.243716 -2.273654 -2.321316 179.420846 112.587623 0 0 0 0 0 0
$definebone "pd.104" "ValveBiped.Bip01_Spine4" 3.894238 1.243715 2.273654 -2.32128 -0.579089 -67.412253 0 0 0 0 0 0
$definebone "pd.128" "ValveBiped.Bip2" -0.021326 -0.017084 3.075672 -1.610069 -1.545843 1.303536 0 0 0 0 0 0
$definebone "pd.129" "pd.128" -0.073547 -0.05117 4.743092 -2.569714 -2.556774 1.866921 0 0 0 0 0 0
$definebone "pd.130" "pd.129" -0.077495 -0.047066 5.165989 -2.38717 -2.407918 1.514783 0 0 0 0 0 0
$definebone "pd.131" "pd.130" -0.07411 -0.038752 5.888031 -1.95642 -1.98708 1.05103 0 0 0 0 0 0
$definebone "pd.132" "ValveBiped.Bip3" -0.03229 -0.01174 3.170059 -2.364994 -2.037843 0.837778 0 0 0 0 0 0
$definebone "pd.133" "pd.132" -0.107449 -0.020611 4.862347 -3.711901 -3.419869 0.745304 0 0 0 0 0 0
$definebone "pd.134" "pd.133" -0.111515 -0.00252 5.261139 -3.443531 -3.308029 0.117629 0 0 0 0 0 0
$definebone "pd.135" "pd.134" -0.106655 0.014372 5.961823 -2.842843 -2.816659 -0.369042 0 0 0 0 0 0
$definebone "pd.136" "ValveBiped.Bip4" -0.026825 0.001395 3.190907 -1.973555 -1.668278 -0.168108 0 0 0 0 0 0
$definebone "pd.137" "pd.136" -0.089855 0.025994 4.906704 -3.153498 -2.847598 -0.946648 0 0 0 0 0 0
$definebone "pd.138" "pd.137" -0.09539 0.049047 5.307724 -3.002812 -2.843818 -1.517773 0 0 0 0 0 0
$definebone "pd.139" "pd.138" -0.093845 0.065496 6.001842 -2.54874 -2.500502 -1.741626 0 0 0 0 0 0
$definebone "pd.140" "ValveBiped.Bip5" -0.01163 0.020613 3.179478 -0.895991 -0.88917 -1.572711 0 0 0 0 0 0
$definebone "pd.141" "pd.140" -0.042721 0.08091 4.884434 -1.585373 -1.559192 -2.872523 0 0 0 0 0 0
$definebone "pd.142" "pd.141" -0.049829 0.096235 5.281723 -1.636997 -1.611272 -2.995133 0 0 0 0 0 0
$definebone "pd.143" "pd.142" -0.052511 0.100945 5.97629 -1.467974 -1.451819 -2.68482 0 0 0 0 0 0
$definebone "pd.144" "ValveBiped.Bip8" 0.015903 0.021338 3.177238 1.167344 1.078305 -1.610758 0 0 0 0 0 0
$definebone "pd.145" "pd.144" 0.047289 0.081381 4.877136 1.661405 1.599697 -2.875506 0 0 0 0 0 0
$definebone "pd.146" "pd.145" 0.043223 0.094965 5.276382 1.349545 1.383119 -2.960246 0 0 0 0 0 0
$definebone "pd.147" "pd.146" 0.035468 0.098776 5.977041 0.938676 1.036307 -2.638016 0 0 0 0 0 0
$definebone "pd.148" "ValveBiped.Bip9" 0.033083 0.003553 3.18502 2.372044 2.029647 -0.274623 0 0 0 0 0 0
$definebone "pd.149" "pd.148" 0.096363 0.027191 4.887688 3.262649 2.935151 -0.940977 0 0 0 0 0 0
$definebone "pd.150" "pd.149" 0.084818 0.045254 5.293816 2.556707 2.447161 -1.414297 0 0 0 0 0 0
$definebone "pd.151" "pd.150" 0.067105 0.05941 6.003803 1.724542 1.781269 -1.615463 0 0 0 0 0 0
$definebone "pd.152" "ValveBiped.Bip10" 0.03833 -0.009118 3.164131 2.748419 2.479069 0.713905 0 0 0 0 0 0
$definebone "pd.153" "pd.152" 0.113415 -0.019338 4.84317 3.804669 3.527691 0.765072 0 0 0 0 0 0
$definebone "pd.154" "pd.153" 0.100536 -0.007123 5.247093 2.992501 2.847763 0.242819 0 0 0 0 0 0
$definebone "pd.155" "pd.154" 0.079924 0.007468 5.963799 2.029645 2.005458 -0.23245 0 0 0 0 0 0
$definebone "pd.156" "ValveBiped.Bip11" 0.025406 -0.015861 3.07336 1.866695 1.875975 1.245839 0 0 0 0 0 0
$definebone "pd.157" "pd.156" 0.077185 -0.050655 4.7356 2.612973 2.626552 1.879989 0 0 0 0 0 0
$definebone "pd.158" "pd.157" 0.069947 -0.049222 5.160545 2.085279 2.06683 1.57277 0 0 0 0 0 0
$definebone "pd.159" "pd.158" 0.056913 -0.041794 5.888805 1.445514 1.415549 1.10856 0 0 0 0 0 0
$definebone "pd.160" "ValveBiped.Bip1" 0.000001 -0.022074 3.017406 -0.000057 0 1.703288 0 0 0 0 0 0
$definebone "pd.161" "pd.160" 0.000007 -0.072325 4.674877 0.000057 0 2.590514 0 0 0 0 0 0
$definebone "pd.162" "pd.161" 0.000004 -0.072306 5.116188 -0.000057 0 2.263126 0 0 0 0 0 0
$definebone "pd.163" "pd.162" 0.000008 -0.065177 5.851667 -0.000172 0 1.727983 0 0 0 0 0 0
$definebone "pd.164" "ValveBiped.Bip6" 0 0.027422 3.17017 0 0 -2.073363 0 0 0 0 0 0
$definebone "pd.165" "pd.164" 0.000002 0.099876 4.862431 0 0 -3.550733 0 0 0 0 0 0
$definebone "pd.166" "pd.165" 0.000003 0.111992 5.256622 0.000057 0 -3.506444 0 0 0 0 0 0
$definebone "pd.167" "pd.166" -0.000001 0.11228 5.95303 -0.000172 0 -3.001438 0 0 0 0 0 0
$definebone "pd" "ValveBiped.Bip01_Head1" 3.761497 -0.484362 -3.660547 66.572693 151.473966 -51.576459 0 0 0 0 0 0
$definebone "pd.001" "ValveBiped.Bip01_Head1" 3.752853 -1.560328 -3.605245 52.255564 145.108434 -45.210088 0 0 0 0 0 0
$definebone "pd.002" "ValveBiped.Bip01_Head1" 4.47464 -3.523696 -2.36113 40.116365 -53.401264 153.300509 0 0 0 0 0 0
$definebone "pd.003" "ValveBiped.Bip01_Head1" 7.239937 -2.86372 -1.353375 69.409059 -37.166341 137.06631 0 0 0 0 0 0
$definebone "pd.004" "ValveBiped.Bip01_Head1" 5.828751 -3.266319 -0.422032 18.526977 -48.035409 147.93448 0 0 0 0 0 0
$definebone "pd.005" "ValveBiped.Bip01_Head1" 6.404037 -2.955704 0.81358 59.978521 -35.130726 135.029985 0 0 0 0 0 0
$definebone "pd.006" "ValveBiped.Bip01_Head1" 3.398285 -0.913291 3.50739 60.580698 -33.561118 133.46023 0 0 0 0 0 0
$definebone "pd.007" "ValveBiped.Bip01_Head1" 3.304718 -2.181828 3.297226 63.769829 -36.997933 136.898042 0 0 0 0 0 0
$definebone "pd.008" "ValveBiped.Bip01_Head1" 5.089508 -2.145199 2.833681 86.562922 -35.995671 135.884141 0 0 0 0 0 0
$definebone "pd.015" "ValveBiped.Bip01_Head1" 3.309242 3.021448 2.807659 20.198013 91.541399 8.357734 0 0 0 0 0 0
$definebone "pd.016" "pd.015" -0.000002 1.299175 0 -58.786817 8.039159 164.087987 0 0 0 0 0 0
$definebone "pd.017" "pd.016" 1.483128 0.889118 -0.760393 -54.677819 -167.982588 -98.744953 0 0 0 0 0 0
$definebone "pd.018" "pd.017" 0.000001 0.000006 1.098301 6.548506 5.084138 -0.640677 0 0 0 0 0 0
$definebone "pd.019" "pd.018" -0.031181 -0.045309 2.776104 -3.383203 -2.790651 4.173712 0 0 0 0 0 0
$definebone "pd.020" "pd.019" -0.063147 -0.055231 3.387466 -3.999708 -3.182498 3.085495 0 0 0 0 0 0
$definebone "pd.021" "pd.020" -0.073409 -0.021782 3.800297 -3.080344 -2.253734 1.021704 0 0 0 0 0 0
$definebone "pd.022" "pd.021" 0 0 1.901588 3.421068 3.15304 -10.963941 0 0 0 0 0 0
$definebone "pd.023" "pd.022" 0.508658 0.249132 2.020947 -4.622288 -5.21524 8.746429 0 0 0 0 0 0
$definebone "pd.024" "pd.023" -0.021115 -0.005932 3.975941 -1.642338 -1.354535 1.082553 0 0 0 0 0 0
$definebone "pd.025" "pd.024" -0.068426 0.014626 3.999939 -3.608504 -2.504922 -0.012941 0 0 0 0 0 0
$definebone "pd.026" "pd.025" -0.007289 0.005527 4.039022 1.558315 0.948981 0.719126 0 0 0 0 0 0
$definebone "pd.027" "pd.026" -0.000628 -0.025537 3.67259 0.177544 -0.159979 1.420485 0 0 0 0 0 0
$definebone "pd.028" "pd.027" -0.135418 -0.087128 4.13764 0.191009 -0.58901 3.604717 0 0 0 0 0 0
$definebone "pd.029" "pd.028" 0.098037 -0.014038 3.938133 4.338022 2.314916 2.89356 0 0 0 0 0 0
$definebone "pd.030" "pd.029" 0 0 1.657495 2.076732 0.949731 2.380473 0 0 0 0 0 0
$definebone "pd.031" "pd.030" 0.152488 -0.043791 3.310966 9.488804 5.381219 3.989279 0 0 0 0 0 0
$definebone "pd.032" "pd.031" 0.319344 -0.179604 4.414724 11.038087 7.075174 10.464217 0 0 0 0 0 0
$definebone "pd.033" "pd.032" 0.315797 -0.299946 4.960559 8.949604 1.744089 -9.863182 0 0 0 0 0 0
$definebone "pd.034" "pd.022" -1.403287 -1.245106 1.653469 -8.627954 -12.160006 20.614672 0 0 0 0 0 0
$definebone "pd.035" "pd.034" -0.036385 -0.040253 4.010429 -0.800097 -0.828446 1.597018 0 0 0 0 0 0
$definebone "pd.036" "pd.035" 0.039886 -0.009483 4.18178 0.423684 0.085941 0.656398 0 0 0 0 0 0
$definebone "pd.037" "pd.036" -0.012575 0.024719 4.669813 -0.032049 0.466615 -2.160718 0 0 0 0 0 0
$definebone "pd.038" "pd.037" 0.003522 0.076195 4.128 0.233918 1.917575 -8.285295 0 0 0 0 0 0
$definebone "pd.039" "pd.038" 0.05706 0.140339 3.77766 4.576368 4.559082 -8.974565 0 0 0 0 0 0
$definebone "pd.040" "pd.039" -0.000002 0.000002 1.827112 3.941306 3.775447 -5.5488 0 0 0 0 0 0
$definebone "pd.041" "pd.040" 0.000005 0.000008 1.819405 4.698823 4.245964 -1.455937 0 0 0 0 0 0
$definebone "pd.042" "pd.041" -0.000027 0.000006 1.79661 3.90259 3.496997 -3.074715 0 0 0 0 0 0
$definebone "pd.043" "pd.042" 0.143147 0.090977 3.417555 13.371942 11.810224 -4.521033 0 0 0 0 0 0
$definebone "pd.044" "pd.043" 0.299864 0.076643 3.734957 19.835779 22.864075 4.198591 0 0 0 0 0 0
$definebone "pd.045" "pd.044" 0.205663 -0.10253 3.28931 10.755592 20.474073 10.804362 0 0 0 0 0 0
$definebone "pd.046" "pd.045" 0.187447 -0.369926 3.245319 -15.090007 -11.961621 3.660555 0 0 0 0 0 0
$definebone "pd.047" "pd.022" 2.69793 0.437963 2.52232 0.83938 0.208552 6.898067 0 0 0 0 0 0
$definebone "pd.048" "pd.047" -0.107486 -0.161879 4.179699 -4.947555 -4.989436 9.547255 0 0 0 0 0 0
$definebone "pd.049" "pd.048" -0.105448 -0.23238 4.477386 -4.044521 -4.697171 11.301084 0 0 0 0 0 0
$definebone "pd.050" "pd.049" -0.054009 -0.142471 4.558023 -2.620609 -2.886109 7.255316 0 0 0 0 0 0
$definebone "pd.051" "pd.050" -0.032272 -0.069145 3.613425 -2.693489 -2.014926 3.70556 0 0 0 0 0 0
$definebone "pd.052" "pd.051" -0.037061 0.026768 3.770075 -2.907892 -0.057129 -3.727073 0 0 0 0 0 0
$definebone "pd.053" "pd.052" -0.069773 0.200871 3.797598 -3.755072 2.909823 -14.785674 0 0 0 0 0 0
$definebone "pd.054" "pd.053" -0.097511 0.349506 3.709995 -5.228379 4.3472 -21.044605 0 0 0 0 0 0
$definebone "pd.055" "pd.054" -0.030209 0.308874 3.588842 4.440862 9.892969 -19.356343 0 0 0 0 0 0
$definebone "pd.056" "pd.055" 0.153002 0.295004 3.523855 17.136547 22.319347 -16.528706 0 0 0 0 0 0
$definebone "pd.057" "pd.056" 0.192851 0.188094 2.468798 25.100556 46.571809 1.898139 0 0 0 0 0 0
$definebone "pd.058" "ValveBiped.Bip01_Head1" 3.309235 3.021465 -2.807641 20.198355 -88.458531 -171.642135 0 0 0 0 0 0
$definebone "pd.059" "pd.058" 0 1.299175 0 58.786065 -8.038933 164.087987 0 0 0 0 0 0
$definebone "pd.060" "pd.059" -1.483133 0.889126 -0.760418 54.678157 167.981905 -98.745575 0 0 0 0 0 0
$definebone "pd.061" "pd.060" -0.000006 -0.000002 1.098301 -6.548793 -5.084256 -0.640685 0 0 0 0 0 0
$definebone "pd.062" "pd.061" 0.031177 -0.045311 2.776096 3.383146 2.790651 4.173707 0 0 0 0 0 0
$definebone "pd.063" "pd.062" 0.063149 -0.055231 3.387466 3.999709 3.182499 3.085486 0 0 0 0 0 0
$definebone "pd.064" "pd.063" 0.073413 -0.02178 3.800289 3.080458 2.253736 1.021693 0 0 0 0 0 0
$definebone "pd.065" "pd.064" 0.000002 -0.000002 1.901588 -3.421297 -3.152639 -10.963953 0 0 0 0 0 0
$definebone "pd.066" "pd.065" -0.508654 0.249136 2.020947 4.622631 5.214956 8.746482 0 0 0 0 0 0
$definebone "pd.067" "pd.066" 0.021119 -0.005928 3.975933 1.64228 1.354653 1.082545 0 0 0 0 0 0
$definebone "pd.068" "pd.067" 0.068434 0.014627 3.999947 3.608615 2.504868 -0.012949 0 0 0 0 0 0
$definebone "pd.069" "pd.068" 0.007291 0.005524 4.039026 -1.558203 -0.949036 0.719118 0 0 0 0 0 0
$definebone "pd.070" "pd.069" 0.000624 -0.025537 3.672588 -0.177548 0.160036 1.420417 0 0 0 0 0 0
$definebone "pd.071" "pd.070" 0.135412 -0.08713 4.137642 -0.191071 0.589066 3.604704 0 0 0 0 0 0
$definebone "pd.072" "pd.071" -0.098038 -0.01404 3.938129 -4.337968 -2.314973 2.893551 0 0 0 0 0 0
$definebone "pd.073" "pd.072" 0 0 1.65749 -2.076848 -0.949673 2.380466 0 0 0 0 0 0
$definebone "pd.074" "pd.073" -0.152492 -0.043795 3.31097 -9.488809 -5.381334 3.989273 0 0 0 0 0 0
$definebone "pd.075" "pd.074" -0.319357 -0.179602 4.414725 -11.038153 -7.075234 10.464156 0 0 0 0 0 0
$definebone "pd.076" "pd.075" -0.315814 -0.299955 4.960563 -8.949786 -1.744091 -9.863178 0 0 0 0 0 0
$definebone "pd.077" "pd.065" 1.403308 -1.245113 1.653461 8.628237 12.159781 20.614667 0 0 0 0 0 0
$definebone "pd.078" "pd.077" 0.036398 -0.04026 4.010426 0.800266 0.828448 1.597064 0 0 0 0 0 0
$definebone "pd.079" "pd.078" -0.039887 -0.009483 4.181797 -0.423689 -0.085936 0.656329 0 0 0 0 0 0
$definebone "pd.080" "pd.079" 0.012575 0.024708 4.669821 0.032044 -0.46661 -2.160731 0 0 0 0 0 0
$definebone "pd.081" "pd.080" -0.003523 0.076199 4.128008 -0.233924 -1.91757 -8.285247 0 0 0 0 0 0
$definebone "pd.082" "pd.081" -0.057062 0.140339 3.777658 -4.576373 -4.559136 -8.974518 0 0 0 0 0 0
$definebone "pd.083" "pd.082" 0 0.000006 1.827118 -3.941369 -3.775502 -5.548749 0 0 0 0 0 0
$definebone "pd.084" "pd.083" -0.000009 0.00001 1.81941 -4.698881 -4.246018 -1.455941 0 0 0 0 0 0
$definebone "pd.085" "pd.084" 0.000027 0.000004 1.796608 -3.902645 -3.496995 -3.074719 0 0 0 0 0 0
$definebone "pd.086" "pd.085" -0.143153 0.090969 3.417557 -13.372044 -11.810281 -4.521093 0 0 0 0 0 0
$definebone "pd.087" "pd.086" -0.299873 0.076631 3.734959 -19.835692 -22.864193 4.198531 0 0 0 0 0 0
$definebone "pd.088" "pd.087" -0.205668 -0.102563 3.28933 -10.755448 -20.474032 10.804288 0 0 0 0 0 0
$definebone "pd.089" "pd.088" -0.187449 -0.369966 3.24534 15.089858 11.961551 3.660542 0 0 0 0 0 0
$definebone "pd.090" "pd.065" -2.697953 0.437979 2.522327 -0.83915 -0.208838 6.89806 0 0 0 0 0 0
$definebone "pd.091" "pd.090" 0.10749 -0.161877 4.179699 4.947555 4.989438 9.547247 0 0 0 0 0 0
$definebone "pd.092" "pd.091" 0.105456 -0.232386 4.477375 4.044578 4.697231 11.301014 0 0 0 0 0 0
$definebone "pd.093" "pd.092" 0.054015 -0.142471 4.558029 2.620668 2.886111 7.255306 0 0 0 0 0 0
$definebone "pd.094" "pd.093" 0.032275 -0.069153 3.613431 2.693551 2.014929 3.70549 0 0 0 0 0 0
$definebone "pd.095" "pd.094" 0.037062 0.026764 3.77008 2.907894 0.057128 -3.727145 0 0 0 0 0 0
$definebone "pd.096" "pd.095" 0.06978 0.200867 3.797603 3.755071 -2.909818 -14.78569 0 0 0 0 0 0
$definebone "pd.097" "pd.096" 0.097515 0.34951 3.710004 5.228488 -4.347369 -21.04468 0 0 0 0 0 0
$definebone "pd.098" "pd.097" 0.030205 0.308855 3.588852 -4.440863 -9.893028 -19.356222 0 0 0 0 0 0
$definebone "pd.099" "pd.098" -0.153004 0.295002 3.523855 -17.136583 -22.319689 -16.528563 0 0 0 0 0 0
$definebone "pd.100" "pd.099" -0.192861 0.188094 2.468803 -25.100546 -46.572266 1.898376 0 0 0 0 0 0
$definebone "pd.107" "ValveBiped.Bip01_Spine" 3.038773 -3.186367 -0.000004 -89.999968 -91.603403 0 0 0 0 0 0 0
$definebone "pd.108" "pd.107" -1.259778 -0.110737 0.228234 74.95897 -74.368889 90.611673 0 0 0 0 0 0
$definebone "pd.109" "pd.108" -0.000001 0 1.663316 -0.000115 -0.000115 0.000232 0 0 0 0 0 0
$definebone "pd.110" "pd.109" 0 0 1.663315 0 -0.000003 -0.000113 0 0 0 0 0 0
$definebone "pd.111" "pd.107" -1.301082 -0.448425 -0.122918 30.161005 -18.785853 116.907512 0 0 0 0 0 0
$definebone "pd.112" "pd.111" 0.000001 0.000004 4.296974 11.763968 3.687613 12.398574 0 0 0 0 0 0
$definebone "pd.113" "pd.112" 0 0 5.29394 0.057295 1.702199 -7.797895 0 0 0 0 0 0
$definebone "pd.114" "pd.113" 0.000002 0.000004 4.67329 0.195666 0.754585 -3.020289 0 0 0 0 0 0
$definebone "pd.115" "pd.107" -1.181794 -0.334217 -0.513912 40.5532 -20.114769 128.711472 0 0 0 0 0 0
$definebone "pd.116" "pd.115" 0.000001 -0.000008 4.514694 4.10295 -0.747939 5.84955 0 0 0 0 0 0
$definebone "pd.117" "pd.116" 0.000005 0.000004 4.56662 8.478914 4.647203 -5.44402 0 0 0 0 0 0
$definebone "pd.118" "pd.107" 1.259783 -0.110741 0.228234 -74.958908 74.368432 90.611714 0 0 0 0 0 0
$definebone "pd.119" "pd.118" 0.000001 0 1.663319 0.000114 0.000172 0.000229 0 0 0 0 0 0
$definebone "pd.120" "pd.119" -0.000003 0.000004 1.663315 -0.000057 0.000059 -0.000058 0 0 0 0 0 0
$definebone "pd.121" "pd.107" 1.301088 -0.448425 -0.122919 -30.161005 18.785793 116.907512 0 0 0 0 0 0
$definebone "pd.122" "pd.121" 0 0 4.296982 -11.763969 -3.687616 12.398574 0 0 0 0 0 0
$definebone "pd.123" "pd.122" 0 -0.000004 5.293945 -0.057297 -1.702146 -7.797902 0 0 0 0 0 0
$definebone "pd.124" "pd.123" -0.000002 0.000004 4.673294 -0.195666 -0.754645 -3.020235 0 0 0 0 0 0
$definebone "pd.125" "pd.107" 1.181799 -0.334221 -0.513912 -40.5532 20.11483 128.711472 0 0 0 0 0 0
$definebone "pd.126" "pd.125" 0 0.000004 4.514696 -4.103009 0.747996 5.849498 0 0 0 0 0 0
$definebone "pd.127" "pd.126" 0 0 4.566618 -8.478922 -4.647204 -5.444014 0 0 0 0 0 0
$definebone "pd.009" "ValveBiped.Bip01_Head1" 6.151886 0.78384 1.728969 20.729141 69.148719 30.750239 0 0 0 0 0 0
$definebone "pd.010" "pd.009" 0 0.000011 2.411968 0.917232 -1.480512 1.17426 0 0 0 0 0 0
$definebone "pd.011" "pd.009" -0.631569 -0.002724 1.030853 0.822984 4.491594 -6.040654 0 0 0 0 0 0
$definebone "pd.012" "ValveBiped.Bip01_Head1" 6.151878 0.783848 -1.729018 20.729488 -110.851327 -149.249797 0 0 0 0 0 0
$definebone "pd.013" "pd.012" 0.000004 0.000008 2.411964 -0.917241 1.480509 1.174263 0 0 0 0 0 0
$definebone "pd.014" "pd.012" 0.631573 -0.002724 1.030849 -0.822989 -4.4916 -6.040649 0 0 0 0 0 0
$definebone "pd.101" "ValveBiped.Bip01_Head1" 1.230007 -0.544867 -2.682516 89.55925 -35.083519 135.020628 0 0 0 0 0 0
$definebone "pd.102" "ValveBiped.Bip01_Head1" 1.230003 -0.544881 2.682512 89.559127 144.875689 -45.020437 0 0 0 0 0 0
$definebone "pd.105" "ValveBiped.Bip01_Spine4" 7.641582 1.69558 0.170169 -39.518549 37.681887 -48.963536 0 0 0 0 0 0
$definebone "pd.106" "ValveBiped.Bip01_Spine4" 7.641582 1.695581 -0.170173 -39.518546 -142.318097 131.036387 0 0 0 0 0 0
$definebone "pd.168" "ValveBiped.Bip13" 0 0.000004 2.319757 0 0 -12.039046 0 0 0 0 0 0
$definebone "pd.169" "pd.168" 0 -0.000011 2.593413 0 0 -5.143498 0 0 0 0 0 0
$definebone "pd.170" "pd.169" 0.000001 -0.000019 2.777902 0 0 -0.249752 0 0 0 0 0 0
$definebone "pd.171" "pd.170" 0 -0.000019 2.801039 0 0 4.472795 0 0 0 0 0 0
$definebone "pd.172" "pd.171" 0.000001 -0.000011 2.659531 0 0 10.763354 0 0 0 0 0 0
$definebone "pd.173" "pd.172" 0 -0.000004 2.413889 0 0 19.695593 0 0 0 0 0 0
$definebone "pd.174" "pd.173" 0 0.000023 2.236877 0 0 26.56249 0 0 0 0 0 0

$bonemerge "ValveBiped.Bip01_Pelvis"
$bonemerge "ValveBiped.Bip01_Spine"
$bonemerge "ValveBiped.Bip01_Spine1"
$bonemerge "ValveBiped.Bip01_Spine2"
$bonemerge "ValveBiped.Bip01_Spine4"
$bonemerge "ValveBiped.Bip01_Neck1"
$bonemerge "ValveBiped.Bip01_Head1"
$bonemerge "ValveBiped.forward"
$bonemerge "ValveBiped.Bip01_L_Clavicle"
$bonemerge "ValveBiped.Bip01_L_UpperArm"
$bonemerge "ValveBiped.Bip01_L_Forearm"
$bonemerge "ValveBiped.Bip01_L_Hand"
$bonemerge "ValveBiped.Anim_Attachment_LH"
$bonemerge "ValveBiped.Bip01_L_Finger4"
$bonemerge "ValveBiped.Bip01_L_Finger41"
$bonemerge "ValveBiped.Bip01_L_Finger42"
$bonemerge "ValveBiped.Bip01_L_Finger3"
$bonemerge "ValveBiped.Bip01_L_Finger31"
$bonemerge "ValveBiped.Bip01_L_Finger32"
$bonemerge "ValveBiped.Bip01_L_Finger2"
$bonemerge "ValveBiped.Bip01_L_Finger21"
$bonemerge "ValveBiped.Bip01_L_Finger22"
$bonemerge "ValveBiped.Bip01_L_Finger1"
$bonemerge "ValveBiped.Bip01_L_Finger11"
$bonemerge "ValveBiped.Bip01_L_Finger12"
$bonemerge "ValveBiped.Bip01_L_Finger0"
$bonemerge "ValveBiped.Bip01_L_Finger01"
$bonemerge "ValveBiped.Bip01_L_Finger02"
$bonemerge "ValveBiped.Bip01_R_Clavicle"
$bonemerge "ValveBiped.Bip01_R_UpperArm"
$bonemerge "ValveBiped.Bip01_R_Forearm"
$bonemerge "ValveBiped.Bip01_R_Hand"
$bonemerge "ValveBiped.Anim_Attachment_RH"
$bonemerge "ValveBiped.Bip01_R_Finger4"
$bonemerge "ValveBiped.Bip01_R_Finger41"
$bonemerge "ValveBiped.Bip01_R_Finger42"
$bonemerge "ValveBiped.Bip01_R_Finger3"
$bonemerge "ValveBiped.Bip01_R_Finger31"
$bonemerge "ValveBiped.Bip01_R_Finger32"
$bonemerge "ValveBiped.Bip01_R_Finger2"
$bonemerge "ValveBiped.Bip01_R_Finger21"
$bonemerge "ValveBiped.Bip01_R_Finger22"
$bonemerge "ValveBiped.Bip01_R_Finger1"
$bonemerge "ValveBiped.Bip01_R_Finger11"
$bonemerge "ValveBiped.Bip01_R_Finger12"
$bonemerge "ValveBiped.Bip01_R_Finger0"
$bonemerge "ValveBiped.Bip01_R_Finger01"
$bonemerge "ValveBiped.Bip01_R_Finger02"
$bonemerge "ValveBiped.Bip01_L_Thigh"
$bonemerge "ValveBiped.Bip01_L_Calf"
$bonemerge "ValveBiped.Bip01_L_Foot"
$bonemerge "ValveBiped.Bip01_L_Toe0"
$bonemerge "ValveBiped.Bip01_R_Thigh"
$bonemerge "ValveBiped.Bip01_R_Calf"
$bonemerge "ValveBiped.Bip01_R_Foot"
$bonemerge "ValveBiped.Bip01_R_Toe0"
$bonemerge "ValveBiped.Bip2"
$bonemerge "ValveBiped.Bip3"
$bonemerge "ValveBiped.Bip4"
$bonemerge "ValveBiped.Bip5"
$bonemerge "ValveBiped.Bip8"
$bonemerge "ValveBiped.Bip9"
$bonemerge "ValveBiped.Bip10"
$bonemerge "ValveBiped.Bip11"
$bonemerge "ValveBiped.Bip12"
$bonemerge "ValveBiped.Bip1"
$bonemerge "ValveBiped.Bip7"
$bonemerge "ValveBiped.Bip6"
$bonemerge "ValveBiped.Bip14"
$bonemerge "ValveBiped.Bip13"

$proceduralbones "miku_pm.vrd"

$jigglebone "pd.103"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.104"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.128"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.129"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.130"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.131"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.132"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.133"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.134"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.135"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.136"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.137"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.138"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.139"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.140"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.141"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.142"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.143"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.144"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.145"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.146"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.147"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.148"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.149"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.150"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.151"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.152"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.153"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.154"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.155"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.156"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.157"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.158"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.159"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.160"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.161"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.162"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.163"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.164"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.165"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.166"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.167"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.001"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.002"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.003"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.004"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.005"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.006"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.007"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.008"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.015"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.016"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.017"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.018"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.019"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.020"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.021"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.022"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.023"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.024"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.025"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.026"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.027"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.028"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.029"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.030"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.031"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.032"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.033"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.034"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.035"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.036"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.037"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.038"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.039"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.040"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.041"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.042"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.043"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.044"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.045"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.046"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.047"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.048"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.049"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.050"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.051"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.052"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.053"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.054"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.055"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.056"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.057"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.058"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.059"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.060"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.061"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.062"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.063"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.064"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.065"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.066"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.067"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.068"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.069"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.070"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.071"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.072"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.073"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.074"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.075"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.076"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.077"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.078"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.079"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.080"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.081"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.082"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.083"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.084"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.085"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.086"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.087"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.088"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.089"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.090"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.091"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.092"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.093"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.094"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.095"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.096"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.097"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.098"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.099"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.100"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.107"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.108"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.109"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.110"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.111"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.112"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.113"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.114"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.115"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.116"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.117"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.118"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.119"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.120"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.121"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.122"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.123"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.124"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.125"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.126"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.127"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.009"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.010"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.011"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.012"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.013"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.014"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.101"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.102"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.105"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.106"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.168"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.169"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.170"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.171"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.172"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.173"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}
$jigglebone "pd.174"
{
	is_flexible
	{
		length 10
		tip_mass 0
		pitch_stiffness 100
		pitch_damping 10
		yaw_stiffness 100
		yaw_damping 10
		along_stiffness 100
		along_damping 10
		angle_constraint 19.999999
	}
}

$poseparameter "move_yaw" -180 180 loop 360
$poseparameter "aim_yaw" -60 60 loop 0
$poseparameter "aim_pitch" -88.95743 50 loop 0
$poseparameter "body_yaw" -43.96424 49.46604 loop 0
$poseparameter "spine_yaw" -54.67891 54.66705 loop 0
$poseparameter "neck_trans" -0.140861 0.163729 loop 0
$poseparameter "head_yaw" -61.7095 61.73312 loop 0
$poseparameter "head_pitch" -39.8978 30.92974 loop 0
$poseparameter "head_roll" -13.33936 13.73894 loop 0

$ikchain "rhand" "ValveBiped.Bip01_R_Hand" knee 0.707 0.707 0
$ikchain "lhand" "ValveBiped.Bip01_L_Hand" knee 0.707 0.707 0
$ikchain "rfoot" "ValveBiped.Bip01_R_Foot" knee 0.707 -0.707 0
$ikchain "lfoot" "ValveBiped.Bip01_L_Foot" knee 0.707 -0.707 0

$ikautoplaylock "rfoot" 1 0.1
$ikautoplaylock "lfoot" 1 0.1
$ikautoplaylock "rfoot" 1 0.1
$ikautoplaylock "lfoot" 1 0.1

$animation "a_proportions_corrective_animation" "miku_pm_anims\a_proportions_corrective_animation.smd" {
}

$animation "a_proportions" "miku_pm_anims\a_proportions.smd" {
	fps 30
	// Crowbar++ writes this subtract option to prevent jigglebone and poseparameter problems when delta sequences are recompiled.
	subtract "a_proportions_corrective_animation" 0
}

$sequence "reef" {
	"miku_pm_anims\reef.smd"
	fadein 0.2
	fadeout 0.2
	hidden
	fps 1
	ikrule "rhand" release contact 0 fakeorigin 0 0 0 fakerotate 0 0 0 floor 0 height 0 radius 0 range 0 0 1 1 target 0
	ikrule "lhand" release contact 0 fakeorigin 0 0 0 fakerotate 0 0 0 floor 0 height 0 radius 0 range 0 0 1 1 target 1
	ikrule "rfoot" release contact 0 fakeorigin 0 0 0 fakerotate 0 0 0 floor 0 height 0 radius 0 range 0 0 1 1 target 2
	ikrule "lfoot" release contact 0 fakeorigin 0 0 0 fakerotate 0 0 0 floor 0 height 0 radius 0 range 0 0 1 1 target 3
}

$sequence "proportions" {
	"a_proportions"
	autoplay
	delta
	fadein 0.2
	fadeout 0.2
	hidden
}

$sequence "ragdoll" {
	"miku_pm_anims\ragdoll.smd"
	activity "ACT_DIERAGDOLL" 1
	fadein 0.2
	fadeout 0.2
	fps 30
	ikrule "rhand" release contact 0 fakeorigin 0 0 0 fakerotate 0 0 0 floor 0 height 0 radius 0 range 0 0 0 0 target 0
	ikrule "lhand" release contact 0 fakeorigin 0 0 0 fakerotate 0 0 0 floor 0 height 0 radius 0 range 0 0 0 0 target 1
	ikrule "rfoot" release contact 0 fakeorigin 0 0 0 fakerotate 0 0 0 floor 0 height 0 radius 0 range 0 0 0 0 target 2
	ikrule "lfoot" release contact 0 fakeorigin 0 0 0 fakerotate 0 0 0 floor 0 height 0 radius 0 range 0 0 0 0 target 3
}

$includemodel "f_anm.mdl"

$collisionjoints "miku_pm_physics.smd"
{
	$mass 40
	$inertia 10
	$damping 0.05
	$rotdamping 5
	$rootbone "valvebiped.bip01_pelvis"

	$jointrotdamping "ValveBiped.Bip01_Pelvis" 3

	$jointmassbias "ValveBiped.Bip01_R_Thigh" 7
	$jointrotdamping "ValveBiped.Bip01_R_Thigh" 7
	$jointconstrain "ValveBiped.Bip01_R_Thigh" x limit -25 25 0
	$jointconstrain "ValveBiped.Bip01_R_Thigh" y limit -60 10 0
	$jointconstrain "ValveBiped.Bip01_R_Thigh" z limit -90 25 0

	$jointmassbias "ValveBiped.Bip01_R_Calf" 4
	$jointconstrain "ValveBiped.Bip01_R_Calf" x limit -10 15 0
	$jointconstrain "ValveBiped.Bip01_R_Calf" y limit -5 5 0
	$jointconstrain "ValveBiped.Bip01_R_Calf" z limit 0 120 0

	$jointrotdamping "ValveBiped.Bip01_R_Foot" 2
	$jointconstrain "ValveBiped.Bip01_R_Foot" x limit -20 20 0
	$jointconstrain "ValveBiped.Bip01_R_Foot" y limit -20 20 0
	$jointconstrain "ValveBiped.Bip01_R_Foot" z limit -20 45 0

	$jointmassbias "ValveBiped.Bip01_L_Thigh" 7
	$jointrotdamping "ValveBiped.Bip01_L_Thigh" 7
	$jointconstrain "ValveBiped.Bip01_L_Thigh" x limit -25 25 0
	$jointconstrain "ValveBiped.Bip01_L_Thigh" y limit -10 60 0
	$jointconstrain "ValveBiped.Bip01_L_Thigh" z limit -90 25 0

	$jointmassbias "ValveBiped.Bip01_L_Calf" 4
	$jointconstrain "ValveBiped.Bip01_L_Calf" x limit -15 10 0
	$jointconstrain "ValveBiped.Bip01_L_Calf" y limit -5 5 0
	$jointconstrain "ValveBiped.Bip01_L_Calf" z limit 0 120 0

	$jointrotdamping "ValveBiped.Bip01_L_Foot" 2
	$jointconstrain "ValveBiped.Bip01_L_Foot" x limit -20 20 0
	$jointconstrain "ValveBiped.Bip01_L_Foot" y limit -20 20 0
	$jointconstrain "ValveBiped.Bip01_L_Foot" z limit -20 75 0

	$jointconstrain "ValveBiped.Bip01_L_Toe0" x limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_L_Toe0" y limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_L_Toe0" z limit 0 0 0

	$jointconstrain "ValveBiped.Bip01_Spine" x limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_Spine" y limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_Spine" z limit 0 0 0

	$jointmassbias "ValveBiped.Bip01_Spine1" 8
	$jointconstrain "ValveBiped.Bip01_Spine1" x limit -10 10 0
	$jointconstrain "ValveBiped.Bip01_Spine1" y limit -16 16 0
	$jointconstrain "ValveBiped.Bip01_Spine1" z limit -10 10 0

	$jointmassbias "ValveBiped.Bip01_Spine4" 9
	$jointconstrain "ValveBiped.Bip01_Spine4" x limit -10 10 0
	$jointconstrain "ValveBiped.Bip01_Spine4" y limit -10 10 0
	$jointconstrain "ValveBiped.Bip01_Spine4" z limit -20 20 0

	$jointconstrain "ValveBiped.Bip01_R_Clavicle" x limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_R_Clavicle" y limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_R_Clavicle" z limit 0 0 0

	$jointconstrain "ValveBiped.Bip01_L_Clavicle" x limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_L_Clavicle" y limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_L_Clavicle" z limit 0 0 0

	$jointmassbias "ValveBiped.Bip01_L_UpperArm" 5
	$jointrotdamping "ValveBiped.Bip01_L_UpperArm" 2
	$jointconstrain "ValveBiped.Bip01_L_UpperArm" x limit -15 20 0
	$jointconstrain "ValveBiped.Bip01_L_UpperArm" y limit -80 80 0
	$jointconstrain "ValveBiped.Bip01_L_UpperArm" z limit -80 25 0

	$jointmassbias "ValveBiped.Bip01_L_Forearm" 4
	$jointrotdamping "ValveBiped.Bip01_L_Forearm" 4
	$jointconstrain "ValveBiped.Bip01_L_Forearm" x limit -40 15 0
	$jointconstrain "ValveBiped.Bip01_L_Forearm" y limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_L_Forearm" z limit -120 10 0

	$jointrotdamping "ValveBiped.Bip01_L_Hand" 1
	$jointconstrain "ValveBiped.Bip01_L_Hand" x limit -25 25 0
	$jointconstrain "ValveBiped.Bip01_L_Hand" y limit -35 35 0
	$jointconstrain "ValveBiped.Bip01_L_Hand" z limit -50 50 0

	$jointmassbias "ValveBiped.Bip01_R_UpperArm" 5
	$jointrotdamping "ValveBiped.Bip01_R_UpperArm" 2
	$jointconstrain "ValveBiped.Bip01_R_UpperArm" x limit -15 20 0
	$jointconstrain "ValveBiped.Bip01_R_UpperArm" y limit -80 80 0
	$jointconstrain "ValveBiped.Bip01_R_UpperArm" z limit -80 25 0

	$jointmassbias "ValveBiped.Bip01_R_Forearm" 4
	$jointrotdamping "ValveBiped.Bip01_R_Forearm" 4
	$jointconstrain "ValveBiped.Bip01_R_Forearm" x limit -40 15 0
	$jointconstrain "ValveBiped.Bip01_R_Forearm" y limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_R_Forearm" z limit -120 0 0

	$jointrotdamping "ValveBiped.Bip01_R_Hand" 1
	$jointconstrain "ValveBiped.Bip01_R_Hand" x limit -25 25 0
	$jointconstrain "ValveBiped.Bip01_R_Hand" y limit -35 35 0
	$jointconstrain "ValveBiped.Bip01_R_Hand" z limit -50 50 0

	$jointmassbias "ValveBiped.Bip01_Head1" 2
	$jointrotdamping "ValveBiped.Bip01_Head1" 3
	$jointconstrain "ValveBiped.Bip01_Head1" x limit -50 50 0
	$jointconstrain "ValveBiped.Bip01_Head1" y limit -30 30 0
	$jointconstrain "ValveBiped.Bip01_Head1" z limit -22 24 0

	$jointconstrain "ValveBiped.Bip01_R_Toe0" x limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_R_Toe0" y limit 0 0 0
	$jointconstrain "ValveBiped.Bip01_R_Toe0" z limit 0 0 0
}
