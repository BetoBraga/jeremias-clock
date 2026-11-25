using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
namespace Jeremias {
 public static class WindowBridge {
  [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; public int Width { get { return Right-Left; } } public int Height { get { return Bottom-Top; } } }
  [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; }
  [StructLayout(LayoutKind.Sequential)] struct MonitorInfo { public int Size; public Rect Monitor, Work; public uint Flags; }
  public class PetWindow { public IntPtr Handle; public uint Pid; public string Process, Title, ClassName; public Rect Bounds; }
  delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr p);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out Rect r);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsZoomed(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetShellWindow();
  [DllImport("user32.dll")] static extern IntPtr GetDesktopWindow();
  [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
  [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr h, ref MonitorInfo m);
  [DllImport("user32.dll")] static extern bool GetCursorPos(out Point p);
  [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point p);
  [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h,StringBuilder s,int n);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
  [DllImport("user32.dll", EntryPoint="GetWindowLongW")] static extern int GetWindowLong(IntPtr h,int index);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int cx,int cy,uint flags);
  [DllImport("dwmapi.dll", EntryPoint="DwmGetWindowAttribute")] static extern int DwmInt(IntPtr h,int attr,out int value,int size);
  [DllImport("dwmapi.dll", EntryPoint="DwmGetWindowAttribute")] static extern int DwmRect(IntPtr h,int attr,out Rect value,int size);
  static string Title(IntPtr h) { var s=new StringBuilder(512); GetWindowText(h,s,s.Capacity); return s.ToString(); }
  static string Class(IntPtr h) { var s=new StringBuilder(256); GetClassName(h,s,s.Capacity); return s.ToString(); }
  static bool Visible(IntPtr h) { if(h==IntPtr.Zero || !IsWindow(h) || !IsWindowVisible(h) || IsIconic(h)) return false; int c; try { if(DwmInt(h,14,out c,4)==0 && c!=0) return false; } catch {} return true; }
  public static bool FullscreenOnWidgetMonitor(IntPtr widget, IntPtr pet) {
   IntPtr f=GetForegroundWindow(); if(f==widget || f==pet || f==GetShellWindow() || f==GetDesktopWindow() || !Visible(f)) return false;
   var cls=Class(f); if(cls=="Progman" || cls=="WorkerW" || cls=="Shell_TrayWnd" || cls=="Shell_SecondaryTrayWnd") return false;
   IntPtr m=MonitorFromWindow(widget,2); var mi=new MonitorInfo(); mi.Size=Marshal.SizeOf(typeof(MonitorInfo)); if(m==IntPtr.Zero || !GetMonitorInfo(m,ref mi)) return false;
   Rect r; if(!GetWindowRect(f,out r)) return false; Rect dw; try { if(DwmRect(f,9,out dw,Marshal.SizeOf(typeof(Rect)))==0) r=dw; } catch {}
   // Ordinary captioned maximized windows are not fullscreen, even with an auto-hidden taskbar.
   if(IsZoomed(f) && (GetWindowLong(f,-16)&0x00C00000)==0x00C00000) return false;
   const int t=3; var a=mi.Monitor;
   return r.Left<=a.Left+t && r.Top<=a.Top+t && r.Right>=a.Right-t && r.Bottom>=a.Bottom-t;
  }
  public static PetWindow Inspect(IntPtr h) {
   if(!Visible(h)) return null; uint pid; GetWindowThreadProcessId(h,out pid); string name;
   try { using(var p=Process.GetProcessById((int)pid)) name=p.ProcessName; } catch { return null; }
   if(name.IndexOf("chatgpt",StringComparison.OrdinalIgnoreCase)<0 && name.IndexOf("codex",StringComparison.OrdinalIgnoreCase)<0) return null;
   Rect r; if(!GetWindowRect(h,out r) || r.Width<20 || r.Height<20 || r.Width>1000 || r.Height>1000) return null;
   // Exclude normal main windows, regardless of size.
   if((GetWindowLong(h,-16)&0x00C00000)==0x00C00000) return null;
   // An off-screen overlay is not a visible pet.
   var mon=MonitorFromWindow(h,0); if(mon==IntPtr.Zero) return null;
   return new PetWindow {Handle=h,Pid=pid,Process=name,Title=Title(h),ClassName=Class(h),Bounds=r};
  }
  public static PetWindow UnderCursor() {
   Point p; if(!GetCursorPos(out p)) return null;
   var direct=Inspect(GetAncestor(WindowFromPoint(p),2)); if(direct!=null) return direct;
   // A transparent pet may be click-through. Accept only a unique eligible overlay under the cursor.
   var candidates=new List<PetWindow>(); EnumWindows(delegate(IntPtr h,IntPtr param) { var w=Inspect(h); if(w!=null && p.X>=w.Bounds.Left && p.X<w.Bounds.Right && p.Y>=w.Bounds.Top && p.Y<w.Bounds.Bottom) candidates.Add(w); return true; },IntPtr.Zero);
   return candidates.Count==1?candidates[0]:null;
  }
  public static PetWindow[] Find(string process,string cls,string title) {
   var list=new List<PetWindow>(); EnumWindows(delegate(IntPtr h,IntPtr p) { var w=Inspect(h); if(w!=null && String.Equals(w.Process,process,StringComparison.OrdinalIgnoreCase) && w.ClassName==cls && w.Title==title) list.Add(w); return true; },IntPtr.Zero); return list.ToArray();
  }
  public static bool Move(PetWindow pet,int x,int y) { if(pet==null) return false; var live=Inspect(pet.Handle); if(live==null || live.Pid!=pet.Pid || live.ClassName!=pet.ClassName || live.Process!=pet.Process) return false; return SetWindowPos(pet.Handle,IntPtr.Zero,x,y,0,0,0x0001|0x0004|0x0010|0x0200); }
 }
}
