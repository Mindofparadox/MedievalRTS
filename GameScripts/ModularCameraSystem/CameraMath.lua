local CameraMath = {}

function CameraMath.clamp(x, a, b)
	return math.max(a, math.min(b, x))
end

function CameraMath.expLerpAlpha(strength, dt)
	return 1 - math.exp(-strength * dt)
end

function CameraMath.calculateOffsetDir(pitch, yaw)
	return Vector3.new(
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		math.cos(pitch) * math.cos(yaw)
	)
end

function CameraMath.calculateMoveVectors(offsetDir)
	local forwardFlat = Vector3.new(-offsetDir.X, 0, -offsetDir.Z)
	if forwardFlat.Magnitude < 1e-4 then 
		forwardFlat = Vector3.new(0, 0, -1) 
	else 
		forwardFlat = forwardFlat.Unit 
	end

	local rightFlat = Vector3.new(-forwardFlat.Z, 0, forwardFlat.X)
	return forwardFlat, rightFlat
end

return CameraMath