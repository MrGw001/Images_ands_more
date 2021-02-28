--       Hologram Editor v0.70
-- by NEO, Totoro (aka MoonlightOwl)
-- 10/14/2014, all right reserved =)

local unicode = require('unicode')
local event = require('event')
local term = require('term')
local fs = require('filesystem')
local com = require('component')
local gpu = com.gpu

--     Цвета     --
local color = {
  back = 0x000000,
  fore = 0xFFFFFF,
  info = 0x335555,
  error = 0xFF3333,
  help = 0x336600,
  gold = 0xFFCC33,
  gray = 0x080808,
  lightgray = 0x333333
}

--  Локализация  --
local loc = {
  FILE_REQUEST = 'Введите сюда имя файла',
  ERROR_CAPTION = 'Ошибка',
  WARNING_CAPTION = 'Внимание',
  DONE_CAPTION = 'Завершено',
  PROJECTOR_UNAVAILABLE_MESSAGE = 'Проектор не подключен!',
  SAVING_MESSAGE = 'Файл сохраняется...',
  SAVED_MESSAGE = 'Файл сохранен!',
  LOADING_MESSAGE = 'Файл загружается...',
  LOADED_MESSAGE = 'Файл загружен!',
  TOO_LOW_RESOLUTION_ERROR = '[ОШИБКА] Ваш монитор/видеокарта не поддерживает разрешение 80×25 или больше.',
  TOO_LOW_SCREEN_TIER_ERROR = '[ОШИБКА] Для использования уменьшенного интерфейса, необходим алмазный монитор.',
  FORMAT_READING_ERROR = 'Ошибка чтения формата!',
  FILE_NOT_FOUND_ERROR = 'Файл не найден!',
  CANNOT_OPEN_ERROR = 'Невозможно открыть файл!',
  CANNOT_SAVE_ERROR = 'Невозможно записать файл!',
  PALETTE_FRAME = 'Палитра',
  VIEWPORT_FRAME = 'Проекция',
  UTILS_FRAME = 'Управление',
  LAYER_LABEL = 'Уровень голограммы:',
  GHOST_LAYER_LABEL = 'Направляющий уровень:',
  PROGRAMMERS_LABEL = 'Программисты:',
  CONTACT_LABEL = 'Контакт:',
  EXIT_LABEL = "Выход: 'Q' или ",
  EXIT_BUTTON = 'Выход',
  REFRESH_BUTTON = 'Обновить',
  TOP_BUTTON = 'Сверху',
  FRONT_BUTTON = 'Спереди',
  SIDE_BUTTON = 'Сбоку',
  BELOW_BUTTON = 'Ниже',
  ABOVE_BUTTON = 'Выше',
  CLEAR_BUTTON = 'Очистить',
  FILL_BUTTON = 'Залить',
  TO_PROJECTOR = 'На проектор',
  SAVE_BUTTON = 'Сохранить',
  LOAD_BUTTON = 'Загрузить',
  NEW_FILE_BUTTON = 'Новый файл'
}
--      ***      --


-- Загружаем доп. оборудование
local function trytofind(name)
  if com.isAvailable(name) then
    return com.getPrimary(name)
  else
    return nil
  end
end

-- Программные константы --
local OLDWIDTH, OLDHEIGHT = gpu.getResolution()
local WIDTH, HEIGHT = gpu.maxResolution()
local FULLSIZE = true
local HOLOW, HOLOH = 48, 32        -- размеры голограммы
local TOP, FRONT, SIDE = 0, 1, 2   -- проекции
local MENUX = HOLOW*2+5            -- начало правой панели
local BUTTONW = 12                 -- ширина кнопок
local GRIDX, GRIDY = 3, 2

-- Переменные интерфейса --
local buttons = {}
local textboxes = {}
local repaint = false

-- Состояние программы --
local colortable = {}
local hexcolortable = {}
local darkhexcolors = {}
local brush = {color = 1, x = 8, cx = 8, moving = false}
local ghost_layer = 1
local ghost_layer_below = true
local layer = 1
local view = TOP
local running = true

-- Вспомогательные функции --
local function rgb2hex(r,g,b)
  return r*65536+g*256+b
end
local function setHexColor(n, r, g, b)
  local hexcolor = rgb2hex(r,g,b)
  hexcolortable[n] = hexcolor
  darkhexcolors[n] = bit32.rshift(bit32.band(hexcolor, 0xfefefe), 1)
end

-- ========================================= H O L O G R A P H I C S ========================================= --
local holo = {}
local function set(x, y, z, value)
  if holo[x] == nil then holo[x] = {} end
  if holo[x][y] == nil then holo[x][y] = {} end
  holo[x][y][z] = value
end
local function get(x, y, z)
  if holo[x] ~= nil and holo[x][y] ~= nil and holo[x][y][z] ~= nil then 
    return holo[x][y][z]
  else
    return 0
  end
end

local writer = {}
function writer:init(file)
  self.buffer = {}
  self.file = file
end
function writer:write(sym)
  table.insert(self.buffer, sym)
  if #self.buffer >= 4 then self:finalize() end
end
function writer:finalize()
  if #self.buffer > 0 then
    local byte = 0
    for i=4, 1, -1 do
      local x = self.buffer[i] or 0
      byte = byte * 4 + x
    end
    self.file:write(string.char(byte))
    self.buffer = {}
  end
end

local function toBinary(x)
  local data = {}
  while x > 0 do
    table.insert(data, x % 2)
    x = math.floor(x / 2)
  end
  return data
end

local function save(filename, compressed)
  -- сохраняем палитру
  local file = io.open(filename, 'wb')
  if file ~= nil then
    for i=1, 3 do
      for c=1, 3 do
        file:write(string.char(colortable[i][c]))
      end
    end
    writer:init(file)
    if compressed then
      local function put(symbol, length)
        if length > 0 then
          writer:write(symbol)
          local l = toBinary(length + 1)
          l[#l] = nil
          l[1] = l[1] + 2
          for i=#l, 1, -1 do writer:write(l[i]) end
        end
      end
      local len = 0
      local sym = -1
      -- сохраняем массив со сжатием данных
      for x=1, HOLOW do
        for y=1, HOLOH do
          for z=1, HOLOW do
            local a = get(x, y, z)
            if sym == a then  -- очередной символ последовательности
              len = len + 1
            else              -- первый символ новой последовательности
              put(sym, len)
              len = 1
              sym = a
            end
          end
        end
      end
      put(sym, len)  -- последняя последовательность
    else
      -- сохраняем массив без сжатия
      for x=1, HOLOW do
        for y=1, HOLOH do
          for z=1, HOLOW do
            writer:write(get(x, y, z))
          end
        end
      end
    end
    writer:finalize()
    file:close()
    return true
  else
    return false, filename..": "..loc.CANNOT_SAVE_ERROR
  end
end

local reader = {}
function reader:init(file)
  self.buffer = {}
  self.file = file
end
function reader:read()
  if #self.buffer == 0 then 
    if not self:fetch() then return nil end
  end
  -- вынимаем последний символ из буфера
  local sym = self.buffer[#self.buffer]
  self.buffer[#self.buffer] = nil
  return sym
end
function reader:fetch()
  self.buffer = {}
  local char = file:read(1)
  if char == nil then return false
  else
    local byte = string.byte(char)
    for i=0, 3 do
      local a = byte % 4
      byte = math.floor(byte / 4)
      self.buffer[4-i] = a   -- записываем байты в обратном порядке
    end
    return true
  end
end

local function load(filename, compressed)
  if fs.exists(filename) then
    file = io.open(filename, 'rb')
    if file ~= nil then
      -- загружаем палитру
      for i=1, 3 do
        for c=1, 3 do
          colortable[i][c] = string.byte(file:read(1))
        end
        setHexColor(i,colortable[i][1],
                      colortable[i][2],
                      colortable[i][3])
      end
      -- загружаем массив
      holo = {}
      reader:init(file)
      if compressed then          -- читаем сжатые данные
        local x, y, z = 1, 1, 1
        while true do
          local a = reader:read() -- читаем значение символа
          if a == nil then file:close(); return true end
          local len = 1
          while true do           -- читаем двоичное значение длины
            local b = reader:read()
            if b == nil then 
              file:close()
              if a == 0 then return true
              else return false, filename..": "..loc.FORMAT_READING_ERROR end
            end
            local fin = (b > 1)
            if fin then b = b-2 end
            len = bit32.lshift(len, 1)
            len = len + b
            if fin then break end
          end
          len = len - 1
          -- записываем последовательность
          for i=1, len do
            -- пишем воксель
            if a ~= 0 then set(x,y,z, a) end
            -- сдвигаем координаты
            z = z+1
            if z > HOLOW then
              y = y+1
              if y > HOLOH then
                x = x+1
                if x > HOLOW then file:close(); return true end
                y = 1
              end
              z = 1
            end  
          end
        end
      else                        -- читаем несжатые данные
        for x=1, HOLOW do
          for y=1, HOLOH do
            for z=1, HOLOW do
              local a = reader:read()
              if a ~= 0 and a ~= nil then 
                set(x,y,z, a)
              end
            end
          end
        end
      end
      file:close()
      return true
    else
      return false, filename..": "..loc.CANNOT_OPEN_ERROR
    end
  else
    return false, filename..": "..loc.FILE_NOT_FOUND_ERROR
  end
end


-- ============================================== B U T T O N S ============================================== --
local Button = {}
Button.__index = Button
function Button.new(func, x, y, text, fore, back, width, nu)
  self = setmetatable({}, Button)
 
  self.form = '[ '
  if width == nil then width = 0
    else width = (width - unicode.len(text))-4 end
  for i=1, math.floor(width/2) do
    self.form = self.form.. ' '
  end
  self.form = self.form..text
  for i=1, math.ceil(width/2) do
    self.form = self.form.. ' '
  end
  self.form = self.form..' ]'
 
  self.func = func
 
  self.x = math.floor(x); self.y = math.floor(y)
  self.fore = fore
  self.back = back
  self.visible = true

  self.notupdate = nu or false
 
  return self
end
function Button:draw(fore, back)
  if self.visible then
    local fore = fore or self.fore
    local back = back or self.back
    gpu.setForeground(fore)
    gpu.setBackground(back)
    gpu.set(self.x, self.y, self.form)
  end
end
function Button:click(x, y)
  if self.visible then
    if y == self.y then
      if x >= self.x and x < self.x+unicode.len(self.form) then
        self:draw(self.back, self.fore)
        local data = self.func()
        if not self.notupdate then self:draw() end
        return true, data
      end
    end
  end
  return false
end

local function buttonNew(buttons, func, x, y, text, fore, back, width, notupdate)
  local button = Button.new(func, x, y, text, fore, back, width, notupdate)
  table.insert(buttons, button)
  return button
end
local function buttonsDraw(buttons)
  for i=1, #buttons do
    buttons[i]:draw()
  end
end
local function buttonsClick(buttons, x, y)
  for i=1, #buttons do
    local ok, data = buttons[i]:click(x, y)
    if ok then return data end
  end
  return nil
end


-- ============================================ T E X T B O X E S ============================================ --
local Textbox = {}
Textbox.__index = Textbox
function Textbox.new(check, func, x, y, value, width)
  self = setmetatable({}, Textbox)

  self.form = '>'
  if width == nil then width = 10 end
  for i=1, width-1 do
    self.form = self.form..' '
  end

  self.check = check
  self.func = func
  self.value = tostring(value)

  self.x = math.floor(x); self.y = math.floor(y)
  self.width = width
  self.visible = true

  return self
end
function Textbox:draw(content)
  if self.visible then
    gpu.setBackground(color.lightgray) 
    gpu.setForeground(color.fore)
    gpu.set(self.x, self.y, self.form)
    if content then gpu.set(self.x+2, self.y, self.value) end
  end
end
function Textbox:click(x, y)
  if self.visible then
    if y == self.y then
      if x >= self.x and x < self.x+self.width then
        self:draw(false)
        term.setCursor(self.x+2, self.y)
        term.setCursorBlink(true)
        local value = self.value
        term.write(value)
        -- читаем данные
        while true do
          name, a, char, code = event.pull()
          if name == 'key_down' then
            if char > 30 then
              if unicode.len(value) < (self.width-3) then
                local letter = unicode.char(char)
                value = value .. letter
                term.write(letter)
              end
            else
              -- enter
              if code == 28 then
                -- проверяем корректность
                if self.check(value) then
                  -- вызываем функцию
                  self.value = value
                  self.func(value)
                end
                break
              -- backspace
              elseif code == 14 then
                if unicode.len(value) > 0 then
                  local x, y = term.getCursor()
                  gpu.set(x-1, y, ' ')
                  term.setCursor(x-1, y)
                  value = unicode.sub(value, 1, -2)
                end
              end
            end
          elseif name == 'touch' then
            break 
          end
        end
        --
        term.setCursorBlink(false)
        self:draw(true)
        gpu.setBackground(color.back)
        return true
      end
    end
  end
  return false
end
function Textbox:setValue(value)
  self.value = tostring(value)
end
function Textbox:getValue()
  return self.value
end
function Textbox:setVisible(flag)
  self.visible = flag
end
function Textbox:isVisible()
  return self.visible
end

local function textboxNew(textboxes, check, func, x, y, value, width)
  textbox = Textbox.new(check, func, x, y, value, width)
  table.insert(textboxes, textbox)
  return textbox
end 
local function textboxesDraw(textboxes)
  for i=1, #textboxes do
    textboxes[i]:draw(true)
  end
end
local function textboxesClick(textboxes, x, y)
  for i=1, #textboxes do
    textboxes[i]:click(x, y)
  end
end


-- ============================================= G R A P H I C S ============================================= --
local gridLine1, gridLine2, gridLine1s, gridLine2s = nil, nil, nil, nil
local strLine = "+"
local colorCursorY, colorCursorWidth = 8, 8
local function initGraphics()
  -- заготовки для сетки
  if FULLSIZE then gridLine1 = string.rep("██  ", HOLOW/2)
  else
    gridLine1 = string.rep("▀", HOLOW/2)
    gridLine2 = string.rep("▄", HOLOW/2)
    gridLine1s = string.rep("▀", HOLOH/2)
    gridLine2s = string.rep("▄", HOLOH/2)
  end
  -- заготовки для линий
  for i=1, WIDTH do
    strLine = strLine..'-'
  end
  -- параметры курсора палитры
  if not FULLSIZE then
    colorCursorY, colorCursorWidth = 1, 7
  end
end

-- рисуем линию
local function line(x1, x2, y)
  gpu.set(x1,y,string.sub(strLine, 1, x2-x1))
  gpu.set(x2,y,'+')
end

-- рисуем фрейм
local function frame(x1, y1, x2, y2, caption, nobottom)
  line(x1, x2, y1)
  if not nobottom then line(x1, x2, y2) end
  if caption ~= nil then
    gpu.set(x1 + math.ceil((x2-x1)/2) - math.ceil(unicode.len(caption)/2), y1, caption)
  end
end

-- рисуем сетку
local function drawGrid(x, y)
  gpu.setBackground(color.back)
  gpu.setForeground(color.gray)
  gpu.fill(0, y, MENUX, HOLOW, ' ')
  if FULLSIZE then
    for i=0, HOLOW-1 do
      if view ~= TOP and i == HOLOH then 
        gpu.setForeground(color.fore)
        line(1, MENUX-1, y+HOLOH)
        break
      end
      gpu.set(x + (i%2)*2, y + i, gridLine1)
    end
  else
    for i=0, HOLOW-1 do
      if view == TOP then
        if i%2==0 then gpu.set(x+i, y, gridLine1, true)
        else gpu.set(x+i, y, gridLine2, true) end
      else
        if i%2==0 then gpu.set(x+i, y, gridLine1s, true)
        else gpu.set(x+i, y, gridLine2s, true) end
      end
    end
  end
end

-- рисуем цветной прямоугольник
local function drawRect(x, y, fill)
  gpu.setForeground(color.fore)
  gpu.setBackground(color.gray)
  gpu.set(x, y,   "╓──────╖")
  gpu.set(x, y+1, "║      ║")
  gpu.set(x, y+2, "╙──────╜")
  gpu.setForeground(fill)
  gpu.set(x+2, y+1, "████")
end
local function drawSmallRect(x, y, fill)
  gpu.setForeground(color.fore)
  gpu.set(x, y,   "╓─────╖")
  gpu.set(x, y+1, "║     ║")
  gpu.set(x, y+2, "╙─────╜")
  gpu.setForeground(fill)
  gpu.set(x+2, y+1, "███")
end

-- рисуем меню выбора "кисти"
local function drawPaletteFrame()
  gpu.setForeground(color.fore)
  gpu.setBackground(color.back)
  if FULLSIZE then
    frame(MENUX, 3, WIDTH-2, 16, "[ "..loc.PALETTE_FRAME.." ]", true)
    for i=0, 3 do
      drawRect(MENUX+1+i*colorCursorWidth, 5, hexcolortable[i])
    end
    gpu.setForeground(0xFF0000); gpu.set(MENUX+1, 10, "R:")
    gpu.setForeground(0x00FF00); gpu.set(MENUX+1, 11, "G:")
    gpu.setForeground(0x0000FF); gpu.set(MENUX+1, 12, "B:")
  else
    for i=0, 3 do
      drawSmallRect(MENUX+1+i*colorCursorWidth, 2, hexcolortable[i])
    end
    gpu.setForeground(0xFF0000); gpu.set(MENUX+1, 5, "R:")
    gpu.setForeground(0x00FF00); gpu.set(MENUX+11, 5, "G:")
    gpu.setForeground(0x0000FF); gpu.set(MENUX+21, 5, "B:")
  end
end
-- рисуем и двигаем указатель кисти
local function drawColorCursor(force)
  if force or brush.moving then 
    gpu.setBackground(color.back)
    gpu.setForeground(color.fore)
    if FULLSIZE then gpu.set(MENUX+2+brush.cx, colorCursorY, "      ")
    else gpu.set(MENUX+2+brush.cx, colorCursorY, "-----") end
    
    if brush.moving then
      if brush.x ~= brush.color * colorCursorWidth then brush.x = brush.color*colorCursorWidth end
      if brush.cx < brush.x then brush.cx = brush.cx + 1
      elseif brush.cx > brush.x then brush.cx = brush.cx - 1
      else brush.moving = false end
    end
    
    if FULLSIZE then 
      gpu.setBackground(color.lightgray)
      gpu.set(MENUX+2+brush.cx, colorCursorY, ":^^^^:")
    else gpu.set(MENUX+2+brush.cx, colorCursorY, ":vvv:") end
  end
end
local function drawLayerFrame()
  gpu.setForeground(color.fore)
  gpu.setBackground(color.back)
  if FULLSIZE then
    frame(MENUX, 16, WIDTH-2, 28, "[ "..loc.VIEWPORT_FRAME.." ]", true)
    gpu.set(MENUX+13, 18, loc.LAYER_LABEL)
    gpu.set(MENUX+1, 23, loc.GHOST_LAYER_LABEL)
  else
    gpu.set(MENUX+1, 8, loc.LAYER_LABEL)
  end
end
local function drawUtilsFrame()
  gpu.setForeground(color.fore)
  gpu.setBackground(color.back)
  frame(MENUX, 28, WIDTH-2, 36, "[ "..loc.UTILS_FRAME.." ]")
end

local function mainScreen()
  gpu.setForeground(color.fore)
  gpu.setBackground(color.back)
  term.clear()
  frame(1,1, WIDTH, HEIGHT, "{ Hologram Editor }", not FULLSIZE)
  -- "холст"
  drawGrid(GRIDX, GRIDY)
  
  drawPaletteFrame()
  drawLayerFrame()
  drawUtilsFrame()
  
  drawColorCursor(true)
  buttonsDraw(buttons)
  textboxesDraw(textboxes)
  
  -- "about" - коротко о создателях
  if FULLSIZE then
    gpu.setForeground(color.info)
    gpu.setBackground(color.gray)
    gpu.set(MENUX+3, HEIGHT-11, " Hologram Editor v0.70 Beta  ")
    gpu.setForeground(color.fore)
    gpu.set(MENUX+3, HEIGHT-10, "            * * *            ")
    gpu.set(MENUX+3, HEIGHT-9,  " "..loc.PROGRAMMERS_LABEL..string.rep(' ', 28-unicode.len(loc.PROGRAMMERS_LABEL)))
    gpu.set(MENUX+3, HEIGHT-8,  "         NEO, Totoro         ")
    gpu.set(MENUX+3, HEIGHT-7,  "            * * *            ")
    gpu.set(MENUX+3, HEIGHT-6,  " "..loc.CONTACT_LABEL..string.rep(' ', 28-unicode.len(loc.CONTACT_LABEL)))
    gpu.set(MENUX+3, HEIGHT-5,  "       computercraft.ru      ")
    gpu.setForeground(color.fore)
    gpu.setBackground(color.back)
    gpu.set(MENUX+1, HEIGHT-2, loc.EXIT_LABEL)
  else
    gpu.setForeground(color.info)
    gpu.setBackground(color.gray)
    gpu.set(MENUX+1, HEIGHT-2,  "by Totoro © computercraft.ru")
    gpu.setForeground(color.fore)
    gpu.setBackground(color.back)
    gpu.set(MENUX+1, HEIGHT, loc.EXIT_LABEL)
  end
end


-- ============================================= M E S S A G E S ============================================= --
local function showMessage(text, caption, textcolor)
  local caption = '[ '..caption..' ]'
  local x = MENUX/2 - unicode.len(text)/2 - 4
  local y = HEIGHT/2 - 2
  gpu.setBackground(color.back)
  gpu.setForeground(color.fore)
  gpu.fill(x, y, unicode.len(text)+9, 5, ' ')
  frame(x, y, x+unicode.len(text)+8, y+4, caption)
  gpu.setForeground(textcolor)
  gpu.set(x+4,y+2, text)
  -- "холст" надо будет перерисовать
  repaint = true
end


-- =============================================== L A Y E R S =============================================== --
local function project(x, y, layer, view)
  if view == TOP then
    return x, layer, y
  elseif view == FRONT then
    return x, HOLOH-y+1, layer
  else
    return layer, HOLOH-y+1, x
  end
end
local function getVoxelColor(x, y, z, grid)
  local voxel = get(x, y, z)
  if voxel ~= 0 then return hexcolortable[voxel]
  elseif grid then return color.gray
  else return color.back end
end
local function drawVoxel(sx, sy, nogrid)
  if FULLSIZE then
    local voxel = get(project(sx, sy, layer, view))
    local dx = (GRIDX-2) + sx*2
    local dy = (GRIDY-1) + sy
    if voxel ~= 0 then
      gpu.setForeground(hexcolortable[voxel])
      gpu.set(dx, dy, "██")
    else  
      local ghost = get(gx, gy, gz)
      if ghost ~= 0 then
        gpu.setForeground(darkhexcolors[ghost])
        gpu.set(dx, dy, "░░")
      elseif not nogrid then
        if (sx+sy)%2 == 0 then gpu.setForeground(color.gray)
        else gpu.setForeground(color.back) end
        gpu.set(dx, dy, "██")
      end
    end
  else
    local sxUp, syUp = sx, sy
    if syUp%2 == 0 then syUp = syUp-1 end
    local sxDown, syDown = sxUp, syUp + 1
    local dx, dy = (GRIDX-1) + sxUp, (GRIDY-1) + math.ceil(syUp/2)
    local a, b, c = project(sxUp, syUp, layer, view)
    gpu.setForeground(getVoxelColor(a, b, c, ((sxUp+syUp)%2 == 0)))
    a, b, c = project(sxDown, syDown, layer, view)
    gpu.setBackground(getVoxelColor(a, b, c, ((sxDown+syDown)%2 == 0)))
    gpu.set(dx, dy, "▀")
  end
end

function drawLayer()
  drawGrid(GRIDX, GRIDY)
  local step, limit
  if FULLSIZE then step = 1 else step = 2 end
  if view == TOP then limit = HOLOW else limit = HOLOH end
  for x=1, HOLOW do
    for y=1, limit, step do drawVoxel(x, y, true) end
  end
  -- обновление экрана уже не требуется
  repaint = false
end
local function fillLayer()
  for x=1, HOLOW do
    for z=1, HOLOW do
      set(x, layer, z, brush.color)
    end
  end
  drawLayer()
end
local function clearLayer()
  for x=1, HOLOW do
    if holo[x] ~= nil then holo[x][layer] = nil end
  end
  drawLayer()
end


-- ==================================== G U I   F U N C T I O N A L I T Y ==================================== --
local function exit() running = false end

local function nextGhost()
  local limit = HOLOH
  if view ~= TOP then limit = HOLOW end
  
  if ghost_layer_below then
    ghost_layer_below = false
    if ghost_layer < limit then
      ghost_layer = layer + 1
    else ghost_layer = limit end
    drawLayer()
  else  
    if ghost_layer < limit then
      ghost_layer = ghost_layer + 1 
      drawLayer()
    end
  end
  tb_ghostlayer:setValue(''); tb_ghostlayer:draw()
end
local function prevGhost()
  if not ghost_layer_below then
    ghost_layer_below = true
    if layer > 1 then
      ghost_layer = layer - 1
    else ghost_layer = 1 end
    drawLayer()
  else
    if ghost_layer > 1 then
      ghost_layer = ghost_layer - 1
      drawLayer()
    end
  end
  tb_ghostlayer:setValue(''); tb_ghostlayer:draw()
end
local function setGhostLayer(value)
  local n = tonumber(value)
  local limit = HOLOH
  if view ~= TOP then limit = HOLOW end
  if n == nil or n < 1 or n > limit then return false end
  ghost_layer = n
  drawLayer()
  return true
end
local function moveGhost()
  if ghost_layer_below then
    if layer > 1 then ghost_layer = layer - 1
    else ghost_layer = 1 end
  else
    local limit = HOLOH
    if view ~= TOP then limit = HOLOW end
    if layer < limit then ghost_layer = layer + 1
    else ghost_layer = limit end
  end
end

local function nextLayer()
  -- ограничения разные для разных видов/проекций
  local limit = HOLOH
  if view ~= TOP then limit = HOLOW end

  if layer < limit then 
    layer = layer + 1
    tb_layer:setValue(layer)
    tb_layer:draw(true)
    moveGhost()
    drawLayer()
  end
end
local function prevLayer()
  if layer > 1 then 
    layer = layer - 1 
    tb_layer:setValue(layer)
    tb_layer:draw(true)
    moveGhost()
    drawLayer()
  end
end
local function setLayer(value)
  local n = tonumber(value)
  local limit = HOLOH
  if view ~= TOP then limit = HOLOW end
  if n == nil or n < 1 or n > limit then return false end
  layer = n
  moveGhost()
  drawLayer()
  tb_layer:setValue(layer)
  tb_layer:draw(true)
  return true
end

local function setFilename(str)
  if str ~= nil and str ~= '' and unicode.len(str)<30 then 
    return true
  else
    return false
  end
end

local function changeColor(rgb, value)
  if value == nil then return false end
  n = tonumber(value)
  if n == nil or n < 0 or n > 255 then return false end
  -- сохраняем данные в таблицу
  colortable[brush.color][rgb] = n
  setHexColor(brush.color, colortable[brush.color][1],
                           colortable[brush.color][2],
                           colortable[brush.color][3])
  -- обновляем цвета на панельке
  drawPaletteFrame()
  return true
end
local function changeRed(value) return changeColor(1, value) end
local function changeGreen(value) return changeColor(2, value) end
local function changeBlue(value) return changeColor(3, value) end

local function moveSelector(num)
  if num == 0 and brush.color ~= 0 then
    tb_red:setVisible(false)
    tb_green:setVisible(false)
    tb_blue:setVisible(false)
    gpu.setBackground(color.back)
    if FULLSIZE then
      gpu.fill(MENUX+3, 10, 45, 3, ' ')
    else
      gpu.set(MENUX+3, 5, '      ')
      gpu.set(MENUX+13, 5, '      ')
      gpu.set(MENUX+23, 5, '      ')
    end
  elseif num ~= 0 and brush.color == 0 then
    tb_red:setVisible(true); tb_red:draw(true)
    tb_green:setVisible(true); tb_green:draw(true)
    tb_blue:setVisible(true); tb_blue:draw(true)
  end
  brush.color = num
  brush.moving = true
  tb_red:setValue(colortable[num][1]); tb_red:draw(true)
  tb_green:setValue(colortable[num][2]); tb_green:draw(true)
  tb_blue:setValue(colortable[num][3]); tb_blue:draw(true)
end

local function setTopView(norefresh) 
  view = TOP 
  -- в виде сверху меньше слоев
  if layer > HOLOH then layer = HOLOH end
  if not norefresh then drawLayer() end
end
local function setFrontView() view = FRONT; drawLayer() end
local function setSideView() view = SIDE; drawLayer() end

local function drawHologram()
  -- проверка на наличие проектора
  local projector = trytofind('hologram')
  if projector ~= nil then
    local depth = projector.maxDepth()
    -- очищаем
    projector.clear()
    -- отправляем палитру
    if depth == 2 then
      for i=1, 3 do
        projector.setPaletteColor(i, hexcolortable[i])
      end
    else
      projector.setPaletteColor(1, hexcolortable[1])
    end
    -- отправляем массив
    for x=1, HOLOW do
      for y=1, HOLOH do
        for z=1, HOLOW do
          n = get(x,y,z)
          if n ~= 0 then
            if depth == 2 then
              projector.set(x,y,z,n)
            else
              projector.set(x,y,z,1)
            end
          end
        end
      end      
    end
  else
    showMessage(loc.PROJECTOR_UNAVAILABLE_MESSAGE, loc.ERROR_CAPTION, color.error)
  end
end

local function newHologram()
  holo = {}
  drawLayer()
end

local function saveHologram()
  local filename = tb_file:getValue()
  if filename ~= loc.FILE_REQUEST then
    -- выводим предупреждение
    showMessage(loc.SAVING_MESSAGE, loc.WARNING_CAPTION, color.gold)
    local compressed = true
    -- добавляем фирменное расширение =)
    if string.sub(filename, -3) == '.3d' then compressed = false
    elseif string.sub(filename, -4) ~= '.3dx' then
      filename = filename..'.3dx'
    end
    -- сохраняем
    local ok, message = save(filename, compressed)
    if ok then
      showMessage(loc.SAVED_MESSAGE, loc.DONE_CAPTION, color.gold)
    else
      showMessage(message, loc.ERROR_CAPTION, color.error)
    end
  end
end

local function loadHologram()
  local filename = tb_file:getValue()
  if filename ~= loc.FILE_REQUEST then
    -- выводим предупреждение
    showMessage(loc.LOADING_MESSAGE, loc.WARNING_CAPTION, color.gold)
    local compressed = nil
    -- добавляем фирменное расширение =)
    if string.sub(filename, -3) == '.3d' then compressed = false
    elseif string.sub(filename, -4) == '.3dx' then compressed = true end
    -- загружаем
    local ok, message = nil, nil
    if compressed ~= nil then
      ok, message = load(filename, compressed)
    else
      -- если расширение файла не было указано, пробуем по очереди оба варианта
      ok, message = load(filename..'.3dx', true)
      if not ok then
        ok, message = load(filename..'.3d', false)
      end
    end
    if ok then
      -- обновляем значения в текстбоксах
      tb_red:setValue(colortable[brush.color][1]); tb_red:draw(true)
      tb_green:setValue(colortable[brush.color][2]); tb_green:draw(true)
      tb_blue:setValue(colortable[brush.color][3]); tb_blue:draw(true)
      -- обновляем цвета на панельке
      drawPaletteFrame()
      -- сброс вьюпорта
      setTopView(true)
      setLayer(1)
    else
      showMessage(message, loc.ERROR_CAPTION, color.error)
    end
  end
end


-- =========================================== M A I N   C Y C L E =========================================== --
-- инициализация
-- проверка разрешения экрана; для комфортной работы необходима золотая или алмазная карта / монитор
if HEIGHT < HOLOW/2 then
  error(loc.TOO_LOW_RESOLUTION_ERROR)
elseif HEIGHT < HOLOW+2 then
  com.screen.setPrecise(true)
  if not com.screen.isPrecise() then error(loc.TOO_LOW_SCREEN_TIER) end
  FULLSIZE = false
  MENUX = HOLOW + 2
  color.gray = color.lightgray
  GRIDX = 1
  GRIDY = 2
  BUTTONW = 9
else
  com.screen.setPrecise(false)
  WIDTH = HOLOW*2 + 40
  HEIGHT = HOLOW + 2
end
gpu.setResolution(WIDTH, HEIGHT)
gpu.setForeground(color.fore)
gpu.setBackground(color.back)

-- установка дефолтной палитры
colortable = {{255, 0, 0}, {0, 255, 0}, {0, 102, 255}}
colortable[0] = {0, 0, 0}  -- стерка
for i=0, 3 do setHexColor(i, colortable[i][1], colortable[i][2], colortable[i][3]) end

initGraphics()

-- генерация интерфейса
if FULLSIZE then
  buttonNew(buttons, exit, WIDTH-BUTTONW-2, HEIGHT-2, loc.EXIT_BUTTON, color.back, color.error, BUTTONW)
  buttonNew(buttons, drawLayer, MENUX+11, 14, loc.REFRESH_BUTTON, color.back, color.gold, BUTTONW)
  buttonNew(buttons, prevLayer, MENUX+1, 19, '-', color.fore, color.info, 5)
  buttonNew(buttons, nextLayer, MENUX+7, 19, '+', color.fore, color.info, 5)
  buttonNew(buttons, setTopView, MENUX+1, 21, loc.TOP_BUTTON, color.fore, color.info, 10)
  buttonNew(buttons, setFrontView, MENUX+12, 21, loc.FRONT_BUTTON, color.fore, color.info, 10)
  buttonNew(buttons, setSideView, MENUX+24, 21, loc.SIDE_BUTTON, color.fore, color.info, 9)

  buttonNew(buttons, prevGhost, MENUX+1, 24, loc.BELOW_BUTTON, color.fore, color.info, 6)
  buttonNew(buttons, nextGhost, MENUX+10, 24, loc.ABOVE_BUTTON, color.fore, color.info, 6)

  buttonNew(buttons, clearLayer, MENUX+1, 26, loc.CLEAR_BUTTON, color.fore, color.info, BUTTONW)
  buttonNew(buttons, fillLayer, MENUX+2+BUTTONW, 26, loc.FILL_BUTTON, color.fore, color.info, BUTTONW)

  buttonNew(buttons, drawHologram, MENUX+9, 30, loc.TO_PROJECTOR, color.back, color.gold, 16)
  buttonNew(buttons, saveHologram, MENUX+1, 33, loc.SAVE_BUTTON, color.fore, color.help, BUTTONW)
  buttonNew(buttons, loadHologram, MENUX+8+BUTTONW, 33, loc.LOAD_BUTTON, color.fore, color.info, BUTTONW)
  buttonNew(buttons, newHologram, MENUX+1, 35, loc.NEW_FILE_BUTTON, color.fore, color.info, BUTTONW)
else
  buttonNew(buttons, exit, WIDTH-BUTTONW-1, HEIGHT, loc.EXIT_BUTTON, color.back, color.error, BUTTONW)
  buttonNew(buttons, drawLayer, MENUX+9, 6, loc.REFRESH_BUTTON, color.back, color.gold, BUTTONW)
  buttonNew(buttons, prevLayer, MENUX+1, 9, '-', color.fore, color.info, 5)
  buttonNew(buttons, nextLayer, MENUX+7, 9, '+', color.fore, color.info, 5)
  buttonNew(buttons, setTopView, MENUX+1, 11, loc.TOP_BUTTON, color.fore, color.info, 8)
  buttonNew(buttons, setFrontView, MENUX+10, 12, loc.FRONT_BUTTON, color.fore, color.info, 8)
  buttonNew(buttons, setSideView, MENUX+20, 13, loc.SIDE_BUTTON, color.fore, color.info, 8)

  buttonNew(buttons, clearLayer, MENUX+1, 15, loc.CLEAR_BUTTON, color.fore, color.info, BUTTONW)
  buttonNew(buttons, fillLayer, MENUX+14, 15, loc.FILL_BUTTON, color.fore, color.info, BUTTONW)

  buttonNew(buttons, drawHologram, MENUX+7, 17, loc.TO_PROJECTOR, color.back, color.gold, 16)
  buttonNew(buttons, saveHologram, MENUX+1, 20, loc.SAVE_BUTTON, color.fore, color.help, BUTTONW)
  buttonNew(buttons, loadHologram, MENUX+16, 20, loc.LOAD_BUTTON, color.fore, color.info, BUTTONW)
  buttonNew(buttons, newHologram, MENUX+1, 21, loc.NEW_FILE_BUTTON, color.fore, color.info, BUTTONW)
end

local function isNumber(value) if tonumber(value) ~= nil then return true else return false end end
local function correctLayer(value)
  local n = tonumber(value)
  if n~= nil then
    if view == TOP then
      if n > 0 and n <= HOLOH then return true end
    else
      if n > 0 and n <= HOLOW then return true end
    end
  end
  return false
end

tb_red, tb_green, tb_blue, tb_layer, tb_ghostlayer, tb_file = nil, nil, nil, nil, nil, nil
if FULLSIZE then
  tb_red = textboxNew(textboxes, isNumber, changeRed, MENUX+5, 10, '255', WIDTH-MENUX-7)
  tb_green = textboxNew(textboxes, isNumber, changeGreen, MENUX+5, 11, '0', WIDTH-MENUX-7)
  tb_blue = textboxNew(textboxes, isNumber, changeBlue, MENUX+5, 12, '0', WIDTH-MENUX-7)
  tb_layer = textboxNew(textboxes, correctLayer, setLayer, MENUX+13, 19, '1', WIDTH-MENUX-15)
  tb_ghostlayer = textboxNew(textboxes, correctLayer, setGhostLayer, MENUX+19, 24, '', WIDTH-MENUX-21)
  tb_file = textboxNew(textboxes, function() return true end, setFilename, MENUX+1, 32, loc.FILE_REQUEST, WIDTH-MENUX-3)
else
  tb_red = textboxNew(textboxes, isNumber, changeRed, MENUX+3, 5, '255', 6)
  tb_green = textboxNew(textboxes, isNumber, changeGreen, MENUX+13, 5, '0', 6)
  tb_blue = textboxNew(textboxes, isNumber, changeBlue, MENUX+23, 5, '0', 6)
  tb_layer = textboxNew(textboxes, correctLayer, setLayer, MENUX+13, 9, '1', WIDTH-MENUX-14)
  tb_file = textboxNew(textboxes, function() return true end, setFilename, MENUX+1, 19, loc.FILE_REQUEST, WIDTH-MENUX-2)
end

mainScreen()
moveSelector(1)

local function delay(active) if active then return 0.02 else return 2.0 end end

while running do
  local name, add, x, y, button = event.pull(delay(brush.moving))

  if name == 'key_down' then 
    -- если нажата 'Q' - выходим
    if y == 16 then break 
    elseif y == 41 then
      moveSelector(0)
    elseif y>=2 and y<=4 then
      moveSelector(y-1)
    elseif y == 211 then
      clearLayer()
    end
  elseif name == 'touch' or name == 'drag' then
  -- перерисуем, если на экране был мессейдж
    if repaint then drawLayer()
    else
      if name == 'touch' then
        -- проверка GUI
        buttonsClick(buttons, math.ceil(x), math.ceil(y))
        textboxesClick(textboxes, math.ceil(x), math.ceil(y))
        -- выбор цвета
        if x > MENUX+1 and x < MENUX+37 then
          if FULLSIZE then
            if y > 4 and y < 8 then
              moveSelector(math.floor((x-MENUX-1)/colorCursorWidth))
            end
          else
            if y > 1 and y < 4 and x < WIDTH-2 then
              moveSelector(math.floor((x-MENUX-1)/colorCursorWidth))
            end
          end
        end
      end
      
      -- "рисование"
      local limit
      if view == TOP then limit = HOLOW else limit = HOLOH end
      
      local dx, dy = nil, nil
      if FULLSIZE then
        if x >= GRIDX and x < GRIDX+HOLOW*2 then
          if y >= GRIDY and y < GRIDY+limit then
            dx, dy = math.floor((x-GRIDX)/2)+1, math.floor(y-GRIDY+1)
          end
        end
      else
        if x >= (GRIDX-1) and x <= GRIDX+HOLOW then
          if y >= (GRIDY-1) and y <= GRIDY+limit/2 then
            dx, dy = math.floor(x - GRIDX + 2), math.floor((y-GRIDY+1)*2)+1
          end
        end
      end
      if dx ~= nil then
        local a, b, c = project(dx, dy, layer, view)
        if button == 0 then set(a, b, c, brush.color)
        else set(a, b, c, 0) end
        drawVoxel(dx, dy)
      end
    end
  end

  drawColorCursor()
end

-- завершение
gpu.setResolution(OLDWIDTH, OLDHEIGHT)
gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
term.clear()