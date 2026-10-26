-- Reflow already expanded native printer tokens. Dialogue, timing controls
-- and variable values stay native; only spaces and line layout change.
return function(tokens,width,measure)
 local out,line,word,pendingSpace={},'',{},false
 local lineNumber=1
 local function newline()
  out[#out+1]={t=lineNumber==1 and 'nl' or 'scroll'}
  lineNumber=2;line='';pendingSpace=false
 end
 local function emit(token)
  out[#out+1]=token;line=line..token.s
 end
 local function flush()
  if #word==0 then return end
  local parts={};for _,tok in ipairs(word)do parts[#parts+1]=tok.s end
  local text=table.concat(parts)
  local sep=pendingSpace and line~='' and ' ' or ''
  if line~='' and measure(line..sep..text)>width then newline();sep='' end
  if sep~='' then emit({t='c',s=sep})end
  for _,tok in ipairs(word)do
   if line~='' and measure(line..tok.s)>width then newline()end
   emit(tok)
  end
  word={};pendingSpace=false
 end
 for _,tok in ipairs(tokens)do
  if tok.t=='c' then
   if tok.s==' ' then flush();pendingSpace=true else word[#word+1]=tok end
  else
   flush()
   if tok.t=='nl' or tok.t=='scroll' then newline()
   else
    out[#out+1]=tok
    if tok.t=='para' then line='';lineNumber=1;pendingSpace=false end
   end
  end
 end
 flush();return out
end
