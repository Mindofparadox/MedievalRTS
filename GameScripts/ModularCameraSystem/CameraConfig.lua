local CameraConfig = {}

-- MOVEMENT
CameraConfig.MOVE_SPEED  = 90
CameraConfig.BOOST_SPEED = 220
CameraConfig.ROT_SPEED   = 0.008

-- ZOOM
CameraConfig.MIN_ZOOM    = 20
CameraConfig.MAX_ZOOM    = 140
CameraConfig.ZOOM_SPEED  = 8

-- PITCH
CameraConfig.MIN_PITCH   = math.rad(15)
CameraConfig.MAX_PITCH   = math.rad(80)

-- SMOOTHING
CameraConfig.ROT_SMOOTHNESS  = 18
CameraConfig.ZOOM_SMOOTHNESS = 18

-- DEFAULTS
CameraConfig.START_YAW   = math.rad(45)
CameraConfig.START_PITCH = math.rad(55)
CameraConfig.START_ZOOM  = 80

return CameraConfig