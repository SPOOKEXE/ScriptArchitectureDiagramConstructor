
return {
	{
		ID = "Test1",
		Layer = 1,
		Depends = {}
	},
	{
		ID = "Test2",
		Layer = 2,
		Depends = {"Test1"}
	},
	{
		ID = "Test3",
		Layer = 3,
		Depends = {"Test2"}
	},
	{
		ID = "Test4",
		Layer = 4,
		Depends = {"Test3"}
	},
	{
		ID = "Test5",
		Layer = 4,
		Depends = {"Test3"}
	},
	{
		ID = "Test6",
		Layer = 5,
		Depends = {"Test4"}
	},
	{
		ID = "Test7",
		Layer = 5,
		Depends = {"Test5"}
	},
	{
		ID = "Test8",
		Layer = 6,
		Depends = {"Test6", "Test7", "Test11"}
	},
	{
		ID = "Test9",
		Layer = 7,
		Depends = {"Test8"}
	},
	{
		ID = "Test10",
		Layer = 4,
		Depends = {"Test3"}
	},
	{
		ID = "Test11",
		Layer = 5,
		Depends = {"Test10"}
	},
}