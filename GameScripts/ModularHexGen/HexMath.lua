local HexMath = {}

function HexMath.axialToWorld(q, r, hexRadius, tileY)
	local x = hexRadius * math.sqrt(3) * (q + r/2)
	local z = hexRadius * 1.5 * r
	return Vector3.new(x, tileY, z)
end

function HexMath.getNormalizedPos(q, r, halfQ, halfR)
	local dx = q / halfQ
	local dy = r / halfR
	return dx, dy
end

function HexMath.getCenterDistance(dx, dy, centers)
	local best = math.huge
	for _, c in ipairs(centers) do
		local cx, cy = c[1], c[2]
		local ddx = dx - cx
		local ddy = dy - cy
		local d = math.sqrt(ddx * ddx + ddy * ddy)
		if d < best then
			best = d
		end
	end
	return best
end

return HexMath