# 枚举所有可见顶层窗口：标题、类名、矩形。用于精确定位 QQ 窗口，不靠肉眼估坐标。
Add-Type -AssemblyName System.Windows.Forms
$sig = @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr hWnd, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    public static string Dump() {
        StringBuilder sb = new StringBuilder();
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            StringBuilder t = new StringBuilder(256); GetWindowTextW(h, t, 256);
            StringBuilder c = new StringBuilder(256); GetClassNameW(h, c, 256);
            RECT r; GetWindowRect(h, out r);
            uint pid; GetWindowThreadProcessId(h, out pid);
            int w = r.Right - r.Left, ht = r.Bottom - r.Top;
            if (w > 120 && ht > 80)
                sb.AppendLine(string.Format("{0}\t{1}\t{2},{3},{4},{5}\tpid={6}", c.ToString(), t.ToString(), r.Left, r.Top, w, ht, pid));
            return true;
        }, IntPtr.Zero);
        return sb.ToString();
    }
}
'@
Add-Type -TypeDefinition $sig -ReferencedAssemblies System.Windows.Forms
[W]::Dump()
