-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Authored labels for host-only spellings absent from the cartridge catalogs.
-- Retail catalog entries always take priority. No dialogue or names are guessed.
local U={}
local labels={
 de={'Wähle ein POKéMON.','EP-PUNKTE','NÄCHSTER L.','TASCHE','NAME','ZEIT'},
 es={'Elige un POKéMON.','PUNTOS EXP','SIG. NIVEL','BOLSILLO','NOMBRE','TIEMPO'},
 fr={'Choisis un POKéMON.','POINTS EXP','NIV. SUIV.','POCHE','NOM','TEMPS'},
 it={'Scegli un POKéMON.','PUNTI ESP','PROSS. L.','TASCA','NOME','TEMPO'},
 ['pt-BR']={'Escolha um POKéMON.','PONTOS EXP','PRÓX. NÍV.','BOLSO','NOME','TEMPO'},
}
function U.apply(data,language)
 local s=data.strings or{};data.strings=s;local row=labels[language];if not row then return end
 for i,key in ipairs({'Choose a POKéMON.','EXP POINTS','LEVEL UP','POCKET','NAME/','TIME'})do if not s[key]then s[key]=i==5 and row[i]..'/'or row[i]end end
 -- Different host consumers spell these with and without punctuation.
 for alias,key in pairs({['EXP. POINTS']='EXP POINTS',['NAME/%s']='NAME/',[' do?']='to do?'})do
  if not s[alias]and s[key]then s[alias]=alias=='NAME/%s'and s[key]..'%s'or s[key]end
 end
 local quit={de='SPIEL BEENDEN',es='SALIR DEL JUEGO',fr='QUITTER LE JEU',it='ESCI DAL GIOCO',['pt-BR']='SAIR DO JOGO'}
 if not s['QUIT GAME']then s['QUIT GAME']=quit[language]end
 local option={de={'ANIMATION','KAMPFSTIL','NORMAL'},es={'ANIMACIONES','TIPO COMBATE','NORMAL'},fr={'ANIMATIONS','STYLE COMBAT','NORMAL'},it={'ANIMAZIONI','STILE LOTTA','NORMALE'},['pt-BR']={'ANIMAÇÕES','ESTILO BATALHA','NORMAL'}}
 for i,key in ipairs({'BATTLE ANIMATION','BATTLE STYLE','MEDIUM'})do if not s[key]then s[key]=option[language][i]end end
 if not s['NAME/']and s.NAME then s['NAME/']=s.NAME..'/'end
end
return U
