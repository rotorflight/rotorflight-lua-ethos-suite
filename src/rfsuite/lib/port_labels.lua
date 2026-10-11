-- Port labels per Rotorflight reference design, for the Ports page.
--
-- Keys: boardDesign as reported by MSP_BOARD_INFO (e.g. "F7B5" for VANTAC_RF007).
-- Inner keys: UART index as used by MSP_SERIAL_CONFIG identifiers (0 = UART1).
-- Values: the silkscreen name the Rotorflight Configurator shows for that port.
--
-- The data is copied unchanged from rotorflight-configurator
-- (src/tabs/configuration/util.js, PORT_NAMES_RF2, commit c08ce74).
-- The circled letters of the Configurator (Ⓐ Ⓑ Ⓒ Ⓔ Ⓖ Ⓓ) are replaced by plain
-- letters: the Ethos font has no glyphs for them and draws a gap instead.
-- That repository is licensed under GNU GPL v3.0. Edit this table to adjust
-- labels; lookup() below is the only code and needs no change for that.

local port_labels = {}

local DESIGNS = {
  F7A1 = {[0] = "DSM D", [1] = "S.BUS", [2] = "Port C", [3] = "Port A", [4] = "Port E", [5] = "Port B"},
  F7A2 = {[0] = "DSM D", [1] = "S.BUS", [2] = "Port G", [3] = "Port A", [4] = "Port E", [5] = "Port G"},
  F7A3 = {[0] = "DSM D", [1] = "S.BUS", [2] = "Port C", [3] = "Port A", [4] = "Int.Rx", [5] = "Port B"},
  F7A4 = {[0] = "DSM D", [1] = "S.BUS", [2] = "Port G", [3] = "Port A", [4] = "Int.Rx", [5] = "Port G"},
  F7B1 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port C", [3] = "Port A", [4] = "DSM D", [5] = "Port B"},
  F7B2 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port G", [3] = "Port A", [4] = "DSM D", [5] = "Port G"},
  F7B3 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port C", [3] = "Port A", [4] = "Port E", [5] = "Port B"},
  F7B4 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port G", [3] = "Port A", [4] = "Port E", [5] = "Port G"},
  F7B5 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port C", [3] = "Port A", [4] = "Int.Rx", [5] = "Port B"},
  F7B6 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port G", [3] = "Port A", [4] = "Int.Rx", [5] = "Port G"},
  F7C1 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port C", [3] = "Port A", [4] = "DSM D", [5] = "Port B"},
  F7C2 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port G", [3] = "Port A", [4] = "DSM D", [5] = "Port G"},
  F7C3 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port C", [3] = "Port A", [4] = "Port E", [5] = "Port B"},
  F7C4 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port G", [3] = "Port A", [4] = "Port E", [5] = "Port G"},
  F7C5 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port C", [3] = "Port A", [4] = "Int.Rx", [5] = "Port B"},
  F7C6 = {[0] = "S.BUS", [1] = "TELEM", [2] = "Port G", [3] = "Port A", [4] = "Int.Rx", [5] = "Port G"},
}

local BY_NAME = {
  ["GOOSKY_F701"] = {[0] = "Int. ELRS", [1] = "SBUS/DSMX", [3] = "AUX", [4] = "TLM"},
}

port_labels.DESIGNS = DESIGNS
port_labels.BY_NAME = BY_NAME

-- Returns the silkscreen name for a UART index, or nil when there is none and the plain
-- UART name should be shown. A board_name listed in BY_NAME is answered from that entry
-- only, so a generic board_design can never pick up another board's labels.
function port_labels.lookup(boardDesign, identifier, boardName)
  local byName = boardName and BY_NAME[boardName]
  if byName then return byName[identifier] end
  local design = boardDesign and DESIGNS[boardDesign]
  return design and design[identifier] or nil
end

return port_labels
