// Set Weight Limit 2.x - 2022, pMarK

class SetWeightLimitManager {

	private var inGameConfigWrapper : CInGameConfigWrapper;

	public function InitSWL()
	{
		inGameConfigWrapper = theGame.GetInGameConfigWrapper();
	}

	public function GetIsModOn() : bool
	{
		return inGameConfigWrapper.GetVarValue('SWL', 'SWLONOFF');
	}

	public function GetWeightLimit() : float
	{
		var value: float;

		value = StringToFloat(inGameConfigWrapper.GetVarValue('SWL', 'SWL'));

		if (value < 60)
		{
			inGameConfigWrapper.SetVarValue('SWL', 'SWL', 60);
			value = 60;
		}

		return value;
	}
}