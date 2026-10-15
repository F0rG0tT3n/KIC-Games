local _, Games = ...
local UI, Theme = Games.UI, Games.Theme
local function number(value)
    return type(value) == "number" and value == value and value >= 0 and value <= 2147483647
end
function UI:CreateResultsWindow()
    local frame = CreateFrame("Frame", nil, self.content)
    frame:SetAllPoints(self.content)
    self.resultsFrame = frame
    self.resultsHeading = Theme:Label(frame, "RESULTS", 0, -6, 550, "GameFontNormalLarge")
    self.resultsSubtitle =
        Theme:Label(frame, "Personal bests and your last 20 saved matches.", 0, -36, 650, "GameFontHighlightSmall")
    self.resultGames, self.resultGamesScroll = Theme:Scroll(frame, 216, 482, 0, -66)
    self.resultGameButtons = {}
    self.resultList, self.resultScroll = Theme:Scroll(frame, 642, 482, 232, -66)
    self.resultSummary = Theme:Label(self.resultList, "", 16, -8, 600)
    self.bestPanel = Theme:StatPanel(self.resultList, "PERSONAL BEST", 610, 112, 0, -86)
    self.bestScore, self.bestMetadata = self.bestPanel.value, self.bestPanel.detail
    self.historyHeading = Theme:Label(self.resultList, "MATCH HISTORY", 16, -222, 500, "GameFontNormalLarge")
    self.resultText = Theme:Label(self.resultList, "", 16, -260, 600)
    self.resultText:SetSpacing(4)
    frame:Hide()
    self:LayoutResults()
end
function UI:ShowResults()
    local id = Games.ActiveGame and Games.ActiveGame.game.id or Games.LastResult and Games.LastResult.gameID
    if Games.Registry[id] then
        self.resultGameID = id
    end
    self:OpenLauncher("results")
end
function UI:LayoutResults()
    local width, height = self.content:GetWidth(), self.content:GetHeight()
    local selectorWidth = math.min(230, math.floor(width * 0.26))
    self.resultSelectorWidth = selectorWidth
    self.resultsHeading:SetWidth(width - 176)
    self.resultsSubtitle:SetWidth(width - 18)
    self.resultGamesScroll:SetSize(selectorWidth, height - 66)
    self.resultGames:SetWidth(selectorWidth - 18)
    self.resultScroll:ClearAllPoints()
    self.resultScroll:SetPoint("TOPLEFT", selectorWidth + 16, -66)
    self.resultScroll:SetSize(width - selectorWidth - 16, height - 66)
    local available = width - selectorWidth - 34
    self.resultList:SetWidth(available)
    self.bestPanel:SetWidth(available)
    for _, text in ipairs({
        self.resultSummary,
        self.bestScore,
        self.bestMetadata,
        self.historyHeading,
        self.resultText,
    }) do
        text:SetWidth(available - 32)
    end
    self:RefreshResults()
end
function UI:RefreshResults()
    if not self.resultsFrame then
        return
    end
    local games = Games:GetGames()
    if not Games.Registry[self.resultGameID] then
        self.resultGameID = games[1] and games[1].id
    end
    for _, b in ipairs(self.resultGameButtons) do
        b:Hide()
    end
    for i, game in ipairs(games) do
        local b = self.resultGameButtons[i]
        if not b then
            b = Theme:Button(self.resultGames, "", 194, 0, 0, function() end, 44)
            b.caption:SetHeight(36)
            b.caption:SetMaxLines(2)
            self.resultGameButtons[i] = b
        end
        local id = game.id
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 52)
        b:SetWidth(self.resultSelectorWidth - 18)
        b.caption:SetWidth(self.resultSelectorWidth - 34)
        b:SetText(game.title)
        b:SetScript("OnClick", function()
            self.resultGameID = id
            self.resultScroll:SetVerticalScroll(0)
            self:RefreshResults()
        end)
        Theme:Select(b, self.resultGameID == id)
        b:Show()
    end
    self.resultGames:SetHeight(math.max(self.resultGamesScroll:GetHeight(), #games * 52))
    local selected = Games.Registry[self.resultGameID]
    local stats = Games:GetResultStats(self.resultGameID)
    self.resultSummary:SetText(
        selected
                and string.format(
                    "%s\nCompleted: %d / Interrupted: %d\nWins: %d / Losses: %d / Draws: %d",
                    selected.title,
                    stats.completed,
                    stats.aborted,
                    stats.wins,
                    stats.losses,
                    stats.draws
                )
            or "Install a game module to view its records."
    )
    local bestY = math.max(86, self.resultSummary:GetStringHeight() + 32)
    self.bestPanel:ClearAllPoints()
    self.bestPanel:SetPoint("TOPLEFT", 0, -bestY)
    self.historyHeading:ClearAllPoints()
    self.historyHeading:SetPoint("TOPLEFT", 16, -(bestY + 136))
    self.resultText:ClearAllPoints()
    self.resultText:SetPoint("TOPLEFT", 16, -(bestY + 174))
    local saved = selected and Games.DB[selected.id]
    local best = type(saved) == "table" and type(saved.best) == "table" and saved.best or nil
    self.bestScore:SetText(best and number(best.score) and tostring(best.score) .. " points" or "No saved best yet")
    local metadata = {}
    local fields = self.resultGameID == "tetris" and { { "lines", "Lines" }, { "level", "Level" } }
        or (self.resultGameID == "bejeweled" or self.resultGameID == "bejeweled_deluxe") and {
            { "moves", "Moves" },
            { "cleared", "Gems" },
            { "bestCascade", "Cascade" },
        }
        or {}
    for _, field in ipairs(fields) do
        if best and number(best[field[1]]) then
            metadata[#metadata + 1] = field[2] .. ": " .. best[field[1]]
        end
    end
    self.bestMetadata:SetText(table.concat(metadata, " / "))
    local lines = {}
    for _, result in ipairs(selected and Games:GetResults(selected.id) or {}) do
        lines[#lines + 1] = (result.status == "aborted" and "Interrupted" or "Completed") .. " / round " .. result.run
        lines[#lines + 1] = result.summary
        if result.status == "aborted" then
            lines[#lines + 1] = "Reason: " .. result.reason .. (result.abortedBy and " / " .. result.abortedBy or "")
        end
        for _, entry in ipairs(result.entries) do
            lines[#lines + 1] = (entry.rank and "#" .. entry.rank .. "  " or "")
                .. entry.player
                .. (entry.score ~= nil and " / " .. tostring(entry.score) or "")
                .. (entry.outcome and " / " .. entry.outcome or "")
        end
        lines[#lines + 1] = " "
    end
    self.resultText:SetText(
        #lines > 0 and table.concat(lines, "\n")
            or "No saved matches for this game yet.\nYour completed and interrupted matches will appear here."
    )
    self.resultList:SetHeight(math.max(self.resultScroll:GetHeight(), self.resultText:GetStringHeight() + bestY + 190))
end
