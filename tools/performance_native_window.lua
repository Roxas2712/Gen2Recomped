-- Qualification host only: change the actual native window, never its queries.
return function(library)
  local ffi=require('ffi')
  ffi.cdef[[
    typedef struct SDL_Window SDL_Window;
    SDL_Window **SDL_GetWindows(int *count);
    bool SDL_SetWindowFocusable(SDL_Window *window, bool focusable);
    bool SDL_ShowWindow(SDL_Window *window);
    bool SDL_HideWindow(SDL_Window *window);
    void SDL_free(void *memory);
  ]]
  local sdl=ffi.load(library)
  local count=ffi.new('int[1]')
  local windows=sdl.SDL_GetWindows(count)
  assert(windows~=nil and count[0]==1,'qualification requires exactly one native window')
  local window=windows[0]
  local focusable=sdl.SDL_SetWindowFocusable(window,false)
  -- An initially hidden Cocoa window can retain SDL's initial focus state.
  -- A real show/hide transition releases it; showing must not activate it.
  local shown=focusable and sdl.SDL_ShowWindow(window)
  local hidden=shown and sdl.SDL_HideWindow(window)
  sdl.SDL_free(windows)
  assert(focusable and shown and hidden,'native unfocused-window control failed')
  return {method='SDL3 non-focusable native show/hide',queryOverridden=false}
end
