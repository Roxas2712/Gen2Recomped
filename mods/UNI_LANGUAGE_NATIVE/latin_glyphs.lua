-- International GBA Latin characters (matching the original font indices).
-- Used only inside the synchronous decoder, then restored by translate.lua.
local glyphs = {
 [0x01]='À',[0x02]='Á',[0x03]='Â',[0x04]='Ç',[0x05]='È',
 [0x07]='Ê',[0x08]='Ë',[0x09]='Ì',[0x0B]='Î',[0x0C]='Ï',
 [0x0D]='Ò',[0x0E]='Ó',[0x0F]='Ô',[0x10]='Œ',[0x11]='Ù',
 [0x12]='Ú',[0x13]='Û',[0x14]='Ñ',[0x15]='ß',[0x16]='à',
 [0x17]='á',[0x19]='ç',[0x1A]='è',[0x1C]='ê',[0x1D]='ë',
 [0x1E]='ì',[0x20]='î',[0x21]='ï',[0x22]='ò',[0x23]='ó',
 [0x24]='ô',[0x25]='œ',[0x26]='ù',[0x27]='ú',[0x28]='û',
 [0x29]='ñ',[0x2A]='º',[0x2B]='ª',[0x51]='¿',[0x52]='¡',
 [0x5A]='Í',[0x68]='â',[0x6F]='í',
 [0xF1]='Ä',[0xF2]='Ö',[0xF3]='Ü',[0xF4]='ä',[0xF5]='ö',[0xF6]='ü',
}

-- These ROMs store localized composite font cells as text tokens.
-- Expand to ordinary glyphs so existing text layout measures the full word.
local language = ...
if language == 'fr' then
 glyphs[0x2C],glyphs[0x84],glyphs[0x64]='er','e','PC'
elseif language == 'es' then
 glyphs[0x2C]='er'
elseif language == 'it' then
 glyphs[0x5E],glyphs[0x5F],glyphs[0x60],glyphs[0x61]='POKé','','MEL',''
 glyphs[0x62],glyphs[0x63]='LA','LE'
elseif language == 'pt-BR' then
 -- Zambrakas 2013 repurposes these font cells in every Latin font face.
 glyphs[0x0C],glyphs[0x21]='Í','í'
 glyphs[0xF1],glyphs[0xF2],glyphs[0xF4],glyphs[0xF5]='Ã','Õ','ã','õ'
end
return glyphs
