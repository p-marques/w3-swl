// Set Weight Limit 3.x - 2026, pMarK

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

@addField(W3PlayerWitcher)
private var setWeightLimitManager : SetWeightLimitManager;

@wrapMethod(W3PlayerWitcher)
function GetMaxRunEncumbrance(out usesHorseBonus : bool) : float
{
	var value : float;

	if (!setWeightLimitManager)
	{
		setWeightLimitManager = new SetWeightLimitManager in this;
		setWeightLimitManager.InitSWL();
	}

	if (setWeightLimitManager.GetIsModOn())
	{
		value = CalculateAttributeValue(GetHorseManager().GetHorseAttributeValue('encumbrance', false));
		usesHorseBonus = (value > 0);
		return value + setWeightLimitManager.GetWeightLimit();
	}

	return wrappedMethod(usesHorseBonus);
}
