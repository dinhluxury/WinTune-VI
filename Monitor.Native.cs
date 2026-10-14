// WinTune read-only Windows APIs. No upstream implementation is copied.
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace WinTune.Monitor {
    public sealed class Times { public ulong Idle, Kernel, User; }
    public sealed class Memory { public ulong Total, Available; public uint Load; }
    public sealed class Adapter { public string Name, Luid; public ulong DedicatedBytes, SharedBytes; }
    public static class Native {
        [StructLayout(LayoutKind.Sequential)] struct FileTime { public uint Low, High; public ulong Value { get { return ((ulong)High << 32) | Low; } } }
        [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetSystemTimes(out FileTime idle, out FileTime kernel, out FileTime user);
        [StructLayout(LayoutKind.Sequential)] class MemoryStatus {
            public uint Length, Load; public ulong TotalPhys, AvailPhys, TotalPage, AvailPage, TotalVirtual, AvailVirtual, AvailExtended;
        }
        [DllImport("kernel32.dll", SetLastError=true)] static extern bool GlobalMemoryStatusEx([In, Out] MemoryStatus status);
        public static Times ReadTimes() {
            FileTime i,k,u;
            if (!GetSystemTimes(out i,out k,out u)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            return new Times { Idle=i.Value, Kernel=k.Value, User=u.Value };
        }
        public static Memory ReadMemory() {
            var s=new MemoryStatus(); s.Length=(uint)Marshal.SizeOf(s);
            if (!GlobalMemoryStatusEx(s)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
            return new Memory { Total=s.TotalPhys, Available=s.AvailPhys, Load=s.Load };
        }
        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct AdapterDesc {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string Description;
            public uint Vendor, Device, SubSys, Revision;
            public UIntPtr DedicatedVideo, DedicatedSystem, SharedSystem;
            public uint LuidLow; public int LuidHigh; public uint Flags;
        }
        [DllImport("dxgi.dll", CallingConvention=CallingConvention.StdCall)] static extern int CreateDXGIFactory1(ref Guid id, out IntPtr factory);
        [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int EnumAdapters(IntPtr factory, uint index, out IntPtr adapter);
        [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int GetDesc(IntPtr adapter, out AdapterDesc desc);
        static Delegate Slot(IntPtr obj, int index, Type signature) {
            var vtable=Marshal.ReadIntPtr(obj);
            return Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtable,index*IntPtr.Size),signature);
        }
        public static Adapter[] ReadAdapters() {
            IntPtr factory=IntPtr.Zero;
            var rows=new List<Adapter>(); var id=new Guid("770aae78-f26f-4dba-a829-253c83d1b387");
            try {
                Marshal.ThrowExceptionForHR(CreateDXGIFactory1(ref id,out factory));
                var enumerate=(EnumAdapters)Slot(factory,12,typeof(EnumAdapters));
                for (uint n=0;n<64;n++) {
                    IntPtr adapter; var hr=enumerate(factory,n,out adapter);
                    if (hr==unchecked((int)0x887A0002)) break;
                    Marshal.ThrowExceptionForHR(hr);
                    try {
                        AdapterDesc d; Marshal.ThrowExceptionForHR(((GetDesc)Slot(adapter,10,typeof(GetDesc)))(adapter,out d));
                        if ((d.Flags&2)!=0) continue; // Software adapter is not a physical GPU.
                        rows.Add(new Adapter { Name=d.Description, DedicatedBytes=d.DedicatedVideo.ToUInt64(), SharedBytes=d.SharedSystem.ToUInt64(),
                            Luid="luid_0x"+unchecked((uint)d.LuidHigh).ToString("x8")+"_0x"+d.LuidLow.ToString("x8") });
                    } finally { if (adapter!=IntPtr.Zero) Marshal.Release(adapter); }
                }
            } finally { if (factory!=IntPtr.Zero) Marshal.Release(factory); }
            return rows.ToArray();
        }
    }
}
