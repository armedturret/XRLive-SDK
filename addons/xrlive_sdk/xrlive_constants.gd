@tool
extends RefCounted

const XRLIVE_AUTOLOAD: StringName = "XRLiveGlobal"
# TODO: make this a commandline arg
const XRLIVE_PORT: int = 3700
const XRLIVE_LEVEL_ROOT_NAME: StringName = "LevelRoot"
const XRLIVE_LEVEL_SPAWNER_NAME: StringName = "LevelSpawner"
const XRLIVE_TIMEOUT_SECONDS: float = 10.0
const XRLIVE_MAX_CLIENTS: int = 50
