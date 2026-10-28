"""Negative component contracts; fixtures contain no executable runtime or ROM."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('mobile_component',ROOT/'tools/mobile-runtime-check/component.py')
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
def result(capacity=120,arch='arm64',jit=False,interpreter=True):
 boundary={'upvalues':capacity,'compiles':True,'interpreter':True}
 if not interpreter:boundary['jit']=True
 return dict(passed=True,capacity=capacity,arch=arch,jitActive=jit,cApiPassed=True,
   ffiCallbackPassed=True,threadVmPassed=True,filesystemPassed=True,
   closureReport=dict(passed=True,minimum=capacity,interpreterOnly=interpreter,cases=[boundary]))
def archive(cpu):
 # Synthetic Mach-O prefix, sufficient only for architecture/bounds contracts.
 obj=b'\xcf\xfa\xed\xfe'+struct.pack('<I',cpu)+b'\0'*24
 header=b'probe.o/        '+b'0           '+b'0     '+b'0     '+b'100644  '+str(len(obj)).encode().ljust(10)+b'`\n'
 assert len(header)==60
 return b'!<arch>\n'+header+obj
class MobileGates(unittest.TestCase):
 def test_ios_interpreter_gate_accepts_no_jit_claim(self):c.closure(result(),120,'arm64',False,True)
 def test_android_arm_checks_jit_even_when_host_starts_with_jit_off(self):c.closure(result(interpreter=False),120,'arm64',False)
 def test_missing_high_capture_execution_rejected(self):
  r=result();r['closureReport']['cases'][0]['interpreter']=False
  with self.assertRaises(ValueError):c.closure(r,120,'arm64',False,True)
 def test_claimed_120_rejects_60_actual_host(self):
  with self.assertRaises(ValueError):c.closure(result(60),120,'arm64',False,True)
 def test_ios_rejects_active_jit(self):
  with self.assertRaises(ValueError):c.closure(result(jit=True),120,'arm64',False,True)
 def test_ios_rejects_silently_skipped_interpreter_mode(self):
  with self.assertRaises(ValueError):c.closure(result(interpreter=False),120,'arm64',False,True)
 def test_android_rejects_missing_jit_execution(self):
  with self.assertRaises(ValueError):c.closure(result(),120,'arm64',False)
 def test_all_host_boundaries_required(self):
  for key in ('cApiPassed','ffiCallbackPassed','threadVmPassed','filesystemPassed'):
   r=result();r[key]=False
   with self.subTest(key=key),self.assertRaises(ValueError):c.closure(r,120,'arm64',False,True)
 def test_receipt_cannot_escape_component(self):
  for name in ('../foreign','/absolute','C:\\foreign','reports/../../foreign'):
   with self.subTest(name=name),self.assertRaises(ValueError):c.child(ROOT,name)
 def test_static_archive_architecture_is_read_from_object(self):
  self.assertEqual(c.archive_slices(archive(0x100000c)),{'arm64':archive(0x100000c)})
  self.assertEqual(c.archive_arch(archive(0x1000007)),'x86_64')
 def test_truncated_static_archive_rejected(self):
  with self.assertRaises(ValueError):c.archive_arch(archive(0x100000c)[:-1])
 def test_static_archive_without_object_is_not_evidence(self):
  with self.assertRaises(ValueError):c.archive_arch(b'!<arch>\n')
 def test_universal_header_cannot_mislabel_static_archive(self):
  arm=archive(0x100000c);x64=archive(0x1000007);at=48
  data=b'\xca\xfe\xba\xbe'+struct.pack('>I',2)+struct.pack('>IIIII',0x1000007,0,at,len(arm),0)+struct.pack('>IIIII',0x100000c,0,at+len(arm),len(x64),0)+arm+x64
  with self.assertRaises(ValueError):c.archive_slices(data)
if __name__=='__main__':unittest.main()
