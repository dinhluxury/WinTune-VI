// Changes only the title bar of the supplied WinTune window.
using System;
using System.Runtime.InteropServices;
namespace WinTune.Appearance {
    public static class Native {
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr window, int attribute, ref int value, int size);
        public static int SetDarkTitleBar(IntPtr window, bool dark) {
            int value=dark?1:0; return DwmSetWindowAttribute(window,20,ref value,sizeof(int));
        }
    }
}
