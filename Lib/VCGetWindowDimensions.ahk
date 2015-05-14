/*
Returns width and height of the game window in the ByRef parameters.
Useful for things like positioning text on-screen.
*/

VCGetWindowDimensions(ByRef Width, ByRef Height)
{
	WindowWidthAddress := 0x009B48D8+0x04+GameVersionCheck("GTAVC")
	WindowHeightAddress := 0x009B48D8+0x08+GameVersionCheck("GTAVC")

	Width := Memory(3, WindowWidthAddress, 4)
	Height := Memory(3, WindowHeightAddress, 4)

}
