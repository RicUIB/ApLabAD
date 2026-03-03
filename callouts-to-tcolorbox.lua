-- callouts-to-tcolorbox_mathsafe.lua
-- PDF: Convierte callout-* a entornos tcolorbox (Definicion, Teorema, etc.)
-- Mantiene matemáticas en el título (Math), pero evita \par en el argumento
-- (causa del error "Paragraph ended before \pgfkeys@addpath...").
--
-- Estrategia:
--  - Construye el título a partir de INLINES:
--      * Math  -> se conserva tal cual con \(...\) (más seguro que $...$)
--      * Texto -> se escapa para LaTeX
--      * Espacios -> espacio normal
--  - Se ignoran saltos de párrafo: el título queda en UNA sola línea.

local map = {
  ["callout-definicion"]  = "Definicion",
  ["callout-teorema"]     = "Teorema",
  ["callout-proposicion"] = "Proposicion",
  ["callout-ejemplo"]     = "Ejemplo",
  ["callout-ejercicio"]   = "Ejercicio",
  ["callout-nota"]        = "Nota",
  ["callout-advertencia"] = "Advertencia",
  ["callout-curiosidad"]  = "Curiosidad",
}

local function has_class(el, cls)
  for _, c in ipairs(el.classes) do
    if c == cls then return true end
  end
  return false
end

local function esc_tex(s)
  if not s or s == "" then return "" end
  s = s:gsub("\\", "\\textbackslash{}")
  s = s:gsub("%%", "\\%%")
  s = s:gsub("#", "\\#")
  s = s:gsub("&", "\\&")
  s = s:gsub("_", "\\_")
  s = s:gsub("%^", "\\textasciicircum{}")
  s = s:gsub("~", "\\textasciitilde{}")
  s = s:gsub("{", "\\{")
  s = s:gsub("}", "\\}")
  return s
end

local function inlines_to_title(inlines)
  local out = {}
  for _, il in ipairs(inlines) do
    if il.t == "Str" then
      table.insert(out, esc_tex(il.text))
    elseif il.t == "Space" or il.t == "SoftBreak" or il.t == "LineBreak" then
      table.insert(out, " ")
    elseif il.t == "Math" then
      -- Usamos \(...\) para inline math: no introduce \par ni problemas con $
      table.insert(out, "\\(" .. il.text .. "\\)")
    elseif il.t == "Code" then
      table.insert(out, "\\texttt{" .. esc_tex(il.text) .. "}")
    elseif il.t == "Emph" or il.t == "Strong" or il.t == "SmallCaps" or il.t == "Span" then
      -- Convertimos a texto conservando contenido; si quieres estilos en título, se puede ampliar
      table.insert(out, esc_tex(pandoc.utils.stringify(il)))
    else
      table.insert(out, esc_tex(pandoc.utils.stringify(il)))
    end
  end

  local title = table.concat(out)
  title = title:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return title
end

local function extract_title_inlines(title_div)
  if not title_div then return pandoc.List() end
  local inlines = pandoc.List()
  for _, b in ipairs(title_div.content) do
    if b.t == "Para" or b.t == "Plain" then
      for _, il in ipairs(b.content) do inlines:insert(il) end
      inlines:insert(pandoc.Space())
    else
      local s = pandoc.utils.stringify(b)
      if s and s ~= "" then
        inlines:insert(pandoc.Str(s))
        inlines:insert(pandoc.Space())
      end
    end
  end
  if #inlines > 0 and inlines[#inlines].t == "Space" then inlines:remove(#inlines) end
  return inlines
end

function Div(el)
  if not FORMAT:match("latex") then return nil end

  local env = nil
  for cls, e in pairs(map) do
    if has_class(el, cls) then env = e; break end
  end
  if not env then return nil end

  local title_div = nil
  local body_blocks = {}

  for _, b in ipairs(el.content) do
    if b.t == "Div" and has_class(b, "callout-title") then
      title_div = b
    elseif b.t == "Div" and (has_class(b, "callout-body") or has_class(b, "callout-content")) then
      for _, bb in ipairs(b.content) do table.insert(body_blocks, bb) end
    else
      table.insert(body_blocks, b)
    end
  end

  local title_inlines = extract_title_inlines(title_div)
  local title = inlines_to_title(title_inlines)

  local begin_env = pandoc.RawBlock("latex", "\\begin{"..env.."}{"..title.."}{}")
  local end_env   = pandoc.RawBlock("latex", "\\end{"..env.."}")

  local out = { begin_env }
  for _, bb in ipairs(body_blocks) do table.insert(out, bb) end
  table.insert(out, end_env)
  return out
end
