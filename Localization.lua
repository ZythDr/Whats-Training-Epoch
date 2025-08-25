--[[	File meta info
	@file		Localization.lua
	@brief		Localization strings, translations and client locale check
--]]

--[[
	@brief		Accessing the addons private table

	@var 	_		addonName, thrown away
	@var	wt		Global addonTable
--]]
local _, wt = ...

--	Table of localized strings
local localeText = {
	enUS = {
		AVAILABLE_HEADER =		"Available Now",
		MISSINGREQS_HEADER =	"Available but Missing Requirements",
		NEXTLEVEL_HEADER =		"Coming Soon",
		NOTLEVEL_HEADER =		"Not Yet Available",
		MISSINGTALENT_HEADER =	"Missing Required Talents",
		KNOWN_HEADER =			"Already Known",
		COST_FORMAT =			"Cost: %s",
		TOTALCOST_FORMAT =		"Total Cost: %s",
		TOTALSAVINGS_FORMAT =	"Total Savings: %s",
		LEVEL_FORMAT =			"Level %s",
		TAB_TEXT =				"What can I train?",
		NO_DATA_TITLE =         "No data yet",
		NO_DATA_BODY =          "Visit class trainer to populate list",
	},
	frFR = {
		AVAILABLE_HEADER =		"Disponible",
		MISSINGREQS_HEADER =	"Disponible mais pré-requis manquants",
		NEXTLEVEL_HEADER =		"Bientôt disponible",
		NOTLEVEL_HEADER =		"Pas encore disponible",
		MISSINGTALENT_HEADER =	"Talents requis manquants",
		KNOWN_HEADER =			"Déjà connu",
		COST_FORMAT =			"Coût : %s",
		TOTALCOST_FORMAT =		"Coût total : %s",
		TOTALSAVINGS_FORMAT =	"Coût économisé : %s",
		LEVEL_FORMAT =			"Niveau %s",
		TAB_TEXT =				"Que puis-je apprendre ?",
		NO_DATA_TITLE =         "No data yet",
		NO_DATA_BODY =          "Visit class trainer to populate list",
	},
	ruRU = {
		AVAILABLE_HEADER =		"Доступен сейчас",
		MISSINGREQS_HEADER =	"Доступно, но отсутствуют требования",
		NEXTLEVEL_HEADER =		"Скоро будет",
		NOTLEVEL_HEADER =		"Пока недоступно",
		MISSINGTALENT_HEADER =	"Отсутствующие необходимые таланты",
		KNOWN_HEADER =			"Уже известно",
		COST_FORMAT =			"Стоимость: %s",
		TOTALCOST_FORMAT =		"Общая стоимость: %s",
		TOTALSAVINGS_FORMAT =	"Все сбережения: %s",
		LEVEL_FORMAT =			"Уровень %s",
		TAB_TEXT =				"Что я могу изучить?",
		NO_DATA_TITLE =         "No data yet",
		NO_DATA_BODY =          "Visit class trainer to populate list",
	},
	zhCN = {
		AVAILABLE_HEADER =		"可学",
		MISSINGREQS_HEADER =	"满足条件方可学习",
		NEXTLEVEL_HEADER =		"即将学习",
		NOTLEVEL_HEADER =		"等级不够",
		MISSINGTALENT_HEADER =	"缺少相关天赋",
		KNOWN_HEADER =			"已学技能",
		COST_FORMAT =			"花费: %s",
		TOTALCOST_FORMAT =		"总花费: %s",
		TOTALSAVINGS_FORMAT =	"总共节省: %s",
		LEVEL_FORMAT =			"等级 %s",
		TAB_TEXT =				"我能学什么技能?",
		NO_DATA_TITLE =         "No data yet",
		NO_DATA_BODY =          "Visit class trainer to populate list",
	},
	zhTW = {
		AVAILABLE_HEADER =		"現在可以訓練",
		MISSINGREQS_HEADER =	"可以訓練但是缺少需求條件",
		NEXTLEVEL_HEADER =		"即將可以訓練",
		NOTLEVEL_HEADER =		"還不可以訓練",
		MISSINGTALENT_HEADER =	"缺少需要的天賦",
		KNOWN_HEADER =			"已學會",
		COST_FORMAT =			"花費: %s",
		TOTALCOST_FORMAT =		"總需花費: %s",
		TOTALSAVINGS_FORMAT =	"總共省下: %s",
		LEVEL_FORMAT =			"等級 %s",
		TAB_TEXT =				"我可以接受什麼訓練?",
		NO_DATA_TITLE =         "No data yet",
		NO_DATA_BODY =          "Visit class trainer to populate list",
	},
	deDE = {
		AVAILABLE_HEADER =		"Jetzt verfügbar",
		MISSINGREQS_HEADER =	"Verfügbar, aber fehlende Anforderungen",
		NEXTLEVEL_HEADER =		"Demnächst",
		NOTLEVEL_HEADER =		"Noch nicht verfügbar",
		MISSINGTALENT_HEADER =	"Fehlende Talente",
		KNOWN_HEADER =			"Bereits bekannt",
		COST_FORMAT =			"Kosten: %s",
		TOTALCOST_FORMAT =		"Gesamtkosten: %s",
		TOTALSAVINGS_FORMAT =	"Gesamtersparnis: %s",
		LEVEL_FORMAT =			"Level %s",
		TAB_TEXT =				"Was kann ich Lernen?",
		NO_DATA_TITLE =         "No data yet",
		NO_DATA_BODY =          "Visit class trainer to populate list",
	},
	koKR = {
		AVAILABLE_HEADER =		"지금 사용 가능",
		MISSINGREQS_HEADER =	"사용 가능하지만 누락된 요구 사항",
		NEXTLEVEL_HEADER =		"곧 사용 가능",
		NOTLEVEL_HEADER =		"아직 사용 불가",
		MISSINGTALENT_HEADER =	"필수 특성 누락",
		KNOWN_HEADER =			"이미 배움",
		COST_FORMAT =			"비용: %s",
		TOTALCOST_FORMAT =		"총 비용: %s",
		TOTALSAVINGS_FORMAT =	"총 절감: %s",
		LEVEL_FORMAT =			"레벨 %s",
		TAB_TEXT =				"무엇을 훈련할 수 있나요?",
		NO_DATA_TITLE =         "No data yet",
		NO_DATA_BODY =          "Visit class trainer to populate list",
	}
}

--	Set "enUS" as default locale
wt.L = localeText["enUS"]

--	Get current locale from game client
local locale = GetLocale()

--	Check if locale is enUS, enGB or missing
if (locale == "enUS" or locale == "enGB" or localeText[locale] == nil) then
	return
end

--	Apply localization
for k, v in pairs(localeText[locale]) do
	wt.L[k] = v
end