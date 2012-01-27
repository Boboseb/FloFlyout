-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

if GetLocale() == "frFR" then

local L = FLOFLYOUT_L10N_STRINGS

L["USAGE"] = "FloFlyout utilisation :\n"..
             "/ffo addflyout : crée un nouveau regroupement\n"..
             "/ffo removeflyout <id regroupement> : supprime un regroupement\n"..
             "/ffo addspell <id regroupement> <id sort> : rajoute un sort à un regroupement\n"..
             "/ffo removespell <id regroupement> <pos sort> : supprime un sort d'un regroupement\n"..
             "/ffo bind <id action> <id regroupement> : affecte un regroupement à une action\n"..
             "/ffo unbind <id action> : libère une action"
L["CONFIRM_DELETE"] = "Voulez-vous vraiment supprimer le regroupement de sorts %s ?"
L["NEW_FLYOUT"] = "Nouveau\nregroupement"

end
