local component = require("component")
local term = require("term")
local unicode = require("unicode")
local event = require("event")
--local fs = require("filesystem")
--local shell = require("shell")
local keyboard = require("keyboard")
local computer = require("computer")
--local serialization = require("serialization")
--local internet = require("internet")
local gpu = component.gpu

local ECSAPI = {}

----------------------------------------------------------------------------------------------------

ECSAPI.windowColors = {
	background = 0xeeeeee,
	usualText = 0x444444,
	subText = 0x888888,
	tab = 0xaaaaaa,
	title = 0xffffff,
	shadow = 0x444444,
}

ECSAPI.colors = {
	white = 0xffffff,
	orange = 0xF2B233,
	magenta = 0xE57FD8,
	lightBlue = 0x99B2F2,
	yellow = 0xDEDE6C,
	lime = 0x7FCC19,
	pink = 0xF2B2CC,
	gray = 0x4C4C4C,
	lightGray = 0x999999,
	cyan = 0x4C99B2,
	purple = 0xB266E5,
	blue = 0x3366CC,
	brown = 0x7F664C,
	green = 0x57A64E,
	red = 0xCC4C4C,
    black = 0x000000,
	["0"] = 0xffffff,
	["1"] = 0xF2B233,
	["2"] = 0xE57FD8,
	["3"] = 0x99B2F2,
	["4"] = 0xDEDE6C,
	["5"] = 0x7FCC19,
	["6"] = 0xF2B2CC,
	["7"] = 0x4C4C4C,
	["8"] = 0x999999,
	["9"] = 0x4C99B2,
	["a"] = 0xB266E5,
	["b"] = 0x3366CC,
	["c"] = 0x7F664C,
	["d"] = 0x57A64E,
	["e"] = 0xCC4C4C,
	["f"] = 0x000000
}

----------------------------------------------------------------------------------------------------


--КЛИКНУЛИ ЛИ В ЗОНУ
function ECSAPI.clickedAtArea(x,y,sx,sy,ex,ey)
  if (x >= sx) and (x <= ex) and (y >= sy) and (y <= ey) then return true end    
  return false
end

--Заливка всего экрана указанным цветом
function ECSAPI.clearScreen(color)
  if color then gpu.setBackground(color) end
  term.clear()
end

--Установка пикселя нужного цвета
function ECSAPI.setPixel(x,y,color)
  gpu.setBackground(color)
  gpu.set(x,y," ")
end

--Простая установка цветов в одну строку, ибо я ленивый
function ECSAPI.setColor(background, foreground)
	gpu.setBackground(background)
	gpu.setForeground(foreground)
end

--Цветной текст
function ECSAPI.colorText(x,y,textColor,text)
  gpu.setForeground(textColor)
  gpu.set(x,y,text)
end

--Цветной текст с жопкой!
function ECSAPI.colorTextWithBack(x,y,textColor,backColor,text)
  gpu.setForeground(textColor)
  gpu.setBackground(backColor)
  gpu.set(x,y,text)
end

--Инверсия цвета
function ECSAPI.invertColor(color)
  return 0xffffff - color
end

--Округление до опред. кол-ва знаков после запятой
function ECSAPI.round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

--Обычный квадрат указанного цвета
function ECSAPI.square(x,y,width,height,color)
  gpu.setBackground(color)
  gpu.fill(x,y,width,height," ")
end

--Юникодовская рамка
function ECSAPI.border(x, y, width, height, back, fore)
	local stringUp = "┌"..string.rep("─", width - 2).."┐"
	local stringDown = "└"..string.rep("─", width - 2).."┘"
	gpu.setForeground(fore)
	gpu.setBackground(back)
	gpu.set(x, y, stringUp)
	gpu.set(x, y + height - 1, stringDown)

	local yPos = 1
	for i = 1, (height - 2) do
		gpu.set(x, y + yPos, "│")
		gpu.set(x + width - 1, y + yPos, "│")
		yPos = yPos + 1
	end
end

--Юникодовский разделитель
function ECSAPI.separator(x, y, width, back, fore)
	ECSAPI.colorTextWithBack(x, y, fore, back, string.rep("─", width))
end

--Корректировка стартовых координат. Core-функция для всех моих программ
function ECSAPI.correctStartCoords(xStart,yStart,xWindowSize,yWindowSize)
	local xSize,ySize = gpu.getResolution()
	if xStart == "auto" then
		xStart = math.floor(xSize/2 - xWindowSize/2)
	end
	if yStart == "auto" then
		yStart = math.ceil(ySize/2 - yWindowSize/2)
	end
	return xStart,yStart
end

--Запомнить область пикселей и возвратить ее в виде массива
function ECSAPI.rememberOldPixels(x, y, x2, y2)
	local newPNGMassiv = { ["backgrounds"] = {} }
	newPNGMassiv.x, newPNGMassiv.y = x, y

	--Перебираем весь массив стандартного PNG-вида по высоте
	local xCounter, yCounter = 1, 1
	for j = y, y2 do
		xCounter = 1
		for i = x, x2 do
			local symbol, fore, back = gpu.get(i, j)

			newPNGMassiv["backgrounds"][back] = newPNGMassiv["backgrounds"][back] or {}
			newPNGMassiv["backgrounds"][back][fore] = newPNGMassiv["backgrounds"][back][fore] or {}

			table.insert(newPNGMassiv["backgrounds"][back][fore], {xCounter, yCounter, symbol} )

			xCounter = xCounter + 1
			back, fore, symbol = nil, nil, nil
		end

		yCounter = yCounter + 1
	end

	return newPNGMassiv
end

--Нарисовать запомненные ранее пиксели из массива
function ECSAPI.drawOldPixels(massivSudaPihay)
	--Перебираем массив с фонами
	for back, backValue in pairs(massivSudaPihay["backgrounds"]) do
		gpu.setBackground(back)
		for fore, foreValue in pairs(massivSudaPihay["backgrounds"][back]) do
			gpu.setForeground(fore)
			for pixel = 1, #massivSudaPihay["backgrounds"][back][fore] do
				if massivSudaPihay["backgrounds"][back][fore][pixel][3] ~= transparentSymbol then
					gpu.set(massivSudaPihay.x + massivSudaPihay["backgrounds"][back][fore][pixel][1] - 1, massivSudaPihay.y + massivSudaPihay["backgrounds"][back][fore][pixel][2] - 1, massivSudaPihay["backgrounds"][back][fore][pixel][3])
				end
			end
		end
	end
end

--Ограничение длины строки. Маст-хев функция.
function ECSAPI.stringLimit(mode, text, size, noDots)
	if unicode.len(text) <= size then return text end
	local length = unicode.len(text)
	if mode == "start" then
		if noDots then
			return unicode.sub(text, length - size + 1, -1)
		else
			return "…" .. unicode.sub(text, length - size + 2, -1)
		end
	else
		if noDots then
			return unicode.sub(text, 1, size)
		else
			return unicode.sub(text, 1, size - 1) .. "…"
		end
	end
end

--Ожидание клика либо нажатия какой-либо клавиши
function ECSAPI.waitForTouchOrClick()
	while true do
		local e = {event.pull()}
		if e[1] == "key_down" or e[1] == "touch" then break end
	end
end

--Функция отрисовки кнопки указанной ширины
function ECSAPI.drawButton(x,y,width,height,text,backColor,textColor)
	x,y = ECSAPI.correctStartCoords(x,y,width,height)

	local textPosX = math.floor(x + width / 2 - unicode.len(text) / 2)
	local textPosY = math.floor(y + height / 2)
	ECSAPI.square(x,y,width,height,backColor)
	ECSAPI.colorText(textPosX,textPosY,textColor,text)

	return x, y, (x + width - 1), (y + height - 1)
end

--Отрисовка кнопки с указанными отступами от текста
function ECSAPI.drawAdaptiveButton(x,y,offsetX,offsetY,text,backColor,textColor)
	local length = unicode.len(text)
	local width = offsetX*2 + length
	local height = offsetY*2 + 1

	x,y = ECSAPI.correctStartCoords(x,y,width,height)

	ECSAPI.square(x,y,width,height,backColor)
	ECSAPI.colorText(x+offsetX,y+offsetY,textColor,text)

	return x,y,(x+width-1),(y+height-1)
end

--Функция по переносу слов на новую строку в зависимости от ограничения по ширине
function ECSAPI.stringWrap(text, limit)
	--Получаем длину текста
	local sText = unicode.len(text)
	--Считаем количество строк, которое будет после парсинга
	local repeats = math.ceil(sText / limit)
	--Создаем массив этих строк
	local massiv = {}
	local counter
	--Парсим строки
	for i = 1, repeats do
		counter = i * limit - limit + 1
		table.insert(massiv, unicode.sub(text, counter, counter + limit - 1))
	end
	--Возвращаем массив строк
	return massiv
end

--Моя любимая функция ошибки C:
function ECSAPI.error(text)
	ECSAPI.universalWindow("auto", "auto", math.ceil(gpu.getResolution() * 0.45), ECSAPI.windowColors.background, true, {"EmptyLine"}, {"CenterText", 0x880000, "Ошибка!"}, {"EmptyLine"}, {"WrappedText", 0x262626, text}, {"EmptyLine"}, {"Button", {0x880000, 0xffffff, "OK!"}})
end

--Очистить экран, установить комфортные цвета и поставить курсок на 1, 1
function ECSAPI.prepareToExit(color1, color2)
	ECSAPI.clearScreen(color1 or 0x333333)
	gpu.setForeground(color2 or 0xffffff)
	gpu.set(1, 1, "")
end

--Конвертация из юникода в символ. Вроде норм, а вроде и не норм. Но полезно.
function ECSAPI.convertCodeToSymbol(code)
	local symbol
	if code ~= 0 and code ~= 13 and code ~= 8 and code ~= 9 and code ~= 200 and code ~= 208 and code ~= 203 and code ~= 205 and not keyboard.isControlDown() then
		symbol = unicode.char(code)
		if keyboard.isShiftPressed then symbol = unicode.upper(symbol) end
	end
	return symbol
end

--Функция для ввода текста в мини-поле.
function ECSAPI.inputText(x, y, limit, cheBiloVvedeno, background, foreground, justDrawNotEvent, maskTextWith)
	limit = limit or 10
	cheBiloVvedeno = cheBiloVvedeno or ""
	background = background or 0xffffff
	foreground = foreground or 0x000000

	gpu.setBackground(background)
	gpu.setForeground(foreground)
	gpu.fill(x, y, limit, 1, " ")

	local text = cheBiloVvedeno

	local function draw()
		term.setCursorBlink(false)

		local dlina = unicode.len(text)
		local xCursor = x + dlina
		if xCursor > (x + limit - 1) then xCursor = (x + limit - 1) end

		if maskTextWith then
			gpu.set(x, y, ECSAPI.stringLimit("start", string.rep("●", dlina), limit))
		else
			gpu.set(x, y, ECSAPI.stringLimit("start", text, limit))
		end

		term.setCursor(xCursor, y)

		term.setCursorBlink(true)
	end

	draw()

	if justDrawNotEvent then term.setCursorBlink(false); return cheBiloVvedeno end

	while true do
		local e = {event.pull()}
		if e[1] == "key_down" then
			if e[4] == 14 then
				term.setCursorBlink(false)
				text = unicode.sub(text, 1, -2)
				if unicode.len(text) < limit then gpu.set(x + unicode.len(text), y, " ") end
				draw()
			elseif e[4] == 28 then
				term.setCursorBlink(false)
				return text
			else
				local symbol = ECSAPI.convertCodeToSymbol(e[3])
				if symbol then
					text = text..symbol
					draw()
				end
			end
		elseif e[1] == "touch" then
			term.setCursorBlink(false)
			return text
		elseif e[1] == "clipboard" then
			if e[3] then
				text = text..e[3]
				draw()
			end
		end
	end
end

--Спросить, заменять ли файл (если таковой уже имеется)
function ECSAPI.askForReplaceFile(path)
	if fs.exists(path) then
		local action = ECSAPI.universalWindow("auto", "auto", 46, ECSAPI.windowColors.background, true, {"EmptyLine"}, {"CenterText", 0x262626, "Файл \"".. fs.name(path) .. "\" уже имеется в этом месте."}, {"CenterText", 0x262626, "Заменить его перемещаемым объектом?"}, {"EmptyLine"}, {"Button", {0xdddddd, 0x262626, "Оставить оба"}, {0xffffff, 0x262626, "Отмена"}, {ECSAPI.colors.lightBlue, 0xffffff, "Заменить"}})
		if action[1] == "Оставить оба" then
			return "keepBoth"
		elseif action[2] == "Отмена" then
			return "cancel"
		else
			return "replace"
		end
	end
end

--Вертикальный скроллбар. Маст-хев!
function ECSAPI.srollBar(x, y, width, height, countOfAllElements, currentElement, backColor, frontColor)
	local sizeOfScrollBar = math.ceil(1 / countOfAllElements * height)
	local displayBarFrom = math.floor(y + height * ((currentElement - 1) / countOfAllElements))

	ECSAPI.square(x, y, width, height, backColor)
	ECSAPI.square(x, displayBarFrom, width, sizeOfScrollBar, frontColor)

	sizeOfScrollBar, displayBarFrom = nil, nil
end

--Отрисовка поля с текстом. Сюда пихать массив вида {"строка1", "строка2", "строка3", ...}
function ECSAPI.textField(x, y, width, height, lines, displayFrom, background, foreground, scrollbarBackground, scrollbarForeground)
	x, y = ECSAPI.correctStartCoords(x, y, width, height)

	background = background or 0xffffff
	foreground = foreground or ECSAPI.windowColors.usualText

	local sLines = #lines
	local lineLimit = width - 3

	--Парсим строки
	local line = 1
	while lines[line] do
		local sLine = unicode.len(lines[line])
		if sLine > lineLimit then
			local part1, part2 = unicode.sub(lines[line], 1, lineLimit), unicode.sub(lines[line], lineLimit + 1, -1)
			lines[line] = part1
			table.insert(lines, line + 1, part2)
			part1, part2 = nil, nil
		end
		line = line + 1
		sLine = nil
	end
	line = nil

	ECSAPI.square(x, y, width - 1, height, background)
	ECSAPI.srollBar(x + width - 1, y, 1, height, sLines, displayFrom, scrollbarBackground, scrollbarForeground)

	gpu.setBackground(background)
	gpu.setForeground(foreground)
	local yPos = y
	for i = displayFrom, (displayFrom + height - 1) do
		if lines[i] then
			gpu.set(x + 1, yPos, lines[i])
			yPos = yPos + 1
		else
			break
		end
	end

	return sLines
end

---------------------------------------------ОКОШЕЧКИ------------------------------------------------------------


--Описание ниже, ебана. Ниже - это значит в самой жопе кода!
function ECSAPI.universalWindow(x, y, width, background, closeWindowAfter, ...)
	local objects = {...}
	local countOfObjects = #objects

	local pressedButton
	local pressedMultiButton

	--Задаем высотные константы для объектов
	local objectsHeights = {
		["button"] = 3,
		["centertext"] = 1,
		["emptyline"] = 1,
		["input"] = 3,
		["slider"] = 3,
		["select"] = 3,
		["selector"] = 3,
		["separator"] = 1,
		["switch"] = 1,
	}

	--Скорректировать ширину, если нужно
	local function correctWidth(newWidthForAnalyse)
		width = math.max(width, newWidthForAnalyse)
	end

	--Корректируем ширину
	for i = 1, countOfObjects do
		local objectType = string.lower(objects[i][1])
		
		if objectType == "centertext" then
			correctWidth(unicode.len(objects[i][3]) + 2)
		elseif objectType == "slider" then --!!!!!!!!!!!!!!!!!! ВОТ ТУТ НЕ ЗАБУДЬ ФИКСАНУТЬ
			correctWidth(unicode.len(objects[i][7]..tostring(objects[i][5].." ")) + 2)
		elseif objectType == "select" then
			for j = 4, #objects[i] do
				correctWidth(unicode.len(objects[i][j]) + 2)
			end
		--elseif objectType == "selector" then
			
		--elseif objectType == "separator" then
			
		elseif objectType == "textfield" then
			correctWidth(7)
		elseif objectType == "wrappedtext" then
			correctWidth(6)
		elseif objectType == "button" then
			--Корректируем ширину
			local widthOfButtons = 0
			local maxButton = 0
			for j = 2, #objects[i] do
				maxButton = math.max(maxButton, unicode.len(objects[i][j][3]) + 2)
			end
			widthOfButtons = maxButton * #objects[i]
			correctWidth(widthOfButtons)
		elseif objectType == "switch" then
			local dlina = unicode.len(objects[i][5]) + 2 + 10 + 4
			correctWidth(dlina)
		end
	end

	--Считаем высоту этой хуйни
	local height = 0
	for i = 1, countOfObjects do
		local objectType = string.lower(objects[i][1])
		if objectType == "select" then
			height = height + (objectsHeights[objectType] * (#objects[i] - 3))
		elseif objectType == "textfield" then
			height = height + objects[i][2]
		elseif objectType == "wrappedtext" then
			--Заранее парсим текст перенесенный
			objects[i].wrapped = ECSAPI.stringWrap(objects[i][3], width - 4)
			objects[i].height = #objects[i].wrapped
			height = height + objects[i].height
		else
			height = height + objectsHeights[objectType]
		end
	end

	--Коорректируем стартовые координаты
	x, y = ECSAPI.correctStartCoords(x, y, width, height)
	--Запоминаем инфу о том, что было нарисовано, если это необходимо
	local oldPixels, oldBackground, oldForeground
	if closeWindowAfter then
		oldBackground = gpu.getBackground()
		oldForeground = gpu.getForeground()
		oldPixels = ECSAPI.rememberOldPixels(x, y, x + width - 1, y + height - 1)
	end
	--Считаем все координаты объектов
	objects[1].y = y
	if countOfObjects > 1 then
		for i = 2, countOfObjects do
			local objectType = string.lower(objects[i - 1][1])
			if objectType == "select" then
				objects[i].y = objects[i - 1].y + (objectsHeights[objectType] * (#objects[i - 1] - 3))
			elseif objectType == "textfield" then
				objects[i].y = objects[i - 1].y + objects[i - 1][2]
			elseif objectType == "wrappedtext" then
				objects[i].y = objects[i - 1].y + objects[i - 1].height
			else
				objects[i].y = objects[i - 1].y + objectsHeights[objectType]
			end
		end
	end

	--Объекты для тача
	local obj = {}
	local function newObj(class, name, ...)
		obj[class] = obj[class] or {}
		obj[class][name] = {...}
	end

	--Отображение объекта по номеру
	local function displayObject(number, active)
		local objectType = string.lower(objects[number][1])
				
		if objectType == "centertext" then
			local xPos = x + math.floor(width / 2 - unicode.len(objects[number][3]) / 2)
			gpu.setForeground(objects[number][2])
			gpu.set(xPos, objects[number].y, objects[number][3])
		
		elseif objectType == "input" then

			if active then
				--Рамочка
				ECSAPI.border(x + 1, objects[number].y, width - 2, objectsHeights.input, background, objects[number][3])
				--Тестик
				objects[number][4] = ECSAPI.inputText(x + 3, objects[number].y + 1, width - 6, "", background, objects[number][3], false, objects[number][5])
			else
				--Рамочка
				ECSAPI.border(x + 1, objects[number].y, width - 2, objectsHeights.input, background, objects[number][2])
				--Текстик
				gpu.set(x + 3, objects[number].y + 1, ECSAPI.stringLimit("start", objects[number][4], width - 6))
				ECSAPI.inputText(x + 3, objects[number].y + 1, width - 6, objects[number][4], background, objects[number][2], true, objects[number][5])
			end

			newObj("Inputs", number, x + 1, objects[number].y, x + width - 2, objects[number].y + 2)

		elseif objectType == "slider" then
			local widthOfSlider = width - 2
			local xOfSlider = x + 1
			local yOfSlider = objects[number].y + 1
			local countOfSliderThings = objects[number][5] - objects[number][4]
			local showSliderValue= objects[number][7]

			local dolya = widthOfSlider / countOfSliderThings
			local position = math.floor(dolya * objects[number][6])
			--Костыль
			if (xOfSlider + position) > (xOfSlider + widthOfSlider - 1)	then position = widthOfSlider - 2 end

			--Две линии
			ECSAPI.separator(xOfSlider, yOfSlider, position, background, objects[number][3])
			ECSAPI.separator(xOfSlider + position, yOfSlider, widthOfSlider - position, background, objects[number][2])
			--Слудир
			ECSAPI.square(xOfSlider + position, yOfSlider, 2, 1, objects[number][3])

			--Текстик под слудиром
			if showSliderValue then
				local text = showSliderValue .. tostring(objects[number][6]) .. (objects[number][8] or "")
				local textPos = (xOfSlider + widthOfSlider / 2 - unicode.len(text) / 2)
				ECSAPI.square(x, yOfSlider + 1, width, 1, background)
				ECSAPI.colorText(textPos, yOfSlider + 1, objects[number][2], text)
			end

			newObj("Sliders", number, xOfSlider, yOfSlider, x + widthOfSlider, yOfSlider, dolya)

		elseif objectType == "select" then
			local usualColor = objects[number][2]
			local selectionColor = objects[number][3]

			objects[number].selectedData = objects[number].selectedData or 1

			local symbol = "✔"
			local yPos = objects[number].y
			for i = 4, #objects[number] do
				--Коробка для галочки
				ECSAPI.border(x + 1, yPos, 5, 3, background, usualColor)
				--Текст
				gpu.set(x + 7, yPos + 1, objects[number][i])
				--Галочка
				if objects[number].selectedData == (i - 3) then
					ECSAPI.colorText(x + 3, yPos + 1, selectionColor, symbol)
				else
					gpu.set(x + 3, yPos + 1, "  ")
				end

				obj["Selects"] = obj["Selects"] or {}
				obj["Selects"][number] = obj["Selects"][number] or {}
				obj["Selects"][number][i - 3] = { x + 1, yPos, x + width - 2, yPos + 2 }

				yPos = yPos + objectsHeights.select
			end

		elseif objectType == "selector" then
			local borderColor = objects[number][2]
			local arrowColor = objects[number][3]
			local selectorWidth = width - 2
			objects[number].selectedElement = objects[number].selectedElement or objects[number][4]

			local topLine = "┌" .. string.rep("─", selectorWidth - 6) .. "┬───┐"
			local midLine = "│" .. string.rep(" ", selectorWidth - 6) .. "│   │"
			local botLine = "└" .. string.rep("─", selectorWidth - 6) .. "┴───┘"

			local yPos = objects[number].y

			local function bordak(borderColor)
				gpu.setBackground(background)
				gpu.setForeground(borderColor)
				gpu.set(x + 1, objects[number].y, topLine)
				gpu.set(x + 1, objects[number].y + 1, midLine)
				gpu.set(x + 1, objects[number].y + 2, botLine)
				gpu.set(x + 3, objects[number].y + 1, ECSAPI.stringLimit("start", objects[number].selectedElement, width - 6))
				ECSAPI.colorText(x + width - 4, objects[number].y + 1, arrowColor, "▼")
			end

			bordak(borderColor)
		
			--Выпадающий список, самый гемор, блядь
			if active then
				local xPos, yPos = x + 1, objects[number].y + 3
				local spisokWidth = width - 2
				local countOfElements = #objects[number] - 3
				local spisokHeight = countOfElements + 1
				local oldPixels = ECSAPI.rememberOldPixels( xPos, yPos, xPos + spisokWidth - 1, yPos + spisokHeight - 1)

				local coords = {}

				bordak(arrowColor)

				--Рамку рисуем поверх фоника
				local topLine = "├"..string.rep("─", spisokWidth - 6).."┴───┤"
				local midLine = "│"..string.rep(" ", spisokWidth - 2).."│"
				local botLine = "└"..string.rep("─", selectorWidth - 2) .. "┘"
				ECSAPI.colorTextWithBack(xPos, yPos - 1, arrowColor, background, topLine)
				for i = 1, spisokHeight - 1 do
					gpu.set(xPos, yPos + i - 1, midLine)
				end
				gpu.set(xPos, yPos + spisokHeight - 1, botLine)

				--Элементы рисуем
				xPos = xPos + 2
				for i = 1, countOfElements do
					ECSAPI.colorText(xPos, yPos, 0x000000, ECSAPI.stringLimit("start", objects[number][i + 3], spisokWidth - 4))
					coords[i] = {xPos - 1, yPos, xPos + spisokWidth - 4, yPos}
					yPos = yPos + 1
				end

				--Обработка
				local exit
				while true do
					if exit then break end
					local e = {event.pull()}
					if e[1] == "touch" then
						for i = 1, #coords do
							if ECSAPI.clickedAtArea(e[3], e[4], coords[i][1], coords[i][2], coords[i][3], coords[i][4]) then
								ECSAPI.square(coords[i][1], coords[i][2], spisokWidth - 2, 1, ECSAPI.colors.blue)
								ECSAPI.colorText(coords[i][1] + 1, coords[i][2], 0xffffff, objects[number][i + 3])
								os.sleep(0.3)
								objects[number].selectedElement = objects[number][i + 3]
								exit = true
								break
							end
						end
					end
				end

				ECSAPI.drawOldPixels(oldPixels)
			end

			newObj("Selectors", number, x + 1, objects[number].y, x + width - 2, objects[number].y + 2)

		elseif objectType == "separator" then
			ECSAPI.separator(x, objects[number].y, width, background, objects[number][2])
		
		elseif objectType == "textfield" then
			newObj("TextFields", number, x + 1, objects[number].y, x + width - 2, objects[number].y + objects[number][2] - 1)
			if not objects[number].strings then objects[number].strings = ECSAPI.stringWrap(objects[number][7], width - 5) end
			objects[number].displayFrom = objects[number].displayFrom or 1
			ECSAPI.textField(x + 1, objects[number].y, width - 2, objects[number][2], objects[number].strings, objects[number].displayFrom, objects[number][3], objects[number][4], objects[number][5], objects[number][6])
		
		elseif objectType == "wrappedtext" then
			gpu.setBackground(background)
			gpu.setForeground(objects[number][2])
			for i = 1, #objects[number].wrapped do
				gpu.set(x + 2, objects[number].y + i - 1, objects[number].wrapped[i])
			end

		elseif objectType == "button" then

			obj["MultiButtons"] = obj["MultiButtons"] or {}
			obj["MultiButtons"][number] = {}

			local widthOfButton = math.floor(width / (#objects[number] - 1))

			local xPos, yPos = x, objects[number].y
			for i = 1, #objects[number] do
				if type(objects[number][i]) == "table" then
					local x1, y1, x2, y2 = ECSAPI.drawButton(xPos, yPos, widthOfButton, 3, objects[number][i][3], objects[number][i][1], objects[number][i][2])
					table.insert(obj["MultiButtons"][number], {x1, y1, x2, y2, widthOfButton})
					xPos = x2 + 1

					if i == #objects[number] then
						ECSAPI.square(xPos, yPos, x + width - xPos, 3, objects[number][i][1])
						obj["MultiButtons"][number][i - 1][5] = obj["MultiButtons"][number][i - 1][5] + x + width - xPos
					end

					x1, y1, x2, y2 = nil, nil, nil, nil
				end
			end

		elseif objectType == "switch" then

			local xPos, yPos = x + 2, objects[number].y
			local activeColor, passiveColor, textColor, text, state = objects[number][2], objects[number][3], objects[number][4], objects[number][5], objects[number][6]
			local switchWidth = 10
			ECSAPI.colorTextWithBack(xPos, yPos, textColor, background, text)

			xPos = x + width - switchWidth - 2
			if state then
				ECSAPI.square(xPos, yPos, switchWidth, 1, activeColor)
				ECSAPI.square(xPos + switchWidth - 2, yPos, 2, 1, passiveColor)
				ECSAPI.colorTextWithBack(xPos + 4, yPos, passiveColor, activeColor, "ON")
			else
				ECSAPI.square(xPos, yPos, switchWidth, 1, passiveColor - 0x444444)
				ECSAPI.square(xPos, yPos, 2, 1, passiveColor)
				ECSAPI.colorTextWithBack(xPos + 4, yPos, passiveColor, passiveColor - 0x444444, "OFF")
			end
			newObj("Switches", number, xPos, yPos, xPos + switchWidth - 1, yPos)
		end
	end

	--Отображение всех объектов
	local function displayAllObjects()
		for i = 1, countOfObjects do
			displayObject(i)
		end
	end

	--Подготовить массив возвращаемый
	local function getReturn()
		local massiv = {}

		for i = 1, countOfObjects do
			local type = string.lower(objects[i][1])

			if type == "button" then
				table.insert(massiv, pressedButton)
			elseif type == "input" then
				table.insert(massiv, objects[i][4])
			elseif type == "select" then
				table.insert(massiv, objects[i][objects[i].selectedData + 3])
			elseif type == "selector" then
				table.insert(massiv, objects[i].selectedElement)
			elseif type == "slider" then
				table.insert(massiv, objects[i][6])
			elseif type == "switch" then
				table.insert(massiv, objects[i][6])
			else
				table.insert(massiv, nil)
			end
		end

		return massiv
	end

	local function redrawBeforeClose()
		if closeWindowAfter then
			ECSAPI.drawOldPixels(oldPixels)
			gpu.setBackground(oldBackground)
			gpu.setForeground(oldForeground)
		end
	end

	--Рисуем окно
	ECSAPI.square(x, y, width, height, background)
	displayAllObjects()

	while true do
		local e = {event.pull()}
		if e[1] == "touch" or e[1] == "drag" then

			--Анализируем клик на кнопки
			if obj["MultiButtons"] then
				for key in pairs(obj["MultiButtons"]) do
					for i = 1, #obj["MultiButtons"][key] do
						if ECSAPI.clickedAtArea(e[3], e[4], obj["MultiButtons"][key][i][1], obj["MultiButtons"][key][i][2], obj["MultiButtons"][key][i][3], obj["MultiButtons"][key][i][4]) then
							ECSAPI.drawButton(obj["MultiButtons"][key][i][1], obj["MultiButtons"][key][i][2], obj["MultiButtons"][key][i][5], 3, objects[key][i + 1][3], objects[key][i + 1][2], objects[key][i + 1][1])
							os.sleep(0.3)
							pressedButton = objects[key][i + 1][3]
							redrawBeforeClose()
							return getReturn()
						end
					end
				end
			end

			--А теперь клик на инпуты!
			if obj["Inputs"] then
				for key in pairs(obj["Inputs"]) do
					if ECSAPI.clickedAtArea(e[3], e[4], obj["Inputs"][key][1], obj["Inputs"][key][2], obj["Inputs"][key][3], obj["Inputs"][key][4]) then
						displayObject(key, true)
						displayObject(key)
						break
					end
				end
			end

			--А теперь галочковыбор!
			if obj["Selects"] then
				for key in pairs(obj["Selects"]) do
					for i in pairs(obj["Selects"][key]) do
						if ECSAPI.clickedAtArea(e[3], e[4], obj["Selects"][key][i][1], obj["Selects"][key][i][2], obj["Selects"][key][i][3], obj["Selects"][key][i][4]) then
							objects[key].selectedData = i
							displayObject(key)
							break
						end
					end
				end
			end

			--Хм, а вот и селектор подъехал!
			if obj["Selectors"] then
				for key in pairs(obj["Selectors"]) do
					if ECSAPI.clickedAtArea(e[3], e[4], obj["Selectors"][key][1], obj["Selectors"][key][2], obj["Selectors"][key][3], obj["Selectors"][key][4]) then
						displayObject(key, true)
						displayObject(key)
						break
					end
				end
			end

			--Слайдеры, епта! "Потный матан", все делы
			if obj["Sliders"] then
				for key in pairs(obj["Sliders"]) do
					if ECSAPI.clickedAtArea(e[3], e[4], obj["Sliders"][key][1], obj["Sliders"][key][2], obj["Sliders"][key][3], obj["Sliders"][key][4]) then
						local xOfSlider, dolya = obj["Sliders"][key][1], obj["Sliders"][key][5]
						local currentPixels = e[3] - xOfSlider
						local currentValue = math.floor(currentPixels / dolya)
						--Костыль
						if e[3] == obj["Sliders"][key][3] then currentValue = objects[key][5] end
						objects[key][6] = currentValue
						displayObject(key)
						break
					end
				end
			end

			if obj["Switches"] then
				for key in pairs(obj["Switches"]) do
					if ECSAPI.clickedAtArea(e[3], e[4], obj["Switches"][key][1], obj["Switches"][key][2], obj["Switches"][key][3], obj["Switches"][key][4]) then
						objects[key][6] = not objects[key][6]
						displayObject(key)
						break
					end
				end
			end

		elseif e[1] == "scroll" then
			if obj["TextFields"] then
				for key in pairs(obj["TextFields"]) do
					if ECSAPI.clickedAtArea(e[3], e[4], obj["TextFields"][key][1], obj["TextFields"][key][2], obj["TextFields"][key][3], obj["TextFields"][key][4]) then
						if e[5] == 1 then
							if objects[key].displayFrom > 1 then objects[key].displayFrom = objects[key].displayFrom - 1; displayObject(key) end
						else
							if objects[key].displayFrom < #objects[key].strings then objects[key].displayFrom = objects[key].displayFrom + 1; displayObject(key) end
						end
					end
				end
			end
		elseif e[1] == "key_down" then
			if e[4] == 28 then
				redrawBeforeClose()
				return getReturn()
			end
		end
	end
end

--Демонстрационное окно, показывающее всю мощь universalWindow
function ECSAPI.demoWindow()
	--Очищаем экран перед юзанием окна и ставим курсор на 1, 1
	ECSAPI.prepareToExit()
	--Рисуем окно и получаем данные после взаимодействия с ним
	local data = ECSAPI.universalWindow("auto", "auto", 36, 0xeeeeee, true, {"EmptyLine"}, {"CenterText", 0x880000, "Здорово, ебана!"}, {"EmptyLine"}, {"Input", 0x262626, 0x880000, "Сюда вводить можно"}, {"Selector", 0x262626, 0x880000, "Выбор формата", "PNG", "JPG", "GIF", "PSD"}, {"EmptyLine"}, {"WrappedText", 0x262626, "Тест автоматического переноса букв в зависимости от ширины данного окна. Пока что тупо режет на куски, не особо красиво."}, {"EmptyLine"}, {"Select", 0x262626, 0x880000, "Я пидор", "Я не пидор"}, {"Slider", 0x262626, 0x880000, 1, 100, 50, "Убито ", " младенцев"}, {"EmptyLine"}, {"Separator", 0xaaaaaa}, {"Switch", 0xF2B233, 0xffffff, 0x262626, "✈ Авиарежим", false}, {"EmptyLine"}, {"Switch", 0x3366CC, 0xffffff, 0x262626, "☾  Не беспокоить", true}, {"Separator", 0xaaaaaa},  {"EmptyLine"}, {"TextField", 5, 0xffffff, 0x262626, 0xcccccc, 0x3366CC, "Тест текстового информационного поля. По сути это тот же самый WrappedText, разве что эта хрень ограничена по высоте, и ее можно скроллить. Ну же, поскролль меня! Скролль меня полностью! Моя жадная пизда жаждет твой хуй!"}, {"EmptyLine"}, {"Button", {0x57A64E, 0xffffff, "Да"}, {0xF2B233, 0xffffff, "Нет"}, {0xCC4C4C, 0xffffff, "Отмена"}})
	--Еще разок
	ECSAPI.prepareToExit()
	--Выводим данные
	print(" ")
	print("Вывод данных из окна:")
	for i = 1, #data do print("["..i.."] = "..tostring(data[i])) end
	print(" ")
end

--[[
Функция universalWindow(x, y, width, background, closeWindowAfter, ...)

	Это универсальная модульная функция для максимально удобного и быстрого отображения
	необходимой вам информации. С ее помощью вводить данные с клавиатуры, осуществлять выбор
	из предложенных вариантов, рисовать красивые кнопки, отрисовывать обычный текст,
	отрисовывать текстовые поля с возможностью прокрутки, рисовать разделители и прочее.
	Любой объект выделяется с помощью клика мыши, после чего функция приступает к работе
	с этим объектом.
 
Аргументы функции:

	x и y: это числа, обозначающие стартовые координаты левого верхнего угла данного окна.
	Вместо цифр вы также можете написать "auto" - и программа автоматически разместит окно
	по центру экрана по выбранной координате. Или по обеим координатам, если вам угодно.
	 
	width: это ширина окна, которую вы можете задать по собственному желанию. Если некторые
	объекты требуют расширения окна, то окно будет автоматически расширено до нужной ширины.
	Да, вот такая вот тавтология ;)

	background: базовый цвет окна (цвет фона, кому как понятнее).

	closeWindowAfter: eсли true, то окно по завершению функции будет выгружено, а на его месте
	отрисуются пиксели, которые имелись на экране до выполнения функции. Удобно, если не хочешь
	париться с перерисовкой интерфейса.

	... : многоточием тут является перечень объектов, указанных через запятую. Каждый объект
	является массивом и имеет собственный формат. Ниже перечислены все возможные типы объектов.
		
		{"Button", {Цвет кнопки1, Цвет текста на кнопке1, Сам текст1}, {Цвет кнопки2, Цвет текста на кнопке2, Сам текст2}, ...}

			Это объект для рисования кнопок. Каждая кнопка - это массив, состоящий из трех элементов:
			цвета кнопки, цвета текста на кнопке и самого текста. Кнопок может быть неограниченное количество,
			однако чем их больше, тем большее требуется разрешение экрана по ширине.

			Интерактивный объект.

		{"Input", Цвет рамки и текста, Цвет при выделении, Стартовый текст [, Маскировать символом]}

			Объект для рисования полей ввода текстовой информации. Удобно для открытия или сохранения файлов,
			Опциональный аргумент "Маскировать символом" полезен, если вы делаете поле для ввода пароля.
			Никто не увидит ваш текст. В качестве данного аргумента передается символ, например "*".

			Интерактивный объект.

		{"Selector", Цвет рамки, Цвет при выделении, Выбор 1, Выбор 2, Выбор 3 ...}

			Внешне схож с объектом "Input", однако в этом случае вы будете выбирать один из предложенных
			вариантов из выпадающего списка. По умолчанию выбран первый вариант.

			Интерактивный объект.

		{"Select", Цвет рамки, Цвет галочки, Выбор 1, Выбор 2, Выбор 3 ...}

			Объект выбора. Отличается от "Selector" тем, что здесь вы выбираете один из вариантов, отмечая
			его галочкой. По умолчанию выбран первый вариант.

			Интерактивный объект. 

		{"Slider", Цвет линии слайдера, Цвет пимпочки слайдера, Значения слайдера ОТ, Значения слайдера ДО, Текущее значение [, Текст-подсказка ДО] [, Текст-подсказка ПОСЛЕ]}

			Ползунок, позволяющий задавать определенное количество чего-либо в указанном интервале. Имеются два
			опциональных аргумента, позволяющих четко понимать, с чем именно мы имеем дело.

			К примеру, если аргумент "Текст-подсказка ДО" будет равен "Съедено ", а аргумент "Текст-подсказка ПОСЛЕ"
			будет равен " яблок", а значение слайдера будет равно 50, то на экране будет написано "Съедено 50 яблок".

			Интерактивный объект.

		{"Switch", Активный цвет, Пассивный цвет, Цвет текста, Текст, Состояние}

			 Переключатель, принимающий два состояния: true или false. Текст - это всего лишь информация, некое
			 название данного переключателя.

			 Интерактивный объект.  

		{"CenterText", Цвет текста, Сам текст}

			Отображение текста указанного цвета по центру окна. Чисто для информативных целей.

		{"WrappedText", Цвет текста, Текст}

			Отображение большого количества текста с автоматическим переносом. Прото режет слова на кусочки,
			перенос символический. Чисто для информативных целей.
 
        {"TextField", Высота, Цвет фона, Цвет текста, Цвет скроллбара, Цвет пимпочки скроллбара, Сам текст}
 
        	Текстовое поле с возможностью прокрутки. Отличается от "WrappedText"
        	фиксированной высотой. Чисто для информативных целей.
   
        {"Separator", Цвет разделителя}
 
        	Линия-разделитель, помогающая лучше отделять объекты друг от друга. Декоративный объект.
 
		{"EmptyLine"}
 
        	Пустое пространство, помогающая лучше отделять объекты друг от друга. Декоративный объект.
 
		Каждый из объектов рисуется по порядку сверху вниз. Каждый объект автоматически
		увеличивает высоту окна до необходимого значения. Если объектов будет указано слишком много -
		т.е. если окно вылезет за пределы экрана, то программа завершится с ошибкой.

	Что возвращает функция:
		
		Возвратом является массив, пронумерованный от 1 до <количества объектов>.
		К примеру, 1 индекс данного массива соответствует 1 указанному объекту.
		Каждый индекс данного массива несет в себе какие-то данные, которые вы
		внесли в объект во время работы функции.
		Например, если в 1-ый объект типа "Input" вы ввели фразу "Hello world",
		то первый индекс в возвращенном массиве будет равен "Hello world".
		Конкретнее это будет вот так: massiv[1] = "Hello world".

		Если взаимодействие с объектом невозможно - например, как в случае
		с EmptyLine, CenterText, TextField или Separator, то в возвращенном
		массиве этот объект указываться не будет.

		Готовые примеры использования функции указаны ниже и закомментированы.
		Выбирайте нужный и раскомментируйте.
]]

--Функция-демонстратор, показывающая все возможные объекты в одном окне. Код окна находится выше.
--ECSAPI.demoWindow()

--Функция-отладчик, выдающая окно с указанным сообщением об ошибке. Полезна при дебаге.
--ECSAPI.error("Это сообщение об ошибке! Hello world!")

--Функция, спрашивающая, стоит ли заменять указанный файл, если он уже имеется
--ECSAPI.askForReplaceFile("OS.lua")

--Функция, предлагающая сохранить файл в нужном месте в нужном формате.
--ECSAPI.universalWindow("auto", "auto", 30, ECSAPI.windowColors.background, true, {"EmptyLine"}, {"CenterText", 0x262626, "Сохранить как"}, {"EmptyLine"}, {"Input", 0x262626, 0x880000, "Путь"}, {"Selector", 0x262626, 0x880000, "PNG", "JPG", "PSD"}, {"EmptyLine"}, {"Button", {0xbbbbbb, 0xffffff, "OK!"}})


----------------------------------------------------------------------------------------------------


return ECSAPI

