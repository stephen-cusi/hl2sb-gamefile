//-----------------------------------------------------------------------------
// HL2SB: the nav mesh generation progress panel (CNavProgress).
//
// WHY THIS FILE EXISTS
//
//   CNavProgress's constructor ends with
//       LoadControlSettings( "Resource/UI/NavProgress.res" );   (NavProgress.cpp:49)
//   and nothing in this mod ever shipped that resource: the only copy on the
//   machine is GMod's, inside its own loose content directory, which is NOT a
//   mounted search path here (gameinfo.txt mounts garrysmod's VPK, not its
//   resource/ tree).  So the panel came up with no layout at all - a 0x0 Frame
//   pinned to the top-left corner of the screen, which is exactly what a
//   nav_generate run looked like: a small dark sliver at the screen edge.
//
//   The control names below are not decoration - the constructor creates
//   TitleLabel, TextLabel, ProgressBarBorder, ProgressBar and ProgressBarSizer
//   by name, and PerformLayout() sizes the bar from ProgressBarSizer's width
//   (NavProgress.cpp:76-86), so a missing name means a zero-width bar.
//
//   The frame is SetProportional(true) (NavProgress.cpp:37), so these numbers
//   are in the 640x480 proportional space and scale with the screen: xpos 300
//   lands the panel just right of centre on any resolution.
//-----------------------------------------------------------------------------
"Resource/UI/NavProgress.res"
{
	"nav_progress"
	{
		"ControlName"		"Frame"
		"fieldName"		"nav_progress"
		"xpos"		"300"
		"ypos"		"50"
		"wide"		"240"
		"tall"		"40"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"settitlebarvisible"	"0"
	}
	"RoundedCornerBackground"
	{
		"ControlName"		"Panel"
		"fieldName"		"RoundedCornerBackground"
		"xpos"		"0"
		"ypos"		"0"
		"wide"		"240"
		"tall"		"40"
		"autoResize"		"0"
		"pinCorner"		"2"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"settitlebarvisible"	"0"
		"zpos"		"0"
	}
	"TitleLabel"
	{
		"ControlName"		"Label"
		"fieldName"		"TitleLabel"
		"xpos"		"5"
		"ypos"		"5"
		"wide"		"80"
		"tall"		"15"
		"autoResize"		"0"
		"pinCorner"		"2"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
		"labelText"		""
		"textAlignment"		"north-west"
		"dulltext"		"0"
		"brighttext"		"0"
		"zpos"		"1"
	}
	"TextLabel"
	{
		"ControlName"		"Label"
		"fieldName"		"TextLabel"
		"xpos"		"5"
		"ypos"		"5"
		"wide"		"230"
		"tall"		"15"
		"autoResize"		"0"
		"pinCorner"		"2"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"labelText"		""
		"textAlignment"		"north-west"
		"dulltext"		"0"
		"brighttext"		"0"
		"zpos"		"1"
	}
	"ProgressBarSizer"
	{
		"ControlName"		"Panel"
		"fieldName"		"ProgressBarSizer"
		"xpos"		"9"
		"ypos"		"24"
		"wide"		"222"
		"tall"		"7"
		"autoResize"		"0"
		"pinCorner"		"2"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"zpos"		"1"
	}
	"ProgressBar"
	{
		"ControlName"		"Panel"
		"fieldName"		"ProgressBar"
		"xpos"		"9"
		"ypos"		"24"
		"wide"		"222"
		"tall"		"7"
		"autoResize"		"0"
		"pinCorner"		"2"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"zpos"		"1"
	}
	"ProgressBarBorder"
	{
		"ControlName"		"Panel"
		"fieldName"		"ProgressBarBorder"
		"xpos"		"7"
		"ypos"		"22"
		"wide"		"226"
		"tall"		"10"
		"autoResize"		"0"
		"pinCorner"		"2"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"zpos"		"2"
	}
}
