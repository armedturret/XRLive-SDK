@tool
extends RefCounted

const XRLIVE_AUTOLOAD: StringName = "XRLiveGlobal"
const XRLIVE_SM_NAME: StringName = "XRLiveSpatialEntitiesManager"
const XRLIVE_LEVEL_ROOT_NAME: StringName = "XRLiveLevelRoot"
const XRLIVE_LEVEL_SPAWNER_NAME: StringName = "XRLiveLevelSpawner"
const XRLIVE_TIMEOUT_SECONDS: float = 10.0
const XRLIVE_MAX_CLIENTS: int = 50
const XRLIVE_DEFAULT_PORT: int = 3700
const XRLIVE_ARG_FILE_PATH: String = "/launch_args.txt"
