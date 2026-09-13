-- ResultMessages.lua
-- Shared reason->message mappings for build/craft action feedback.

local ResultMessages = {}

ResultMessages.Build = {
	Success = "Build action complete.",
	InvalidPayload = "Invalid build request.",
	InvalidType = "That item cannot be placed.",
	OutOfRange = "Move closer to build there.",
	OutOfBounds = "That location is out of bounds.",
	OutsideCamp = "Build within 100 studs of spawn (the 200-stud camp).",
	Occupied = "That spot is already occupied.",
	NoSurface = "Aim at solid ground or a supported surface.",
	MissingPlaceableItem = "You do not have that placeable item.",
	EquipBuildItem = "Equip that build item in your hotbar first.",
	HoldToSalvage = "Keep holding on the same structure for three seconds.",
	CookingQueueNotEmpty = "Finish or cancel queued meals before salvaging this station.",
	CookingOutputNotEmpty = "Collect the cooked food before salvaging this station.",
	SalvageBlocked = "Move where you can reach this structure directly.",
	MissingCost = "Not enough materials.",
	PlacementFailed = "Could not place that structure.",
	InventoryFull = "Inventory full.",
	NotStructure = "That target is not a removable structure.",
	NotOwner = "You can only remove your own structure.",
	RemoveOutOfRange = "Move closer to remove that structure.",
	GameOver = "The run has already ended.",
	Unknown = "Build action failed.",
}

ResultMessages.Craft = {
	InvalidQuantity = "Choose a craft quantity from 1 to 99.",
	InvalidRequest = "That crafting request is invalid.",
	NotAlive = "You must be alive to craft.",
	WorldLoading = "Wait for your expedition to finish loading before crafting.",
	RefundPending = "Craft cancelled. Your materials have been returned.",
	Success = "Crafting complete.",
	UseCookingStation = "Open the cooking station to queue this meal and choose seasoning.",
	NoRecipe = "Recipe not found.",
	WrongStation = "Use the required station for this recipe.",
	NotNearStation = "Move closer to the crafting station.",
	MissingItems = "Missing required materials.",
	ConsumeFailed = "Could not consume crafting materials.",
	InventoryFull = "Inventory full.",
	CraftInProgress = "You are already crafting an item.",
	GameOver = "The run has already ended.",
	Unknown = "Crafting failed.",
}

return ResultMessages
