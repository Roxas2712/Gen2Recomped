return function(languages)
 local choices={{'Per-game choice','auto'}}
 for _,language in ipairs(languages) do if language.available then choices[#choices+1]={language.name,language.id} end end
 return {
 {key='language',type='choice',label='Language / Sprache (restart)',default='auto',choices=choices},
 {key='showPicker',type='choice',label='Language screen before title',default=true,choices={{'Show',true},{'Hide',false}}},
}
end
