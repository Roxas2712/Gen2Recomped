//! In-process LÖVE frontend bridge. Integration by Roxas2712.
//! Zakuro remains a separately licensed dependency (MIT); no game code here.
use std::{cell::RefCell,ffi::{CStr,CString},fs::{File,OpenOptions},panic::{catch_unwind,AssertUnwindSafe},path::PathBuf,sync::Once};
use serde::Deserialize;
mod language_patterns;
use zakuro_core::{System,Config,FrameOutcome};
use zakuro_core::services::hid::{InputState,PadState};
use zakuro_common::Screen;
thread_local! { static ERROR:RefCell<CString>=RefCell::new(CString::new("").unwrap()); }
static LOG:Once=Once::new();
fn error(message:impl ToString){ERROR.with(|e|*e.borrow_mut()=CString::new(message.to_string().replace('\0'," ")).unwrap());}
fn guard<T>(fallback:T,f:impl FnOnce()->Result<T,String>)->T {
 match catch_unwind(AssertUnwindSafe(f)) {Ok(Ok(value))=>value,Ok(Err(e))=>{error(e);fallback},Err(_)=>{error("3DS backend panic; session stopped");fallback}}
}
#[cfg(unix)]
fn thread_cpu_ms()->Option<f64>{
 let mut value=libc::timespec{tv_sec:0,tv_nsec:0};
 (unsafe{libc::clock_gettime(libc::CLOCK_THREAD_CPUTIME_ID,&mut value)}==0).then_some(value.tv_sec as f64*1000.0+value.tv_nsec as f64/1_000_000.0)
}
#[cfg(not(unix))]
fn thread_cpu_ms()->Option<f64>{None}
unsafe fn string(ptr:*const libc::c_char)->Result<String,String>{
 if ptr.is_null(){return Err("Missing bridge argument".into());}
 CStr::from_ptr(ptr).to_str().map(str::to_owned).map_err(|e|e.to_string())
}
#[derive(Deserialize)]
struct Request {
 rom:PathBuf,library:PathBuf,data:PathBuf,session_lock:PathBuf,
 resolution:u32,language:u8,depth_3d:u32,stereo:String,texture_packs:bool,
 #[serde(default)] vulkan_loader:Option<PathBuf>,
 #[serde(default)] driver_manifest:Option<PathBuf>,
}
pub struct Bridge {
 system:System,_lease:File,
 pictures:[Option<zakuro_core::Screen>;3],revisions:[u64;3],digests:[Option<(u32,u32,u64)>;3],blank_cache:Option<(u64,bool)>,emu_ms:f64,emu_cpu_ms:Option<f64>,readback_ms:f64,audio:Vec<[i16;2]>,status:CString,
}
#[repr(C)]
pub struct Picture {pub data:*const u8,pub width:u32,pub height:u32,pub bytes:usize}
#[no_mangle]
pub extern "C" fn ascendant_3ds_error()->*const libc::c_char{ERROR.with(|e|e.borrow().as_ptr())}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_open(json:*const libc::c_char)->*mut Bridge {
 guard(std::ptr::null_mut(),||{
  LOG.call_once(||{let _=env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info,cranelift_jit=warn")).try_init();});
  let request:Request=serde_json::from_str(&string(json)?).map_err(|e|e.to_string())?;
  if let Some(path)=&request.vulkan_loader {
   if !path.is_file(){return Err("Bundled Vulkan loader is missing".into());}
   std::env::set_var("RETRO_3DS_VULKAN_LIBRARY",path);
  }
  if let Some(path)=&request.driver_manifest {
   if !path.is_file(){return Err("Bundled graphics driver is missing".into());}
   if cfg!(windows) {
    std::env::set_var("VK_ADD_DRIVER_FILES",path);
   }else{
    std::env::set_var("VK_DRIVER_FILES",path);
    std::env::set_var("VK_ICD_FILENAMES",path);
   }
  }
  if !(1..=8).contains(&request.resolution){return Err("Resolution out of range".into());}
  std::fs::create_dir_all(&request.data).map_err(|e|e.to_string())?;
  if let Some(parent)=request.session_lock.parent(){std::fs::create_dir_all(parent).map_err(|e|e.to_string())?;}
  // Windows LockFileEx requires read or non-append write access. An append-
  // only handle fails even when nobody holds the session lock.
  let lease=OpenOptions::new().create(true).read(true).append(true).open(&request.session_lock).map_err(|e|e.to_string())?;
  lease.try_lock().map_err(|_|"Eine andere 3DS-Sitzung ist noch aktiv. Bitte dort zuerst beenden.".to_owned())?;
  let config=Config{data_dir:Some(request.data),recompiled:Some(request.library),hardware_renderer:true,resolution:request.resolution,language:request.language,slider_3d:if request.stereo=="off"{0.0}else{request.depth_3d.min(100) as f32/100.0},texture_packs:request.texture_packs,..Config::default()};
  let system=zakuro_core::loader::load(request.rom,config).map_err(|e|e.to_string())?;
  if ![0x0004000000055D00,0x0004000000055E00].contains(&system.kernel.program_id){return Err("Unsupported title".into());}
  if system.recompiled.is_none(){return Err("Recompiled game library could not be loaded".into());}
  if !system.gpu.draws_on_gpu(){return Err("Hardware-Grafikbackend nicht verfügbar".into());}
  Ok(Box::into_raw(Box::new(Bridge{system,_lease:lease,pictures:[None,None,None],revisions:[0;3],digests:[None,None,None],blank_cache:None,emu_ms:0.0,emu_cpu_ms:None,readback_ms:0.0,audio:Vec::new(),status:CString::new("").unwrap()})))
 })
}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_step(handle:*mut Bridge,buttons:u32,cx:f32,cy:f32,tx:i32,ty:i32,read_right:bool)->i32 {
 guard(-1,||{
  let b=handle.as_mut().ok_or("Missing game session")?;
  b.system.set_input(InputState{buttons:PadState::from_bits_retain(buttons),circle_x:cx.clamp(-1.0,1.0),circle_y:cy.clamp(-1.0,1.0),touch:if (0..320).contains(&tx)&&(0..240).contains(&ty){Some((tx as u16,ty as u16))}else{None},..InputState::default()});
  let cpu=thread_cpu_ms();let began=std::time::Instant::now();
  let outcome=b.system.run_frame();
  b.emu_ms=began.elapsed().as_secs_f64()*1000.0;b.emu_cpu_ms=cpu.zip(thread_cpu_ms()).map(|(a,z)|(z-a).max(0.0));let readback=std::time::Instant::now();
  if !b.system.fatal_errors.is_empty(){return Err(b.system.fatal_errors.join("; "));}
  if outcome!=FrameOutcome::Completed{return Err(format!("Game stopped: {outcome:?}"));}
  let pictures=[Some(b.system.read_screen_scaled(Screen::Top)),Some(b.system.read_screen_scaled(Screen::Bottom)),if read_right{b.system.read_right_eye_scaled()}else{None}];
  for (i,picture) in pictures.into_iter().enumerate(){
   let identical_arc=match (&b.pictures[i],&picture){(Some((a,w,h)),Some((v,x,y)))=>w==x&&h==y&&std::sync::Arc::ptr_eq(a,v),(None,None)=>true,_=>false};
   if identical_arc{continue;}
   // Some CPU/2D buffers get fresh allocations despite identical pixels.
   // Hash the complete RGBA image with the existing fast upstream dependency;
   // retain the image/revision when content stays the same, not just its Arc.
   let digest=picture.as_ref().map(|(pixels,w,h)|(*w,*h,twox_hash::XxHash64::oneshot(0,pixels)));
   if digest!=b.digests[i]{b.revisions[i]=b.revisions[i].wrapping_add(1);b.digests[i]=digest;b.pictures[i]=picture;}
  }
  b.readback_ms=readback.elapsed().as_secs_f64()*1000.0;
  b.audio=b.system.take_audio();
  Ok(0)
 })
}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_picture(handle:*mut Bridge,index:u32,out:*mut Picture)->bool {
 guard(false,||{
  let b=handle.as_ref().ok_or("Missing game session")?;
  let out=out.as_mut().ok_or("Missing picture descriptor")?;
  *out=Picture{data:std::ptr::null(),width:0,height:0,bytes:0};
  let Some(Some((pixels,width,height)))=b.pictures.get(index as usize) else{return Ok(false)};
  *out=Picture{data:pixels.as_ptr(),width:*width,height:*height,bytes:pixels.len()};Ok(true)
 })
}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_revision(handle:*mut Bridge,index:u32)->u64 {
 handle.as_ref().and_then(|b|b.revisions.get(index as usize)).copied().unwrap_or(0)
}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_audio(handle:*mut Bridge,frames:*mut usize)->*const i16 {
 let Some(b)=handle.as_ref()else{return std::ptr::null()};
 if let Some(frames)=frames.as_mut(){*frames=b.audio.len();}
 b.audio.as_ptr().cast()
}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_slider(handle:*mut Bridge,value:f32){if let Some(b)=handle.as_mut(){b.system.set_slider_3d(value.clamp(0.0,1.0));}}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_status(handle:*mut Bridge)->*const libc::c_char {
 guard(std::ptr::null(),||{
  let b=handle.as_mut().ok_or("Missing game session")?;
  b.status=CString::new(serde_json::json!({"frames":b.system.frames,"recompiled":b.system.recompiled_instructions,"interpreted":b.system.interpreted_instructions,"hardware":b.system.gpu.draws_on_gpu(),"resolution":b.system.gpu.scale(),"emulation_ms":b.emu_ms,"emulation_cpu_ms":b.emu_cpu_ms,"readback_ms":b.readback_ms}).to_string()).map_err(|e|e.to_string())?;Ok(b.status.as_ptr())
 })
}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_state(handle:*mut Bridge,path:*const libc::c_char,load:bool)->bool {
 guard(false,||{
  let b=handle.as_mut().ok_or("Missing game session")?;let path=PathBuf::from(string(path)?);
  if load {let data=std::fs::read(&path).map_err(|e|e.to_string())?;b.system.load_state(&data)?;}
  else {let data=b.system.save_state()?;if let Some(parent)=path.parent(){std::fs::create_dir_all(parent).map_err(|e|e.to_string())?;}let pending=path.with_extension("pending");std::fs::write(&pending,data).map_err(|e|e.to_string())?;std::fs::rename(pending,path).map_err(|e|e.to_string())?;}
  Ok(true)
 })
}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_close(handle:*mut Bridge){if !handle.is_null(){let _=catch_unwind(AssertUnwindSafe(||drop(Box::from_raw(handle))));}}

#[repr(C)]
pub struct Place {pub x:f32,pub y:f32,pub width:f32,pub height:f32,pub screen:u32}
/// Uses the real backend layout, shared with the standalone presenter.
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_layout(w:u32,h:u32,layout:u32,stereo:u32,swap:bool,right:bool,out:*mut Place,capacity:usize)->usize {
 use zakuro_gpu::backend::{place,ScreenLayout as L,Stereo,StereoMode as S,Shown};
 let layouts=[L::Stacked,L::SideBySide,L::LargeTop,L::Overlay,L::TopOnly,L::BottomOnly];
 let modes=[S::Off,S::Anaglyph,S::SideBySide,S::HalfSideBySide,S::Interlaced];
 let Some(&layout)=layouts.get(layout as usize)else{return 0};let Some(&mode)=modes.get(stereo as usize)else{return 0};
 if out.is_null(){return 0;}
 let positions=place(w,h,layout,400.0,false,Stereo{mode,swap},right);
 if positions.len()>capacity{return 0;}
 for (i,(p,shown)) in positions.iter().enumerate(){*out.add(i)=Place{x:p.x,y:p.y,width:p.width,height:p.height,screen:match shown{Shown::Top=>0,Shown::Bottom=>1,Shown::Right=>2,Shown::Both=>3}};}
 positions.len()
}

#[repr(C)]
#[derive(Default)]
pub struct Assessment {pub fps:f64,pub p95_ms:f64,pub target_fps:f64,pub status:u32,pub samples:u32}
/// 0 incomplete, 1 unsupported backend, 2 startup pass, 3 lower resolution,
/// 4 currently too slow at 1x. This qualifies only the measured scene/profile.
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_assess(seconds:*const f64,length:usize,hardware:bool,recompiled:bool,scale:u32,out:*mut Assessment)->bool {
 let Some(out)=out.as_mut()else{return false};*out=Assessment::default();
 out.target_fps=268111856.0/4481136.0;
 if !hardware||!recompiled{out.status=1;return true;}
 if seconds.is_null()||length<360||length>1000000{return true;}
 let input=std::slice::from_raw_parts(seconds,length);
 if input.iter().any(|&v|!v.is_finite()||v<=0.0){return true;}
 let total:f64=input.iter().sum();let mut sorted=input.to_vec();sorted.sort_by(|a,b|a.total_cmp(b));
 out.samples=length as u32;out.fps=length as f64/total;
 out.p95_ms=sorted[((length-1) as f64*0.95) as usize]*1000.0;
 out.status=if out.fps>=out.target_fps&&out.p95_ms<=33.4{2}else if scale==1{4}else{3};true
}
#[cfg(test)]
mod device_tests {
 use super::*;
 #[test]fn session_lease_is_acquirable_exclusive_and_released(){
  let path=std::env::temp_dir().join(format!("retro-3ds-own-lock-{}-{}",std::process::id(),std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
  let first=OpenOptions::new().create(true).read(true).append(true).open(&path).unwrap();
  first.try_lock().unwrap();
  let second=OpenOptions::new().read(true).append(true).open(&path).unwrap();
  assert!(second.try_lock().is_err());drop(first);
  second.try_lock().unwrap();drop(second);std::fs::remove_file(path).unwrap();
 }
 fn assess(samples:&[f64],scale:u32)->Assessment{let mut out=Assessment::default();unsafe{assert!(ascendant_3ds_assess(samples.as_ptr(),samples.len(),true,true,scale,&mut out));}out}
 #[test]fn qualified_startup_is_full_emulation_speed(){let out=assess(&vec![0.012;360],3);assert_eq!(out.status,2);assert!((out.fps-83.333333).abs()<0.001);}
 #[test]fn slow_profile_requests_lower_resolution_before_weak(){assert_eq!(assess(&vec![0.020;360],3).status,3);assert_eq!(assess(&vec![0.020;360],1).status,4);}
 #[test]fn missing_or_invalid_samples_never_qualify(){for rows in [vec![0.01;359],vec![f64::NAN;360],vec![0.0;360],vec![f64::INFINITY;360]]{assert_eq!(assess(&rows,1).status,0);}}
 #[test]fn tail_latency_matters_even_when_average_is_fast(){let mut rows=vec![0.004;360];rows[..30].fill(0.05);let out=assess(&rows,1);assert!(out.fps>out.target_fps);assert_eq!(out.status,4);}
 #[test]fn missing_gpu_is_not_called_weak(){let mut out=Assessment::default();unsafe{ascendant_3ds_assess(std::ptr::null(),0,false,true,1,&mut out);}assert_eq!(out.status,1);}
}

fn blank_rgba(pixels:&[u8])->bool{!pixels.is_empty()&&pixels.chunks_exact(4).all(|p|p[0]==0&&p[1]==0&&p[2]==0)}
// Full-frame digests of the unchanged X/Y neutral touch background, measured
// at 1x..8x with the pinned renderer. Both editions independently match at 3x.
// No background artwork is bundled. Unknown/modified backgrounds stay visible.
const EMPTY_TOUCH_RGB:[u64;8]=[0xf9477e936d782cfb,0xc6dd6c70f1855565,0xe09fd5d5b8eaad3c,0xb1c0762a1d49df31,0xbca849fa308ca56e,0x142d00c3b6dce37a,0x3fe3933007bb2717,0x3c850e0be1678065];
fn rgb_digest(pixels:&[u8])->u64 {
 let mut hash=0xcbf29ce484222325u64;
 for p in pixels.chunks_exact(4){for &v in &p[..3]{hash=(hash^v as u64).wrapping_mul(0x100000001b3);}}
 hash
}
fn empty_touch(pixels:&[u8],width:u32,height:u32)->bool {
 if pixels.len()!=width as usize*height as usize*4||pixels.is_empty(){return false;}
 if blank_rgba(pixels){return true;}
 let scale=width/320;
 (1..=8).contains(&scale)&&width==320*scale&&height==240*scale&&rgb_digest(pixels)==EMPTY_TOUCH_RGB[scale as usize-1]
}
/// Compare every visible pixel with black or the verified neutral X/Y image.
/// This never guesses from motion, a few sampled pixels, or low contrast.
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_blank(handle:*mut Bridge,index:u32)->bool {
 let Some(b)=handle.as_mut()else{return false};
 let Some(&revision)=b.revisions.get(index as usize)else{return false};
 if index==1 {if let Some((cached,value))=b.blank_cache{if cached==revision{return value;}}}
 let value=b.pictures.get(index as usize).and_then(Option::as_ref).is_some_and(|(pixels,width,height)|empty_touch(pixels,*width,*height));
 if index==1{b.blank_cache=Some((revision,value));}value
}
#[cfg(test)]mod blank_tests {
 use super::*;
 #[test]fn full_frame_digest_detects_one_changed_pixel(){let mut p=vec![24;320*240*4];let before=rgb_digest(&p);p[4*137+2]^=1;assert_ne!(before,rgb_digest(&p));}
 #[test]fn unknown_and_incomplete_images_stay_visible(){assert!(!empty_touch(&[24;4],320,240));assert!(!empty_touch(&vec![24;320*240*4],320,240));}
 #[test]fn alpha_does_not_turn_an_empty_display_into_content(){assert!(blank_rgba(&[0,0,0,255,0,0,0,0]));assert!(!blank_rgba(&[]));}
 #[test]fn even_a_single_coloured_pixel_must_stay_visible(){let mut p=vec![0;320*240*4];let n=p.len();p[n-2]=1;assert!(!blank_rgba(&p));}
}

/// 0 unknown, 1 initial language picker, 2..8 confirmed language label.
/// A small, exact opaque label band excludes the animated background/mascot.
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_language_prompt(handle:*mut Bridge)->u32 {
 let Some(b)=handle.as_ref()else{return 0};
 let Some((pixels,width,height))=&b.pictures[0]else{return 0};
 let scale=width/400;if !(1..=8).contains(&scale)||*width!=400*scale||*height!=240*scale{return 0;}
 let mut hash=0xcbf29ce484222325u64;
 for y in 120*scale..139*scale{for x in 50*scale..345*scale{
  let offset=((y*width+x)*4)as usize;
  for &value in &pixels[offset..offset+3]{hash=(hash^value as u64).wrapping_mul(0x100000001b3);}
 }}
 language_patterns::PROMPTS[scale as usize-1].iter().position(|v|*v==hash).map(|i|i as u32+1).unwrap_or(0)
}

#[cfg(test)]mod revision_tests {
 #[test]fn complete_image_digest_changes_even_for_one_changed_byte(){
  let mut bytes=vec![0u8;320*240*4];let first=twox_hash::XxHash64::oneshot(0,&bytes);
  let middle=bytes.len()/2;bytes[middle]=1;assert_ne!(first,twox_hash::XxHash64::oneshot(0,&bytes));
 }
}

#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_keyboard(handle:*mut Bridge)->*const libc::c_char {
 guard(std::ptr::null(),||{
  let b=handle.as_mut().ok_or("Missing game session")?;
  let Some(request)=b.system.keyboard_request()else{return Ok(std::ptr::null());};
  b.status=CString::new(serde_json::to_string(request).map_err(|e|e.to_string())?).map_err(|e|e.to_string())?;Ok(b.status.as_ptr())
 })
}
#[no_mangle]
pub unsafe extern "C" fn ascendant_3ds_answer_keyboard(handle:*mut Bridge,text:*const libc::c_char,button:u32)->bool {
 guard(false,||{
  let b=handle.as_mut().ok_or("Missing game session")?;let text=string(text)?;
  let request=b.system.keyboard_request().ok_or("No keyboard request")?;
  if button as usize>=request.buttons.len(){return Err("Unknown keyboard button".into());}
  if button as usize==request.buttons.len()-1&&!request.accepts(&text){return Err("Diese Eingabe entspricht nicht den Vorgaben des Spiels.".into());}
  b.system.answer_keyboard(&text,button as usize);Ok(true)
 })
}
