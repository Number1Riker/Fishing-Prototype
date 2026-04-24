local Behavior = {}

function Behavior:Init(state)
	state.Zones = {
		{ Center = 0.5, Width = state.ZoneWidth }
	}
end

function Behavior:Step(state, dt)
end

function Behavior:OnClick(state, cursorX, hitAny)
end

return Behavior
