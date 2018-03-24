--[[
--- Some field related utility functions
module "Field"
]]--

--[[***********************************************************************
*   Copyright 2015 Alexander Danzer, Michael Eischer, Christian Lobmeier, *
*       André Pscherer                                                    *
*   Robotics Erlangen e.V.                                                *
*   http://www.robotics-erlangen.de/                                      *
*   info@robotics-erlangen.de                                             *
*                                                                         *
*   This program is free software: you can redistribute it and/or modify  *
*   it under the terms of the GNU General Public License as published by  *
*   the Free Software Foundation, either version 3 of the License, or     *
*   any later version.                                                    *
*                                                                         *
*   This program is distributed in the hope that it will be useful,       *
*   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
*   GNU General Public License for more details.                          *
*                                                                         *
*   You should have received a copy of the GNU General Public License     *
*   along with this program.  If not, see <http://www.gnu.org/licenses/>. *
*************************************************************************]]

local Field = {}

local geom = require "../base/geom"
local math = require "../base/math"
local Referee = require "../base/referee"
local World = require "../base/world"


local G = World.Geometry

--- returns the nearest position inside the field (extended by boundaryWidth)
-- @name limitToField
-- @param pos Vector - the position to limit
-- @param boundaryWidth number - how much the field should be extended beyond the borders
-- @return Vector - limited vector
function Field.limitToField(pos, boundaryWidth)
	boundaryWidth = boundaryWidth or 0

	local allowedHeight = G.FieldHeightHalf + boundaryWidth -- limit height to field
	local y = math.bound(-allowedHeight, pos.y, allowedHeight)

	local allowedWidth = G.FieldWidthHalf + boundaryWidth -- limit width to field
	local x = math.bound(-allowedWidth, pos.x, allowedWidth)

	return Vector(x, y)
end

--- returns the nearest position inside the field without defense areas
-- @name limitToAllowedField
-- @param extraLimit number - how much the field should be additionally limited
-- @param pos Vector - the position to limit
-- @return Vector - limited vector
function Field.limitToAllowedField(pos, extraLimit)
	extraLimit = extraLimit or 0
	local oppExtraLimit = extraLimit
	if Referee.isStopState() or Referee.isFriendlyFreeKickState() then
		oppExtraLimit = oppExtraLimit + G.FreeKickDefenseDist + 0.10
	end
	pos = Field.limitToField(pos, -extraLimit)
	if Field.isInFriendlyDefenseArea(pos, extraLimit) then
		if math.abs(pos.x) <= G.DefenseStrechHalf then
			pos = Vector(pos.x, -G.FieldHeightHalf + G.DefenseRadius + extraLimit)
		else
			local circleMidpoint = Vector(
				G.DefenseStretchHalf * math.sign(pos.x), -G.FieldHeightHalf)
			pos = circleMidpoint + (pos - circleMidpoint):setLength(G.DefenseRadius + extraLimit)
		end
		return pos
	elseif Field.isInOpponentDefenseArea(pos, oppExtraLimit) then
		if math.abs(pos.x) <= G.DefenseStretchHalf then
			pos = Vector(pos.x, G.FieldHeightHalf-G.DefenseRadius-oppExtraLimit)
		else
			local circleMidpoint = Vector(
				G.DefenseStretchHalf*math.sign(pos.x), G.FieldHeightHalf)
			pos = circleMidpoint + (pos - circleMidpoint):setLength(G.DefenseRadius+oppExtraLimit)
		end
		return pos
	end
	return pos
end

--- check if pos is inside the field (extended by boundaryWidth)
-- @name isInField
-- @param pos Vector - the position to limit
-- @param boundaryWidth number - how much the field should be extended beyond the borders
-- @return bool - is in field
function Field.isInField(pos, boundaryWidth)
	boundaryWidth = boundaryWidth or 0

	local allowedHeight = G.FieldHeightHalf + boundaryWidth -- limit height to field
	if math.abs(pos.x) > G.GoalWidth / 2 and math.abs(pos.y) > allowedHeight -- check whether robot is inside the goal
			or math.abs(pos.y) > allowedHeight + G.GoalDepth then -- handle area behind goal
		return false
	end

	local allowedWidth = G.FieldWidthHalf + boundaryWidth -- limit width to field
	if math.abs(pos.x) > allowedWidth then
		return false
	end

	return true
end

--- Returns the minimum distance to the field borders (extended by boundaryWidth)
-- @name distanceToFieldBorders
-- @param pos Vector - the position to limit
-- @param boundaryWidth number - how much the field should be extended beyond the borders
-- @return number - distance to field borders
function Field.distanceToFieldBorder(pos, boundaryWidth)
	boundaryWidth = boundaryWidth or 0

	local allowedWidth = G.FieldWidthHalf + boundaryWidth
	local dx = allowedWidth - math.abs(pos.x)

	local allowedHeight = G.FieldHeightHalf + boundaryWidth
	local dy = allowedHeight - math.abs(pos.y)

	-- returns the minimum of dx and dy
	return math.bound(0, dx, dy)
end





local function distanceToDefenseAreaSq_2018(pos, friendly)
	local defenseYmin = friendly and -G.FieldHeightHalf or G.FieldHeightHalf - G.DefenseHeight
	local defenseYmax = friendly and -G.FieldHeightHalf + G.DefenseHeight or G.FieldHeightHalf

	local inside = Vector(math.bound(-G.DefenseWidthHalf, pos.x, G.DefenseWidthHalf),
				math.bound(defenseYmin, pos.y, defenseYmax))

	return pos:distanceToSq(inside)
end
local function distanceToDefenseArea_2018(pos, radius, friendly)
	local distance = math.sqrt(distanceToDefenseAreaSq_2018(pos, friendly)) - radius
	return (distance < 0) and 0 or distance
end
local function distanceToDefenseArea_2017(pos, radius, friendly)
	radius = radius + G.DefenseRadius
	local defenseY = friendly and -G.FieldHeightHalf or G.FieldHeightHalf
	local inside = Vector(math.bound(-G.DefenseStretchHalf, pos.x, G.DefenseStretchHalf), defenseY)
	local distance = pos:distanceTo(inside) - radius
	return (distance < 0) and 0 or distance
end

if World.RULEVERSION == "2018" then
	Field.distanceToDefenseArea = distanceToDefenseArea_2018
else
	Field.distanceToDefenseArea = distanceToDefenseArea_2017
end


--- check if position is inside/touching the (friendly) defense area
-- @name isInDefenseArea
-- @param pos Vector - the position to check
-- @param radius number - Radius of object to check
-- @param friendly bool - selection of Own/Opponent area
-- @return bool

local function isInDefenseArea_2017(pos, radius, friendly)
	radius = radius + G.DefenseRadius
	local defenseY = friendly and -G.FieldHeightHalf or G.FieldHeightHalf
	local inside = Vector(math.bound(-G.DefenseStretchHalf, pos.x, G.DefenseStretchHalf), defenseY)
	return pos:distanceToSq(inside) < radius * radius
end


local function isInDefenseArea_2018(pos, radius, friendly)
	return distanceToDefenseAreaSq_2018(pos, friendly) < radius * radius
end

if World.RULEVERSION == "2018" then
	Field.isInDefenseArea = isInDefenseArea_2018
else
	Field.isInDefenseArea = isInDefenseArea_2017
end


--- check if pos is inside the field (extended by boundaryWidth)
-- @name isInAllowedField
-- @param pos Vector - the position to check
-- @param boundaryWidth number - how much the field should be extended beyond the borders
-- @return bool - is in field
function Field.isInAllowedField(pos, boundaryWidth)
	return Field.isInField(pos, boundaryWidth) and
		not isInDefenseArea(pos, -boundaryWidth, true) and
		not isInDefenseArea(pos, -boundaryWidth, false)
end

--- Returns true if the position is inside/touching the friendly defense area
-- @name isInFriendlyDefenseArea
-- @param pos Vector - the position to check
-- @param radius number - Radius of object to check
-- @return bool
function Field.isInFriendlyDefenseArea(pos, radius)
	return isInDefenseArea(pos, radius, true)
end

--- Returns true if the position is inside/touching the opponent defense area
-- @name isInOpponentDefenseArea
-- @param pos Vector - the position to check
-- @param radius number - Radius of object to check
-- @return bool
function Field.isInOpponentDefenseArea(pos, radius)
	return isInDefenseArea(pos, radius, false)
end

--- Calculates the distance (between robot hull and field line) to the friendly defense area
-- @name distanceToFriendlyDefenseArea
-- @param pos Vector - the position to check
-- @param radius number - Radius of object to check
-- @return number - distance
function Field.distanceToFriendlyDefenseArea(pos, radius)
	return distanceToDefenseArea(pos, radius, true)
end

--- Calculates the distance (between robot hull and field line) to the opponent defense area
-- @name distanceToOpponentDefenseArea
-- @param pos Vector - the position to check
-- @param radius number - Radius of object to check
-- @return number - distance
function Field.distanceToOpponentDefenseArea(pos, radius)
	return distanceToDefenseArea(pos, radius, false)
end

local normalize = function(angle)
	while angle >= 2*math.pi do angle = angle - 2*math.pi end
	while angle < 0 do angle = angle + 2*math.pi end
	return angle
end

local intersectRayArc = function(pos, dir, m, r, minangle, maxangle)
	local intersections = {}
	local i1, i2, l1, l2 = geom.intersectLineCircle(pos, dir, m, r)
	local interval = normalize(maxangle - minangle)
	if i1 and l1 >= 0 then
		local a1 = normalize((i1 - m):angle() - minangle)
		if a1 < interval then
			table.insert(intersections, {i1, a1, l1})
		end
	end
	if i2 and l2 >= 0 then
		local a2 = normalize((i2 - m):angle() - minangle)
		if a2 < interval then
			table.insert(intersections, {i2, a2, l2})
		end
	end
	return intersections
end

local intersectRayDefenseArea = function(pos, dir, extraDistance, opp)
	-- calculate defense radius
	extraDistance = extraDistance or 0
	local radius = G.DefenseRadius + extraDistance
	assert(radius >= 0, "extraDistance must not be smaller than -G.DefenseRadius")

	-- calculate length of defense border (arc - line - arc)
	local arcway = radius * math.pi/2
	local lineway = G.DefenseStretch
	local totalway = 2 * arcway + lineway

	-- calculate global positions
	local oppfac = opp and -1 or 1
	local leftCenter = Vector(-G.DefenseStretchHalf, -G.FieldHeightHalf) * oppfac
	local rightCenter = Vector(G.DefenseStretchHalf, -G.FieldHeightHalf) * oppfac

	-- calclulate global angles
	local oppadd = opp and math.pi or 0
	local to_opponent = normalize(oppadd + math.pi/2)
	local to_friendly = normalize(oppadd - math.pi/2)

	-- calctulate intersection points with defense arcs
	local intersections = {}
	local ileft = intersectRayArc(pos, dir, leftCenter, radius, to_opponent, to_friendly)
	for _,i in ipairs(ileft) do
		table.insert(intersections, {i[1], (math.pi/2-i[2]) * radius, i[3]})
	end
	local iright = intersectRayArc(pos, dir, rightCenter, radius, to_friendly, to_opponent)
	for _,i in ipairs(iright) do
		table.insert(intersections, {i[1], (math.pi-i[2]) * radius + arcway + lineway, i[3]})
	end

	-- calculate intersection point with defense stretch
	local defenseLineOnpoint = Vector(0, -G.FieldHeightHalf + radius) * oppfac
	local lineIntersection,l1,l2 = geom.intersectLineLine(pos, dir, defenseLineOnpoint, Vector(1,0))
	if lineIntersection and l1 >= 0 and math.abs(l2) <= G.DefenseStrechHalf then
		table.insert(intersections, {lineIntersection, l2 + totalway/2, l1})
	end
	return intersections, totalway
end

--- Returns one intersection of a given line with the (extended) defense area
--- The intersection is the one with the smallest t in x = pos + t * dir, t >= 0
-- @name intersectRayDefenseArea
-- @param pos Vector - starting point of the line
-- @param dir Vector - the direction of the line
-- @param extraDistance number - gets added to G.DefenseRadius
-- @param opp bool - whether the opponent or the friendly defense area is considered
-- @return Vector - the intersection position (May also be behind the goalline)
-- @return number - the length of the way from the very left of the defense area to the
-- intersection point, when moving along its border
function Field.intersectRayDefenseArea(pos, dir, extraDistance, opp)
	local intersections, totalway = intersectRayDefenseArea(pos, dir, extraDistance, opp)

	-- choose nearest intersection
	local minDistance = math.huge
	local minIntersection = nil
	local minWay = totalway/2
	for _,i in ipairs(intersections) do
		local dist = pos:distanceTo(i[1])
		if dist < minDistance then
			minDistance = dist
			minIntersection = i[1]
			minWay = i[2]
		end
	end
	return minIntersection, minWay
end

--- Return all line segments of the line segment pos to pos + dir * maxLength which are in the allowed field part
-- @name allowedLineSegments
-- @param pos Vector - starting point of the line
-- @param dir Vector - the direction of the line
-- @param maxLength number - length of the line segment, optional
-- @return table - contains n {pos1, pos2} tables representing the resulting line segments
function Field.allowedLineSegments(pos, dir, maxLength)
	maxLength = maxLength or math.inf
	local direction = dir:copy()
	direction:setLength(1)
	local pos1, lambda1 = geom.intersectLineLine(pos, direction, Vector(G.FieldWidthHalf, 0), Vector(0, 1))
	local pos2, lambda2 = geom.intersectLineLine(pos, direction, Vector(-G.FieldWidthHalf, 0), Vector(0, 1))
	local pos3, lambda3 = geom.intersectLineLine(pos, direction, Vector(0, G.FieldHeightHalf), Vector(1, 0))
	local pos4, lambda4 = geom.intersectLineLine(pos, direction, Vector(0, -G.FieldHeightHalf), Vector(1, 0))
	local lambdas = {}
	local fieldLambdas = {lambda1, lambda2, lambda3, lambda4}
	local fieldPos = {pos1, pos2, pos3, pos4}
	for i, lambda in ipairs(fieldLambdas) do
		if lambda > maxLength then
			lambda = maxLength
		end
		-- an offset 0f 0.05 is used here and below as the calculated point is on
		-- the border of the field anyways, otherwise it might flicker due to floating
		-- point inaccuracies
		if lambda and Field.isInField(fieldPos[i], 0.05) and lambda > 0 then
			table.insert(lambdas, lambda)
		end
	end

	local intersectionsOwn = intersectRayDefenseArea(pos, direction, 0, false)
	local intersectionsOpp = intersectRayDefenseArea(pos, direction, 0, true)
	table.append(intersectionsOwn, intersectionsOpp)
	for _, intersection in ipairs(intersectionsOwn) do
		local lambda = pos:distanceTo(intersection[1])
		if lambda > maxLength then
			lambda = maxLength
		end
		if Field.isInField(intersection[1], 0.05) and lambda > 0 then
			table.insert(lambdas, lambda)
		end
	end

	if Field.isInAllowedField(pos, 0) then
		table.insert(lambdas, 0)
	end

	table.sort(lambdas)

	local result = {}
	for i = 1, math.floor(#lambdas / 2) do
		local p1 = pos + direction * lambdas[i * 2 - 1]
		local p2 = pos + direction * lambdas[i * 2]
		if p1:distanceTo(p2) > 0 then
			table.insert(result, {p1, p2})
		end
	end
	return result
end

--- Calculates the point on the (extended) defense area when given the way along its border
-- @name defenseIntersectionByWay
-- @param way number - the way along the border
-- @param extraDistance number - gets added to G.DefenseRadius
-- @param opp bool - whether the opponent or the friendly defense area is considered
-- @return Vector - the position
function Field.defenseIntersectionByWay(way, extraDistance, opp)
	-- calculate defense radius
	extraDistance = extraDistance or 0
	local radius = G.DefenseRadius + extraDistance
	assert(radius >= 0, "extraDistance must not be smaller than -G.DefenseRadius: "..tostring(extraDistance))

	-- calculate length of defense border (arc - line - arc)
	local arcway = radius * math.pi/2
	local lineway = G.DefenseStretch
	local totalway = 2 * arcway + lineway

	-- bind way to [0, totalway] by mirroring it
	-- inserted way can be in [-2*totalway, 2*totalway]
	if way < 0 then
		way = -way
	end
	if way > totalway then
		way = 2*totalway - way -- if abs(way) > 2*totalway, way will be negative and be eaten by the folling assert
	end

	assert(way >= 0, "way is out of bounds ("..tostring(way)..", "..tostring(extraDistance)..", "..tostring(opp))

	local intersection
	if way < arcway then
		local angle = way / radius
		intersection = Vector.fromAngle(math.pi - angle) * radius +
			Vector(-G.DefenseStretchHalf, -G.FieldHeightHalf)
	elseif way <= arcway + lineway then
		intersection = Vector(way - arcway - G.DefenseStretchHalf, radius - G.FieldHeightHalf)
	else
		local angle = (way - arcway - lineway) / radius
		intersection = Vector.fromAngle(math.pi/2 - angle) * radius +
			Vector(G.DefenseStretchHalf, -G.FieldHeightHalf)
	end

	if opp then
		intersection = -intersection
	end

	return intersection
end

--- Calculates all intersections (0 to 4) of a given circle with the (extended) defense area
-- @name intersectCircleDefenseArea
-- @param pos Vector - center point of the circle
-- @param radius number - radius of the circle
-- @param extraDistance number - gets added to G.DefenseRadius
-- @param opp bool - whether the opponent or the friendly defense area is considered
-- @return [Vector] - a list of intersection points, not sorted
function Field.intersectCircleDefenseArea(pos, radius, extraDistance, opp)
	-- invert coordinates if opp-flag is set
	if opp then pos = pos * -1 end

	local leftCenter = Vector(-G.DefenseStretchHalf, -G.FieldHeightHalf)
	local rightCenter = Vector(G.DefenseStretchHalf, -G.FieldHeightHalf)
	local defenseRadius = G.DefenseRadius + extraDistance

	local intersections = {}

	-- get intersections with circles
	local li1, li2 = geom.intersectCircleCircle(leftCenter, defenseRadius, pos, radius)
	local ri1, ri2 = geom.intersectCircleCircle(rightCenter, defenseRadius, pos, radius)
	if li1 and li1.x < G.DefenseStretchHalf and li1.y > -G.FieldHeightHalf then
		table.insert(intersections, li1)
	end
	if li2 and li2.x < G.DefenseStretchHalf and li2.y > -G.FieldHeightHalf then
		table.insert(intersections, li2)
	end
	if ri1 and ri1.x > G.DefenseStretchHalf and ri1.y > -G.FieldHeightHalf then
		table.insert(intersections, ri1)
	end
	if ri2 and ri2.x > G.DefenseStretchHalf and ri2.y > -G.FieldHeightHalf then
		table.insert(intersections, ri2)
	end

	-- get intersections with line
	local mi1, mi2 = geom.intersectLineCircle(
				Vector(0, -G.FieldHeightHalf+defenseRadius), Vector(1, 0), pos, radius)
	if mi1 and math.abs(mi1.x) <= G.DefenseStretchHalf then
		table.insert(intersections, li1)
	end
	if mi2 and math.abs(mi1.x) <= G.DefenseStretchHalf then
		table.insert(intersections, li2)
	end


	-- invert coordinates if opp-flag is set
	if opp then
		for i, intersection in ipairs(intersections) do
			intersections[i] = intersection * -1
		end
	end

	return intersections
end

--- Calculates the distance (between robot hull and field line) to the own goal line
-- @name distanceToFriendlyGoalLine
-- @param pos Vector - the position to check
-- @param radius number - Radius of object to check
-- @return number - distance
function Field.distanceToFriendlyGoalLine(pos, radius)
	if math.abs(pos.x) < G.GoalWidth/2 then
		return math.max(G.FieldHeightHalf + pos.y - radius, 0)
	end
	local goalpost = Vector(pos.x > 0 and G.GoalWidth/2 or - G.GoalWidth/2, -G.FieldHeightHalf)
	return goalpost:distanceTo(pos) - radius
end

--- Check whether to position is in the teams own corner
-- @name isInOwnCorner
-- @param pos Vector - the position to check
-- @param opp bool - Do the check from the opponents point of view
-- @return bool
function Field.isInOwnCorner(pos, opp)
	local oppfac = opp and 1 or -1
	return (G.FieldWidthHalf - math.abs(pos.x))^2
		+ (oppfac * G.FieldHeightHalf - pos.y)^2 < 1
end

--- The position, where the half-line given by startPos and dir intersects the next field boundary
-- @param startPos vector - the initial point of the half-line
-- @param dir vector - the direction of the half-line
-- @param [offset number - additional offset to move field lines further outwards]
-- @return [vector]
function Field.nextLineCut(startPos, dir, offset)
	if dir.x == 0 and dir.y == 0 then
		return
	end
	offset = offset or 0
	local width = Vector((dir.x > 0 and 1 or -1) * (G.FieldWidthHalf + offset), 0)
	local height = Vector(0, (dir.y > 0 and 1 or -1) * (G.FieldHeightHalf + offset))
	local sideCut, sideLambda = geom.intersectLineLine(startPos, dir, width, height)
	local frontCut, frontLambda = geom.intersectLineLine(startPos, dir, height, width)
	if sideCut then
		if frontCut then
			if sideLambda < frontLambda then
				return sideCut
			else
				return frontCut
			end
		else
			return sideCut
		end
	else
		return frontCut
	end
end



--- Calculates the next intersection with the field boundaries or the defense areas
-- @name nextAllowedFieldLineCut
-- @param startPos vector - the initial point of the half-line
-- @param dir vector - the direction of the half-line
-- @param extraDistance number - the radius of the object (gets added to G.DefenseRadius)
-- @return Vector - minLineCut
-- @return Number - the lambda for the line cut
function Field.nextAllowedFieldLineCut(startPos, dir, extraDistance)
	local normalizedDir = dir:copy():normalize()
	local perpendicularDir = normalizedDir:perpendicular()

	local boundaryLineCut = Field.nextLineCut(startPos, normalizedDir, -extraDistance)
	local friendlyDefenseLineCut = Field.intersectRayDefenseArea(startPos, normalizedDir, extraDistance, false)
	local opponentDefenseLineCut = Field.intersectRayDefenseArea(startPos, normalizedDir, extraDistance, true)

	local lineCuts = {}
	if boundaryLineCut then table.insert(lineCuts, boundaryLineCut) end
	if friendlyDefenseLineCut then table.insert(lineCuts, friendlyDefenseLineCut) end
	if opponentDefenseLineCut then table.insert(lineCuts, opponentDefenseLineCut) end

	local minLambda = math.huge
	local minLineCut = nil
	for _, lineCut in ipairs(lineCuts) do
		local _, lambda = geom.intersectLineLine(startPos, normalizedDir, lineCut, perpendicularDir)
		if lambda and lambda > 0 and lambda < minLambda then
			minLambda = lambda
			minLineCut = lineCut
		end
	end

	return minLineCut, minLineCut and minLambda or 0
end


return Field
