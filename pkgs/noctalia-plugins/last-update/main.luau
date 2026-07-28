-- Bar widget: how stale is the auto-update source?
--
-- Runs the packaged freshness probe (pkgs/scripts/noctalia-last-update.sh, its
-- absolute store path baked in below by modules/home/desktop/noctalia.nix),
-- which queries GitHub for the last commit on the branch `system.autoUpgrade`
-- tracks. The widget shows the age in days and turns red ("error" role) once
-- that exceeds the threshold — the fleet has stopped receiving updates.
--
-- Offline is deliberately NOT red: a failed probe reports `status=offline`, and
-- we show a muted "?" so a missing network never looks like a broken pipeline.

local CHECK = "@CHECK_SCRIPT@"

barWidget.setGlyph("refresh")
barWidget.setText("…")

local function render(out)
  if out:match("status=(%w+)") ~= "ok" then
    barWidget.setText("?")
    barWidget.setColor("on_surface_variant")
    barWidget.setTooltip("Auto-update: offline — freshness unknown")
    return
  end

  local stale = out:match("stale=(%d)")
  local days = out:match("days=(%d+)") or "?"
  local date = out:match("date=(%S+)") or ""

  barWidget.setText(days .. "d")
  if stale == "1" then
    barWidget.setColor("error")
    barWidget.setTooltip(
      "Auto-update source is STALE: last commit " .. days ..
      " day(s) ago (" .. date .. "). The update pipeline may be broken."
    )
  else
    barWidget.setColor("on_surface")
    barWidget.setTooltip(
      "Auto-update source healthy: last commit " .. days ..
      " day(s) ago (" .. date .. ")."
    )
  end
end

-- Called by the host on load (below) and on every setUpdateInterval tick.
function update()
  noctalia.runAsync(CHECK, function(res)
    local out = ""
    if type(res) == "table" then
      out = res.stdout or ""
    elseif type(res) == "string" then
      out = res
    end
    render(out)
  end)
end

noctalia.setUpdateInterval(3600000) -- hourly; GitHub's unauth limit is 60/hr
update()
