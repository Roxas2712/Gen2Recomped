local L={
 {"original","Original ROM text"},{"en","English"},{"fr","French"},{"de","German"},
 -- two Portugueses, by Argos' own codes: "pt" is European, "pb" Brazilian
 {"es","Spanish"},{"it","Italian"},{"pt","Portuguese (Portugal)"},{"pb","Portuguese (Brazil)"},{"nl","Dutch"},
 {"pl","Polish"},{"cs","Czech"},{"da","Danish"},{"sv","Swedish"},
 {"fi","Finnish"},{"el","Greek"},{"ro","Romanian"},{"hu","Hungarian"},
 {"tr","Turkish"},{"nb","Norwegian"},{"bg","Bulgarian"},
 {"sk","Slovak"},{"sl","Slovenian"},{"ca","Catalan"},
 {"uk","Ukrainian"},{"ru","Russian"},{"ja","日本語"},{"ko","한국어"},
 {"zh","简体中文"},{"zh-Hant","繁體中文"}}
function L.choices(inherit)
 local values,labels={},{}
 if inherit then values[1]="inherit";labels.inherit="Use launcher language" end
 for _,v in ipairs(L)do values[#values+1]=v[1];labels[v[1]]=v[2]end
 return values,labels
end
function L.resolve(options,version)
 options=type(options)=="table" and options or {}
 local per=type(options.translationPerGame)=="table" and options.translationPerGame[version] or {}
 per=type(per)=="table" and per or {}
 local target=per.target
 if not target or target=="inherit" then target=options.translationLanguage or "original" end
 local valid={original=true};for _,v in ipairs(L)do valid[v[1]]=true end
 if not valid[target] then target="original" end
 -- The source is what the ROM's text IS, not a choice: every ROM this port
 -- imports is identified as an English (USA) dump, so its text is English.
 -- A saved per-game or launcher "source" (an older settings row) is ignored --
 -- one set to the target language made French -> French jobs that returned
 -- the English text unchanged.
 local source=L.romLanguage(version)
 -- Nothing to translate when the target is the ROM's own language.
 if target==source then target="original" end
 return target,source
end
function L.romLanguage(version)
 local ok,GameVersion=pcall(require,"src.core.GameVersion")
 local info=ok and version and GameVersion.info and GameVersion.info(version)
 local lang=type(info)=="table" and info.textLanguage
 return type(lang)=="string" and lang or "en"
end
function L.bundledFont(target)
 local family=({ja='jp',ko='kr',zh='sc',['zh-Hans']='sc',['zh-Hant']='tc'})[target]
 return family and 'mods/UNI_LANGUAGE_NATIVE/fonts/ascendant-'..family..'.otf' or nil
end
function L.font(target)
 if target=='ko' then
  return 'NotoSansCJKkr-Regular.otf','https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/Korean/NotoSansCJKkr-Regular.otf'
 end
 if target=='zh-Hant' then
  return 'NotoSansCJKtc-Regular.otf','https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/TraditionalChinese/NotoSansCJKtc-Regular.otf'
 end
 if target=="ja" or target=="zh" or target=='zh-Hans' then
  return "NotoSansCJK-Regular.otf","https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf"
 end
 return "NotoSans-Regular.ttf","https://raw.githubusercontent.com/notofonts/noto-fonts/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf"
end
return L
