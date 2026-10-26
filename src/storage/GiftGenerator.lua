-- National-species pools contain identifiers only. Every result still passes
-- edition checks and is built from that game's native species definitions.
local G={}
G.LEGENDARY={144,145,146,150,151,243,244,245,249,250,251,377,378,379,380,381,382,383,384,385,386,
 480,481,482,483,484,485,486,487,488,489,490,491,492,493,494,638,639,640,641,642,643,644,645,646,647,648,649}
G.RANGES={{1,151},{152,251},{252,386},{387,493},{494,649}}
function G.roll(generation,legendary,egg,rng)
 local range=G.RANGES[generation]
 if not range then return nil,'Choose Generation 1–5.' end
 if egg and generation==1 then return nil,'Generation 1 cannot represent eggs.' end
 local special={};for _,dex in ipairs(G.LEGENDARY) do special[dex]=true end
 local pool={};for dex=range[1],range[2] do if (special[dex]==true)==legendary then pool[#pool+1]=dex end end
 local dex=pool[(rng or math.random)(1,#pool)]
 return {kind='pokemon',dex=dex,level=egg and (generation>=4 and 1 or 5) or 5,egg=egg==true,shiny=false}
end
return G
