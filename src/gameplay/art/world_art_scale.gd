extends RefCounted
## 世界物体与地图树木/台阶统一视觉比例；HUD插画和玩法占格不使用此倍率。
const UNIT_FACTOR := 4.5
const BUILDING_FACTOR := 3.25
const CITY_FACTOR := BUILDING_FACTOR / 2.0

static func height_for(asset_name: String, original_height: float) -> float:
	return original_height * factor_for(asset_name)

static func factor_for(asset_name: String) -> float:
	return UNIT_FACTOR if asset_name in ["villager","guard","wolf"] else BUILDING_FACTOR
